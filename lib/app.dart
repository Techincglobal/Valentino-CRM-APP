import 'package:flutter/material.dart';
import 'src/models/user_model.dart';
import 'src/screens/site_setup_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/home_screen.dart';
import 'src/services/storage_service.dart';
import 'src/theme/app_theme.dart';

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

      if (sid != null && sid.isNotEmpty) {
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
      return (route: _StartupRoute.login, user: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: FutureBuilder(
        future: _resolveStartup(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.bgStart, AppColors.bgMid, AppColors.bgEnd],
                ),
              ),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: snapshot.hasError
                      ? const Text(
                          'Failed to load. Please restart the app.',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      : SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ),
                        ),
                ),
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
