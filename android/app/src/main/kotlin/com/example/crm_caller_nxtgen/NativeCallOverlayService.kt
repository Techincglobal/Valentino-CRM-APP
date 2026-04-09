package com.example.crm_caller_nxtgen

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.Toast
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.ComposeView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.example.crm_caller_nxtgen.overlay.data.FrappeRepository
import com.example.crm_caller_nxtgen.overlay.data.SessionTimerManager
import com.example.crm_caller_nxtgen.overlay.data.SyncWorker
import com.example.crm_caller_nxtgen.overlay.domain.CallPhase
import com.example.crm_caller_nxtgen.overlay.domain.ComplaintPopupState
import com.example.crm_caller_nxtgen.overlay.domain.OverlayEvent
import com.example.crm_caller_nxtgen.overlay.domain.OverlaySideEffect
import com.example.crm_caller_nxtgen.overlay.domain.OverlayState
import com.example.crm_caller_nxtgen.overlay.domain.needsFocus
import com.example.crm_caller_nxtgen.overlay.domain.shouldShowWindow
import com.example.crm_caller_nxtgen.overlay.recording.CallRecorder
import com.example.crm_caller_nxtgen.overlay.state.OverlayStateMachine
import com.example.crm_caller_nxtgen.overlay.ui.ComplaintPopupRoot
import com.example.crm_caller_nxtgen.overlay.ui.OverlayRoot
import com.example.crm_caller_nxtgen.overlay.ui.WindowLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class NativeCallOverlayService : Service() {

    companion object {
        const val ACTION_SHOW        = "crm_caller_nxtgen.action.SHOW"
        const val ACTION_CALL_ACTIVE = "crm_caller_nxtgen.action.CALL_ACTIVE"
        const val ACTION_CALL_ENDED  = "crm_caller_nxtgen.action.CALL_ENDED"
        const val ACTION_HIDE        = "crm_caller_nxtgen.action.HIDE"
        const val EXTRA_PHONE        = "phone"
        const val EXTRA_NAME         = "name"
        const val EXTRA_TYPE         = "type"
        const val EXTRA_DOCNAME      = "docname"
        const val EXTRA_FOUND        = "found"

        private const val CHANNEL_ID      = "crm_caller_overlay"
        private const val NOTIFICATION_ID = 2007
        private const val EDGE_MARGIN_DP  = 16
    }

    private val handler      = Handler(Looper.getMainLooper())
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // ── Main overlay window ───────────────────────────────────────────────────
    private var windowManager: WindowManager? = null
    private var composeView: ComposeView?      = null
    private var lifecycleOwner: WindowLifecycleOwner? = null
    private var params: WindowManager.LayoutParams?   = null

    private var windowX = 24
    private var windowY = 200

    // ── Complaint popup window (second overlay) ───────────────────────────────
    private var complaintView: ComposeView?           = null
    private var complaintLifecycle: WindowLifecycleOwner? = null

    // ── Core dependencies ─────────────────────────────────────────────────────
    private lateinit var stateMachine: OverlayStateMachine
    private lateinit var repository: FrappeRepository
    private lateinit var timerManager: SessionTimerManager
    private lateinit var callRecorder: CallRecorder

    private var wakeLock: PowerManager.WakeLock? = null

    // ─────────────────────────────────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────────────────────────────────

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        repository    = FrappeRepository(applicationContext)
        timerManager  = SessionTimerManager(serviceScope)
        stateMachine  = OverlayStateMachine(repository, serviceScope)
        callRecorder  = CallRecorder(applicationContext)

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "crm:overlay_wakelock")

        createNotificationChannel()
        startForegroundCompat()
        observeSideEffects()
        observeStateForWindowFlags()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        wakeLock?.acquire(10_000L)

        when (intent?.action) {
            ACTION_HIDE -> {
                cleanup()
                return START_NOT_STICKY
            }

            ACTION_SHOW -> {
                if (!hasOverlayPermission()) { stopSelf(); return START_NOT_STICKY }
                val phone = intent.getStringExtra(EXTRA_PHONE) ?: ""
                if (phone.isNotBlank()) {
                    timerManager.reset()
                    stateMachine.handleEvent(OverlayEvent.CallRinging(phone))
                    ensureWindowShown()
                }
            }

            ACTION_CALL_ACTIVE -> {
                val phone = intent.getStringExtra(EXTRA_PHONE) ?: ""
                repository.markCallAnswered(phone)
                timerManager.start()
                stateMachine.handleEvent(OverlayEvent.CallAnswered)
                updateNotification("In call — CRM overlay active")
            }

            ACTION_CALL_ENDED -> {
                val phone = intent.getStringExtra(EXTRA_PHONE) ?: ""
                timerManager.stop()
                repository.markCallEnded(phone)
                stateMachine.handleEvent(OverlayEvent.CallEnded)
                updateNotification("Call ended — overlay open")
                SyncWorker.enqueue(applicationContext)
                // No auto-dismiss — overlay stays until user closes it
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        if (callRecorder.isRecording) callRecorder.stopRecording()
        removeComplaintPopup()
        removeOverlay()
        serviceScope.cancel()
        super.onDestroy()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Main overlay window management
    // ─────────────────────────────────────────────────────────────────────────

    private fun ensureWindowShown() {
        if (composeView != null) {
            updateComposeContent()
            return
        }

        lifecycleOwner = WindowLifecycleOwner()
        composeView = ComposeView(this).apply {
            lifecycleOwner?.attachTo(this)
            lifecycleOwner?.onCreate()
            lifecycleOwner?.onStart()
            lifecycleOwner?.onResume()
        }

        params = buildWindowParams(focusable = false)
        updateComposeContent()

        try {
            windowManager?.addView(composeView, params)
        } catch (_: Exception) { }
    }

    private fun updateComposeContent() {
        composeView?.setContent {
            OverlayRoot(
                stateMachine = stateMachine,
                timerManager = timerManager,
                onClose      = { stateMachine.handleEvent(OverlayEvent.DismissOverlay) },
                onDrag       = { dx, dy -> handleDrag(dx, dy) },
                onDragEnd    = { snapToEdge() },
            )
        }
    }

    private fun handleDrag(dx: Float, dy: Float) {
        params?.let { p ->
            windowX = (windowX + dx.toInt()).coerceAtLeast(0)
            windowY = (windowY + dy.toInt()).coerceAtLeast(0)
            p.x = windowX
            p.y = windowY
            try { windowManager?.updateViewLayout(composeView, p) } catch (_: Exception) {}
        }
    }

    private fun snapToEdge() {
        val displayMetrics = resources.displayMetrics
        val screenWidth    = displayMetrics.widthPixels
        val density        = displayMetrics.density
        val edgeMargin     = (EDGE_MARGIN_DP * density).toInt()

        val snapToRight = windowX > screenWidth / 2
        val targetX     = if (snapToRight) screenWidth - edgeMargin - (composeView?.width ?: 200)
                          else edgeMargin

        val steps  = 8
        val deltaX = (targetX - windowX) / steps
        var step   = 0

        handler.post(object : Runnable {
            override fun run() {
                if (step >= steps) {
                    windowX = targetX
                    params?.x = windowX
                    try { windowManager?.updateViewLayout(composeView, params) } catch (_: Exception) {}
                    return
                }
                windowX += deltaX
                params?.x = windowX
                try { windowManager?.updateViewLayout(composeView, params) } catch (_: Exception) {}
                step++
                handler.postDelayed(this, 16)
            }
        })
    }

    private fun setWindowFocusable(focusable: Boolean) {
        params = buildWindowParams(focusable)
        try { windowManager?.updateViewLayout(composeView, params) } catch (_: Exception) {}
    }

    private fun buildWindowParams(focusable: Boolean): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        var baseFlags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON

        if (!focusable) baseFlags = baseFlags or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            baseFlags,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = windowX
            y = windowY
        }
    }

    private fun removeOverlay() {
        composeView?.let { view ->
            try {
                windowManager?.removeView(view)
                lifecycleOwner?.onPause()
                lifecycleOwner?.onStop()
                lifecycleOwner?.onDestroy()
            } catch (_: Exception) {}
        }
        composeView    = null
        lifecycleOwner = null
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Complaint popup window (second overlay, centred, dims behind)
    // ─────────────────────────────────────────────────────────────────────────

    private fun showComplaintPopup() {
        if (complaintView != null) return

        val lco = WindowLifecycleOwner()
        complaintLifecycle = lco

        complaintView = ComposeView(this).apply {
            lco.attachTo(this)
            lco.onCreate()
            lco.onStart()
            lco.onResume()
            setContent {
                val complaintState by stateMachine.complaintState.collectAsState()
                ComplaintPopupRoot(
                    complaintState = complaintState,
                    onEvent        = { stateMachine.handleEvent(it) },
                )
            }
        }

        val popupParams = buildComplaintWindowParams()
        try {
            windowManager?.addView(complaintView, popupParams)
        } catch (_: Exception) {}
    }

    private fun removeComplaintPopup() {
        complaintView?.let { v ->
            try { windowManager?.removeView(v) } catch (_: Exception) {}
            complaintLifecycle?.apply {
                onPause()
                onStop()
                onDestroy()
            }
        }
        complaintView     = null
        complaintLifecycle = null
    }

    private fun buildComplaintWindowParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE

        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_DIM_BEHIND or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity   = Gravity.CENTER
            dimAmount = 0.55f
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Side effects & state observers
    // ─────────────────────────────────────────────────────────────────────────

    private fun observeSideEffects() {
        serviceScope.launch {
            stateMachine.sideEffects.collect { effect ->
                when (effect) {
                    is OverlaySideEffect.DismissWindow -> {
                        removeComplaintPopup()
                        removeOverlay()
                        stopForeground(STOP_FOREGROUND_REMOVE)
                        stopSelf()
                    }

                    is OverlaySideEffect.ShowToast ->
                        Toast.makeText(applicationContext, effect.message, Toast.LENGTH_SHORT).show()

                    is OverlaySideEffect.ShowComplaintPopup -> {
                        showComplaintPopup()
                        // Main overlay stays non-focusable while popup is open
                        setWindowFocusable(false)
                    }

                    is OverlaySideEffect.HideComplaintPopup -> {
                        removeComplaintPopup()
                        // Restore focus for main overlay based on current state
                        setWindowFocusable(stateMachine.state.value.needsFocus)
                    }

                    is OverlaySideEffect.StartRecording -> {
                        if (!hasRecordAudioPermission()) {
                            // Roll back toggle
                            stateMachine.handleEvent(OverlayEvent.ToggleRecording)
                            Toast.makeText(applicationContext, "Microphone permission needed. Grant it in app settings.", Toast.LENGTH_LONG).show()
                            startActivity(Intent(this@NativeCallOverlayService, MainActivity::class.java).apply {
                                action = "crm.REQUEST_RECORD_AUDIO"
                                flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            })
                            return@collect
                        }
                        val phone = stateMachine.state.value.let {
                            when (it) {
                                is OverlayState.KnownCaller   -> it.phoneNumber
                                is OverlayState.UnknownCaller -> it.phoneNumber
                                else -> "unknown"
                            }
                        }
                        val path = callRecorder.startRecording(phone)
                        if (path == null) {
                            stateMachine.handleEvent(OverlayEvent.ToggleRecording) // roll back
                            Toast.makeText(applicationContext, "Recording failed to start", Toast.LENGTH_SHORT).show()
                        }
                    }

                    is OverlaySideEffect.StopRecording -> {
                        val savedPath = callRecorder.stopRecording()
                        if (savedPath != null) {
                            Toast.makeText(applicationContext, "Recording saved", Toast.LENGTH_SHORT).show()
                        }
                    }

                    is OverlaySideEffect.CancelAutoDismiss -> { /* no-op — auto-dismiss removed */ }

                    is OverlaySideEffect.OpenFlutter -> { /* handled in MainActivity via MethodChannel */ }

                    is OverlaySideEffect.Vibrate -> {
                        val vib = getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vib?.vibrate(android.os.VibrationEffect.createOneShot(50, android.os.VibrationEffect.DEFAULT_AMPLITUDE))
                        } else {
                            @Suppress("DEPRECATION")
                            vib?.vibrate(50)
                        }
                    }
                }
            }
        }
    }

    private fun observeStateForWindowFlags() {
        serviceScope.launch {
            stateMachine.state.collect { state ->
                if (composeView == null) return@collect
                // Only update focus if complaint popup is not active (it holds focus)
                if (complaintView == null) {
                    setWindowFocusable(state.needsFocus)
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Permissions, notifications, cleanup
    // ─────────────────────────────────────────────────────────────────────────

    private fun hasOverlayPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this)

    private fun hasRecordAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun startForegroundCompat() {
        val notification = buildNotification("Monitoring calls")
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                // API 30+: include microphone FGS type so recording works,
                // BUT only if we actually have the permission, else Android 14+ crashes us!
                var fgsType = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                if (hasRecordAudioPermission()) {
                    fgsType = fgsType or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                
                try {
                    startForeground(NOTIFICATION_ID, notification, fgsType)
                } catch (e: SecurityException) {
                    // Fallback if system still denies microphone FGS (e.g. started from background without exemption)
                    startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
                }
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
                )
            }
            else -> startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private fun buildNotification(text: String): Notification {
        val hideIntent = PendingIntent.getService(
            this, 100,
            Intent(this, NativeCallOverlayService::class.java).apply { action = ACTION_HIDE },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("CRM Caller")
            .setContentText(text)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "Close", hideIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Call Overlay", NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "CRM overlay on incoming calls"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun cleanup() {
        if (callRecorder.isRecording) callRecorder.stopRecording()
        removeComplaintPopup()
        removeOverlay()
        timerManager.reset()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}
