import 'dart:async';
import 'dart:io';

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
      if (mounted) setState(() => _callsToday = prefs.getInt('crm_call_count') ?? 0);
    } else {
      await prefs.setString('crm_call_date', today);
      await prefs.setInt('crm_call_count', 0);
      if (mounted) setState(() => _callsToday = 0);
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
    if (mounted) setState(() => _callsToday = newCount);
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
    if (!phoneGranted) return;
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
    if (duplicate) return false;
    _lastHandledPhone = phone;
    _lastHandledAt = now;
    return true;
  }

  Future<void> _showInAppOverlay(Map<String, dynamic> data) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => OverlayBubble(initialPayload: data, useSystemOverlay: false),
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
      String phone, Map<String, dynamic> response) async {
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

  Future<void> _handleIncomingNumber(String phone,
      {bool incrementCount = true}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    if (incrementCount) await _incrementCallCount();
    Map<String, dynamic> response;
    try {
      response = await CallerService.getCallerDetails(phone);
    } catch (e) {
      if (!mounted) return;
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
      debugPrint('Overlay error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceShowOverlay(bool isKnown) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final name = isKnown ? 'Test Caller' : 'Unknown Number';
      final type = isKnown ? 'Test Contact' : '';
      final docname = isKnown ? 'TEST-CALLER' : '';
      
      await prefs.setString('crm_caller_phone', '+1 555 010 2026');
      await prefs.setString('crm_caller_name', name);
      await prefs.setString('crm_caller_type', type);
      await prefs.setString('crm_caller_docname', docname);
      await prefs.setBool('crm_caller_found', isKnown);
      
      final data = {
        'phone': '+1 555 010 2026',
        'name': name,
        'type': type,
        'docname': docname,
        'found': isKnown,
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
      String phone, Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_caller_phone', phone);
    await prefs.setString(
        'crm_caller_name', (result['customer_name'] as String?) ?? '');
    await prefs.setString('crm_caller_type', (result['type'] as String?) ?? '');
    await prefs.setString(
        'crm_caller_docname', (result['name'] as String?) ?? '');
    await prefs.setBool('crm_caller_found', result['found'] == true);
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopUiPhoneListener();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 72,
          16,
          32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardHeader(
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
            _TestOverlayCard(onTest: _forceShowOverlay),
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
      backgroundColor: AppColors.bgBase.withValues(alpha: 0.92),
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: AppColors.bgBase.withValues(alpha: 0.92),
          border: const Border(
            bottom: BorderSide(color: AppColors.borderLight, width: 1),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.bgCard,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.5),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.user.username.isNotEmpty
                      ? widget.user.username[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user.username,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    const Text('Signed in',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'logout',
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: const Row(children: [
                  Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
                  SizedBox(width: 10),
                  Text('Sign out',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ]),
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

// ════════════════════════════════════════════════════════════════════════════
// DASHBOARD HEADER
// ════════════════════════════════════════════════════════════════════════════

class _DashboardHeader extends StatelessWidget {
  final String username;
  final int callsToday;

  const _DashboardHeader({required this.username, required this.callsToday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1F36), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
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
                        color: AppColors.primary.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Hello, $username 👋',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              // Online badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Online',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stats row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgInput,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone_in_talk_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calls Today',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$callsToday',
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
                // Gradient chip for activity indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MANUAL LOOKUP CARD
// ════════════════════════════════════════════════════════════════════════════

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
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.manage_search_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Lookup',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Search any number in your CRM',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Input row
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
              const SizedBox(width: 10),
              GestureDetector(
                onTap: loading ? null : onLookup,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: loading
                          ? [
                              AppColors.primary.withValues(alpha: 0.4),
                              AppColors.primaryDark.withValues(alpha: 0.4),
                            ]
                          : [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: loading
                        ? []
                        : [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded,
                            color: Colors.white, size: 22),
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

// ════════════════════════════════════════════════════════════════════════════
// OVERLAY PERMISSION CARD
// ════════════════════════════════════════════════════════════════════════════

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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Permission Required',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Grant "Display over other apps" so the CRM bubble appears during incoming calls, even when the app is in the background.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Grant Overlay Permission',
              icon: Icons.security_rounded,
              onTap: _request,
              color: AppColors.warning,
              colorEnd: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TEST OVERLAY CARD
// ════════════════════════════════════════════════════════════════════════════

class _TestOverlayCard extends StatelessWidget {
  final Future<void> Function(bool isKnown) onTest;
  const _TestOverlayCard({required this.onTest});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.flash_on_rounded,
                color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Overlay',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Trigger caller bubble',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
               _buildBtn('Known Caller', () => onTest(true)),
               const SizedBox(height: 6),
               _buildBtn('Unknown Caller', () => onTest(false)),
            ]
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.accentLight,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BOTTOM SHEETS
// ════════════════════════════════════════════════════════════════════════════

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
      _showSnack('Lead created successfully', AppColors.success,
          icon: Icons.check_circle_outline_rounded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color bg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(msg)),
        ]),
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
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded,
                    color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unknown Caller',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        )),
                    Text(widget.phone,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              _SheetCloseBtn(),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 20),
          const AppFieldLabel(label: 'Lead Name', required: true),
          const SizedBox(height: 8),
          AppTextField(
              controller: _nameCtrl,
              hint: 'Enter full name',
              icon: Icons.person_outline_rounded),
          const SizedBox(height: 14),
          const AppFieldLabel(label: 'Email (Optional)'),
          const SizedBox(height: 8),
          AppTextField(
              controller: _emailCtrl,
              hint: 'email@example.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 14),
          const AppFieldLabel(label: 'Call Note'),
          const SizedBox(height: 8),
          AppTextField(
              controller: _noteCtrl,
              hint: 'Briefly describe this call...',
              maxLines: 3),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: AppOutlineButton(
                    label: 'Cancel',
                    onTap: _saving ? null : () => Navigator.pop(context)),
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
      _showSnack('Note added successfully', AppColors.success,
          icon: Icons.check_circle_outline_rounded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', AppColors.danger);
    }
  }

  void _showSnack(String msg, Color bg, {IconData? icon}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(msg)),
        ]),
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
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.accent.withValues(alpha: 0.15),
                    ],
                  ),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    initials(name),
                    style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w700,
                        fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppTypeChip(label: type, color: _typeColor),
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_outlined,
                            size: 13, color: AppColors.textTertiary),
                        const SizedBox(width: 3),
                        Text(widget.phone,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              _SheetCloseBtn(),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: AppColors.borderLight, height: 1),
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
                autofocus: true),
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

// ════════════════════════════════════════════════════════════════════════════
// SHARED ATOMS
// ════════════════════════════════════════════════════════════════════════════

class _SheetCloseBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.bgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Icon(Icons.close_rounded,
            color: AppColors.textSecondary, size: 18),
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
          width: MediaQuery.of(context).size.width,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() => _position += details.delta);
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.primary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  const Text('Background Logs',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ],
              ),
              GestureDetector(
                onTap: onRefresh,
                child: const Icon(Icons.refresh_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: ListView.separated(
              itemCount: logs.length,
              physics: const BouncingScrollPhysics(),
              separatorBuilder: (_, _) => Divider(
                  height: 12,
                  thickness: 0.5,
                  color: AppColors.divider),
              itemBuilder: (context, index) {
                final log = logs[index];
                final isError =
                    log.contains('❌') || log.contains('⚠️');
                return Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: isError ? AppColors.danger : AppColors.textSecondary,
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
