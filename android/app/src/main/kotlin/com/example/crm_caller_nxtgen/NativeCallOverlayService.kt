package com.example.crm_caller_nxtgen

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.text.InputType
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import android.transition.AutoTransition
import android.transition.TransitionManager
import android.view.ViewGroup
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStream
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.abs

class NativeCallOverlayService : Service() {
    companion object {
        const val ACTION_SHOW = "crm_caller_nxtgen.action.SHOW"
        const val ACTION_CALL_ACTIVE = "crm_caller_nxtgen.action.CALL_ACTIVE"
        const val ACTION_CALL_ENDED = "crm_caller_nxtgen.action.CALL_ENDED"
        const val ACTION_HIDE = "crm_caller_nxtgen.action.HIDE"

        const val EXTRA_PHONE = "phone"
        const val EXTRA_NAME = "name"
        const val EXTRA_TYPE = "type"
        const val EXTRA_DOCNAME = "docname"
        const val EXTRA_FOUND = "found"

        private const val CHANNEL_ID = "crm_caller_overlay"
        private const val NOTIFICATION_ID = 2007
        private const val PREF_OVERLAY_X = "crm_native_overlay_x"
        private const val PREF_OVERLAY_Y = "crm_native_overlay_y"
        private const val COMPACT_WIDTH_DP = 68
        private const val EXPANDED_WIDTH_DP = 330
        private const val BUBBLE_RADIUS_DP = 34

        // New Design Tokens
        private const val COLOR_BG = "#0F172A"
        private const val COLOR_CARD = "#1E293B"
        private const val COLOR_BORDER = "#334155"
        private const val COLOR_ACCENT = "#6366F1"
        private const val COLOR_ACCENT_MID = "#818CF8"
        private const val COLOR_ACCENT_DARK = "#4338CA"
        private const val COLOR_TEXT_PRIM = "#FFFFFF"
        private const val COLOR_TEXT_SEC = "#94A3B8"
    }

    private val handler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private val durationTicker = object : Runnable {
        override fun run() {
            updateCallStateUi()
            if (isCallActive) {
                handler.postDelayed(this, 1000)
            }
        }
    }

    private var windowManager: WindowManager? = null
    private var rootView: View? = null
    private var params: WindowManager.LayoutParams? = null

    private var titleView: TextView? = null
    private var subtitleView: TextView? = null
    private var badgeView: TextView? = null
    private var avatarView: TextView? = null
    private var callStateView: TextView? = null
    private var durationView: TextView? = null
    private var compactHintView: TextView? = null
    private var formStatusView: TextView? = null
    private var expandedContainer: View? = null
    private var expandButton: ImageView? = null
    private var closeButtonView: ImageView? = null
    private var latestNoteCard: LinearLayout? = null
    private var latestNoteTextView: TextView? = null
    private var nameInput: EditText? = null
    private var emailInput: EditText? = null
    private var noteInput: EditText? = null
    private var primaryActionButton: TextView? = null

    private var phoneNumber: String = ""
    private var callerName: String = "Incoming call"
    private var callerType: String = ""
    private var callerDocname: String = ""
    private var callerFound: Boolean = false
    private var isExpanded: Boolean = false
    private var isCallActive: Boolean = false
    private var isCallEnded: Boolean = false
    private var isPostCallMode: Boolean = false  // overlay stays open for notes
    private var callStartedAtMillis: Long? = null
    private var lastCallDurationMillis: Long = 0L
    private var isSubmitting: Boolean = false
    private var latestNote: String = ""
    private var latestNoteLoading: Boolean = false
    private var touchSlop: Int = 0
    private var dragStartRawX = 0f
    private var dragStartRawY = 0f
    private var dragStartX = 0
    private var dragStartY = 0
    private var isDragging = false
    private var overlayX = 0
    private var overlayY = 0

