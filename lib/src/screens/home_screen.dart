import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/caller_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'overlay_bubble.dart';

const MethodChannel _nativeOverlayChannel =
    MethodChannel('crm_caller_nxtgen/native_overlay');

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
  List<String> _bgLogs = [];
  String _lastHandledPhone = '';
  DateTime? _lastHandledAt;
  bool _workflowOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePhoneListener();
    _loadDailyCallCount();
    _loadLogs();
    unawaited(_consumeLaunchPhone());
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bgLogs = prefs.getStringList('bg_service_logs') ?? [];
      });
    }
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
    if (state != AppLifecycleState.resumed) {
      _stopUiPhoneListener();
    } else {
      _startUiPhoneListener();
      unawaited(_consumeLaunchPhone());
    }
  }

  Future<void> _initializePhoneListener() async {
    if (!Platform.isAndroid) return;

    final statuses = await [
      Permission.phone,
      Permission.notification,
    ].request();

    final phoneGranted = statuses[Permission.phone]?.isGranted ?? false;
    final notificationsGranted =
        statuses[Permission.notification]?.isGranted ?? false ||
        !await Permission.notification.isDenied;

    if (!phoneGranted) {
      return;
    }

    if (!notificationsGranted) {
      return;
    }

    _startUiPhoneListener();
  }

  Future<void> _consumeLaunchPhone() async {
    if (!Platform.isAndroid) return;

    try {
      final phone =
          await _nativeOverlayChannel.invokeMethod<String>('consumeLaunchPhone');
      if (phone != null && phone.isNotEmpty && mounted) {
        _phoneController.text = phone;
        await _handleIncomingNumber(phone, incrementCount: false);
      }
    } catch (_) {}
  }

  void _startUiPhoneListener() {
    if (_phoneSubscription != null) return;

    _phoneSubscription = PhoneState.stream.listen((event) async {
      if (!mounted) return;

      if (event.status == PhoneStateStatus.CALL_INCOMING &&
          event.number != null &&
          _shouldHandleIncoming(event.number!)) {
        await _handleIncomingNumber(event.number!);
      } else if (event.status == PhoneStateStatus.CALL_ENDED) {
        await _hideNativeOverlay();
      }
    });
  }

  void _stopUiPhoneListener() {
    _phoneSubscription?.cancel();
    _phoneSubscription = null;
  }

  bool _shouldHandleIncoming(String phone) {
    final now = DateTime.now();
    final duplicate = _lastHandledPhone == phone &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 5);

    if (duplicate) {
      return false;
    }

    _lastHandledPhone = phone;
    _lastHandledAt = now;
    return true;
  }

  Future<void> _showInAppOverlay(Map<String, dynamic> data) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) {
        return _DraggableOverlayWrapper(
          child: OverlayBubble(
            initialPayload: data,
            useSystemOverlay: false,
          ),
        );
      },
    );
  }

  Future<void> _showNativeOverlay(Map<String, dynamic> data) async {
    await _nativeOverlayChannel.invokeMethod('showNativeOverlay', data);
  }

  Future<void> _hideNativeOverlay() async {
    try {
      await _nativeOverlayChannel.invokeMethod('hideNativeOverlay');
    } catch (_) {}
  }

  Future<void> _presentCallerWorkflow(
    String phone,
    Map<String, dynamic> response,
  ) async {
    if (!mounted || _workflowOpen) return;

    _workflowOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          if (response['found'] == true) {
            return _KnownCallerSheet(phone: phone, result: response);
          }
          return _CreateLeadSheet(phone: phone);
        },
      );
    } finally {
      _workflowOpen = false;
    }
  }

  Future<void> _handleIncomingNumber(
    String phone, {
    bool incrementCount = true,
  }) async {
    if (!mounted) return;
    setState(() => _loading = true);

    if (incrementCount) {
      await _incrementCallCount();
    }

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

      await _presentCallerWorkflow(phone, response);
    } catch (e) {
      debugPrint("Overlay error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceShowOverlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('crm_caller_phone', '+1 555 010 2026');
      await prefs.setString('crm_caller_name', 'Test Caller');
      await prefs.setString('crm_caller_type', 'Test Contact');
      await prefs.setString('crm_caller_docname', 'TEST-CALLER');
      await prefs.setBool('crm_caller_found', true);

      final data = {
        'phone': '+1 555 010 2026',
        'name': 'Test Caller',
        'type': 'Test Contact',
        'docname': 'TEST-CALLER',
        'found': true,
        'event_id': DateTime.now().millisecondsSinceEpoch,
      };

      if (Platform.isAndroid) {
        var overlayGranted =
            await _nativeOverlayChannel.invokeMethod<bool>('canDrawOverlays') ??
            false;
        if (!overlayGranted) {
          await _nativeOverlayChannel.invokeMethod('openOverlaySettings');
          return;
        }

        await _showNativeOverlay(data);
        return;
      }

      await _showInAppOverlay(data);
    } catch (e) {
      _showError('Could not show overlay: $e');
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
    _stopUiPhoneListener();
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
            const _OverlayPermissionCard(),
            const SizedBox(height: 16),
            _TestOverlayCard(
              onTest: _forceShowOverlay,
            ),
            if (_bgLogs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LogsCard(logs: _bgLogs, onRefresh: _loadLogs),
            ],
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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OVERVIEW',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hello, $username',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calls Today',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$callsToday',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      AppColors.primary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Manual Lookup',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 54),
            child: Text(
              'Search a phone number in your CRM database instantly.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: controller,
                  hint: '+91 98765 43210',
                  icon: Icons.dialpad_rounded,
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => onLookup(),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: loading ? null : onLookup,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: loading
                          ? [
                              AppColors.primary.withValues(alpha: 0.5),
                              AppColors.primaryDark.withValues(alpha: 0.5),
                            ]
                          : [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: loading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Lookup',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
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
      final granted =
          await _nativeOverlayChannel.invokeMethod<bool>('canDrawOverlays') ??
          false;
      if (mounted) setState(() => _granted = granted);
    } catch (_) {
      if (mounted) setState(() => _granted = true);
    }
  }

  Future<void> _request() async {
    try {
      await _nativeOverlayChannel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.warning.withValues(alpha: 0.2),
                      AppColors.warning.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bubble_chart_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Background Bubble',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 54),
            child: Text(
              'Grant "Display over other apps" so the CRM bubble appears when a call ends, even when the app is closed.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _request,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.warning, Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.security_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Grant Permission',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.2),
                      AppColors.accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.code_rounded,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'Developer Tools',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 54),
            child: Text(
              'Force show the overlay popup even if the app is open.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppOutlineButton(
              label: 'Force Overlay Popup',
              icon: Icons.flash_on_rounded,
              onTap: onTest,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableOverlayWrapper extends StatefulWidget {
  final Widget child;
  const _DraggableOverlayWrapper({required this.child});

  @override
  State<_DraggableOverlayWrapper> createState() =>
      _DraggableOverlayWrapperState();
}

class _DraggableOverlayWrapperState extends State<_DraggableOverlayWrapper> {
  Offset _position = const Offset(0, 100);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          // Limit exactly to media query to ensure the inner constrained boxes don't overflow
          width: MediaQuery.of(context).size.width,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            behavior: HitTestBehavior.deferToChild,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _LogsCard extends StatelessWidget {
  final List<String> logs;
  final VoidCallback onRefresh;

  const _LogsCard({required this.logs, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Background Logs',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Refresh Logs',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: ListView.separated(
              itemCount: logs.length,
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (_, _) => const Divider(height: 12, thickness: 0.5),
              itemBuilder: (context, index) {
                final log = logs[index];
                final isError = log.contains('❌') || log.contains('⚠️');
                return Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: isError ? AppColors.danger : AppColors.textPrimary,
                    height: 1.4,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
