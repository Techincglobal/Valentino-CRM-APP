package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import com.example.crm_caller_nxtgen.core.db.AppDatabase
import com.example.crm_caller_nxtgen.core.db.CallLogEntity
import com.example.crm_caller_nxtgen.core.db.ComplaintEntity
import com.example.crm_caller_nxtgen.core.db.LeadEntity
import com.example.crm_caller_nxtgen.core.db.NoteEntity
import com.example.crm_caller_nxtgen.core.db.OpportunityEntity
import com.example.crm_caller_nxtgen.overlay.domain.CallerIdentity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
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

    init {
        // Refresh CSRF token eagerly so the first POST is never blocked by a stale token.
        CoroutineScope(Dispatchers.IO).launch { api.refreshCsrfToken() }
    }

    // Call session tracking (phone → callAnsweredAt timestamp)
    private val sessionStarts = mutableMapOf<String, Long>()

    fun markCallAnswered(phone: String) {
        sessionStarts[phone] = System.currentTimeMillis()
    }

    fun markCallEnded(phone: String) {
        // Keep the value; durationSeconds reads it
    }

    fun getSessionDuration(phone: String): Long {
        val start = sessionStarts.remove(phone) ?: return 0L
        return (System.currentTimeMillis() - start) / 1000L
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST DATA CLEANUP — only callable in debug builds
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun clearLocalLeadByPhone(phone: String) = withContext(Dispatchers.IO) {
        if (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0) return@withContext
        db.leadDao().deleteLeadByPhone(phone, phone.takeLast(10))
    }

    suspend fun clearAllLocalLeads() = withContext(Dispatchers.IO) {
        if (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0) return@withContext
        db.leadDao().deleteAllLeads()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LOOKUP  — local-first with 6h TTL network refresh
    //
    // ┌─ cache hit + fresh (< 6h)  → return instantly from Room
    // ├─ cache hit + stale (> 6h)  → network refresh, update Room, return fresh
    // ├─ cache miss                → network lookup, insert into Room, return
    // └─ network failure           → return stale cache if available, else null
    // ─────────────────────────────────────────────────────────────────────────

    private val CACHE_TTL_MS = 30L * 60 * 1000  // 30 minutes — short enough to stay fresh

    suspend fun lookupIdentityByPhone(phone: String): CallerIdentity? = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()

        val localLead = db.leadDao().getLeadByPhone(phone)
            ?: db.leadDao().getLeadByPhone(phone.takeLast(10))

        // Fast path: synced + cache is fresh
        if (localLead != null && localLead.isSynced &&
            localLead.cachedAt > 0 && (now - localLead.cachedAt) < CACHE_TTL_MS) {
            return@withContext localLead.toCallerIdentity()
        }

        // Network refresh
        return@withContext try {
            val remote = api.lookupLeadByPhone(phone)
            if (remote == null) {
                // Server says unknown — return whatever we have locally (may be null)
                localLead?.toCallerIdentity()
            } else {
                val entity = if (localLead != null) {
                    // Refresh existing cache entry in place
                    localLead.copy(
                        frappeDocname      = remote.docname,
                        name               = remote.leadName,
                        email              = remote.email,
                        company            = remote.companyName,
                        status             = remote.status,
                        isSynced           = true,
                        cachedAt           = now,
                        latestNote         = remote.latestNote,
                        latestQuoteSubject = remote.latestQuoteSubject,
                        latestQuoteAmount  = remote.latestQuoteAmount,
                        latestQuoteStatus  = remote.latestQuoteStatus,
                    )
                } else {
                    LeadEntity(
                        id                 = UUID.randomUUID().toString(),
                        frappeDocname      = remote.docname,
                        phoneNumber        = phone,
                        name               = remote.leadName,
                        email              = remote.email,
                        company            = remote.companyName,
                        status             = remote.status,
                        isSynced           = true,
                        cachedAt           = now,
                        latestNote         = remote.latestNote,
                        latestQuoteSubject = remote.latestQuoteSubject,
                        latestQuoteAmount  = remote.latestQuoteAmount,
                        latestQuoteStatus  = remote.latestQuoteStatus,
                    )
                }
                db.leadDao().insertLead(entity)  // REPLACE strategy handles both insert + update
                entity.toCallerIdentity()
            }
        } catch (_: Exception) {
            // Network unavailable — serve stale cache so the overlay still shows context
            localLead?.toCallerIdentity()
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

        val existing = db.leadDao().getLeadByPhone(phone)

        // Already synced with Frappe — skip creation to avoid duplicates
        if (existing != null && existing.isSynced && existing.frappeDocname.isNotBlank()) {
            return@withContext existing.toCallerIdentity() as CallerIdentity.Lead
        }

        // Use existing unsynced entity (failed previous attempt) or create a new one
        val entity = existing ?: LeadEntity(
            id            = UUID.randomUUID().toString(),
            frappeDocname = "",
            phoneNumber   = phone,
            name          = name,
            email         = email,
            company       = company,
            status        = "Lead",
            isSynced      = false,
        )
        if (existing == null) {
            db.leadDao().insertLead(entity)
        }

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

        // Ensure CSRF token is fresh before the POST — stale tokens cause silent 403s.
        api.refreshCsrfToken()

        // Network sync — throw on failure so the UI can show a proper error.
        // The local save above is kept regardless, so SyncWorker can retry later.
        val remote = api.createLead(name, email, company, phone, note)
        val synced = entity.copy(
            frappeDocname = remote.docname,
            isSynced      = true,
            cachedAt      = System.currentTimeMillis(),
        )
        db.leadDao().updateLead(synced)
        synced.toCallerIdentity() as CallerIdentity.Lead
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
    // SAVE NOTE — saves locally then syncs to Frappe
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun saveNote(
        phone:    String,
        content:  String,
        identity: CallerIdentity? = null,
    ) = withContext(Dispatchers.IO) {
        if (content.isBlank()) return@withContext

        val entity = NoteEntity(
            id          = UUID.randomUUID().toString(),
            phoneNumber = phone,
            content     = content,
            entityType  = "CALL_LOG",
            timestamp   = System.currentTimeMillis(),
            isSynced    = false,
        )
        db.noteDao().insertNote(entity)

        // Resolve docname: prefer identity, fall back to local Room cache
        try {
            val docname: String?
            val doctype: String
            when {
                identity is CallerIdentity.Lead && identity.docname.isNotBlank() -> {
                    docname = identity.docname
                    doctype = "Lead"
                }
                identity is CallerIdentity.Customer && identity.leadDocname.isNotBlank() -> {
                    docname = identity.leadDocname
                    doctype = "Lead"
                }
                else -> {
                    val local = db.leadDao().getLeadByPhone(phone)
                        ?: db.leadDao().getLeadByPhone(phone.takeLast(10))
                    docname = local?.frappeDocname?.ifBlank { null }
                    doctype = "Lead"
                }
            }
            if (!docname.isNullOrBlank() && api.getConfig().isValid) {
                api.addNote(doctype, docname, content)
                db.noteDao().updateNote(entity.copy(isSynced = true))
            }
        } catch (_: Exception) { /* SyncWorker will retry unsynced notes */ }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CREATE QUOTATION
    // Returns the Frappe docname on success, or empty string on network failure.
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createQuotation(
        identity: CallerIdentity,
        subject: String,
        amount: Double,
        note: String,
    ): String = withContext(Dispatchers.IO) {
        val (leadDocname, partyType) = when (identity) {
            is CallerIdentity.Lead     -> Pair(identity.docname,     "Lead")
            is CallerIdentity.Customer -> Pair(identity.leadDocname, "Customer")
            else -> throw IllegalStateException("Cannot create quotation for unknown caller")
        }

        return@withContext try {
            if (api.getConfig().isValid && leadDocname.isNotBlank()) {
                val result = api.createQuotation(
                    leadDocname = leadDocname,
                    partyType   = partyType,
                    subject     = subject,
                    amount      = amount,
                    note        = note,
                )
                result.docname
            } else ""
        } catch (_: Exception) { "" }
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

        if (!api.getConfig().isValid) throw IllegalStateException("Not connected to server")
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

    // ─────────────────────────────────────────────────────────────────────────
    // CALL LOG — local-first, then sync to Frappe Communication doctype
    // ─────────────────────────────────────────────────────────────────────────

    suspend fun createCallLog(
        identity: CallerIdentity,
        phoneArg: String,
        durationSeconds: Long,
        notes: String,
        callType: String,
        direction: String = "Inbound",
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
        val callerName = when (identity) {
            is CallerIdentity.Unknown  -> "Unknown"
            is CallerIdentity.Lead     -> identity.name
            is CallerIdentity.Customer -> identity.name
        }

        val entity = CallLogEntity(
            id              = UUID.randomUUID().toString(),
            phoneNumber     = phone,
            callerName      = callerName,
            leadDocname     = leadDocname,
            durationSeconds = durationSeconds,
            notes           = notes,
            callType        = callType,
            direction       = direction,
            createdAt       = System.currentTimeMillis(),
            isSynced        = false,
        )
        db.callLogDao().insert(entity)

        // Best-effort network sync — if offline or config missing, SyncWorker retries later
        if (!api.getConfig().isValid) return@withContext
        try {
            val remote = api.createCallLog(
                phone           = phone,
                callerName      = callerName,
                leadDocname     = leadDocname.ifBlank { null },
                durationSeconds = durationSeconds,
                notes           = notes,
                callType        = callType,
                direction       = direction,
            )
            db.callLogDao().update(entity.copy(
                frappeDocname = remote.docname,
                isSynced      = true,
            ))
        } catch (_: Exception) { /* SyncWorker retries unsynced call logs */ }
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
    docname            = frappeDocname,
    localId            = id,
    name               = name ?: "Unknown",
    company            = company ?: "",
    email              = email ?: "",
    phone              = phoneNumber,
    status             = status,
    isCustomer         = status == "Converted",
    latestNote         = latestNote,
    latestQuoteSubject = latestQuoteSubject,
    latestQuoteAmount  = latestQuoteAmount,
    latestQuoteStatus  = latestQuoteStatus,
)
