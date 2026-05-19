import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'tickets_screen.dart';
import 'sales_screen.dart' show SalesScreen, SalesScreenController;
import 'quotes_screen.dart' show QuotesScreen, QuotesScreenController;
import 'settings_screen.dart';
import 'call_logs_screen.dart';

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

  final _salesKey  = GlobalKey();
  final _quotesKey = GlobalKey();

  static const _overlayChannel = MethodChannel('crm_caller_nxtgen/native_overlay');

  @override
  void initState() {
    super.initState();
    _overlayChannel.setMethodCallHandler(_handleNativeCall);
  }

  @override
  void dispose() {
    _overlayChannel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onPipelineRefreshNeeded') {
      (_salesKey.currentState as SalesScreenController?)?.refreshPipeline();
    }
  }

  void _onTap(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    if (i == 2) {
      (_salesKey.currentState as SalesScreenController?)?.refreshPipeline();
    } else if (i == 3) {
      (_quotesKey.currentState as QuotesScreenController?)?.refreshQuotes();
    }
    // index 4 = Call Logs, index 5 = Settings — no refresh needed
  }

  late final _pages = [
    HomeScreen(
      user: widget.user,
      onOpportunityCreated: () {
        (_salesKey.currentState as SalesScreenController?)?.refreshPipeline();
      },
    ),
    TicketsScreen(user: widget.user),
    SalesScreen(key: _salesKey, onGoToQuotes: () => _onTap(3)),
    QuotesScreen(key: _quotesKey),
    const CallLogsScreen(),
    SettingsScreen(user: widget.user),
  ];

  // Nav bar pill height + spacing — used to push inner-Scaffold FABs above the pill.
  static const _kNavBarArea = 76.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final navOffset = _kNavBarArea + mq.viewPadding.bottom;

    return Scaffold(
      backgroundColor: context.ac.bgBase,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Tell pages how much bottom space the floating nav bar takes so
          // inner-Scaffold FABs and scroll lists don't hide behind it.
          MediaQuery(
            data: mq.copyWith(
              padding:     mq.padding.copyWith(bottom: navOffset),
              viewPadding: mq.viewPadding.copyWith(bottom: navOffset),
            ),
            child: IndexedStack(index: _index, children: _pages),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 18),
              child: Center(
                child: RepaintBoundary(
                  child: _GlassNavBar(currentIndex: _index, onTap: _onTap),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GlassNavBar
// iOS:     ClipRRect + BackdropFilter (blur works in release builds on iOS)
// Android: Solid gradient pill — BackdropFilter renders invisible in Android
//          release APKs due to a known Flutter/Skia compositor bug.
// ─────────────────────────────────────────────────────────────────────────────

class _GlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GlassNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final pills = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavPill(icon: Icons.home_rounded,                  label: 'Home',     selected: currentIndex == 0, onTap: () => onTap(0)),
        const SizedBox(width: 4),
        _NavPill(icon: Icons.confirmation_number_rounded,   label: 'Tickets',  selected: currentIndex == 1, onTap: () => onTap(1)),
        const SizedBox(width: 4),
        _NavPill(icon: Icons.trending_up_rounded,           label: 'Pipeline', selected: currentIndex == 2, onTap: () => onTap(2)),
        const SizedBox(width: 4),
        _NavPill(icon: Icons.receipt_long_rounded,          label: 'Quotes',   selected: currentIndex == 3, onTap: () => onTap(3)),
        const SizedBox(width: 4),
        _NavPill(icon: Icons.call_rounded,                  label: 'Calls',    selected: currentIndex == 4, onTap: () => onTap(4)),
        const SizedBox(width: 4),
        _NavPill(icon: Icons.settings_rounded,              label: 'Settings', selected: currentIndex == 5, onTap: () => onTap(5)),
      ],
    );

    final Widget pill;

    if (Platform.isIOS) {
      // iOS: real frosted glass
      pill = ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0D1117).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.07),
              ),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                  blurRadius: 24,
                  offset:     const Offset(0, 8),
                ),
              ],
            ),
            child: pills,
          ),
        ),
      );
    } else {
      // Android: solid gradient pill — blur is unreliable in release APKs
      pill = Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF1C2333), const Color(0xFF0D1117)]
                : [Colors.white, const Color(0xFFF0F3FF)],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.primary.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: isDark ? 0.60 : 0.12),
              blurRadius: 28,
              spreadRadius: 0,
              offset:     const Offset(0, 8),
            ),
            BoxShadow(
              color:      AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
              blurRadius: 12,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: pills,
      );
    }

    return pill;
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
          horizontal: selected ? 14 : 10,
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
