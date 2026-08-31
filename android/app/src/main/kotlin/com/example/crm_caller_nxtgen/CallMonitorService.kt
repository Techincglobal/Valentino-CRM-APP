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

    // registerTelephonyCallback()/PhoneStateListener.listen() immediately deliver
    // ONE synthetic callback with whatever the CURRENT call state already is at
    // registration time — this is not a real state transition. If the phone is
    // idle when the service (re)registers (e.g. right after app launch), that
    // synthetic callback reports CALL_STATE_IDLE, and without this guard we'd
    // treat it as a real "call just ended" — firing a phantom overlay popup and
    // a bogus backend log entry for a call that never happened. Only trust an
    // IDLE if we've actually seen a RINGING/OFFHOOK since the last one.
    private var callSessionActive = false
    private var callStartedAt = 0L

    private fun handleState(state: Int, rawPhone: String?) {
        // NOTE: no overlay-permission gate here. Call detection drives both the
        // visual overlay AND backend call logging — logging must never be
        // blocked just because "Display over other apps" wasn't granted.
        // NativeCallOverlayService already self-checks that permission before
        // it tries to actually draw anything (see hasOverlayPermission() there).
        android.util.Log.d("CrmMonitor", "handleState called: state=$state rawPhone=$rawPhone")

        // Logged out — do nothing at all for this call. Returning before the
        // session bookkeeping below means a call that starts while logged out
        // never reaches IDLE with callSessionActive=true, so it is never logged
        // even if the user signs in mid-call.
        if (!hasCrmSession(this)) {
            android.util.Log.d("CrmMonitor", "CallMonitorService: no CRM session — ignoring state=$state")
            return
        }

        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        when (state) {
            TelephonyManager.CALL_STATE_RINGING -> {
                callSessionActive = true
                callStartedAt = System.currentTimeMillis()
                // Mark session as incoming
                prefs.edit()
                    .putBoolean("crm_is_incoming_call", true)
                    .putLong("crm_call_started_at", callStartedAt)
                    .apply()

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
                // If OFFHOOK is the FIRST signal this session (no preceding RINGING),
                // this call skipped ringing entirely — only possible for an outgoing
                // call. Since ACTION_NEW_OUTGOING_CALL no longer fires on recent Android
                // to tell us that directly, and the incoming-flag is deliberately no
                // longer cleared on IDLE (to avoid the cross-receiver race), it would
                // otherwise still read "true" from whatever the LAST real call set it
                // to — mislabeling this new outgoing call as inbound too. Correct it here.
                if (!callSessionActive) {
                    callStartedAt = System.currentTimeMillis()
                    prefs.edit().putBoolean("crm_is_incoming_call", false).apply()
                    // Also drop any stale inbound-caller-ID cache now — it belongs to
                    // whatever call last used it and must not leak into this new
                    // outgoing call's own number resolution at IDLE.
                    clearStoredValue(this, "crm_caller_phone")
                }
                if (callStartedAt == 0L) callStartedAt = System.currentTimeMillis()
                callSessionActive = true
                val phone = rawPhone?.takeIf { it.isNotBlank() }
                    ?: readStoredValue(this, "crm_caller_phone")
                    ?: readStoredValue(this, "crm_last_out_phone")
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ACTIVE
                        if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    },
                )
            }

            TelephonyManager.CALL_STATE_IDLE -> {
                if (!callSessionActive) return  // synthetic initial callback — no real call happened
                callSessionActive = false
                // Deliberately NOT cleared here — CallStateReceiver's IDLE handler reads this
                // same key independently (both fire for one real hangup), and whichever ran
                // first clearing it would make the other always read the false default,
                // permanently mislabeling every other call's direction. It's safe to leave
                // as-is: the NEXT call always overwrites it fresh via RINGING (true) or
                // ACTION_NEW_OUTGOING_CALL (false) before reaching IDLE again.
                val wasIncoming = prefs.getBoolean("crm_is_incoming_call", false)
                val startedAt = callStartedAt.takeIf { it > 0L }
                    ?: prefs.getLong("crm_call_started_at", 0L)
                callStartedAt = 0L

                val direction = if (wasIncoming) "Inbound" else "Outbound"
                // crm_caller_phone is an INBOUND-only cache (written by the caller-ID path)
                // and can hold a stale value from a PREVIOUS inbound call. For an outbound
                // call it must never be consulted before the CallLog-based lookup, or a
                // stale inbound number can silently win over the number actually dialed.
                val phone = if (wasIncoming) {
                    rawPhone?.takeIf { it.isNotBlank() }
                        ?: readStoredValue(this, "crm_caller_phone")
                        ?: readStoredValue(this, "crm_last_out_phone")
                } else {
                    readStoredValue(this, "crm_last_out_phone")
                        // ACTION_NEW_OUTGOING_CALL no longer reaches third-party receivers on
                        // recent Android, so crm_last_out_phone is never set either — query the
                        // CallLog provider directly (READ_CALL_LOG is already held).
                        ?: queryLastOutgoingNumber(this)
                        ?: rawPhone?.takeIf { it.isNotBlank() }
                }
                android.util.Log.d("CrmMonitor", "CallMonitorService IDLE resolved: phone=$phone direction=$direction startedAt=$startedAt wasIncoming=$wasIncoming rawPhone=$rawPhone")
                ContextCompat.startForegroundService(
                    this,
                    Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_CALL_ENDED
                        putExtra("direction", direction)
                        putExtra("call_started_at", startedAt)
                        if (!phone.isNullOrBlank()) putExtra(NativeCallOverlayService.EXTRA_PHONE, phone)
                    },
                )

                // Clear the cached caller identity now that this call is over — otherwise
                // a lagging Flutter phone_state listener on the NEXT call causes native to
                // fall back to THIS call's number/identity (e.g. showing the previous
                // caller's popup for a brand-new, different incoming number).
                clearStoredValue(this, "crm_caller_phone")
                clearStoredValue(this, "crm_caller_name")
                clearStoredValue(this, "crm_caller_type")
                clearStoredValue(this, "crm_caller_docname")
                prefs.edit().remove("crm_call_started_at").apply()
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
