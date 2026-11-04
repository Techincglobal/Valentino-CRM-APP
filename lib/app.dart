import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'src/models/user_model.dart';
import 'src/screens/site_setup_screen.dart';
import 'src/screens/login_screen.dart';
import 'src/screens/main_shell.dart';
import 'src/services/api_service.dart';
import 'src/services/native_call_service.dart';
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
        // Verify the session is still alive. If the server says 401 (expired
        // after an app update, server restart, etc.) clear it and go to login
        // immediately — avoids the home screen loading with all-unknown data.
        // On network error / timeout we still go to home so offline cache works.
        final sessionOk = await _pingSession(baseUrl, sid);
        if (!sessionOk) {
          await StorageService.clearSession();
          return (route: _StartupRoute.login, user: null);
        }

        final fullName = await StorageService.getFullName();

        // Sync credentials to SharedPreferences so native CallService can read
        // them even if the user logged in before this migration was added.
        await StorageService.saveBaseUrl(baseUrl);
        await StorageService.saveSessionId(sid);
        await NativeCallService.startCallMonitor();

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

  // Returns false only when the server explicitly says the session is invalid
  // (401/403). Any network/timeout error returns true so offline mode still
  // reaches home with cached data. Also captures a fresh CSRF token so the
  // first POST doesn't need a 403 → refresh → retry cycle.
  static Future<bool> _pingSession(String baseUrl, String sid) async {
    try {
      final url = Uri.parse('$baseUrl/api/method/frappe.auth.get_logged_user');
      final resp = await http
          .get(url, headers: {'Cookie': 'sid=$sid', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 401 || resp.statusCode == 403) return false;

      // Frappe sends a fresh csrf_token in Set-Cookie on every GET response.
      // Save it now so the first POST has a valid token without needing a retry.
      final setCookie = resp.headers['set-cookie'] ?? '';
      final match = RegExp(r'csrf_token=([^;,\s]+)').firstMatch(setCookie);
      final csrf = match?.group(1);
      if (csrf != null && csrf.isNotEmpty) {
        await StorageService.saveCsrfToken(csrf);
      }

      return true;
    } on SocketException {
      return true; // offline — let the app proceed with cached data
    } on TimeoutException {
      return true; // slow server — don't block startup
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valentino CRM',
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
                              'Starting Valentino CRM...',
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
