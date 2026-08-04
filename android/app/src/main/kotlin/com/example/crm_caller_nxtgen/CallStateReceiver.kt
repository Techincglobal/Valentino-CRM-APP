package com.example.crm_caller_nxtgen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import kotlinx.coroutines.delay

/**
 * Listens for phone state changes and drives the overlay service.
 *
 * Both directions are tracked so every call — inbound and outbound — gets
 * logged:
 *  - NEW_OUTGOING_CALL → mark session as outbound, show overlay for the number
 *  - RINGING           → mark session as inbound,  show overlay for the caller
 *  - OFFHOOK           → notify overlay the call is active (either direction)
 *  - IDLE              → always end the overlay/log the call (either direction)
 *
 * Android 10+ hides EXTRA_INCOMING_NUMBER unless the app holds READ_CALL_LOG — the
 * app now requests it (see MainActivity.requestRuntimePermissions) after the
 * ROLE_CALL_SCREENING replacement was confirmed, via live device testing, to never
 * actually get invoked by Telecom. If the permission was denied or the extra is
 * still null for some other reason, CallMonitorService (TelephonyCallback) or the
 * Flutter phone_state listener may have already stored a number in SharedPreferences
 * as a fallback.
 */
class CallStateReceiver : BroadcastReceiver() {

    companion object {
        private const val KEY_LAST_STATE    = "crm_last_phone_state"
        private const val KEY_LAST_PHONE    = "crm_last_phone_number"
        private const val KEY_LAST_TS       = "crm_last_phone_state_ts"
        private const val KEY_IS_INCOMING   = "crm_is_incoming_call"
        private const val KEY_CALL_STARTED_AT = "crm_call_started_at"
        private const val DEBOUNCE_MS       = 1500L
        private const val PREFS             = "FlutterSharedPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d("CrmMonitor", "CallStateReceiver.onReceive action=${intent.action} state=${intent.getStringExtra(TelephonyManager.EXTRA_STATE)}")

        // ── Outgoing call — show overlay so this call gets logged too ─────────
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            val outPhone = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_IS_INCOMING, false)
                .putLong(KEY_CALL_STARTED_AT, System.currentTimeMillis())
                .putString("crm_last_out_phone", outPhone ?: "")
                .apply()

