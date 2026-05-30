package com.example.crm_caller_nxtgen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.content.pm.PackageManager
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Persistent foreground service that monitors phone state and starts the overlay service.
 *
 * WHY THIS EXISTS:
 * Android 8+ restricts BroadcastReceivers from starting ForegroundServices when the app is
 * not running. However, a *running* ForegroundService can start another ForegroundService
 * without restriction (service-to-service starts are always allowed).
 *
 * This service stays alive continuously (START_STICKY + BootReceiver), listens for
 * incoming calls via TelephonyCallback/PhoneStateListener, and starts
 * NativeCallOverlayService directly — bypassing the background start restriction.
 *
 * CallStateReceiver is kept as a fallback (it works when the app is already running).
 * The OverlayStateMachine's duplicate-event guard handles both firing simultaneously.
 */
class CallMonitorService : Service() {

    companion object {
        private const val CHANNEL_ID = "crm_call_monitor"
        private const val NOTIF_ID   = 2008

        fun start(context: Context) {
            ContextCompat.startForegroundService(
                context,
                Intent(context, CallMonitorService::class.java),
            )
        }
    }

    private var telephonyManager: TelephonyManager? = null

    // API 31+ callback (stored as Any to avoid ClassNotFound on older devices)
    private var telephonyCallback: Any? = null

    @Suppress("DEPRECATION")
    private var legacyListener: PhoneStateListener? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        try {
            createNotificationChannel()
            // Layered startForeground — never crash regardless of OEM or Android version
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                try {
                    startForeground(NOTIF_ID, buildNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                } catch (_: Exception) {
                    startForeground(NOTIF_ID, buildNotification())
                }
            } else {
                startForeground(NOTIF_ID, buildNotification())
            }
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            registerPhoneListener()
        } catch (e: Exception) {
            android.util.Log.e("CrmMonitor", "CallMonitorService onCreate failed: $e")
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Ensure foreground if system restarted us after being killed by OEM battery saver
        try {
            createNotificationChannel()
            startForeground(NOTIF_ID, buildNotification())
            registerPhoneListener()
        } catch (_: Exception) { }
        return START_STICKY
    }

    override fun onDestroy() {
        unregisterPhoneListener()
        super.onDestroy()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Telephony listener
    // ─────────────────────────────────────────────────────────────────────────

    private fun registerPhoneListener() {
        if (telephonyCallback != null || legacyListener != null) {
            return
        }
        if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED) {
            android.util.Log.w("CrmMonitor", "Cannot register phone listener: READ_PHONE_STATE permission not granted")
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val cb = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) = handleState(state, null)
                }
                telephonyCallback = cb
                telephonyManager?.registerTelephonyCallback(mainExecutor, cb)
            } else {
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Deprecated("Deprecated in Java")
                    override fun onCallStateChanged(state: Int, number: String?) =
                        handleState(state, number)
                }
                legacyListener = listener
                @Suppress("DEPRECATION")
                telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
            }
            android.util.Log.i("CrmMonitor", "Phone listener registered successfully")
        } catch (e: Exception) {
            // Some OEMs (MIUI, ColorOS) may restrict TelephonyCallback registration.
            // CallStateReceiver broadcast is still active as fallback.
            android.util.Log.e("CrmMonitor", "Failed to register phone listener: $e")
        }
    }

    private fun unregisterPhoneListener() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (telephonyCallback as? TelephonyCallback)?.let {
                telephonyManager?.unregisterTelephonyCallback(it)
            }
        } else {
            @Suppress("DEPRECATION")
            legacyListener?.let {
                @Suppress("DEPRECATION")
                telephonyManager?.listen(it, PhoneStateListener.LISTEN_NONE)
            }
        }
        telephonyCallback = null
        legacyListener    = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Call state handler
    // ─────────────────────────────────────────────────────────────────────────

    private fun handleState(state: Int, rawPhone: String?) {
        // Overlay permission gate
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) return

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                // Mark session as incoming
                prefs.edit().putBoolean("crm_is_incoming_call", true).apply()

                // Resolve number: callback param (legacy API) → stored prefs fallback → "Hidden"
                val phone = rawPhone?.takeIf { it.isNotBlank() }
                    ?: readStoredValue(this, "crm_caller_phone")?.takeIf { it.isNotBlank() }
                    ?: "Hidden"

                // Service-to-service start — no background restriction applies
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_SHOW
                        putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    },
                )
            }

            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (!prefs.getBoolean("crm_is_incoming_call", false)) return
                val phone = rawPhone?.takeIf { it.isNotBlank() }
                    ?: readStoredValue(this, "crm_caller_phone")
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ACTIVE
                        if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    },
                )
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                val wasIncoming = prefs.getBoolean("crm_is_incoming_call", false)
                prefs.edit().remove("crm_is_incoming_call").apply()
                if (!wasIncoming) return

                val phone = rawPhone?.takeIf { it.isNotBlank() }
                    ?: readStoredValue(this, "crm_caller_phone")
                startService(
                    Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ENDED
                        if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    },
                )
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Silent low-priority notification (required for ForegroundService)
    // ─────────────────────────────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Call Monitor",
                NotificationManager.IMPORTANCE_MIN,
            ).apply {
                description = "Monitors for incoming calls in the background"
                setShowBadge(false)
                setSound(null, null)
                enableLights(false)
                enableVibration(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("CRM Caller")
            .setContentText("Ready for incoming calls")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()
}
