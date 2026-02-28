import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SiteSetupScreen extends StatefulWidget {
  const SiteSetupScreen({super.key});

  @override
  State<SiteSetupScreen> createState() => _SiteSetupScreenState();
}

class _SiteSetupScreenState extends State<SiteSetupScreen> {
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
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
    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              // Branding
              Center(
                child: Column(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dns_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Connect Your Site',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your Frappe CRM site URL\nto get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 40),

              // Card
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppFieldLabel(label: 'Site URL'),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: _urlCtrl,
                      hint: 'https://yoursite.frappe.cloud',
                      icon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _saveSite(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'e.g. https://demo.frappe.cloud',
                      style: TextStyle(
                        color: AppColors.textTertiary,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
