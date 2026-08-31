import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SiteSetupScreen extends StatefulWidget {
  const SiteSetupScreen({super.key});

  @override
  State<SiteSetupScreen> createState() => _SiteSetupScreenState();
}

class _SiteSetupScreenState extends State<SiteSetupScreen>
    with SingleTickerProviderStateMixin {
  final _urlCtrl = TextEditingController();
  bool _saving = false;
  String? _existingUrl;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
    _loadExistingUrl();
  }

  Future<void> _loadExistingUrl() async {
    final url = await StorageService.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _existingUrl = url;
      if (url != null) _urlCtrl.text = url;
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSite() async {
    var url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    setState(() => _saving = true);
    await StorageService.saveBaseUrl(url);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final ac = context.ac;
    
    return Scaffold(
      backgroundColor: ac.bgBase,
      appBar: _existingUrl != null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: ac.textSecondary),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 72),

                  // ── Branding ──────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: 88,
                          height: 88,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.dns_rounded,
                            color: AppColors.primary,
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Connect Your Site',
                          style: TextStyle(
                            color: ac.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your Frappe CRM site URL\nto get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ac.textSecondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Card ──────────────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection indicator
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.link_rounded,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Site Configuration',
                              style: TextStyle(
                                color: ac.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const AppFieldLabel(label: 'Site URL'),
                        const SizedBox(height: 8),
                        AppTextField(
                          controller: _urlCtrl,
                          hint: 'https://yoursite.frappe.cloud',
                          icon: Icons.language_rounded,
                          keyboardType: TextInputType.url,
                          onSubmitted: (_) => _saveSite(),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'e.g. https://demo.frappe.cloud',
                          style: TextStyle(
                            color: ac.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            label: 'Continue',
                            icon: Icons.arrow_forward_rounded,
                            loading: _saving,
                            onTap: _saving ? null : _saveSite,
                          ),
                        ),
                        // Debug-only shortcut. Without this gate it shipped in
                        // release builds, letting a real user skip site setup and
                        // silently point the app at demo.frappe.cloud — every
                        // subsequent request then fails against a site that isn't
                        // theirs, with no obvious way back.
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: AppOutlineButton(
                              label: 'Dev Skip Site Setup',
                              icon: Icons.developer_mode,
                              onTap: () async {
                                await StorageService.saveBaseUrl(
                                    'https://demo.frappe.cloud');
                                if (!context.mounted) return;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const LoginScreen()),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
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
