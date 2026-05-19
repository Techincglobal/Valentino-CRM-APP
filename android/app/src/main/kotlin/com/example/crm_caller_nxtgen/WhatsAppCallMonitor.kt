package com.example.crm_caller_nxtgen

import android.app.Notification
import android.content.Intent
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.content.ContextCompat

/**
 * Detects incoming WhatsApp / WhatsApp Business calls via notification events
 * and shows the CRM overlay exactly as a regular phone call would.
 *
 * The user must grant Notification Access in Settings → Notifications → Special
 * app access → Notification access (or the equivalent OEM path).
 *
 * Phone number: WhatsApp doesn't expose the raw number in the notification, so
 * we use "wa:<display_name>" as the overlay phone key. The CRM lookup will find
 * no match (expected), showing the UnknownCaller form pre-tagged as WhatsApp.
 */
class WhatsAppCallMonitor : NotificationListenerService() {

    private var activeNotificationKey: String? = null

    companion object {
        private const val WA_PKG  = "com.whatsapp"
        private const val WAB_PKG = "com.whatsapp.w4b"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return
        if (sbn.packageName != WA_PKG && sbn.packageName != WAB_PKG) return

        val notification = sbn.notification ?: return
        // Only trigger on call category — ignore message notifications
        if (notification.category != Notification.CATEGORY_CALL &&
            notification.category != Notification.CATEGORY_STATUS) return

        val extras = notification.extras ?: return
        val title  = extras.getString(Notification.EXTRA_TITLE) ?: "WhatsApp Caller"

        // Skip if it looks like a message notification rather than a call
        if (notification.category == Notification.CATEGORY_STATUS) {
            val text = extras.getString(Notification.EXTRA_TEXT) ?: ""
            if (!text.contains("call", ignoreCase = true) && !text.contains("Calling", ignoreCase = true)) return
        }

        // Avoid double-triggering for the same call
        if (activeNotificationKey != null) return
        activeNotificationKey = sbn.key

        val intent = Intent(this, NativeCallOverlayService::class.java).apply {
            action = NativeCallOverlayService.ACTION_SHOW
            // Prefix "wa:" lets the Log Call form auto-select WhatsApp type
            putExtra(NativeCallOverlayService.EXTRA_PHONE, "wa:$title")
            putExtra(NativeCallOverlayService.EXTRA_NAME,  title)
            putExtra(NativeCallOverlayService.EXTRA_TYPE,  "WhatsApp")
            putExtra(NativeCallOverlayService.EXTRA_FOUND, false)
        }
        ContextCompat.startForegroundService(this, intent)
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        sbn ?: return
        if (sbn.key != activeNotificationKey) return

        activeNotificationKey = null
        startService(Intent(this, NativeCallOverlayService::class.java).apply {
            action = NativeCallOverlayService.ACTION_CALL_ENDED
            putExtra(NativeCallOverlayService.EXTRA_PHONE, "")
        })
    }
}
