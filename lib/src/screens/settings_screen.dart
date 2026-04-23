import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'site_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens (same as rest of app)
// ─────────────────────────────────────────────────────────────────────────────

const _indigo  = Color(0xFF6366F1);
const _emerald = Color(0xFF10B981);
const _red     = Color(0xFFEF4444);
const _amber   = Color(0xFFF59E0B);
const _violet  = Color(0xFF8B5CF6);
const _slate   = Color(0xFF94A3B8);

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

  // Overlay schedule state
  bool          _overlayEnabled     = true;
  bool          _officeHoursEnabled = false;
  TimeOfDay     _officeStart        = const TimeOfDay(hour: 9,  minute: 0);
  TimeOfDay     _officeEnd          = const TimeOfDay(hour: 17, minute: 0);
  // true = day active; index 0=Mon … 6=Sun
  List<bool>    _officeDays         = [true, true, true, true, true, false, false];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final results = await Future.wait([
      StorageService.getBaseUrl(),
      StorageService.getOverlayEnabled(),
      StorageService.getOfficeHoursEnabled(),
      StorageService.getOfficeHoursStart(),
      StorageService.getOfficeHoursEnd(),
      StorageService.getOfficeHoursDays(),
    ]);
    if (!mounted) return;
    final url          = results[0] as String?;
    final overlayOn    = results[1] as bool;
    final officeOn     = results[2] as bool;
    final startStr     = results[3] as String;
    final endStr       = results[4] as String;
    final days         = results[5] as List<int>;

    final startParts = startStr.split(':');
    final endParts   = endStr.split(':');

    final activeDays = List<bool>.filled(7, false);
    for (final d in days) {
      if (d >= 1 && d <= 7) activeDays[d - 1] = true;
    }

    setState(() {
      _serverUrl          = url ?? '';
      _loading            = false;
      _overlayEnabled     = overlayOn;
      _officeHoursEnabled = officeOn;
      _officeStart        = TimeOfDay(
        hour:   int.tryParse(startParts.first) ?? 9,
        minute: int.tryParse(startParts.last)  ?? 0,
      );
      _officeEnd          = TimeOfDay(
        hour:   int.tryParse(endParts.first) ?? 17,
        minute: int.tryParse(endParts.last)  ?? 0,
      );
      _officeDays = activeDays;
    });
  }

  Future<void> _setOverlayEnabled(bool v) async {
    setState(() => _overlayEnabled = v);
    await StorageService.saveOverlayEnabled(v);
  }

  Future<void> _setOfficeHoursEnabled(bool v) async {
    setState(() => _officeHoursEnabled = v);
    await StorageService.saveOfficeHoursEnabled(v);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context:     context,
      initialTime: isStart ? _officeStart : _officeEnd,
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary:   _indigo,
            surface:   const Color(0xFF1A2235),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    if (isStart) {
      setState(() => _officeStart = picked);
      final s = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
      await StorageService.saveOfficeHoursStart(s);
    } else {
      setState(() => _officeEnd = picked);
      final s = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
      await StorageService.saveOfficeHoursEnd(s);
    }
  }

  Future<void> _toggleDay(int index) async {
    final updated = List<bool>.from(_officeDays)..[index] = !_officeDays[index];
    setState(() => _officeDays = updated);
    final activeDayNums = <int>[];
    for (var i = 0; i < updated.length; i++) {
      if (updated[i]) activeDayNums.add(i + 1);
    }
    await StorageService.saveOfficeHoursDays(activeDayNums);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';


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
    await StorageService.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SiteSetupScreen()),
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
      body: Stack(
        children: [
          // ── Background mesh glows ──────────────────────────────────────────
          Positioned(
            top: -60, right: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _violet.withValues(alpha: 0.16),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 120, left: -60,
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _indigo.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // ── Main content ───────────────────────────────────────────────────
          CustomScrollView(
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
                        iconColor: const Color(0xFF60A5FA),
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
                      _ToggleTile(
                        icon:      Icons.phone_in_talk_rounded,
                        iconColor: _emerald,
                        title:     'Show Call Overlay',
                        subtitle:  _overlayEnabled
                            ? 'Overlay shown on incoming calls'
                            : 'Overlay disabled — calls will not show info',
                        value:     _overlayEnabled,
                        onChanged: _setOverlayEnabled,
                      ),
                      const SizedBox(height: 8),
                      _ToggleTile(
                        icon:      Icons.schedule_rounded,
                        iconColor: _overlayEnabled ? _amber : _slate,
                        title:     'Office Hours Only',
                        subtitle:  _overlayEnabled
                            ? (_officeHoursEnabled
                                ? 'Overlay active ${_fmtTime(_officeStart)} – ${_fmtTime(_officeEnd)}'
                                : 'Show overlay at all times')
                            : 'Enable overlay first',
                        value:     _overlayEnabled && _officeHoursEnabled,
                        onChanged: _overlayEnabled ? _setOfficeHoursEnabled : null,
                      ),
                      if (_overlayEnabled && _officeHoursEnabled) ...[
                        const SizedBox(height: 8),
                        // Time range
                        Row(children: [
                          Expanded(
                            child: _TimeTile(
                              label:   'Start',
                              time:    _officeStart,
                              onTap:   () => _pickTime(isStart: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TimeTile(
                              label:   'End',
                              time:    _officeEnd,
                              onTap:   () => _pickTime(isStart: false),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        // Days of week
                        _DaySelector(
                          activeDays: _officeDays,
                          onToggle:   _toggleDay,
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Sign out ────────────────────────────────────────
                      _SignOutButton(onTap: _signOut),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile hero header — always dark gradient (brand section)
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1240), Color(0xFF0A0F1E), Color(0xFF14102E)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, topPad + 22, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _violet.withValues(alpha: 0.28)),
                  ),
                  child: const Text('ACCOUNT',
                      style: TextStyle(color: _violet, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white54, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Settings',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1)),
            const SizedBox(height: 22),
            // ── Profile glass card ──────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: 0.10), Colors.white.withValues(alpha: 0.04)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                    boxShadow: [
                      BoxShadow(color: _indigo.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 58, height: 58,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [_indigo, _violet],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.40), blurRadius: 16, offset: const Offset(0, 5))],
                        ),
                        child: Center(child: Text(_initials(user.username),
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.username,
                                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                            const SizedBox(height: 5),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _indigo.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: _indigo.withValues(alpha: 0.35)),
                                ),
                                child: const Text('CRM USER',
                                    style: TextStyle(color: _indigo, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: _emerald, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: _emerald.withValues(alpha: 0.6), blurRadius: 6)],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text('Active', style: TextStyle(color: _emerald, fontSize: 11, fontWeight: FontWeight.w600)),
                            ]),
                          ],
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
          if (trailing case final t?) t,
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
// Toggle tile — GlassTile with a Switch trailing
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData   icon;
  final Color      iconColor;
  final String     title;
  final String     subtitle;
  final bool       value;
  final void Function(bool)? onChanged;

  const _ToggleTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final active = onChanged != null;
    return GestureDetector(
      onTap: active ? () => onChanged!(!value) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? null : ac.bgCard,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2235), Color(0xFF0D1526)],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [iconColor.withValues(alpha: active ? 0.22 : 0.10), iconColor.withValues(alpha: active ? 0.10 : 0.04)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: active ? 0.25 : 0.10)),
            ),
            child: Icon(icon, color: active ? iconColor : iconColor.withValues(alpha: 0.40), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: active ? ac.textPrimary : ac.textTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: ac.textSecondary, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Switch(
            value:           value,
            onChanged:       active ? onChanged : null,
            activeThumbColor: iconColor,
            activeTrackColor: iconColor.withValues(alpha: 0.40),
            inactiveThumbColor: ac.textTertiary,
            inactiveTrackColor: isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Time tile — tappable pill showing a time
// ─────────────────────────────────────────────────────────────────────────────

class _TimeTile extends StatelessWidget {
  final String     label;
  final TimeOfDay  time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark ? null : ac.bgCard,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2235), Color(0xFF0D1526)],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.access_time_rounded, size: 15, color: _amber),
            const SizedBox(width: 6),
            Text(_fmt(time), style: TextStyle(color: ac.textPrimary, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
            const Spacer(),
            Icon(Icons.edit_rounded, size: 13, color: ac.textTertiary),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day selector — 7 pill toggles Mon–Sun
// ─────────────────────────────────────────────────────────────────────────────

class _DaySelector extends StatelessWidget {
  final List<bool>      activeDays; // length 7, index 0=Mon
  final void Function(int) onToggle;
  const _DaySelector({required this.activeDays, required this.onToggle});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? null : ac.bgCard,
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A2235), Color(0xFF0D1526)],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ACTIVE DAYS', style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final on = activeDays[i];
            return GestureDetector(
              onTap: () => onToggle(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: on
                      ? const LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [_indigo, Color(0xFF4F46E5)],
                        )
                      : null,
                  color: on ? null : (isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: on ? _indigo.withValues(alpha: 0.60) : (isDark ? Colors.white.withValues(alpha: 0.09) : ac.border),
                  ),
                  boxShadow: on
                      ? [BoxShadow(color: _indigo.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(
                    _labels[i],
                    style: TextStyle(
                      color:      on ? Colors.white : ac.textTertiary,
                      fontSize:   13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

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
