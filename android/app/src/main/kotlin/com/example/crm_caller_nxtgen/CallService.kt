package com.example.crm_caller_nxtgen

import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import android.os.Handler
import android.os.Looper

/**
 * Foreground service that:
 * 1. Checks whether the Flutter app is already in the foreground (if so, skip — Flutter handles it)
 * 2. Makes an HTTP call to Frappe to look up the caller
 * 3. Writes the result to SharedPreferences
 * 4. Starts the flutter_overlay_window OverlayService so the Flutter overlay widget appears
 * 5. Falls back to a persistent notification if the overlay cannot be started
 */
class CallService : Service() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification("CRM: Looking up caller…"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val phone = intent?.getStringExtra(EXTRA_PHONE)

        if (phone.isNullOrEmpty() || isAppInForeground()) {
            // Flutter is active — its own phone_state stream handles the popup
            stopSelf()
            return START_NOT_STICKY
        }

        Thread {
            try {
                val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val baseUrl = prefs.getString("flutter.crm_base_url", null)
                val sid = prefs.getString("flutter.crm_sid", null)

                if (baseUrl.isNullOrEmpty() || sid.isNullOrEmpty()) {
                    // Not logged in yet — nothing to show
                    stopSelf()
                    return@Thread
                }

                val result = lookupCaller(baseUrl, sid, phone)
                val found = result?.optBoolean("found", false) ?: false
                val name = result?.optString("customer_name", "") ?: ""
                val type = result?.optString("type", "") ?: ""
                val docname = result?.optString("name", "") ?: ""

                // Write caller data so the Flutter overlay widget can read it
                prefs.edit()
                    .putString("flutter.crm_caller_phone", phone)
                    .putString("flutter.crm_caller_name", name)
                    .putString("flutter.crm_caller_type", type)
                    .putString("flutter.crm_caller_docname", docname)
                    .putBoolean("flutter.crm_caller_found", found)
                    .apply()

                if (!tryStartOverlay()) {
                    // Overlay permission not granted or service unavailable — show notification
                    val label = if (found && name.isNotEmpty()) name else "Unknown caller"
                    updateNotification("$label • $phone")
                } else {
                    // Overlay started — dismiss our processing notification
                    val nm = getSystemService(NotificationManager::class.java)
                    nm.cancel(NOTIF_ID)
                }
            } catch (_: Exception) {
                // Network or parse error — silently stop
            }
            stopSelf()
        }.start()

        return START_NOT_STICKY
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    private fun lookupCaller(baseUrl: String, sid: String, phone: String): JSONObject? {
        return try {
            val url = URL("$baseUrl/api/method/nxtgen_crm_mobile.api.get_caller_details")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Cookie", "sid=$sid")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            OutputStreamWriter(conn.outputStream).use {
                it.write("{\"caller_number\":\"$phone\"}")
            }

            val body = conn.inputStream.bufferedReader().readText()
            conn.disconnect()
            JSONObject(body).optJSONObject("message")
        } catch (_: Exception) {
            null
        }
    }

    /**
     * Attempts to start the flutter_overlay_window OverlayService.
     * The fully-qualified class name is confirmed from the build output:
     * flutter_overlay_window-0.4.5/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java
     */
    private fun tryStartOverlay(): Boolean {
        return try {
            try {
                // We use reflection to set the WindowSetup variables before starting OverlayService.
                // This ensures the overlay starts correctly from the background with correct size and layout flags.
                val setupClazz = Class.forName("flutter.overlay.window.flutter_overlay_window.WindowSetup")
                
                setupClazz.getDeclaredField("height").apply {
                    isAccessible = true
                    set(null, 360) // Will be resized properly by Flutter soon after boot
                }
                setupClazz.getDeclaredField("width").apply {
                    isAccessible = true
                    set(null, -1) // match_parent
                }
                setupClazz.getDeclaredMethod("setGravityFromAlignment", String::class.java).apply {
                    isAccessible = true
                    invoke(null, "topCenter")
                }
                setupClazz.getDeclaredMethod("setFlag", String::class.java).apply {
                    isAccessible = true
                    invoke(null, "flagNotFocusable") // allows tap events inside the window without capturing all back presses
                }
                setupClazz.getDeclaredField("enableDrag").apply {
                    isAccessible = true
                    set(null, true)
                }
            } catch (e: Exception) {
                // If reflection fails, we still try starting the service.
            }

            Handler(Looper.getMainLooper()).post {
                try {
                    val ctx = applicationContext
                    if (FlutterEngineCache.getInstance().get("myCachedEngine") == null) {
                        FlutterInjector.instance().flutterLoader().ensureInitializationComplete(ctx, null)
                        val group = FlutterEngineGroup(ctx)
                        val dEntry = DartExecutor.DartEntrypoint(
                            FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                            "overlayMain"
                        )
                        val engine = group.createAndRunEngine(ctx, dEntry)
                        FlutterEngineCache.getInstance().put("myCachedEngine", engine)
                    }

                    val clazz = Class.forName("flutter.overlay.window.flutter_overlay_window.OverlayService")
                    startService(Intent(this@CallService, clazz))
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    /** Returns true when the CRM app is in the foreground (Flutter stream active). */
    private fun isAppInForeground(): Boolean {
        val am = getSystemService(ActivityManager::class.java)
        return am.runningAppProcesses?.any {
            it.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                    it.processName == packageName
        } ?: false
    }

    // ── Notifications ──────────────────────────────────────────────────────────

    private fun buildNotification(text: String): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("CRM Caller")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentIntent(openApp)
            .setAutoCancel(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, buildNotification(text))
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "CRM Call Lookup",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val EXTRA_PHONE = "phone"
        const val PREFS = "FlutterSharedPreferences"
        const val CHANNEL_ID = "crm_call_lookup"
        const val NOTIF_ID = 9001
    }
}