            if (!outPhone.isNullOrBlank() &&
                (Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context))
            ) {
                ContextCompat.startForegroundService(
                    context,
                    Intent(context, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_SHOW
                        putExtra(NativeCallOverlayService.EXTRA_PHONE, outPhone)
                        putExtra("direction", "Outbound")
                    },
                )
            }
            return
        }

        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        // NOTE: no overlay-permission gate here. Call detection drives both the
        // visual overlay AND backend call logging — logging must never be
        // blocked just because "Display over other apps" wasn't granted.
        // NativeCallOverlayService already self-checks that permission before
        // it tries to actually draw anything (see hasOverlayPermission() there).

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return

        // Resolve phone number: try the broadcast extra first, then our stored fallback
        val phone: String? = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            ?.takeIf { it.isNotBlank() }
            ?: readStoredValue(context, "crm_caller_phone")?.takeIf { it.isNotBlank() }

        // Debounce: ignore duplicate state+phone combos within 1.5 s
        if (isDuplicate(context, state, phone)) return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        when (state) {

            // ── Phone is ringing ──────────────────────────────────────────────
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Mark this session as incoming so OFFHOOK/IDLE know to act
                prefs.edit()
                    .putBoolean(KEY_IS_INCOMING, true)
                    .putLong(KEY_CALL_STARTED_AT, System.currentTimeMillis())
                    .apply()

                // Use "Hidden" if the number wasn't available (Android 10+ privacy mask)
                val safePhone = phone?.takeIf { it.isNotBlank() } ?: "Hidden"

                val overlayIntent = Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_SHOW
                    putExtra(NativeCallOverlayService.EXTRA_PHONE, safePhone)
                }
                ContextCompat.startForegroundService(context, overlayIntent)
            }

            // ── Call answered ─────────────────────────────────────────────────
            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                if (prefs.getLong(KEY_CALL_STARTED_AT, 0L) == 0L) {
                    // An outgoing call may begin with OFFHOOK, without the outgoing
                    // broadcast being delivered on newer Android versions.
                    prefs.edit().putLong(KEY_CALL_STARTED_AT, System.currentTimeMillis()).apply()
                }
                val activePhone = phone
                    ?: readStoredValue(context, "crm_last_out_phone")
                    ?: ""
                val overlayIntent = Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_CALL_ACTIVE
                    if (activePhone.isNotBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, activePhone)
                }
                ContextCompat.startForegroundService(context, overlayIntent)
            }

            // ── Call ended / hung up ──────────────────────────────────────────
            TelephonyManager.EXTRA_STATE_IDLE -> {
                val wasIncoming = prefs.getBoolean(KEY_IS_INCOMING, false)
                val startedAt = prefs.getLong(KEY_CALL_STARTED_AT, 0L)
                val direction   = if (wasIncoming) "Inbound" else "Outbound"
                // `phone` (EXTRA_INCOMING_NUMBER / crm_caller_phone fallback, computed above)
                // is an INBOUND-only signal — crm_caller_phone is written specifically by the
                // inbound caller-ID path and can hold a stale leftover value from a PREVIOUS
                // inbound call. For an outbound call it must never be consulted before the
                // CallLog-based lookup, or a stale inbound number can silently win and get
                // logged as this call's number instead of the number actually dialed.
                val safePhone = if (wasIncoming) {
                    phone ?: readStoredValue(context, "crm_last_out_phone") ?: ""
                } else {
                    readStoredValue(context, "crm_last_out_phone")
                        // ACTION_NEW_OUTGOING_CALL no longer reaches third-party receivers on
                        // recent Android, so crm_last_out_phone is never set either — query the
                        // CallLog provider directly (READ_CALL_LOG is already held).
                        ?: queryLastOutgoingNumber(context)
                        ?: phone
                        ?: ""
                }
                android.util.Log.d("CrmMonitor", "CallStateReceiver IDLE resolved: phone=$safePhone direction=$direction startedAt=$startedAt wasIncoming=$wasIncoming rawPhoneExtra=$phone")

                // KEY_IS_INCOMING deliberately NOT cleared here — CallMonitorService's IDLE
                // handler reads this same key independently (both fire for one real hangup),
                // and whichever ran first clearing it would make the other always read the
                // false default, permanently mislabeling every other call's direction. It's
                // safe to leave as-is: the NEXT call always overwrites it fresh via RINGING
                // (true) or ACTION_NEW_OUTGOING_CALL (false) before reaching IDLE again.
                //
                // Still clear crm_caller_phone/crm_caller_name/etc — these ARE safe/necessary
                // to clear per-call (see clearStoredValue calls below), unrelated to the race.
                prefs.edit()
                    .remove(KEY_LAST_STATE)
                    .remove(KEY_CALL_STARTED_AT)
                    .remove("crm_last_out_phone")
                    .apply()
                clearStoredValue(context, "crm_caller_phone")
                clearStoredValue(context, "crm_caller_name")
                clearStoredValue(context, "crm_caller_type")
                clearStoredValue(context, "crm_caller_docname")

                ContextCompat.startForegroundService(
                    context,
                    Intent(context, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ENDED
                        putExtra("direction", direction)
                        putExtra("call_started_at", startedAt)
                        if (safePhone.isNotBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, safePhone)
                    }
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun isDuplicate(context: Context, state: String, phone: String?): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now       = System.currentTimeMillis()
        val lastState = prefs.getString(KEY_LAST_STATE, null)
        val lastPhone = prefs.getString(KEY_LAST_PHONE, null)
        val lastTs    = prefs.getLong(KEY_LAST_TS, 0L)

        val isDup = lastState == state &&
            (lastPhone ?: "") == (phone ?: "") &&
            now - lastTs < DEBOUNCE_MS

        prefs.edit()
            .putString(KEY_LAST_STATE, state)
            .putString(KEY_LAST_PHONE, phone ?: "")
            .putLong(KEY_LAST_TS, now)
            .apply()

        return isDup
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Outgoing number lookup via CallLog content provider
//
// Intent.ACTION_NEW_OUTGOING_CALL — the only other way to learn an outgoing
// number — has been confirmed (via live device testing) to no longer reach
// third-party BroadcastReceivers on recent Android versions; it simply never
// fires. Since the app now holds READ_CALL_LOG (for inbound EXTRA_INCOMING_NUMBER),
// the same permission also grants read access to this content provider, so we
// use it as the reliable way to resolve an outgoing call's number instead.
// ─────────────────────────────────────────────────────────────────────────────

internal fun queryLastOutgoingNumber(context: Context): String? {
    return try {
        val result = context.contentResolver.query(
            android.provider.CallLog.Calls.CONTENT_URI,
            arrayOf(android.provider.CallLog.Calls.NUMBER, android.provider.CallLog.Calls.TYPE, android.provider.CallLog.Calls.DATE),
            "${android.provider.CallLog.Calls.TYPE} = ?",
            arrayOf(android.provider.CallLog.Calls.OUTGOING_TYPE.toString()),
            // No LIMIT here — this provider's sortOrder validator rejects it outright
            // ("Invalid token LIMIT") on recent Android. moveToFirst() on the DESC-sorted
            // cursor below already gets the single most recent row without it.
            "${android.provider.CallLog.Calls.DATE} DESC",
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                cursor.getString(cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.NUMBER))
                    ?.takeIf { it.isNotBlank() }
            } else null
        }
        android.util.Log.d("CrmMonitor", "queryLastOutgoingNumber result=$result")
        result
    } catch (e: Exception) {
        android.util.Log.e("CrmMonitor", "queryLastOutgoingNumber threw", e)
        null
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Call outcome lookup via CallLog content provider
//
// TelephonyManager's RINGING/OFFHOOK/IDLE transitions can't reliably tell us
// whether a call was actually answered, missed, rejected, or blocked — most
// notably, OFFHOOK fires for an OUTGOING call the instant it's dialed,
// regardless of whether the far end ever picks up. Android's own CallLog
// provider, however, already classifies every call correctly (the system
// writes this entry right as the call ends) — read that instead of trying to
// reconstruct the outcome ourselves.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Wait for Android to commit this call's CallLog row, then return the outcome
 * only if it belongs to this call. At IDLE the provider commonly still exposes
 * the previous row for a short time, which was why every record became Answered.
 */
internal suspend fun waitForSystemCallStatus(
    context: Context,
    phone: String,
    direction: String,
    startedAt: Long,
): String? {
    repeat(5) { attempt ->
        if (attempt > 0) delay(500L)
        queryLatestSystemCallStatus(context, phone, direction, startedAt)?.let { return it }
    }
    return null
}

internal fun queryLatestSystemCallStatus(
    context: Context,
    phone: String,
    direction: String,
    startedAt: Long,
): String? {
    return try {
        val result = context.contentResolver.query(
            android.provider.CallLog.Calls.CONTENT_URI,
            arrayOf(
                android.provider.CallLog.Calls.NUMBER,
                android.provider.CallLog.Calls.TYPE,
                android.provider.CallLog.Calls.DATE,
                android.provider.CallLog.Calls.DURATION,
            ),
            null,
            null,
            "${android.provider.CallLog.Calls.DATE} DESC",
        )?.use { cursor ->
            val phoneDigits = phone.filter { it.isDigit() }.takeLast(10)
            val earliestDate = if (startedAt > 0L) startedAt - 5_000L else System.currentTimeMillis() - 120_000L
            while (cursor.moveToNext()) {
                val rowPhone = cursor.getString(cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.NUMBER)).orEmpty()
                val rowDigits = rowPhone.filter { it.isDigit() }.takeLast(10)
                val type = cursor.getInt(cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.TYPE))
                val date = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.DATE))
                val duration = cursor.getLong(cursor.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION))

                if (date < earliestDate) break
                if (phoneDigits.isNotBlank() && rowDigits != phoneDigits) continue

                val isInboundType = type in setOf(
                    android.provider.CallLog.Calls.INCOMING_TYPE,
                    android.provider.CallLog.Calls.MISSED_TYPE,
                    android.provider.CallLog.Calls.REJECTED_TYPE,
                    android.provider.CallLog.Calls.BLOCKED_TYPE,
                    android.provider.CallLog.Calls.VOICEMAIL_TYPE,
                )
                if ((direction == "Inbound") != isInboundType) continue

                return@use when (type) {
                    android.provider.CallLog.Calls.INCOMING_TYPE,
                    android.provider.CallLog.Calls.ANSWERED_EXTERNALLY_TYPE -> "Answered"
                    android.provider.CallLog.Calls.OUTGOING_TYPE -> if (duration > 0L) "Answered" else "No Answer"
                    android.provider.CallLog.Calls.MISSED_TYPE -> "Missed"
                    android.provider.CallLog.Calls.REJECTED_TYPE,
                    android.provider.CallLog.Calls.BLOCKED_TYPE -> "Rejected"
                    android.provider.CallLog.Calls.VOICEMAIL_TYPE -> "No Answer"
                    else -> null
                }
            }
            null
        }
        android.util.Log.d("CrmMonitor", "queryLatestSystemCallStatus result=$result")
        result
    } catch (e: Exception) {
        android.util.Log.e("CrmMonitor", "queryLatestSystemCallStatus threw", e)
        null
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// SharedPreferences helpers (Flutter keys are prefixed with "flutter.")
// ─────────────────────────────────────────────────────────────────────────────

internal fun readStoredValue(context: Context, key: String): String? {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    return prefs.getString(key, null) ?: prefs.getString("flutter.$key", null)
}

internal fun writeStoredValue(context: Context, key: String, value: String) {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    prefs.edit()
        .putString(key, value)
        .putString("flutter.$key", value)
        .apply()
}

internal fun writeStoredBool(context: Context, key: String, value: Boolean) {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    prefs.edit()
        .putBoolean(key, value)
        .putBoolean("flutter.$key", value)
        .apply()
}

internal fun clearStoredValue(context: Context, key: String) {
    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
    prefs.edit()
        .remove(key)
        .remove("flutter.$key")
        .apply()
}
