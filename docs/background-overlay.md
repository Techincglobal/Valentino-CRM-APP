# Background Call Overlay

How the CRM overlay appears on incoming calls even when the app is closed.

---

## The Problem

Android 8+ blocks `BroadcastReceiver` from starting a `ForegroundService` when the app process is dead. The original `CallStateReceiver` approach worked while the app was open but silently failed when killed.

Android 16 (targetSDK=36) added another restriction: declaring `foregroundServiceType="microphone"` in the manifest causes a `SecurityException` at service-create time — even inside a `try-catch` — because the type is validated before `onCreate()` runs.

---

## The Solution

### 1. Persistent `CallMonitorService`

A lightweight foreground service that **always runs**. A running service can start another foreground service without restriction (service-to-service starts bypass the background-start block entirely).

```
Incoming call
  └─ CallMonitorService (always alive)
       ├─ TelephonyCallback (API 31+) / PhoneStateListener (older)
       └─ startForegroundService → NativeCallOverlayService → overlay shown
```

`CallStateReceiver` is kept as a fallback. The state machine's duplicate-event guard handles both firing simultaneously.

### 2. `BootReceiver`

Restarts `CallMonitorService` after device reboot. Handles `BOOT_COMPLETED` plus OEM variants (`QUICKBOOT_POWERON` for Samsung/HTC).

### 3. `foregroundServiceType` — `specialUse` only

`microphone` was removed from the manifest. Android 16 validates all declared types at service creation regardless of what you pass to `startForeground()`. `MediaRecorder` works independently of the FGS type declaration.

### 4. Layered `startForeground` fallbacks

```kotlin
try { startForeground(id, notif, FOREGROUND_SERVICE_TYPE_SPECIAL_USE) }
catch (_: Exception) { startForeground(id, notif) }  // type-less fallback
```

Service `onCreate` is also wrapped in try-catch — any failure calls `stopSelf()` instead of crashing the app.

---

## OEM Battery Killers

Xiaomi (MIUI), Oppo (ColorOS), and Samsung (One UI) aggressively kill background services. Two mitigations are in place:

**Battery optimization exemption** — requested on first launch via `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. User must tap **Allow**.

**OEM deep links** — `openOemBatterySettings()` in `MainActivity` opens the exact right screen per manufacturer:

| Brand | Destination |
|-------|-------------|
| Xiaomi / Redmi | Security Center → Autostart |
| Oppo / Realme / OnePlus | Safe Center → Startup Manager |
| Samsung | Device Care → Battery → App Power Management |
| Huawei / Honor | System Manager → Startup Manager |
| Any other | Standard battery optimization settings |

Called from Flutter via `openOemBatterySettings` on the `crm_caller_nxtgen/native_overlay` method channel.

---

## Key Files

| File | Role |
|------|------|
| `CallMonitorService.kt` | Persistent FGS, TelephonyCallback listener |
| `BootReceiver.kt` | Restarts monitor after reboot |
| `NativeCallOverlayService.kt` | Draws the overlay window via WindowManager |
| `CallStateReceiver.kt` | Fallback broadcast receiver |
| `AndroidManifest.xml` | Both services declared with `specialUse` only |
| `MainActivity.kt` | Starts monitor, requests battery exemption, OEM deep links |

---

## Required Permissions

```xml
SYSTEM_ALERT_WINDOW        <!-- overlay drawing — user must grant manually -->
READ_PHONE_STATE            <!-- detect call state -->
READ_CALL_LOG               <!-- get phone number on older Android -->
FOREGROUND_SERVICE          <!-- run as foreground service -->
FOREGROUND_SERVICE_SPECIAL_USE
RECEIVE_BOOT_COMPLETED      <!-- restart on boot -->
WAKE_LOCK                   <!-- keep CPU alive during call -->
REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
POST_NOTIFICATIONS          <!-- show FGS notification (Android 13+) -->
```

---

## First-Time Setup Checklist

1. Open the app → tap **Allow** on the battery optimization dialog
2. Grant **Display over other apps** (`SYSTEM_ALERT_WINDOW`) in settings
3. On Xiaomi/Oppo: go to Settings → enable **Autostart** for the app
4. All subsequent incoming calls trigger the overlay automatically, app closed or open
