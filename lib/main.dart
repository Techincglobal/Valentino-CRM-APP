import 'package:flutter/material.dart';

import 'app.dart';
import 'src/screens/overlay_bubble.dart';
import 'src/theme/app_theme.dart';

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
      theme: CrmTheme.light(),
      darkTheme: CrmTheme.dark(),
      themeMode: ThemeMode.system,
      home: const OverlayBubble(),
    ),
  );
}
