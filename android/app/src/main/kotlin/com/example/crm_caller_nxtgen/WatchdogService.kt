package com.example.crm_caller_nxtgen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * A ultra-lightweight persistent foreground service that keeps the CRM Caller
 * process alive at all times.
 *
 * When Android kills background processes, this service restarts itself via
 * START_STICKY. This ensures the CallStateReceiver always fires for incoming
 * calls, even if the user hasn't opened the app.
 *
 * The notification is intentionally silent / low priority so it doesn't
 * disturb the user.
 */
class WatchdogService : Service() {

    companion object {
        private const val CHANNEL_ID = "crm_watchdog"
        private const val NOTIFICATION_ID = 9001
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForegroundCompat()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Restart ourselves if killed
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // When the user swipes the app from recents, restart this service
        val restartIntent = Intent(applicationContext, WatchdogService::class.java)
        startService(restartIntent)
        super.onTaskRemoved(rootIntent)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CRM Caller Background",
                NotificationManager.IMPORTANCE_MIN, // completely silent
            ).apply {
                setShowBadge(false)
                description = "Keeps CRM Caller ready for incoming call overlays"
            }
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0),
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CRM Caller")
            .setContentText("Active — overlay ready for incoming calls")
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .build()
    }
}
