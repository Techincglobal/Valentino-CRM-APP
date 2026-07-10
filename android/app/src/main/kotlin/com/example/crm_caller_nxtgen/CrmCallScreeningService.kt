package com.example.crm_caller_nxtgen

import android.content.Intent
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * Modern, Play-Protect-safe way to learn the incoming caller's number on Android 10+.
 *
 * Since API 29, the OS strips the real number out of the PHONE_STATE broadcast unless
 * the app holds READ_CALL_LOG — a permission that matches Google's stalkerware
 * detection profile (removed from this app for that exact reason). The sanctioned
 * alternative is the system "Caller ID & spam blocking" role (RoleManager.
 * ROLE_CALL_SCREENING), the same mechanism apps like Truecaller/Hiya use — holding it
 * does not trigger the same flagging.
 *
 * This service never blocks, rejects, or alters a call — onScreenCall always allows it
 * through. It only captures the real number.
 *
 * IMPORTANT: this fires ACTION_SHOW directly with the real number instead of only
 * writing it to shared prefs for CallStateReceiver/CallMonitorService to read later.
 * Telecom (which drives this service) and Telephony (which drives those two) are
 * independent subsystems with no ordering guarantee between them — relying on a
 * shared-prefs handoff meant the fallback path could read a stale/blank value if it
 * ran first, silently showing "Hidden" (or worse, a stale cached identity) even
 * though the real number was available moments later. Firing directly here removes
 * that race: this is the authoritative, guaranteed-real-number path.
 */
class CrmCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "CrmScreening"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created/bound by Telecom")
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val number = callDetails.handle?.schemeSpecificPart
        Log.d(TAG, "onScreenCall fired — number=$number handle=${callDetails.handle}")
        if (!number.isNullOrBlank()) {
            writeStoredValue(this, "crm_caller_phone", number)
            ContextCompat.startForegroundService(
                this,
                Intent(this, NativeCallOverlayService::class.java).apply {
                    action = NativeCallOverlayService.ACTION_SHOW
                    putExtra(NativeCallOverlayService.EXTRA_PHONE, number)
                },
            )
            Log.d(TAG, "ACTION_SHOW dispatched with real number")
        } else {
            Log.w(TAG, "callDetails.handle had no usable number")
        }
        respondToCall(
            callDetails,
            CallResponse.Builder()
                .setDisallowCall(false)
                .setRejectCall(false)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build(),
        )
        Log.d(TAG, "respondToCall sent")
    }
}
