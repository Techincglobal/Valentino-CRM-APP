package com.example.crm_caller_nxtgen.overlay.data

import android.content.Context
import com.example.crm_caller_nxtgen.core.util.redactPhone
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.example.crm_caller_nxtgen.core.db.AppDatabase
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * WorkManager worker that syncs all unsynced local entities to Frappe.
 *
 * Enqueue whenever:
 *  - App comes to foreground (network may now be available)
 *  - A local-only entity is created while offline
 *  - Frappe connectivity is restored
 *
 * Uses UNIQUE work with KEEP policy so only one instance runs at a time.
 */
class SyncWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val WORK_NAME = "crm_sync"

        fun enqueue(context: Context) {
            val request = OneTimeWorkRequestBuilder<SyncWorker>()
                .build()
            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.KEEP,  // Don't restart if already running
                request,
            )
        }
    }

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val db  = AppDatabase.getDatabase(applicationContext)
        val api = FrappeApiService(applicationContext)
        val config = api.getConfig()

        if (!config.hasSession) return@withContext Result.success()  // nothing to do without session

        // Refresh CSRF token proactively before performing sync requests
        try {
            api.refreshCsrfToken()
        } catch (_: Exception) { }

        var anyFailure = false

        // ── Sync unsynced leads ───────────────────────────────────────────────
        val unsyncedLeads = db.leadDao().getUnsyncedLeads()
        for (lead in unsyncedLeads) {
            if (lead.frappeDocname.isNotBlank()) continue  // already synced
            try {
                val remote = api.createLead(
                    name    = lead.name ?: "",
                    email   = lead.email ?: "",
                    company = lead.company ?: "",
                    phone   = lead.phoneNumber,
                    note    = "",
                )
                db.leadDao().updateLead(lead.copy(frappeDocname = remote.docname, isSynced = true))
            } catch (_: Exception) {
                anyFailure = true
            }
        }

        // ── Sync unsynced opportunities ───────────────────────────────────────
        val unsyncedOpps = db.opportunityDao().getUnsyncedOpportunities()
        for (opp in unsyncedOpps) {
            val leadDocname = opp.leadDocname.ifBlank {
                // Try to find the Frappe docname from the local lead
                db.leadDao().getLeadById(opp.leadId)?.frappeDocname ?: ""
            }
            if (leadDocname.isBlank()) {
                anyFailure = true
                continue
            }
            try {
                val remote = api.createOpportunity(leadDocname, opp.dealValue, opp.stage, opp.note)
                db.opportunityDao().updateOpportunity(
                    opp.copy(leadDocname = leadDocname, frappeDocname = remote.docname, isSynced = true)
                )
            } catch (_: Exception) {
                anyFailure = true
            }
        }

        // ── Sync unsynced complaints ──────────────────────────────────────────
        val unsyncedComplaints = db.complaintDao().getUnsyncedComplaints()
        for (complaint in unsyncedComplaints) {
            try {
                val remote = api.createComplaint(
                    leadDocname  = complaint.leadDocname.ifBlank { null },
                    category     = complaint.category,
                    details      = complaint.description,
                    priority     = complaint.priority,
                    callerName   = "",
                    phone        = complaint.phoneNumber,
                )
                db.complaintDao().updateComplaint(
                    complaint.copy(frappeDocname = remote.docname, isSynced = true)
                )
            } catch (_: Exception) {
                anyFailure = true
            }
        }

        // ── Sync unsynced call logs ───────────────────────────────────────────
        val unsyncedCallLogs = db.callLogDao().getUnsynced()
        for (log in unsyncedCallLogs) {
            if (log.frappeDocname.isNotBlank()) continue
            try {
                val remote = api.createCallLog(
                    phone           = log.phoneNumber,
                    callerName      = log.callerName,
                    leadDocname     = log.leadDocname.ifBlank { null },
                    durationSeconds = log.durationSeconds,
                    notes           = log.notes,
                    callType        = log.callType,
                    direction       = log.direction,
                    status          = log.status,
                )
                db.callLogDao().update(log.copy(frappeDocname = remote.docname, isSynced = true))
            } catch (e: Exception) {
                android.util.Log.e("CrmMonitor", "SyncWorker: call log sync failed for ${redactPhone(log.phoneNumber)}", e)
                anyFailure = true
            }
        }

        if (anyFailure) Result.retry() else Result.success()
    }
}
