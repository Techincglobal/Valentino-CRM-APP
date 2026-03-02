package com.example.crm_caller_nxtgen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager

/**
 * Manifest-registered BroadcastReceiver that fires on every phone state change,
 * including when the app is completely killed. Tracks RINGING → OFFHOOK → IDLE
 * transitions to detect call end and start CallService.
 */
class CallReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val prevState = prefs.getString(KEY_PREV_STATE, TelephonyManager.EXTRA_STATE_IDLE)
            ?: TelephonyManager.EXTRA_STATE_IDLE

        when (state) {
            TelephonyManager.EXTRA_STATE_RINGING -> {
                // Call starts ringing — trigger Truecaller-like lookup overlay!
                val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
                if (!number.isNullOrEmpty()) {
                    prefs.edit().putString(KEY_INCOMING_NUMBER, number).apply()

                    // Immediately start service to fetch CRM data & show popup
                    try {
                        val serviceIntent = Intent(context, CallService::class.java)
                        serviceIntent.putExtra(CallService.EXTRA_PHONE, number)
                        context.startForegroundService(serviceIntent)
                    } catch (_: Exception) {
                        // Handle strict foreground start limits
                    }
                }
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {
                // Call ended or rejected — clean up intent and stop flutter overlay
                val wasActive = prevState == TelephonyManager.EXTRA_STATE_OFFHOOK ||
                        prevState == TelephonyManager.EXTRA_STATE_RINGING

                if (wasActive) {
                    val phone = prefs.getString(KEY_INCOMING_NUMBER, null)
                    if (!phone.isNullOrEmpty()) {
                        // Clear stored number
                        prefs.edit().remove(KEY_INCOMING_NUMBER).apply()
                    }
                }
            }
        }

        // Always persist the latest state for transition detection
        prefs.edit().putString(KEY_PREV_STATE, state).apply()
    }

    companion object {
        const val PREFS = "FlutterSharedPreferences"
        const val KEY_PREV_STATE = "flutter.crm_prev_call_state"
        const val KEY_INCOMING_NUMBER = "flutter.crm_incoming_number"
    }
}
