import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'site_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens (same as rest of app)
// ─────────────────────────────────────────────────────────────────────────────

const _indigo  = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
const _emerald = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);
const _amber   = Color(0xFFF59E0B);
const _violet  = _indigo; // collapsed into the single brand blue

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _serverUrl = '';
  bool   _loading   = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await StorageService.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _serverUrl = url ?? '';
      _loading   = false;
    });
  }


  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _GlassDialog(
        title: 'Sign out?',
        body: 'You will need to log in again to use the app.',
        confirmLabel: 'Sign out',
        confirmColor: _red,
        onCancel: () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    await StorageService.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final top = MediaQuery.of(context).padding.top;
    final ac  = context.ac;

    return Scaffold(
      backgroundColor: ac.bgBase,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _ProfileHeader(user: widget.user, topPad: top)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator(color: _indigo, strokeWidth: 2)),
                      )
                    else ...[
                      // ── Server section ──────────────────────────────────
                      _SectionLabel('CRM SERVER'),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.dns_rounded,
                        iconColor: _indigo,
                        title: 'Server URL',
                        subtitle: _serverUrl.isNotEmpty ? _serverUrl : 'Not configured',
                        trailing: _GlassTextBtn(
                          label: 'Change',
                          color: _indigo,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SiteSetupScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.wifi_rounded,
                        iconColor: _serverUrl.isNotEmpty ? _emerald : _amber,
                        title: 'Connection',
                        subtitle: _serverUrl.isNotEmpty ? 'Configured & active' : 'Not set up',
                        trailing: _serverUrl.isNotEmpty
                            ? _StatusDot(color: _emerald)
                            : _StatusDot(color: _amber),
                      ),

                      const SizedBox(height: 24),

                      // ── App section ─────────────────────────────────────
                      _SectionLabel('APPLICATION'),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: _indigo,
                        title: 'Version',
                        subtitle: '1.0.0 · Build 1',
                      ),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.phone_android_rounded,
                        iconColor: _violet,
                        title: 'Platform',
                        subtitle: 'Android',
                      ),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.shield_outlined,
                        iconColor: _emerald,
                        title: 'Data & Privacy',
                        subtitle: 'All data stored on your CRM server',
                      ),

                      const SizedBox(height: 24),

                      // ── Call Overlay section ─────────────────────────────
                      _SectionLabel('CALL OVERLAY'),
                      const SizedBox(height: 8),
                      _GlassTile(
                        icon: Icons.schedule_rounded,
                        iconColor: _amber,
                        title: 'Settings Managed Centrally',
                        subtitle: 'Overlay hours are configured in Frappe.',
                      ),
                      const SizedBox(height: 32),

                      // ── Sign out ────────────────────────────────────────
                      _SignOutButton(onTap: _signOut),
                    ],
                  ]),
                ),
              ),
            ],
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header — compact adaptive style, consistent with every other screen
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final double topPad;
  const _ProfileHeader({required this.user, required this.topPad});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'[\s._@]+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5BAAFF), _indigo, Color(0xFF1A7FD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _indigo.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: _indigo.withValues(alpha: 0.20), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.settings_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Settings',
                style: TextStyle(color: ac.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _indigo.withValues(alpha: 0.3)),
              ),
              child: Text('ACCOUNT',
                  style: TextStyle(color: _indigo, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
          ]),
        ]),
        const SizedBox(height: 20),
        // ── Profile card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131A2A) : ac.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: _indigo.withValues(alpha: 0.30)),
              ),
              child: Center(child: Text(_initials(user.username),
                  style: TextStyle(color: _indigo, fontSize: 18, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.username,
                    style: TextStyle(color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: _emerald, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('Active', style: TextStyle(color: _emerald, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label — adaptive
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.ac.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass tile row — adaptive
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String   subtitle;
  final Widget?  trailing;
  const _GlassTile({required this.icon, required this.iconColor, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? null : ac.bgCard,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [const Color(0xFF1A2235), const Color(0xFF0D1526)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [iconColor.withValues(alpha: 0.22), iconColor.withValues(alpha: 0.10)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: ac.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trailing micro-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTextBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlassTextBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8)],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sign-out button — adaptive
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_red.withValues(alpha: 0.16), _red.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _red.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: _red.withValues(alpha: 0.85), size: 18),
            const SizedBox(width: 8),
            Text('Sign Out',
                style: TextStyle(color: _red.withValues(alpha: 0.90), fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The End
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Glass dialog — adaptive
// ─────────────────────────────────────────────────────────────────────────────

class _GlassDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  const _GlassDialog({
    required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor,
    required this.onCancel, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? null : ac.bgCard,
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [const Color(0xFF1A2235), const Color(0xFF0D1526)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12), blurRadius: 40, offset: const Offset(0, 16)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 8),
                Text(body, style: TextStyle(color: ac.textSecondary, fontSize: 14, height: 1.5)),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onCancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.bgInput,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                        ),
                        child: Center(
                          child: Text('Cancel', style: TextStyle(color: ac.textSecondary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [confirmColor, Color.lerp(confirmColor, Colors.black, 0.18)!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: confirmColor.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Center(
                          child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