    override fun onBind(intent: Intent?): IBinder? = null

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "crm:call_overlay_wakelock")
        loadOverlayPosition()
        createChannel()
        startForegroundWithType("Waiting for calls")
    }

    private fun startForegroundWithType(content: String) {
        val notification = buildNotification(content)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID, 
                notification, 
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        if (wakeLock?.isHeld == true) wakeLock?.release()
        stopDurationTicker()
        removeOverlay()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        
        // Brief wakelock for Samsung stability
        wakeLock?.acquire(8000)
        
        when (action) {
            ACTION_HIDE -> {
                stopDurationTicker()
                resetSessionState()
                removeOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }

            ACTION_CALL_ACTIVE -> {
                if (!ensureOverlayPermission()) return START_NOT_STICKY
                val previousPhone = phoneNumber
                hydrateFromIntent(intent, keepExistingName = true)
                if (previousPhone.isNotBlank() && previousPhone != phoneNumber) {
                    resetInteractiveState()
                }
                isCallActive = true
                isCallEnded = false
                if (callStartedAtMillis == null) {
                    callStartedAtMillis = System.currentTimeMillis()
                }
                showOverlay()
                updateCallStateUi()
                startDurationTicker()
                if (phoneNumber.isNotBlank() && callerDocname.isBlank()) {
                    fetchCallerDetails(phoneNumber)
                }
            }

            ACTION_CALL_ENDED -> {
                if (!ensureOverlayPermission()) return START_NOT_STICKY
                hydrateFromIntent(intent, keepExistingName = true)
                lastCallDurationMillis = when {
                    callStartedAtMillis != null -> System.currentTimeMillis() - callStartedAtMillis!!
                    lastCallDurationMillis > 0L -> lastCallDurationMillis
                    else -> 0L
                }
                isCallActive = false
                isCallEnded = true
                isPostCallMode = true  // Keep overlay open; user must dismiss manually
                callStartedAtMillis = null
                stopDurationTicker()
                // Auto-expand so the note field is immediately visible
                if (!isExpanded) {
                    isExpanded = true
                }
                showOverlay()
                updateCallStateUi()
            }

            else -> {
                if (!ensureOverlayPermission()) return START_NOT_STICKY
                val previousPhone = phoneNumber
                hydrateFromIntent(intent, keepExistingName = false)
                if (previousPhone != phoneNumber) {
                    resetSessionState()
                    hydrateFromIntent(intent, keepExistingName = false)
                }
                isCallActive = false
                isCallEnded = false
                callStartedAtMillis = null
                lastCallDurationMillis = 0L
                isExpanded = false
                showOverlay()
                updateCallStateUi()
                stopDurationTicker()
                if (phoneNumber.isNotBlank()) {
                    fetchCallerDetails(phoneNumber)
                }
            }
        }
        return START_STICKY
    }

    private fun ensureOverlayPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            stopSelf()
            return false
        }
        return true
    }

    private fun hydrateFromIntent(intent: Intent?, keepExistingName: Boolean) {
        val incomingPhone = intent?.getStringExtra(EXTRA_PHONE).orEmpty()
        if (incomingPhone.isNotBlank()) {
            phoneNumber = incomingPhone
        }

        val incomingFound = intent?.getBooleanExtra(EXTRA_FOUND, callerFound) ?: callerFound
        callerFound = incomingFound

        val incomingName = intent?.getStringExtra(EXTRA_NAME).orEmpty()
        if (incomingName.isNotBlank() || !keepExistingName) {
            callerName = incomingName.ifBlank {
                if (callerFound) "CRM Contact" else "Incoming call"
            }
        }

        callerType = intent?.getStringExtra(EXTRA_TYPE).orEmpty().ifBlank { callerType }
        callerDocname = intent?.getStringExtra(EXTRA_DOCNAME).orEmpty().ifBlank { callerDocname }
    }

    private fun showOverlay() {
        if (rootView == null) {
            rootView = buildOverlayView()
            params = buildLayoutParams()
            try {
                windowManager?.addView(rootView, params)
            } catch (_: Exception) {
                removeOverlay()
                rootView = buildOverlayView()
                params = buildLayoutParams()
                windowManager?.addView(rootView, params)
            }
        }

        bindOverlay()
        refreshWindowLayout()
    }

    private fun buildLayoutParams(): WindowManager.LayoutParams {
        val widthMode = if (isExpanded) dp(EXPANDED_WIDTH_DP) else dp(COMPACT_WIDTH_DP)
        return WindowManager.LayoutParams(
            widthMode,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            },
            currentWindowFlags(),
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            x = 0
            y = if (isExpanded) overlayY else dp(20) // Floating at top center when compact
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        }
    }

    private fun currentWindowFlags(): Int {
        // Always show above other apps including games and full-screen content
        val base = WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        return if (isExpanded) {
            base or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        } else {
            base or WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
        }
    }

    private fun bindOverlay() {
        titleView?.text = callerName.ifBlank { "Incoming call" }
        subtitleView?.text = phoneNumber.ifBlank { "Unknown number" }
        avatarView?.text = initials(callerName)

        badgeView?.text = if (callerFound) {
            callerType.ifBlank { "CRM Match" }
        } else {
            "Unknown"
        }
        badgeView?.background = roundedFill(
            if (callerFound) "#1E3A8A" else "#334155",
            14f,
        )
        badgeView?.setTextColor(Color.parseColor(if (callerFound) "#DBEAFE" else "#CBD5E1"))
        avatarView?.background = GradientDrawable(
            GradientDrawable.Orientation.TL_BR,
            intArrayOf(Color.parseColor(COLOR_ACCENT_MID), Color.parseColor(COLOR_ACCENT), Color.parseColor(COLOR_ACCENT_DARK)),
        ).apply {
            shape = GradientDrawable.OVAL
        }

        nameInput?.visibility = if (callerFound) View.GONE else View.VISIBLE
        emailInput?.visibility = if (callerFound) View.GONE else View.VISIBLE
        noteInput?.hint = if (callerFound) "Add a live call note..." else "Lead note / call summary"
        latestNoteCard?.visibility = if (callerFound && isExpanded) View.VISIBLE else View.GONE
        badgeView?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        subtitleView?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        callStateView?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        expandButton?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        closeButtonView?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        compactHintView?.visibility = if (isExpanded) View.GONE else View.VISIBLE
        primaryActionButton?.text = if (isSubmitting) {
            "Saving..."
        } else if (callerFound) {
            "Save Note"
        } else {
            "Create Lead"
        }
        primaryActionButton?.alpha = if (isSubmitting) 0.6f else 1f

        bindLatestNote()
        updateCallStateUi()

        writeStoredValue(this, "crm_caller_phone", phoneNumber)
        writeStoredValue(this, "crm_caller_name", callerName)
        writeStoredValue(this, "crm_caller_type", callerType)
        writeStoredValue(this, "crm_caller_docname", callerDocname)
        writeStoredBool(this, "crm_caller_found", callerFound)
    }

    private fun updateCallStateUi() {
        val duration = when {
            isCallActive -> callStartedAtMillis?.let { System.currentTimeMillis() - it } ?: 0L
            lastCallDurationMillis > 0L -> lastCallDurationMillis
            else -> 0L
        }

        val stateLabel = when {
            isCallActive -> "LIVE CALL"
            isCallEnded -> "CALL ENDED"
            else -> "INCOMING"
        }
        callStateView?.text = stateLabel
        durationView?.text = if (isCallActive || isCallEnded) {
            formatDuration(duration)
        } else {
            "00:00"
        }
        compactHintView?.text = when {
            isCallEnded -> "Tap for details"
            isCallActive -> stateLabel
            else -> "Tap for details"
        }
        val durationBg = when {
            isCallActive -> "#166534"
            isCallEnded -> "#334155"
            else -> "#1E3A8A"
        }
        val durationFg = when {
            isCallActive -> "#DCFCE7"
            isCallEnded -> "#E2E8F0"
            else -> "#DBEAFE"
        }
        durationView?.background = roundedFill(durationBg, 14f)
        durationView?.setTextColor(Color.parseColor(durationFg))

        val summary = buildString {
            append(callerName.ifBlank { "Incoming call" })
            if (phoneNumber.isNotBlank()) {
                append(" • ")
                append(phoneNumber)
            }
            if (isCallActive || isCallEnded) {
                append(" • ")
                append(durationView?.text ?: "")
            }
        }

        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(summary))
    }

    private fun refreshWindowLayout() {
        val view = rootView ?: return
        val layoutParams = params ?: return

        // Update Design State before updating layout
        (view as? LinearLayout)?.let { shell ->
            val mainBubble = shell.getChildAt(0)
            val spacer = shell.getChildAt(1)
            val textCol = (mainBubble as? ViewGroup)?.getChildAt(1)
            val trailing = (mainBubble as? ViewGroup)?.getChildAt(2)
            if (textCol != null && trailing != null && spacer != null) {
                updateDesignState(shell, mainBubble, textCol, trailing, spacer)
            }
        }

        layoutParams.width = dp(if (isExpanded) EXPANDED_WIDTH_DP else COMPACT_WIDTH_DP)
        layoutParams.y = if (isExpanded) overlayY else dp(20)
        layoutParams.flags = currentWindowFlags()
        layoutParams.softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
        expandedContainer?.visibility = if (isExpanded) View.VISIBLE else View.GONE
        expandButton?.rotation = if (isExpanded) 180f else 0f
        try {
            windowManager?.updateViewLayout(view, layoutParams)
        } catch (_: Exception) {
        }

        if (!isExpanded) {
            hideKeyboard()
        } else {
            noteInput?.requestFocus()
            if (callerFound &&
                latestNote.isBlank() &&
                !latestNoteLoading &&
                callerDocname.isNotBlank() &&
                callerType.isNotBlank()
            ) {
                fetchLatestNote()
            }
        }
    }

    private fun startDurationTicker() {
        handler.removeCallbacks(durationTicker)
        handler.post(durationTicker)
    }

    private fun stopDurationTicker() {
        handler.removeCallbacks(durationTicker)
    }

    private fun fetchCallerDetails(phone: String) {
        executor.execute {
            try {
                val payload = postJson(
                    "/api/method/nxtgen_crm_mobile.api.get_caller_details",
                    JSONObject().put("caller_number", phone),
                ) ?: return@execute

                val message = payload.optJSONObject("message") ?: return@execute
                val found = message.optBoolean("found", false)
                val name = message.optString("customer_name")
                    .ifBlank { message.optString("name") }
                    .ifBlank { "Unknown Caller" }
                val type = message.optString("type")
                val docname = message.optString("name")

                handler.post {
                    callerFound = found
                    callerName = name
                    callerType = type
                    callerDocname = docname
                    bindOverlay()
                    if (found && isExpanded && callerDocname.isNotBlank() && callerType.isNotBlank()) {
                        fetchLatestNote()
                    }
                }
            } catch (_: Exception) {
                handler.post {
                    callerFound = false
                    callerType = if (callerType.isBlank()) "Unknown" else callerType
                    if (callerName.isBlank()) callerName = "Incoming call"
                    bindOverlay()
                }
            }
        }
    }

    private fun fetchLatestNote() {
        if (!callerFound || callerDocname.isBlank() || callerType.isBlank() || latestNoteLoading) {
            return
        }

        latestNoteLoading = true
        bindLatestNote()

        executor.execute {
            try {
                val payload = postJson(
                    "/api/method/nxtgen_crm_mobile.api.get_notes",
                    JSONObject()
                        .put("doctype", callerType)
                        .put("docname", callerDocname),
                ) ?: return@execute
                val notes = payload.optJSONArray("message")
                val content = if (notes != null && notes.length() > 0) {
                    notes.optJSONObject(0)?.optString("content").orEmpty().trim()
                } else {
                    ""
                }

                handler.post {
                    latestNote = content
                    latestNoteLoading = false
                    bindLatestNote()
                }
            } catch (_: Exception) {
                handler.post {
                    latestNoteLoading = false
                    bindLatestNote()
                }
            }
        }
    }

    private fun submitPrimaryAction() {
        if (isSubmitting) return
        clearStatus()

        if (callerFound) {
            saveNote()
        } else {
            createLead()
        }
    }

    private fun saveNote() {
        val note = noteInput?.text?.toString()?.trim().orEmpty()
        if (note.isBlank()) {
            showStatus("Enter a note first", true)
            return
        }
        if (callerDocname.isBlank()) {
            showStatus("Caller details are still loading", true)
            return
        }

        setSubmitting(true)
        executor.execute {
            try {
                val body = JSONObject()
                    .put("doctype", callerType.ifBlank { "Lead" })
                    .put("docname", callerDocname)
                    .put("note_content", note)
                postJson("/api/method/nxtgen_crm_mobile.api.add_call_note", body, requireSuccess = true)

                handler.post {
                    noteInput?.text?.clear()
                    latestNote = note
                    setSubmitting(false)
                    if (isPostCallMode) {
                        // Auto-dismiss after successful save in post-call mode
                        showStatus("Note saved! Closing...")
                        handler.postDelayed({
                            startService(Intent(this, NativeCallOverlayService::class.java).apply {
                                action = ACTION_HIDE
                            })
                        }, 1200)
                    } else {
                        showStatus("Note saved")
                        bindLatestNote()
                    }
                }
            } catch (e: Exception) {
                handler.post {
                    setSubmitting(false)
                    showStatus(e.message ?: "Could not save note", true)
                }
            }
        }
    }

    private fun createLead() {
        val leadName = nameInput?.text?.toString()?.trim().orEmpty()
        val email = emailInput?.text?.toString()?.trim().orEmpty()
        val note = noteInput?.text?.toString()?.trim().orEmpty()

        if (leadName.isBlank()) {
            showStatus("Lead name is required", true)
            return
        }

        setSubmitting(true)
        executor.execute {
            try {
                val body = JSONObject()
                    .put("first_name", leadName)
                    .put("mobile_no", phoneNumber)
                    .putIfNotBlank("email_id", email)
                    .putIfNotBlank("note_content", note)

                val payload = postJson(
                    "/api/method/nxtgen_crm_mobile.api.create_lead_with_note",
                    body,
                    requireSuccess = true,
                )

                val message = payload?.optJSONObject("message")
                val newDocname = message?.optString("name").orEmpty()

                handler.post {
                    callerFound = true
                    callerName = leadName
                    callerType = "Lead"
                    callerDocname = newDocname.ifBlank { callerDocname }
                    latestNote = note
                    noteInput?.text?.clear()
                    nameInput?.text?.clear()
                    emailInput?.text?.clear()
                    setSubmitting(false)
                    bindOverlay()
                    showStatus("Lead created")
                }
            } catch (e: Exception) {
                handler.post {
                    setSubmitting(false)
                    showStatus(e.message ?: "Could not create lead", true)
                }
            }
        }
    }

    private fun setSubmitting(submitting: Boolean) {
        isSubmitting = submitting
        primaryActionButton?.isEnabled = !submitting
        bindOverlay()
    }

    private fun postJson(
        path: String,
        body: JSONObject,
        requireSuccess: Boolean = false,
    ): JSONObject? {
        val baseUrl = readStoredValue(this, "crm_base_url") ?: throw Exception("Please log in again")
        val sid = readStoredValue(this, "crm_sid") ?: throw Exception("Please log in again")

        val url = URL(baseUrl.trimEnd('/') + path)
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 8000
            readTimeout = 8000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Cookie", "sid=$sid")
        }

        return try {
            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(body.toString())
                writer.flush()
            }

            val stream: InputStream = if (connection.responseCode in 200..299) {
                connection.inputStream
            } else {
                connection.errorStream ?: connection.inputStream
            }

            val responseBody = stream.bufferedReader().use(BufferedReader::readText)
            val payload = JSONObject(responseBody)

            if (requireSuccess && connection.responseCode !in 200..299) {
                val message = payload.optString("message").ifBlank { "Request failed" }
                throw Exception(message)
            }

            payload
        } finally {
            connection.disconnect()
        }
    }

    private fun buildOverlayView(): View {
        val shell = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(12), dp(12), dp(12))
            clipToPadding = false
        }

        val mainBubble = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setOnClickListener {
                isExpanded = !isExpanded
                applyDesignTransition()
                refreshWindowLayout()
            }
        }
        attachDragBehavior(mainBubble)

        avatarView = TextView(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(44), dp(44))
            gravity = Gravity.CENTER
            textSize = 15f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.WHITE)
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(Color.parseColor("#1E293B"), Color.parseColor("#3B82F6")),
            ).apply {
                shape = GradientDrawable.OVAL
            }
        }

        val textColumn = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply {
                marginStart = dp(14)
                marginEnd = dp(6)
            }
        }

        callStateView = TextView(this).apply {
            setTextColor(Color.parseColor(COLOR_ACCENT_MID))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            letterSpacing = 0.1f
        }

        titleView = TextView(this).apply {
            setTextColor(Color.parseColor(COLOR_TEXT_PRIM))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            maxLines = 1
        }

        subtitleView = TextView(this).apply {
            setTextColor(Color.parseColor(COLOR_TEXT_SEC))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            maxLines = 1
        }

        compactHintView = TextView(this).apply {
            setTextColor(Color.parseColor(COLOR_ACCENT_MID))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            visibility = View.GONE
        }

        textColumn.addView(callStateView)
        textColumn.addView(titleView)
        textColumn.addView(subtitleView)
        textColumn.addView(compactHintView)

        val trailingContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        badgeView = TextView(this).apply {
            setPadding(dp(12), dp(5), dp(12), dp(5))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 10f)
            setTextColor(Color.WHITE)
            background = roundedFill(COLOR_ACCENT, 10f)
        }

        durationView = TextView(this).apply {
            setTextColor(Color.parseColor("#BFDBFE"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER_HORIZONTAL
            background = roundedFill("#1E3A8A", 18f)
            setPadding(dp(10), dp(5), dp(10), dp(5))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(4) }
        }

        expandButton = ImageView(this).apply {
            setImageResource(android.R.drawable.arrow_down_float)
            setColorFilter(Color.parseColor(COLOR_TEXT_SEC))
            setPadding(dp(8), dp(4), dp(8), dp(4))
            setOnClickListener {
                isExpanded = !isExpanded
                applyDesignTransition()
                refreshWindowLayout()
            }
        }

        closeButtonView = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.parseColor(COLOR_TEXT_SEC))
            setPadding(dp(8), dp(4), dp(8), dp(4))
            setOnClickListener {
                startService(Intent(this@NativeCallOverlayService, NativeCallOverlayService::class.java).apply {
                    action = ACTION_HIDE
                })
            }
        }

        trailingContainer.addView(badgeView)
        trailingContainer.addView(durationView)
        trailingContainer.addView(expandButton)
        trailingContainer.addView(closeButtonView)

        mainBubble.addView(avatarView)
        mainBubble.addView(textColumn)
        mainBubble.addView(trailingContainer)

        val spacerLine = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(1)).apply {
                topMargin = dp(14)
                bottomMargin = dp(6)
            }
            setBackgroundColor(Color.parseColor(COLOR_BORDER))
        }

        expandedContainer = buildExpandedContent()

        shell.addView(mainBubble)
        shell.addView(spacerLine)
        shell.addView(expandedContainer)

        updateDesignState(shell, mainBubble, textColumn, trailingContainer, spacerLine)

        return shell
    }

    private fun applyDesignTransition() {
        (rootView as? ViewGroup)?.let {
            TransitionManager.beginDelayedTransition(it, AutoTransition().apply {
                duration = 250
            })
        }
    }

    private fun updateDesignState(
        shell: LinearLayout,
        mainBubble: View,
        textColumn: View,
        trailing: View,
        spacer: View,
    ) {
        if (isExpanded) {
            shell.background = GradientDrawable().apply {
                setColor(Color.parseColor(COLOR_BG))
                cornerRadius = dp(24).toFloat()
                setStroke(dp(1), Color.parseColor(COLOR_BORDER))
            }
            shell.elevation = dp(12).toFloat()
            textColumn.visibility = View.VISIBLE
            trailing.visibility = View.VISIBLE
            spacer.visibility = View.VISIBLE
            expandedContainer?.visibility = View.VISIBLE
            expandButton?.setImageResource(android.R.drawable.arrow_up_float)
        } else {
            shell.background = null
            shell.elevation = 0f
            textColumn.visibility = View.GONE
            trailing.visibility = View.VISIBLE // Keep duration visible
            badgeView?.visibility = View.GONE
            expandButton?.visibility = View.GONE
            closeButtonView?.visibility = View.GONE
            spacer.visibility = View.GONE
            expandedContainer?.visibility = View.GONE
            
            // Re-order for bubble look
            (trailing as ViewGroup).let { vg ->
                // Ensure duration is always there
            }
        }
    }

    private fun buildExpandedContent(): View {
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(12), 0, 0)
        }

        val heroCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(20).toFloat()
                colors = intArrayOf(
                    Color.parseColor(COLOR_ACCENT_DARK),
                    Color.parseColor(COLOR_ACCENT),
                )
                orientation = GradientDrawable.Orientation.LEFT_RIGHT
            }
        }

        val heroTitle = TextView(this).apply {
            text = "Call Workspace"
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        }

        val heroSubtitle = TextView(this).apply {
            text = "Capture details while fresh."
            setTextColor(Color.parseColor("#CBD5E1"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
        }

        val metaRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        metaRow.addView(buildMetaChip("Duration", true))
        metaRow.addView(spaceWidth(8))
        metaRow.addView(buildMetaChip("Drag to move", false))
        metaRow.addView(spaceWidth(8))
        metaRow.addView(buildMetaChip(if (callerFound) "CRM Match" else "New Lead", false))

        formStatusView = TextView(this).apply {
            visibility = View.GONE
            setPadding(dp(12), dp(10), dp(12), dp(10))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            background = roundedFill("#EFF6FF", 14f)
            setTextColor(Color.parseColor("#1D4ED8"))
        }

        nameInput = buildInput(
            hint = "Lead name",
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_WORDS,
        )
        emailInput = buildInput(
            hint = "Email address",
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS,
        )
        noteInput = buildInput(
            hint = "Add call notes...",
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE,
            lines = 4,
        )

        latestNoteTextView = TextView(this).apply {
            setTextColor(Color.parseColor("#334155"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            setLineSpacing(0f, 1.2f)
        }

        latestNoteCard = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(14), dp(12), dp(14), dp(12))
            background = roundedFill("#EFF6FF", 18f)
            visibility = View.GONE
            addView(
                TextView(this@NativeCallOverlayService).apply {
                    text = "Latest Note"
                    setTypeface(typeface, Typeface.BOLD)
                    setTextColor(Color.parseColor("#1D4ED8"))
                    setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
                },
            )
            addView(space(8))
            addView(latestNoteTextView)
        }

        val primaryButton = TextView(this).apply {
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(12), dp(14), dp(12))
            setTextColor(Color.WHITE)
            setTypeface(typeface, Typeface.BOLD)
            background = roundedFill(COLOR_ACCENT, 16f)
            setOnClickListener { submitPrimaryAction() }
        }
        primaryActionButton = primaryButton

        val openAppButton = TextView(this).apply {
            text = "Open App"
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(12), dp(14), dp(12))
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor(COLOR_TEXT_PRIM))
            background = roundedFill(COLOR_CARD, 16f)
            setOnClickListener { openApp() }
        }

        val hideButton = TextView(this).apply {
            text = "Hide"
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(12), dp(14), dp(12))
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.parseColor(COLOR_TEXT_PRIM))
            background = roundedFill(COLOR_CARD, 16f)
            setOnClickListener {
                isExpanded = false
                refreshWindowLayout()
            }
        }

        val actionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }

        actionsRow.addView(
            primaryButton,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        actionsRow.addView(spaceWidth(10))
        actionsRow.addView(
            hideButton,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )

        val secondaryActionsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        secondaryActionsRow.addView(
            openAppButton,
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )
        secondaryActionsRow.addView(spaceWidth(10))
        secondaryActionsRow.addView(
            TextView(this).apply {
                text = "Close"
                gravity = Gravity.CENTER
                setPadding(dp(14), dp(12), dp(14), dp(12))
                setTypeface(typeface, Typeface.BOLD)
                setTextColor(Color.parseColor("#B91C1C"))
                background = roundedFill("#FEE2E2", 16f)
                setOnClickListener {
                    startService(Intent(this@NativeCallOverlayService, NativeCallOverlayService::class.java).apply {
                        action = ACTION_HIDE
                    })
                }
            },
            LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f),
        )

        heroCard.addView(heroTitle)
        heroCard.addView(space(6))
        heroCard.addView(heroSubtitle)
        heroCard.addView(space(12))
        heroCard.addView(metaRow)

        container.addView(heroCard)
        container.addView(space(12))
        container.addView(formStatusView)
        container.addView(space(10))
        container.addView(latestNoteCard)
        container.addView(space(10))
        container.addView(nameInput)
        container.addView(space(10))
        container.addView(emailInput)
        container.addView(space(10))
        container.addView(noteInput)
        container.addView(space(12))
        container.addView(actionsRow)
        container.addView(space(10))
        container.addView(secondaryActionsRow)

        return ScrollView(this).apply {
            isFillViewport = true
            addView(container)
        }
    }

    private fun buildInput(hint: String, inputType: Int, lines: Int = 1): EditText {
        return EditText(this).apply {
            this.hint = hint
            this.inputType = inputType
            minLines = lines
            maxLines = lines
            setTextColor(Color.parseColor(COLOR_TEXT_PRIM))
            setHintTextColor(Color.parseColor(COLOR_TEXT_SEC))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor(COLOR_CARD))
                setStroke(dp(1), Color.parseColor(COLOR_BORDER))
            }
            setPadding(dp(14), dp(12), dp(14), dp(12))
        }
    }

    private fun clearStatus() {
        formStatusView?.visibility = View.GONE
        formStatusView?.text = ""
    }

    private fun bindLatestNote() {
        latestNoteTextView?.text = when {
            latestNoteLoading -> "Loading latest note..."
            latestNote.isNotBlank() -> latestNote
            else -> "No call note found for this contact yet."
        }
        latestNoteCard?.visibility = if (callerFound && isExpanded) View.VISIBLE else View.GONE
    }

    private fun buildMetaChip(label: String, emphasized: Boolean): TextView {
        return TextView(this).apply {
            text = label
            setTextColor(Color.parseColor(if (emphasized) COLOR_ACCENT_MID else COLOR_TEXT_SEC))
            setTypeface(typeface, Typeface.BOLD)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            setPadding(dp(10), dp(7), dp(10), dp(7))
            background = roundedFill(if (emphasized) "#1E293B" else "#1E293B", 14f)
        }
    }

    private fun showStatus(message: String, isError: Boolean = false) {
        formStatusView?.visibility = View.VISIBLE
        formStatusView?.text = message
        formStatusView?.setTextColor(
            Color.parseColor(if (isError) "#B91C1C" else "#1D4ED8"),
        )
        formStatusView?.background = roundedFill(
            if (isError) "#FEE2E2" else "#DBEAFE",
            14f,
        )
    }

    private fun openApp() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("open_phone", phoneNumber)
        } ?: return
        startActivity(launchIntent)
        startService(Intent(this, NativeCallOverlayService::class.java).apply { action = ACTION_HIDE })
    }

    private fun removeOverlay() {
        hideKeyboard()
        rootView?.let { view ->
            try {
                windowManager?.removeView(view)
            } catch (_: Exception) {
            }
        }
        rootView = null
        params = null
        titleView = null
        subtitleView = null
        badgeView = null
        avatarView = null
        callStateView = null
        durationView = null
        formStatusView = null
        expandedContainer = null
        expandButton = null
        nameInput = null
        emailInput = null
        noteInput = null
        primaryActionButton = null
        isExpanded = false
    }

    private fun resetSessionState() {
        resetInteractiveState()
        phoneNumber = ""
        callerName = "Incoming call"
        callerType = ""
        callerDocname = ""
        callerFound = false
        isCallActive = false
        isCallEnded = false
        isPostCallMode = false
        callStartedAtMillis = null
        lastCallDurationMillis = 0L
    }

    private fun resetInteractiveState() {
        isExpanded = false
        isSubmitting = false
        latestNote = ""
        latestNoteLoading = false
        clearStatus()
        nameInput?.text?.clear()
        emailInput?.text?.clear()
        noteInput?.text?.clear()
    }

    private fun hideKeyboard() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        val token = noteInput?.windowToken ?: nameInput?.windowToken ?: return
        imm.hideSoftInputFromWindow(token, 0)
    }

    private fun attachDragBehavior(target: View) {
        target.setOnTouchListener { view, event ->
            val layoutParams = params ?: return@setOnTouchListener false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragStartRawX = event.rawX
                    dragStartRawY = event.rawY
                    dragStartX = layoutParams.x
                    dragStartY = layoutParams.y
                    isDragging = false
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - dragStartRawX).toInt()
                    val dy = (event.rawY - dragStartRawY).toInt()
                    if (!isDragging && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        isDragging = true
                    }

                    if (isDragging) {
                        overlayX = (dragStartX + dx).coerceAtLeast(0)
                        overlayY = (dragStartY + dy).coerceAtLeast(0)
                        layoutParams.x = overlayX
                        layoutParams.y = overlayY
                        try {
                            windowManager?.updateViewLayout(rootView, layoutParams)
                            saveOverlayPosition()
                        } catch (_: Exception) {
                        }
                    }
                    true
                }

                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        view.performClick()
                    }
                    isDragging = false
                    true
                }

                MotionEvent.ACTION_CANCEL -> {
                    isDragging = false
                    true
                }

                else -> false
            }
        }
    }

    private fun loadOverlayPosition() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        overlayX = prefs.getInt(PREF_OVERLAY_X, dp(20))
        overlayY = prefs.getInt(PREF_OVERLAY_Y, dp(56))
    }

    private fun saveOverlayPosition() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putInt(PREF_OVERLAY_X, overlayX)
            .putInt(PREF_OVERLAY_Y, overlayY)
            .apply()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(
                CHANNEL_ID,
                "CRM Caller Overlay",
                NotificationManager.IMPORTANCE_HIGH, // High priority for Samsung
            ).apply {
                description = "Shows caller information overlay"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(content: String): Notification {
        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0),
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("CRM Caller")
            .setContentText(content)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun roundedFill(color: String, radiusDp: Float): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp.toInt()).toFloat()
            setColor(Color.parseColor(color))
        }
    }

    private fun space(heightDp: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(1, dp(heightDp))
        }
    }

    private fun spaceWidth(widthDp: Int): View {
        return View(this).apply {
            layoutParams = LinearLayout.LayoutParams(dp(widthDp), 1)
        }
    }

    private fun dp(value: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics,
        ).toInt()

    private fun initials(name: String): String {
        return name.split(" ")
            .filter { it.isNotBlank() }
            .take(2)
            .joinToString("") { it.first().uppercase() }
            .ifBlank { "?" }
    }

    private fun formatDuration(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000).coerceAtLeast(0)
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format(Locale.US, "%02d:%02d", minutes, seconds)
    }
}

private fun JSONObject.putIfNotBlank(key: String, value: String): JSONObject {
    if (value.isNotBlank()) {
        put(key, value)
    }
    return this
}
