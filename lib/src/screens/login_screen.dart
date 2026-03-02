import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'site_setup_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) return;

    final baseUrl = await StorageService.getBaseUrl();
    if (baseUrl == null) {
      _showError('Site URL not configured');
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await AuthService.login(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(
            user: UserModel(
              username: result['full_name'] as String? ?? username,
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 17,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo + branding
                Center(
                  child: Column(
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
                              color: AppColors.primary.withValues(alpha: 0.4),
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
                        child: const Icon(
                          Icons.hub_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'CRM Caller',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Welcome back. Sign in to continue.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Card
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Username
                      const AppFieldLabel(label: 'Email / Username'),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _userCtrl,
                        hint: 'you@example.com',
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                      ),

                      const SizedBox(height: 18),

                      // Password
                      const AppFieldLabel(label: 'Password'),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _passCtrl,
                        hint:
                            '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscure,
                        onSubmitted: (_) => _login(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textTertiary,
                            size: 20,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'Sign In',
                          icon: Icons.arrow_forward_rounded,
                          loading: _loading,
                          onTap: _loading ? null : _login,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Change site link
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SiteSetupScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.language_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Change Site Configuration',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
