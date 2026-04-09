package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import com.example.crm_caller_nxtgen.core.db.AppDatabase
import com.example.crm_caller_nxtgen.core.db.ComplaintEntity
import com.example.crm_caller_nxtgen.core.db.LeadEntity
import com.example.crm_caller_nxtgen.core.db.NoteEntity
import com.example.crm_caller_nxtgen.core.db.OpportunityEntity
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Single data-access point for all overlay CRM operations.
 *
 * Strategy: local-first.
 *  1. lookupIdentityByPhone → Room first (fast), then Frappe network call.
 *     Network result is cached into Room for next time.
 *  2. createLead / createOpportunity / createComplaint → optimistic local save first,
 *     then network. If network fails, entity stays in Room with isSynced=false and
 *     SyncWorker will retry it later.
 *  3. Duplicate prevention: check for existing local record before INSERT.
 */
class FrappeRepository(private val context: Context) {

    private val db by lazy {
        try {
            val dbDir = context.getDatabasePath("crm_caller_database").parentFile
            if (dbDir != null && !dbDir.exists()) dbDir.mkdirs()
        } catch (_: Exception) {}
        AppDatabase.getDatabase(context)
    }

    private val api by lazy { FrappeApiService(context) }

    // Call session tracking (phone → callAnsweredAt timestamp)
    private val sessionStarts = mutableMapOf<String, Long>()

    fun markCallAnswered(phone: String) {
        sessionStarts[phone] = System.currentTimeMillis()
    }

    fun markCallEnded(phone: String) {
        // Keep the value; durationSeconds reads it
    }

