import 'dart:async';
import 'package:flutter/material.dart';
import 'src/models/user_model.dart';
import 'src/screens/site_setup_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/main_shell.dart';
import 'src/services/api_service.dart';
import 'src/services/storage_service.dart';
import 'src/theme/app_theme.dart';

enum _StartupRoute { siteSetup, login, home }

// ─────────────────────────────────────────────────────────────────────────────
// MyApp — StatefulWidget so _startup future is computed once in initState and
// never re-created on rebuilds (prevents the loading flash when the system
// calls build() again, e.g. on theme changes or orientation).
// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final Future<({_StartupRoute route, UserModel? user})> _startup;
  StreamSubscription<void>? _sessionExpiredSub;
  bool _sessionExpired = false;

  @override
  void initState() {
    super.initState();
    _startup = _resolveStartup();
    _sessionExpiredSub = ApiService.onSessionExpired.listen((_) {
      if (mounted) setState(() => _sessionExpired = true);
    });
  }

  @override
  void dispose() {
    _sessionExpiredSub?.cancel();
    super.dispose();
  }

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
      theme:     CrmTheme.light(),
      darkTheme:  CrmTheme.dark(),
      themeMode:  ThemeMode.system,
      home: FutureBuilder(
        future: _startup,
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
                            Image.asset(
                              'assets/images/logo.png',
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.hub_rounded,
                                  color: AppColors.primary,
                                  size: 64,
                                );
                              },
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

          // Session expired mid-session — redirect to login immediately
          if (_sessionExpired) return const LoginScreen();

          final startup = snapshot.data!;
          return switch (startup.route) {
            _StartupRoute.siteSetup => const SiteSetupScreen(),
            _StartupRoute.login     => const LoginScreen(),
            _StartupRoute.home      => MainShell(user: startup.user!),
          };
        },
      ),
    );
  }
}
