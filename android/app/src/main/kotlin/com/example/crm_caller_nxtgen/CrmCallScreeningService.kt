package com.example.crm_caller_nxtgen

import android.telecom.Call
import android.telecom.CallScreeningService

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
 * through. It only captures the real number and stashes it where CallStateReceiver /
 * CallMonitorService already look for a fallback value.
 */
class CrmCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val number = callDetails.handle?.schemeSpecificPart
        if (!number.isNullOrBlank()) {
            writeStoredValue(this, "crm_caller_phone", number)
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
    }
}