    fun getSessionDuration(phone: String): Long {
        val start = sessionStarts[phone] ?: return 0L
        return (System.currentTimeMillis() - start) / 1000L
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LOOKUP
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun lookupIdentityByPhone(phone: String): CallerIdentity? = withContext(Dispatchers.IO) {
        // 1. Local Room lookup (instant)
        val localLead = db.leadDao().getLeadByPhone(phone)
            ?: db.leadDao().getLeadByPhone(phone.takeLast(10))  // partial match fallback

        if (localLead != null) {
            return@withContext localLead.toCallerIdentity()
        }

        // 2. Network lookup (requires Frappe config to be set up in Flutter settings)
        try {
            val remote = api.lookupLeadByPhone(phone) ?: return@withContext null

            // Cache the result locally
            val entity = LeadEntity(
                id            = UUID.randomUUID().toString(),
                frappeDocname = remote.docname,
                phoneNumber   = phone,
                name          = remote.leadName,
                email         = remote.email,
                company       = remote.companyName,
                status        = remote.status,
                isSynced      = true,  // came from server
            )
            db.leadDao().insertLead(entity)
            return@withContext entity.toCallerIdentity()

        } catch (_: Exception) {
            // Network unavailable — treat as unknown, SyncWorker can catch up
            return@withContext null
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE LEAD
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createLead(
        name: String,
        email: String,
        company: String,
        phone: String,
        note: String,
    ): CallerIdentity.Lead = withContext(Dispatchers.IO) {

        // Duplicate guard: refuse to create if phone already exists locally
        val existing = db.leadDao().getLeadByPhone(phone)
        if (existing != null) return@withContext existing.toCallerIdentity() as CallerIdentity.Lead

        val localId = UUID.randomUUID().toString()

        // Optimistic local save — UI immediately shows as created
        val entity = LeadEntity(
            id            = localId,
            frappeDocname = "",        // filled after network succeeds
            phoneNumber   = phone,
            name          = name,
            email         = email,
            company       = company,
            status        = "Lead",
            isSynced      = false,
        )
        db.leadDao().insertLead(entity)

        // Save note if provided
        if (note.isNotBlank()) {
            db.noteDao().insertNote(NoteEntity(
                id          = UUID.randomUUID().toString(),
                phoneNumber = phone,
                content     = note,
                entityType  = "LEAD",
                timestamp   = System.currentTimeMillis(),
                isSynced    = false,
            ))
        }

        // Network sync (best-effort — failure does not block the return)
        try {
            val remote = api.createLead(name, email, company, phone, note)
            val synced = entity.copy(frappeDocname = remote.docname, isSynced = true)
            db.leadDao().updateLead(synced)
            synced.toCallerIdentity() as CallerIdentity.Lead
        } catch (_: Exception) {
            // Return optimistic identity — SyncWorker will sync later
            entity.toCallerIdentity() as CallerIdentity.Lead
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE OPPORTUNITY
    // Returns updated CallerIdentity with hasOpportunity=true
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createOpportunity(
        identity: CallerIdentity,
        expectedValue: Double,
        stage: String,
        note: String,
    ): CallerIdentity = withContext(Dispatchers.IO) {

        val (localLeadId, leadDocname) = when (identity) {
            is CallerIdentity.Lead     -> Pair(identity.localId, identity.docname)
            is CallerIdentity.Customer -> Pair("", identity.leadDocname)
            else -> throw IllegalStateException("Cannot create opportunity for unknown caller")
        }

        val oppId = UUID.randomUUID().toString()
        val entity = OpportunityEntity(
            id            = oppId,
            leadId        = localLeadId,
            leadDocname   = leadDocname,
            dealValue     = expectedValue,
            stage         = stage,
            note          = note,
            isSynced      = false,
        )
        db.opportunityDao().insertOpportunity(entity)

        // Network sync
        try {
            if (leadDocname.isNotBlank()) {
                val remote = api.createOpportunity(leadDocname, expectedValue, stage, note)
                db.opportunityDao().updateOpportunity(entity.copy(
                    frappeDocname = remote.docname,
                    isSynced = true,
                ))
            }
        } catch (_: Exception) { /* SyncWorker retry */ }

        // Return updated identity with hasOpportunity flag
        when (identity) {
            is CallerIdentity.Lead     -> identity.copy(hasOpportunity = true)
            is CallerIdentity.Customer -> identity  // customer already has all flags
            else -> identity
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SAVE NOTE
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun saveNote(phone: String, content: String) = withContext(Dispatchers.IO) {
        if (content.isBlank()) return@withContext
        db.noteDao().insertNote(NoteEntity(
            id          = UUID.randomUUID().toString(),
            phoneNumber = phone,
            content     = content,
            entityType  = "CALL_LOG",
            timestamp   = System.currentTimeMillis(),
            isSynced    = false,
        ))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE COMPLAINT
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createComplaint(
        identity: CallerIdentity,
        phoneArg: String,
        category: String,
        details: String,
        priority: String,
    ): Unit = withContext(Dispatchers.IO) {

        val phone = when (identity) {
            is CallerIdentity.Lead     -> identity.phone
            is CallerIdentity.Customer -> identity.phone
            else -> phoneArg
        }
        val leadDocname = when (identity) {
            is CallerIdentity.Lead     -> identity.docname
            is CallerIdentity.Customer -> identity.leadDocname
            else -> ""
        }
        val callerName = identity.displayName

        val entity = ComplaintEntity(
            id            = UUID.randomUUID().toString(),
            phoneNumber   = phone,
            leadDocname   = leadDocname,
            category      = category,
            description   = details,
            priority      = priority,
            isSynced      = false,
        )
        db.complaintDao().insertComplaint(entity)

        try {
            if (api.getConfig().isValid) {
                val remote = api.createComplaint(
                    leadDocname  = leadDocname.ifBlank { null },
                    category     = category,
                    details      = details,
                    priority     = priority,
                    callerName   = callerName,
                    phone        = phone,
                )
                db.complaintDao().updateComplaint(entity.copy(
                    frappeDocname = remote.docname,
                    isSynced      = true,
                ))
            }
        } catch (_: Exception) { /* SyncWorker retry */ }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapping helpers (Room entity → domain model)
// ─────────────────────────────────────────────────────────────────────────────

private val CallerIdentity.displayName: String
    get() = when (this) {
        is CallerIdentity.Unknown  -> "Unknown"
        is CallerIdentity.Lead     -> name
        is CallerIdentity.Customer -> name
    }

fun LeadEntity.toCallerIdentity(): CallerIdentity.Lead = CallerIdentity.Lead(
    docname      = frappeDocname,
    localId      = id,
    name         = name ?: "Unknown",
    company      = company ?: "",
    email        = email ?: "",
    phone        = phoneNumber,
    status       = status,
    isCustomer   = status == "Converted",
)
