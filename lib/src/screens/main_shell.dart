import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'sales_screen.dart';
import 'quotes_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MainShell
// IndexedStack keeps every page alive — no fade, no blackout.
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final UserModel user;
  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  late final _pages = [
    HomeScreen(user: widget.user),
    SalesScreen(onGoToQuotes: () => _onTap(2)),
    const QuotesScreen(),
    SettingsScreen(user: widget.user),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Pages — instant switch, no animation ─────────────────────────
          IndexedStack(index: _index, children: _pages),

          // ── Floating glass nav bar — always on top ────────────────────────
          _GlassNavBar(currentIndex: _index, onTap: _onTap),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlassNavBar  — frosted pill floating at the bottom centre
// BackdropFilter is fine here — it's one static widget, not in a list.
// ─────────────────────────────────────────────────────────────────────────────

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    // viewPadding.bottom is never reduced by the keyboard — ensures the nav bar
    // stays correctly positioned after overlay keyboard interactions end.
    final bottom = MediaQuery.of(context).viewPadding.bottom;

    return Positioned(
      bottom: bottom + 18,
      left: 0,
      right: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0D1117).withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.09)
                      : Colors.black.withValues(alpha: 0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                    blurRadius: 20,
                    offset:     const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _NavPill(icon: Icons.home_rounded,          label: 'Home',     selected: currentIndex == 0, onTap: () => onTap(0)),
                  const SizedBox(width: 4),
                  _NavPill(icon: Icons.trending_up_rounded,   label: 'Pipeline', selected: currentIndex == 1, onTap: () => onTap(1)),
                  const SizedBox(width: 4),
                  _NavPill(icon: Icons.receipt_long_rounded,  label: 'Quotes',   selected: currentIndex == 2, onTap: () => onTap(2)),
                  const SizedBox(width: 4),
                  _NavPill(icon: Icons.settings_rounded,      label: 'Settings', selected: currentIndex == 3, onTap: () => onTap(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavPill — fast 150 ms spring feel
// ─────────────────────────────────────────────────────────────────────────────

class _NavPill extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 13,
          vertical:   10,
        ),
        decoration: BoxDecoration(
          color:        selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : ac.textSecondary,
              size:  20,
            ),
            if (selected) ...[
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color:         Colors.white,
                  fontSize:      13,
                  fontWeight:    FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
