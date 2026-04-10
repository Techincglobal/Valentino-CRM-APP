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
 * INCOMING-ONLY rule:
 *  - RINGING     → set incoming flag = true  → start overlay
 *  - OFFHOOK     → only notify overlay if incoming flag is still true
 *  - IDLE        → only end overlay if it was an incoming call; clear flag
 *  - NEW_OUTGOING_CALL → immediately clear incoming flag + hide any overlay
 *
 * Android 12+ note: EXTRA_INCOMING_NUMBER requires READ_CALL_LOG at runtime.
 * If null, we fall back to the value Flutter stored in SharedPreferences.
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

        // ── Block outgoing calls immediately ──────────────────────────────────
        if (intent.action == Intent.ACTION_NEW_OUTGOING_CALL) {
            // User placed an outgoing call — make absolutely sure no overlay appears
            clearIncomingFlag(context)
            // If overlay is somehow running from a previous call, hide it
            context.startService(
                Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_HIDE
                }
            )
            return
        }

        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        // Overlay permission gate — if not granted, nothing to do
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) return

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
                val isIncoming = prefs.getBoolean(KEY_IS_INCOMING, false)
                if (!isIncoming) return  // outgoing call — do nothing

                val overlayIntent = Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_CALL_ACTIVE
                    if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                }
                ContextCompat.startForegroundService(context, overlayIntent)
            }

            // ── Call ended / hung up ──────────────────────────────────────────
            TelephonyManager.EXTRA_STATE_IDLE -> {
                val wasIncoming = prefs.getBoolean(KEY_IS_INCOMING, false)

                // Always clear the incoming flag on IDLE
                prefs.edit()
                    .remove(KEY_IS_INCOMING)
                    .remove(KEY_LAST_STATE)
                    .apply()

                if (!wasIncoming) return  // was outgoing — no overlay to end

                context.startService(
                    Intent(context, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ENDED
                        if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    }
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private fun clearIncomingFlag(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_IS_INCOMING, false)
            .apply()
    }

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
