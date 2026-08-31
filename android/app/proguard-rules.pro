# Flutter — keep everything Flutter needs
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** { volatile <fields>; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Room — keep entity and DAO classes
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    abstract *;
}

# WorkManager
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# Compose — needed for reflection-based Compose compiler
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# App-specific overlay domain models
-keep class com.example.crm_caller_nxtgen.overlay.domain.** { *; }
-keep class com.example.crm_caller_nxtgen.core.db.** { *; }

# ─────────────────────────────────────────────────────────────────────────────
# Strip debug/verbose/info logging from release builds.
#
# The call pipeline logs phone numbers at Log.d to make missed-call and
# direction-resolution bugs diagnosable during development. Those numbers are
# customer PII and must not reach logcat on a user's device, where any app
# holding READ_LOGS — or anyone with adb — can read them.
#
# Log.w / Log.e are deliberately KEPT so production crashes and sync failures
# stay diagnosable; the few of those that referenced a phone number now pass it
# through redactPhone() instead.
# ─────────────────────────────────────────────────────────────────────────────
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
