import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility;
import 'package:phone_state/phone_state.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'caller_service.dart';

class BackgroundService {
  static Future<void> _log(String message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('bg_service_logs') ?? [];
      final timestamp = DateTime.now().toString().split('.')[0];
      logs.insert(0, '[$timestamp] $message'); // Newest first
      // Keep last 150 items
      final trimmed = logs.take(150).toList();
      await prefs.setStringList('bg_service_logs', trimmed);
    } catch (_) {}
  }

  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await _log("Initializing BackgroundService");

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'Caller App Service',
      description: 'Monitors incoming calls for CRM integration.',
      importance: Importance.high,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'CRM App',
        initialNotificationContent: 'Monitoring calls...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  
  await BackgroundService._log("🚀 onStart initialized!");

  // Keep foreground notification alive
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: 'CRM App',
          content: 'Monitoring calls (Active)',
        );
      }
    }
  });

  service.on('stopService').listen((event) {
    BackgroundService._log("Stopping Service");
    service.stopSelf();
  });

  PhoneState.stream.listen((event) async {
    await BackgroundService._log("📞 Phone Event: ${event.status} | Number: ${event.number}");

    if (event.status == PhoneStateStatus.CALL_INCOMING) {
      if (event.number == null) {
        await BackgroundService._log("⚠️ Incoming call detected but number is NULL!");
        return;
      }
      final phone = event.number!;
      await BackgroundService._log("🔍 Processing Incoming Call: $phone");

      String callerName = 'Unknown Caller';
      String callerType = '';
      String callerDocname = '';
      bool found = false;

      try {
        await BackgroundService._log("🌐 Fetching CRT Details for $phone");
        final details = await CallerService.getCallerDetails(phone);
        found = details['found'] == true;
        callerName = details['customer_name'] ?? details['name'] ?? 'Unknown Caller';
        callerType = details['type'] ?? '';
        callerDocname = details['name'] ?? '';
        await BackgroundService._log("✅ Caller Identified: $callerName");
      } catch (e) {
        await BackgroundService._log("❌ CRM Lookup Error: $e");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("crm_caller_phone", phone);
      await prefs.setString("crm_caller_name", callerName);
      await prefs.setString("crm_caller_type", callerType);
      await prefs.setString("crm_caller_docname", callerDocname);
      await prefs.setBool("crm_caller_found", found);

      // Increment call count
      final today = DateTime.now().toIso8601String().split('T')[0];
      final savedDate = prefs.getString('crm_call_date') ?? '';
      int newCount = 1;
      if (savedDate == today) {
        newCount = (prefs.getInt('crm_call_count') ?? 0) + 1;
      } else {
        await prefs.setString('crm_call_date', today);
      }
      await prefs.setInt('crm_call_count', newCount);
      service.invoke('update_call_count', {'count': newCount});
      await BackgroundService._log("📈 Call Count Incremented: $newCount");

      await BackgroundService._log("🖥️ Attempting to show Overlay...");

      if (Platform.isAndroid) {
        final isActive = await FlutterOverlayWindow.isActive();
        await BackgroundService._log("Overlay Active State: $isActive");
        if (!isActive) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: "Incoming Call",
            overlayContent: "$callerName is calling",
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            alignment: OverlayAlignment.topCenter,
            height: found ? 380 : 520,
            width: WindowSize.matchParent,
          );

          // Wait for overlay to be ready
          await Future.delayed(const Duration(milliseconds: 600));

          final data = {
            'phone': phone,
            'name': callerName,
            'type': callerType,
            'docname': callerDocname,
            'found': found,
          };
          await FlutterOverlayWindow.shareData(data);
          await BackgroundService._log("✨ Overlay shown and data shared!");
        } else {
          await BackgroundService._log("ℹ️ Overlay already active. Refreshing data...");
          final data = {
            'phone': phone,
            'name': callerName,
            'type': callerType,
            'docname': callerDocname,
            'found': found,
          };
          await FlutterOverlayWindow.shareData(data);
        }
      }
    } else if (event.status == PhoneStateStatus.CALL_ENDED) {
      await BackgroundService._log("📱 Call Status: ${event.status}. Closing Overlay.");
      if (Platform.isAndroid) {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      }
    }
  });
}
