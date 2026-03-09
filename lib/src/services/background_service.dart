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
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground',
      'Caller App Service',
      description: 'Monitors incoming calls for CRM integration.',
      importance: Importance.high, // Increased importance
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
  debugPrint("🚀 [BackgroundService] onStart initialized!");

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

  service.on('stopService').listen((event) => service.stopSelf());

  PhoneState.stream.listen((event) async {
    debugPrint(
      "📞 [BackgroundService] Phone Event: ${event.status} | Number: ${event.number}",
    );

    if (event.status == PhoneStateStatus.CALL_INCOMING) {
      if (event.number == null) {
        debugPrint(
          "⚠️ [BackgroundService] Incoming call detected but number is NULL!",
        );
        return;
      }
      final phone = event.number!;
      debugPrint("🔍 [BackgroundService] Processing Incoming Call: $phone");

      String callerName = 'Unknown Caller';
      String callerType = '';
      String callerDocname = '';
      bool found = false;

      try {
        final details = await CallerService.getCallerDetails(phone);
        found = details['found'] == true;
        callerName =
            details['customer_name'] ?? details['name'] ?? 'Unknown Caller';
        callerType = details['type'] ?? '';
        callerDocname = details['name'] ?? '';
        debugPrint("✅ [BackgroundService] Caller Identified: $callerName");
      } catch (e) {
        debugPrint("❌ [BackgroundService] CRM Lookup Error: $e");
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("crm_caller_phone", phone);
      await prefs.setString("crm_caller_name", callerName);
      await prefs.setString("crm_caller_type", callerType);
      await prefs.setString("crm_caller_docname", callerDocname);
      await prefs.setBool("crm_caller_found", found);

      debugPrint("🖥️ [BackgroundService] Attempting to show Overlay...");

      if (Platform.isAndroid) {
        final isActive = await FlutterOverlayWindow.isActive();
        if (!isActive) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: "Incoming Call",
            overlayContent: "$callerName is calling",
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            alignment: OverlayAlignment.topCenter,
            height: 250,
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
          debugPrint("✨ [BackgroundService] Overlay shown and data shared!");
        } else {
          debugPrint(
            "ℹ️ [BackgroundService] Overlay active. Refreshing data...",
          );
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
    } else if (event.status == PhoneStateStatus.CALL_ENDED ||
        event.status == PhoneStateStatus.CALL_STARTED) {
      debugPrint(
        "📱 [BackgroundService] Call Status Change: ${event.status}. Closing Overlay.",
      );
      if (Platform.isAndroid) {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      }
    }
  });
}
