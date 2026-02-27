import 'package:flutter/material.dart';
import 'src/screens/site_setup_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/services/storage_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _hasBaseUrl() async {
    final url = await StorageService.getBaseUrl();
    return url != null && url.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<bool>(
        future: _hasBaseUrl(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.data == true) {
            return const LoginScreen();
          } else {
            return const SiteSetupScreen();
          }
        },
      ),
    );
  }
}