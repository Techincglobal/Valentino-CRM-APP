package com.example.crm_caller_nxtgen

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.example.crm_caller_nxtgen.overlay.data.FrappeRepository
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private var pendingOpenPhone: String? = null
    private val repository by lazy { FrappeRepository(applicationContext) }
    private val mainScope = CoroutineScope(Dispatchers.Main)

    private var flutterChannel: MethodChannel? = null

    private val pipelineRefreshReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            mainScope.launch {
                flutterChannel?.invokeMethod("onPipelineRefreshNeeded", null)
            }
        }
    }

    private val callLogSavedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            mainScope.launch {
                flutterChannel?.invokeMethod("onCallLogSaved", null)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOpenPhone = intent?.getStringExtra("open_phone")
        requestRuntimePermissions()
        CallMonitorService.start(this)
        LocalBroadcastManager.getInstance(this).registerReceiver(
            pipelineRefreshReceiver,
            IntentFilter(NativeCallOverlayService.ACTION_PIPELINE_REFRESH),
        )
        LocalBroadcastManager.getInstance(this).registerReceiver(
            callLogSavedReceiver,
            IntentFilter(NativeCallOverlayService.ACTION_CALL_LOG_SAVED),
        )
    }

    override fun onDestroy() {
        super.onDestroy()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(pipelineRefreshReceiver)
        LocalBroadcastManager.getInstance(this).unregisterReceiver(callLogSavedReceiver)
    }

    private fun requestRuntimePermissions() {
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
                    != PackageManager.PERMISSION_GRANTED)
                needed.add(Manifest.permission.READ_CALL_LOG)
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
                    != PackageManager.PERMISSION_GRANTED)
                needed.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {  // API 33
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                    != PackageManager.PERMISSION_GRANTED)
                needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), REQUEST_PERMISSIONS)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val phoneStateGranted = permissions.indices.any { i ->
            permissions[i] == Manifest.permission.READ_PHONE_STATE && grantResults[i] == PackageManager.PERMISSION_GRANTED
        }
        if (phoneStateGranted) {
            CallMonitorService.start(this)
        }
    }

    /**
     * Opens OEM-specific background/autostart settings.
     * Each OEM hides the real battery setting behind a different package + activity.
     * We try them in priority order and fall back to the standard battery settings.
     */
    private fun openOemBatterySettings() {
        val intents = buildList {
            val manufacturer = Build.MANUFACTURER.lowercase()
            when {
                "xiaomi" in manufacturer || "redmi" in manufacturer -> {
                    // MIUI: Security Centre → Autostart
                    add(Intent().apply {
                        setClassName("com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity")
                    })
                    // MIUI battery saver page
                    add(Intent().apply {
                        setClassName("com.miui.powerkeeper",
                            "com.miui.powerkeeper.ui.HiddenAppsContainerManagementActivity")
                    })
                }
                "oppo" in manufacturer || "realme" in manufacturer || "oneplus" in manufacturer -> {
                    // ColorOS: Phone Manager → Startup Manager
                    add(Intent().apply {
                        setClassName("com.coloros.safecenter",
                            "com.coloros.safecenter.permission.startup.FakeActivity")
                    })
                    add(Intent().apply {
                        setClassName("com.oppo.safe",
                            "com.oppo.safe.permission.startup.FakeActivity")
                    })
                    add(Intent().apply {
                        setClassName("com.coloros.oppoguardelf",
                            "com.coloros.powermanager.fuelgaue.PowerUsageModelActivity")
                    })
                }
                "samsung" in manufacturer -> {
                    // One UI: Device Care → Battery → App Power Management
                    add(Intent().apply {
                        setClassName("com.samsung.android.lool",
                            "com.samsung.android.sm.battery.ui.BatteryActivity")
                    })
                }
                "huawei" in manufacturer || "honor" in manufacturer -> {
                    add(Intent().apply {
                        setClassName("com.huawei.systemmanager",
                            "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")
                    })
                }
            }
            // Universal fallback — standard battery optimisation settings
            add(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
        }

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return  // opened successfully
            } catch (_: Exception) { }
        }
    }

    companion object {
        private const val REQUEST_PERMISSIONS   = 42
        private const val REQUEST_READ_CALL_LOG = 42  // kept for back-compat
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingOpenPhone = intent.getStringExtra("open_phone")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "crm_caller_nxtgen/native_overlay",
        )
        flutterChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "canDrawOverlays" -> {
                    result.success(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            Settings.canDrawOverlays(this)
                        } else {
                            true
                        },
                    )
                }

                "openOverlaySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                    result.success(true)
                }

                "showNativeOverlay" -> {
                    val data = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    val intent = Intent(this, NativeCallOverlayService::class.java).apply {
                        action = NativeCallOverlayService.ACTION_SHOW
                        putExtra(
                            NativeCallOverlayService.EXTRA_PHONE,
                            data["phone"] as? String ?: "",
                        )
                        putExtra(
                            NativeCallOverlayService.EXTRA_NAME,
                            data["name"] as? String ?: "Unknown Caller",
                        )
                        putExtra(
                            NativeCallOverlayService.EXTRA_TYPE,
                            data["type"] as? String ?: "",
                        )
                        putExtra(
                            NativeCallOverlayService.EXTRA_DOCNAME,
                            data["docname"] as? String ?: "",
                        )
                        putExtra(
                            NativeCallOverlayService.EXTRA_FOUND,
                            data["found"] as? Boolean ?: false,
                        )
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }

                "hideNativeOverlay" -> {
                    startService(
                        Intent(this, NativeCallOverlayService::class.java).apply {
                            action = NativeCallOverlayService.ACTION_HIDE
                        },
                    )
                    result.success(true)
                }

                "consumeLaunchPhone" -> {
                    result.success(pendingOpenPhone)
                    pendingOpenPhone = null
                }

                "getDatabasePath" -> {
                    result.success(getDatabasePath("crm_caller_database").absolutePath)
                }

                // Returns the detected OEM brand for the Flutter side to show tailored guidance
                "getDeviceBrand" -> {
                    result.success(Build.MANUFACTURER.lowercase())
                }

                // Opens the OEM-specific autostart / background permission settings.
                // Called from Flutter when the user taps "Fix background permission" on Xiaomi/Oppo/Samsung.
                "openOemBatterySettings" -> {
                    openOemBatterySettings()
                    result.success(true)
                }

                // Clears a single lead from local Room cache by phone number.
                // Call this before re-simulating an unknown call for that number.
                "clearLocalLeadByPhone" -> {
                    val phone = call.arguments as? String ?: ""
                    mainScope.launch {
                        repository.clearLocalLeadByPhone(phone)
                        result.success(true)
                    }
                }

                // Nuclear option: wipe ALL locally cached leads so every number is unknown again.
                "clearAllLocalLeads" -> {
                    mainScope.launch {
                        repository.clearAllLocalLeads()
                        result.success(true)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
