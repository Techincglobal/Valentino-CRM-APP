import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import 'app.dart';
import 'src/screens/overlay_bubble.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Entry point for the system overlay (runs in a separate Flutter engine).
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2490EF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const OverlayBubble(),
    ),
  );
  // Keep overlay listener active to receive close signals from main app
  FlutterOverlayWindow.overlayListener.listen((_) {});
}
