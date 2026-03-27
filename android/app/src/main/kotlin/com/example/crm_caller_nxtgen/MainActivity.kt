package com.example.crm_caller_nxtgen

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingOpenPhone: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingOpenPhone = intent?.getStringExtra("open_phone")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingOpenPhone = intent.getStringExtra("open_phone")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "crm_caller_nxtgen/native_overlay",
        ).setMethodCallHandler { call, result ->
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

                "startWatchdog" -> {
                    ContextCompat.startForegroundService(
                        this,
                        Intent(this, WatchdogService::class.java),
                    )
                    result.success(true)
                }

                "openBatterySettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        }
                    }
                    result.success(true)
                }

                "consumeLaunchPhone" -> {
                    result.success(pendingOpenPhone)
                    pendingOpenPhone = null
                }

                else -> result.notImplemented()
            }
        }
    }
}
