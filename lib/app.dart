import 'package:flutter/material.dart';
import 'src/models/user_model.dart';
import 'src/screens/site_setup_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/services/storage_service.dart';

enum _StartupRoute { siteSetup, login, home }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<({_StartupRoute route, UserModel? user})> _resolveStartup() async {
    try {
      final baseUrl = await StorageService.getBaseUrl();
      if (baseUrl == null || baseUrl.isEmpty) {
        return (route: _StartupRoute.siteSetup, user: null);
      }

      final sid = await StorageService.getSessionId();

      // sid present → treat as logged in (session may have expired, APIs will
      // show errors naturally; user can sign out from the menu).
      if (sid != null && sid.isNotEmpty) {
        // full_name might not have been saved on older installs — fall back gracefully
        final fullName = await StorageService.getFullName();

        // Sync credentials to SharedPreferences so native CallService can read
        // them even if the user logged in before this migration was added.
        await StorageService.saveBaseUrl(baseUrl);
        await StorageService.saveSessionId(sid);

        return (
          route: _StartupRoute.home,
          user: UserModel(username: fullName ?? ''),
        );
      }

      return (route: _StartupRoute.login, user: null);
    } catch (_) {
      // Keystore or storage error — send user to login
      return (route: _StartupRoute.login, user: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2490EF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: FutureBuilder(
        future: _resolveStartup(),
        builder: (context, snapshot) {
          // Error or still loading
          if (!snapshot.hasData) {
            return Scaffold(
              body: Center(
                child: snapshot.hasError
                    ? const Text('Failed to load. Please restart the app.')
                    : const CircularProgressIndicator(),
              ),
            );
          }

          final startup = snapshot.data!;
          return switch (startup.route) {
            _StartupRoute.siteSetup => const SiteSetupScreen(),
            _StartupRoute.login => const LoginScreen(),
            _StartupRoute.home => HomeScreen(user: startup.user!),
          };
        },
      ),
    );
  }
}
