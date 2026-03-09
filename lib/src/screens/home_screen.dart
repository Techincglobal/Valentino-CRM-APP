import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/caller_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'overlay_bubble.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();
  StreamSubscription<PhoneState>? _phoneSubscription;

  bool _loading = false;
  int _callsToday = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePhoneListener();
    _loadDailyCallCount();
  }

  Future<void> _loadDailyCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final savedDate = prefs.getString('crm_call_date') ?? '';

    if (savedDate == today) {
      if (mounted) {
        setState(() {
          _callsToday = prefs.getInt('crm_call_count') ?? 0;
        });
      }
    } else {
      await prefs.setString('crm_call_date', today);
      await prefs.setInt('crm_call_count', 0);
      if (mounted) {
        setState(() {
          _callsToday = 0;
        });
      }
    }
  }

  Future<void> _incrementCallCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final savedDate = prefs.getString('crm_call_date') ?? '';

    int newCount = 1;
    if (savedDate == today) {
      newCount = (prefs.getInt('crm_call_count') ?? 0) + 1;
    } else {
      await prefs.setString('crm_call_date', today);
    }

    await prefs.setInt('crm_call_count', newCount);
    if (mounted) {
      setState(() {
        _callsToday = newCount;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Left empty since we no longer track lifecycle manually for overlays
  }

  Future<void> _initializePhoneListener() async {
    if (!Platform.isAndroid) return;

    // 1. Standard phone permissions
    await [Permission.phone, Permission.notification].request();

    // 2. Battery Optimization (for reliable background execution)
    // Most Chinese OEMs (Xiaomi, Oppo) kill background apps unless this is enabled.
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // 3. System Alert Window (Overlay)
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }

    _phoneSubscription = PhoneState.stream.listen((PhoneState event) {
      if (event.status == PhoneStateStatus.CALL_INCOMING &&
          event.number != null &&
          event.number!.isNotEmpty) {
        _handleIncomingNumber(event.number!);
      }
    });
  }

  Future<void> _handleIncomingNumber(String phone) async {
    if (!mounted) return;
    setState(() => _loading = true);

    await _incrementCallCount();

    Map<String, dynamic> response;
    try {
      response = await CallerService.getCallerDetails(phone);
    } catch (e) {
      if (!mounted) return;
      // Show snackbar, but continue to show popup with fallback data
      _showError('Lookup failed (Using Fallback)');
      response = {
        'found': false,
        'name': 'Unknown Caller',
        'customer_name': 'Unknown Caller',
        'type': 'Network/API Error',
      };
    }

    if (!mounted) return;

    try {
      await _saveCallerDataToPrefs(phone, response);

      if (Platform.isAndroid) {
        final isActive = await FlutterOverlayWindow.isActive();
        if (!isActive) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: 'CRM Caller',
            overlayContent: 'Looking up details...',
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            alignment: OverlayAlignment.center,
            height: 220,
            width: 340,
          );

          // Wait to be ready
          await Future.delayed(const Duration(milliseconds: 600));

          final data = {
            'phone': phone,
            'name':
                response['customer_name'] ??
                response['name'] ??
                'Unknown Caller',
            'type': response['type'] ?? '',
            'docname': response['name'] ?? '',
            'found': response['found'] == true,
          };
          await FlutterOverlayWindow.shareData(data);
        } else {
          final data = {
            'phone': phone,
            'name':
                response['customer_name'] ??
                response['name'] ??
                'Unknown Caller',
            'type': response['type'] ?? '',
            'docname': response['name'] ?? '',
            'found': response['found'] == true,
          };
          await FlutterOverlayWindow.shareData(data);
        }
      } else {
        if (!mounted) return;
        // Render fake overlay for iOS testing
        showDialog(
          context: context,
          barrierColor: Colors.black26,
          builder: (context) {
            return const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 100),
                child: OverlayBubble(),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Overlay error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCallerDataToPrefs(
    String phone,
    Map<String, dynamic> result,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_caller_phone', phone);
    await prefs.setString(
      'crm_caller_name',
      (result['customer_name'] as String?) ?? '',
    );
    await prefs.setString('crm_caller_type', (result['type'] as String?) ?? '');
    await prefs.setString(
      'crm_caller_docname',
      (result['name'] as String?) ?? '',
    );
    await prefs.setBool('crm_caller_found', result['found'] == true);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneSubscription?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top +
              76, // accounts for floating app bar
          16,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardCard(
              username: widget.user.username,
              callsToday: _callsToday,
            ),
            const SizedBox(height: 16),
            _ManualLookupCard(
              controller: _phoneController,
              loading: _loading,
              onLookup: () {
                final phone = _phoneController.text.trim();
                if (phone.isNotEmpty) _handleIncomingNumber(phone);
              },
            ),
            const SizedBox(height: 16),
            const _StatusCard(),
            const SizedBox(height: 16),
            const _OverlayPermissionCard(),
            const SizedBox(height: 16),
            _TestOverlayCard(
              onTest: () => _handleIncomingNumber('+91 99999 88888'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.15),
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(color: Colors.transparent),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(
          color: Colors.white.withValues(alpha: 0.2),
          height: 1.0,
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'CRM Caller',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Center(
                child: Text(
                  widget.user.username.isNotEmpty
                      ? widget.user.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Signed in',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'logout',
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Sign out',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await StorageService.clearAll();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// HOME CARDS
// ════════════════════════════════════════════════════════════════════════════════

class _DashboardCard extends StatelessWidget {
  final String username;
  final int callsToday;
  const _DashboardCard({required this.username, required this.callsToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark, Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
            spreadRadius: 4,
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header row with Username and Active status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      username,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF4ADE80,
                            ).withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          // Main stat
          Container(
            padding: const EdgeInsets.all(42),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  callsToday.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Calls Today',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ManualLookupCard extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onLookup;

  const _ManualLookupCard({
    required this.controller,
    required this.loading,
    required this.onLookup,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Manual Lookup',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 42),
            child: Text(
              'Search a phone number in your CRM',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  hint: '+91 98765 43210',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => onLookup(),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: loading ? null : onLookup,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: loading
                          ? [
                              AppColors.primary.withValues(alpha: 0.5),
                              AppColors.primaryDark.withValues(alpha: 0.5),
                            ]
                          : [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: loading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Lookup',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  const _StatusCard();

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.sensors_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Auto Detection',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return _StatusRow(
                color: AppColors.success,
                text: 'Listening for incoming calls',
                pulseValue: _pulseCtrl.value,
              );
            },
          ),
          const SizedBox(height: 10),
          _StatusRow(
            color: AppColors.primary,
            text: 'CRM lookup runs automatically on incoming calls',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Color color;
  final String text;
  final double pulseValue;
  const _StatusRow({
    required this.color,
    required this.text,
    this.pulseValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4 + (pulseValue * 0.4)),
                blurRadius: 4 + (pulseValue * 4),
                spreadRadius: 1 + (pulseValue * 2),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Overlay Permission Card ─────────────────────────────────────────────────

class _OverlayPermissionCard extends StatefulWidget {
  const _OverlayPermissionCard();

  @override
  State<_OverlayPermissionCard> createState() => _OverlayPermissionCardState();
}

class _OverlayPermissionCardState extends State<_OverlayPermissionCard>
    with WidgetsBindingObserver {
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!Platform.isAndroid) {
      if (mounted) setState(() => _granted = true);
      return;
    }

    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (mounted) setState(() => _granted = granted);
    } catch (_) {
      if (mounted) setState(() => _granted = true);
    }
  }

  Future<void> _request() async {
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bubble_chart_outlined,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Background Bubble',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 42),
            child: Text(
              'Grant "Display over other apps" so the CRM bubble appears when a call ends, even when the app is closed.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _request,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warning, Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security_rounded, size: 17, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Grant Permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEETS
// ════════════════════════════════════════════════════════════════════════════════

class _CreateLeadSheet extends StatefulWidget {
  final String phone;
  const _CreateLeadSheet({required this.phone});

  @override
  State<_CreateLeadSheet> createState() => _CreateLeadSheetState();
}

class _CreateLeadSheetState extends State<_CreateLeadSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Lead name is required', AppColors.danger);
      return;
    }

    setState(() => _saving = true);

    try {
      await CallerService.createLead(
        firstName: name,
        mobile: widget.phone,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSnack(
        'Lead created successfully',
        AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color bg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return AppSheetContainer(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSheetHandle(),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: AppColors.warning,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unknown Caller',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _SheetCloseBtn(),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 20),

          // Name
          const AppFieldLabel(label: 'Lead Name', required: true),
          const SizedBox(height: 8),
          AppTextField(
            controller: _nameCtrl,
            hint: 'Enter full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Email
          const AppFieldLabel(label: 'Email (Optional)'),
          const SizedBox(height: 8),
          AppTextField(
            controller: _emailCtrl,
            hint: 'email@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),

          // Note
          const AppFieldLabel(label: 'Call Note'),
          const SizedBox(height: 8),
          AppTextField(
            controller: _noteCtrl,
            hint: 'Briefly describe this call...',
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppOutlineButton(
                  label: 'Cancel',
                  onTap: _saving ? null : () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AppButton(
                  label: 'Create Lead',
                  icon: Icons.add_rounded,
                  loading: _saving,
                  onTap: _saving ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KnownCallerSheet extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> result;
  const _KnownCallerSheet({required this.phone, required this.result});

  @override
  State<_KnownCallerSheet> createState() => _KnownCallerSheetState();
}

class _KnownCallerSheetState extends State<_KnownCallerSheet> {
  final _noteCtrl = TextEditingController();
  bool _showNoteField = false;
  bool _saving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Color get _typeColor => typeColor(widget.result['type'] as String? ?? '');

  Future<void> _saveNote() async {
    if (_noteCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);

    try {
      await CallerService.addNote(
        doctype: widget.result['type'] as String? ?? 'Lead',
        docname: widget.result['name'] as String? ?? '',
        note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showSnack(
        'Note added successfully',
        AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color bg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.result['customer_name'] as String? ?? 'Unknown';
    final type = widget.result['type'] as String? ?? '-';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AppSheetContainer(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSheetHandle(),

          // Caller info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Center(
                  child: Text(
                    initials(name),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppTypeChip(label: type, color: _typeColor),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.phone_outlined,
                          size: 13,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.phone,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _SheetCloseBtn(),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),

          if (!_showNoteField)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Add Call Note',
                icon: Icons.edit_note_rounded,
                onTap: () => setState(() => _showNoteField = true),
              ),
            )
          else ...[
            const AppFieldLabel(label: 'Call Note'),
            const SizedBox(height: 8),
            AppTextField(
              controller: _noteCtrl,
              hint: 'Describe this call...',
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppOutlineButton(
                    label: 'Cancel',
                    onTap: _saving
                        ? null
                        : () => setState(() {
                            _showNoteField = false;
                            _noteCtrl.clear();
                          }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Save Note',
                    icon: Icons.check_rounded,
                    loading: _saving,
                    onTap: _saving ? null : _saveNote,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// SHARED ATOMS
// ════════════════════════════════════════════════════════════════════════════════

class _SheetCloseBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        child: const Icon(
          Icons.close_rounded,
          color: AppColors.textSecondary,
          size: 18,
        ),
      ),
    );
  }
}

class _TestOverlayCard extends StatelessWidget {
  final VoidCallback onTest;
  const _TestOverlayCard({required this.onTest});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Developer Tools',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 42),
            child: Text(
              'Force show the overlay popup even if the app is open.',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppOutlineButton(
              label: 'Force Overlay Popup',
              icon: Icons.flash_on,
              onTap: onTest,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
