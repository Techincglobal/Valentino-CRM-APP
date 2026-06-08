import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'main_shell.dart';
import 'site_setup_screen.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  static final _emailRe = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  Future<void> _login() async {
    final usr = _userCtrl.text.trim();
    final pwd = _passCtrl.text.trim();

    if (usr.isEmpty) {
      _showError('Please enter your username or email.');
      return;
    }
    if (usr.contains('@') && !_emailRe.hasMatch(usr)) {
      _showError('Enter a valid email address (e.g. you@example.com).');
      return;
    }
    if (pwd.isEmpty) {
      _showError('Please enter your password.');
      return;
    }
    if (pwd.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }
    final baseUrl = await StorageService.getBaseUrl();
    if (baseUrl == null) {
      _showError('Site URL not configured. Tap "Change Site Configuration" below.');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await AuthService.login(
        baseUrl: baseUrl,
        username: usr,
        password: pwd,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainShell(
            user: UserModel(
              username: result['full_name'] as String? ?? usr,
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
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    setSystemUIOverlay(context);
    final ac = context.ac;
    return Scaffold(
      backgroundColor: ac.bgBase,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // ── Branding ──────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        // Logo glow ring
                        Image.asset(
                          'assets/images/logo.png',
                          width: 88,
                          height: 88,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.hub_rounded,
                            color: AppColors.primary,
                            size: 64,
                          ),
                        ),
                         const SizedBox(height: 28),
                        Text(
                          'CRM Caller',
                          style: TextStyle(
                            color: ac.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Welcome back. Sign in to continue.',
                          style: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 15,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Login Card ────────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        const AppFieldLabel(label: 'Password'),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _passCtrl,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscureText: _obscure,
                          onSubmitted: (_) => _login(),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: ac.textTertiary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
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

                  const SizedBox(height: 28),

                  // ── Change Site ───────────────────────────────────────────
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const SiteSetupScreen()),
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        borderRadius: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language_rounded,
                                size: 16, color: ac.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Change Site Configuration',
                              style: TextStyle(
                                color: ac.textSecondary,
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
      ),
    );
  }
}
