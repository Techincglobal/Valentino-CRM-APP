package com.example.crm_caller_nxtgen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat

class CallStateReceiver : BroadcastReceiver() {
    companion object {
        private const val KEY_LAST_PHONE_STATE = "crm_last_phone_state"
        private const val KEY_LAST_PHONE_NUMBER = "crm_last_phone_number"
        private const val KEY_LAST_PHONE_STATE_TS = "crm_last_phone_state_ts"
        private const val DUPLICATE_STATE_WINDOW_MS = 1500L
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(context)
        ) {
            return
        }

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val phone = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            ?: readStoredValue(context, "crm_caller_phone")
        if (isDuplicateState(context, state, phone)) {
            return
        }

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                if (phone.isNullOrBlank()) return

                val overlayIntent = Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_SHOW
                    putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                }
                ContextCompat.startForegroundService(context, overlayIntent)
            }

            TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                val overlayIntent = Intent(context, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_CALL_ACTIVE
                    if (!phone.isNullOrBlank()) {
                        putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    }
                }
                ContextCompat.startForegroundService(context, overlayIntent)
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                context.startService(
                    Intent(context, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ENDED
                        if (!phone.isNullOrBlank()) {
                            putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                        }
                    },
                )
            }
        }
    }

    private fun isDuplicateState(context: Context, state: String, phone: String?): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val lastState = prefs.getString(KEY_LAST_PHONE_STATE, null)
        val lastPhone = prefs.getString(KEY_LAST_PHONE_NUMBER, null)
        val lastTs = prefs.getLong(KEY_LAST_PHONE_STATE_TS, 0L)
        val isDuplicate = lastState == state &&
            (lastPhone ?: "") == (phone ?: "") &&
            now - lastTs < DUPLICATE_STATE_WINDOW_MS

        prefs.edit()
            .putString(KEY_LAST_PHONE_STATE, state)
            .putString(KEY_LAST_PHONE_NUMBER, phone ?: "")
            .putLong(KEY_LAST_PHONE_STATE_TS, now)
            .apply()

        return isDuplicate
    }
}

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
