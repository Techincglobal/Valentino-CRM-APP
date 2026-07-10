package com.example.crm_caller_nxtgen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

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
 * Android 10+ hides EXTRA_INCOMING_NUMBER without READ_CALL_LOG; we intentionally
 * don't request that permission. If the number is null here, CallMonitorService
 * (TelephonyCallback) already stored it in SharedPreferences as a fallback.
 */
class CallStateReceiver : BroadcastReceiver() {

    companion object {
        private const val KEY_LAST_STATE    = "crm_last_phone_state"
        private const val KEY_LAST_PHONE    = "crm_last_phone_number"
        private const val KEY_LAST_TS       = "crm_last_phone_state_ts"
        private const val KEY_IS_INCOMING   = "crm_is_incoming_call"
        private const val DEBOUNCE_MS       = 1500L
        private const val PREFS             = "FlutterSharedPreferences"
    }

    override fun onReceive(context: Context, intent: Intent) {

        // ── Outgoing call — show overlay so this call gets logged too ─────────
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            val outPhone = intent.getStringExtra(Intent.EXTRA_PHONE_NUMBER)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_IS_INCOMING, false)
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
                prefs.edit().putBoolean(KEY_IS_INCOMING, true).apply()

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
                val direction   = if (wasIncoming) "Inbound" else "Outbound"
                val safePhone   = phone
                    ?: readStoredValue(context, "crm_last_out_phone")
                    ?: ""

                // Always clear the incoming flag on IDLE. Critically, also clear
                // crm_caller_phone/crm_caller_name/etc — these are written by the
                // Flutter-side phone_state listener as the only way native code can
                // learn the incoming number on Android 12+ (TelephonyCallback no
                // longer exposes it, and this app deliberately doesn't request
                // READ_CALL_LOG). If left stale, a lagging Flutter listener on the
                // NEXT call causes native to fall back to the PREVIOUS caller's
                // number/identity — e.g. showing a friend's popup when your dad calls.
                prefs.edit()
                    .remove(KEY_IS_INCOMING)
                    .remove(KEY_LAST_STATE)
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
