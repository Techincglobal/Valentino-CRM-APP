import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

const _primary = Color(0xFF2490EF);
const _primaryDark = Color(0xFF1A6EC7);
const _bgPage = Color(0xFFF0F4F8);
const _cardBg = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF1F272B);
const _textSecondary = Color(0xFF687076);
const _border = Color(0xFFE2E8F0);
const _inputBg = Color(0xFFF8FAFC);

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
    return Scaffold(
      backgroundColor: _bgPage,
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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.dns_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Connect Your Site',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter your Frappe CRM site URL to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                ]),
              ),

              const SizedBox(height: 40),

              // Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Site URL',
                      style: TextStyle(
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _urlCtrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      onSubmitted: (_) => _saveSite(),
                      style: const TextStyle(
                          color: _textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'https://yoursite.frappe.cloud',
                        hintStyle: const TextStyle(
                            color: _textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.link_rounded,
                            color: _textSecondary, size: 18),
                        filled: true,
                        fillColor: _inputBg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: _border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: _primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'e.g. https://demo.frappe.cloud',
                      style: TextStyle(
                          color: _textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveSite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _primary.withValues(alpha: 0.5),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text('Continue',
                                      style: TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                          fontSize: 15)),
                                  SizedBox(width: 6),
                                  Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 17),
                                ],
                              ),
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
