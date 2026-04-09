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
      theme: CrmTheme.light(),
      darkTheme: CrmTheme.dark(),
      themeMode: ThemeMode.system,
      home: FutureBuilder(
        future: _resolveStartup(),
        builder: (context, snapshot) {
          final ac = context.ac;
          if (!snapshot.hasData) {
            return Container(
              color: ac.bgBase,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: Center(
                  child: snapshot.hasError
                      ? Text(
                          'Failed to load. Please restart the app.',
                          style: TextStyle(color: ac.textSecondary),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primaryLight,
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                    spreadRadius: 4,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.hub_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Starting CRM Caller...',
                              style: TextStyle(
                                color: ac.textSecondary,
                                fontSize: 13,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
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
