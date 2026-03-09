import 'dart:ui';
import 'package:flutter/material.dart';

import 'app.dart';
import 'src/screens/overlay_bubble.dart';
import 'src/services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.initializeService();
  runApp(const MyApp());
}

/// Entry point for the system overlay (runs in a separate Flutter engine).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const OverlayBubble(),
    ),
  );
}
