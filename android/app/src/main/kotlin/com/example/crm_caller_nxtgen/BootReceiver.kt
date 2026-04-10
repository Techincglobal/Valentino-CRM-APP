package com.example.crm_caller_nxtgen

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Starts CallMonitorService automatically after device reboot.
 * Handles standard BOOT_COMPLETED plus quick-boot variants used by Samsung/HTC.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> CallMonitorService.start(context)
        }
    }
}
