import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../services/app_settings_service.dart';
import '../services/caller_service.dart';
import '../services/sales_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import '../features/notes/notes_repository.dart';

const MethodChannel _nativeOverlayChannel =
    MethodChannel('crm_caller_nxtgen/native_overlay');

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback? onOpportunityCreated;
  const HomeScreen({super.key, required this.user, this.onOpportunityCreated});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _phoneController = TextEditingController();
  StreamSubscription<PhoneState>? _phoneSubscription;

  bool _loading = false;
  int _callsToday = 0;
  List<double> _weeklyData = List.filled(7, 0);
  List<String> _bgLogs = [];
  String _lastHandledPhone = '';
  DateTime? _lastHandledAt;
  bool _workflowOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(AppSettingsService.load());
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
    await _loadWeeklyData(prefs);
  }

  Future<void> _loadWeeklyData([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();
    final now = DateTime.now();
    final data = List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final key = 'crm_calls_${day.toIso8601String().split('T')[0]}';
      return (prefs.getInt(key) ?? 0).toDouble();
    });
    if (mounted) setState(() => _weeklyData = data);
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
    await prefs.setInt('crm_calls_$today', newCount);
    if (mounted) {
      setState(() {
        _callsToday = newCount;
        final updated = List<double>.from(_weeklyData);
        updated[6] = newCount.toDouble();
        _weeklyData = updated;
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
    if (statuses[Permission.phone] == PermissionStatus.granted) {
      _startUiPhoneListener();
    }
  }

  void _startUiPhoneListener() {
    _phoneSubscription?.cancel();
    _phoneSubscription = PhoneState.stream.listen((event) async {
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final phone = event.number ?? '';
        if (phone.isEmpty) return;
        final now = DateTime.now();
        if (phone == _lastHandledPhone &&
            _lastHandledAt != null &&
            now.difference(_lastHandledAt!).inSeconds < 5) { return; }
        _lastHandledPhone = phone;
        _lastHandledAt = now;
        // Save phone immediately so native CallStateReceiver can use it as fallback
        // (EXTRA_INCOMING_NUMBER requires READ_CALL_LOG on Android 12+, this is the backup)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('crm_caller_phone', phone);
        unawaited(_handleIncomingNumber(phone));
      }
    });
  }

  void _stopUiPhoneListener() {
    _phoneSubscription?.cancel();
    _phoneSubscription = null;
  }

  Future<void> _consumeLaunchPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final launchPhone = prefs.getString('crm_launch_phone') ?? '';
    if (launchPhone.isNotEmpty && mounted) {
      await prefs.remove('crm_launch_phone');
      unawaited(_handleIncomingNumber(launchPhone));
    }
  }

  Future<void> _showNativeOverlay(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('crm_caller_phone', data['phone'] ?? '');
      await prefs.setString('crm_caller_name', data['name'] ?? '');
      await prefs.setString('crm_caller_type', data['type'] ?? '');
      await prefs.setString('crm_caller_docname', data['docname'] ?? '');
      await prefs.setBool('crm_caller_found', data['found'] == true);
      await _nativeOverlayChannel.invokeMethod('showNativeOverlay', data);
    } catch (e) {
      debugPrint('Native overlay failed: $e');
    }
  }


  Future<void> _handleIncomingNumber(String phone) async {
    // if (!AppSettingsService.current.enableIncomingCallPopup) return;
    if (_workflowOpen) return;
    _workflowOpen = true;
    if (mounted) setState(() => _loading = true);
    unawaited(_incrementCallCount());
    try {
      Map<String, dynamic> response;
      try {
        response = await CallerService.getCallerDetails(phone);
      } catch (e) {
        response = {
          'found': false,
          'name': 'Unknown Caller',
          'customer_name': 'Unknown Caller',
          'type': 'Network/API Error',
        };
      }
      if (!mounted) return;
      await _saveCallerDataToPrefs(phone, response);
      await _presentCallerWorkflow(phone, response);
    } catch (e) {
      debugPrint('Overlay error: $e');
    } finally {
      // Always reset the flag so the next call is never silently dropped
      _workflowOpen = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveCallerDataToPrefs(
      String phone, Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_caller_phone', phone);
    await prefs.setString(
        'crm_caller_name', response['name'] as String? ?? '');
    await prefs.setString(
        'crm_caller_type', response['type'] as String? ?? '');
    await prefs.setString(
        'crm_caller_docname', response['docname'] as String? ?? '');
    await prefs.setBool('crm_caller_found', response['found'] == true);
  }

  Future<void> _presentCallerWorkflow(
      String phone, Map<String, dynamic> response) async {
    if (!mounted) return;
    final data = {
      'phone':    phone,
      'name':     response['name'] ?? '',
      'type':     response['type'] ?? '',
      'docname':  response['docname'] ?? '',
      'found':    response['found'] == true,
      'event_id': DateTime.now().millisecondsSinceEpoch,
    };
    if (Platform.isAndroid) {
      final overlayGranted =
          await _nativeOverlayChannel.invokeMethod<bool>('canDrawOverlays') ??
          false;
      if (!overlayGranted) return; // permission not granted — native receiver won't show it either
    }
    await _showNativeOverlay(data);
  }

  Future<void> _doManualLookup(String phone) async {
    setState(() => _loading = true);
    Map<String, dynamic> result;
    try {
      result = await CallerService.getCallerDetails(phone);
    } catch (_) {
      result = {'found': false, 'name': 'Unknown', 'type': 'Error'};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _LookupResultSheet(phone: phone, result: result),
    );
    if (outcome == 'lead_created') {
      messenger.showSnackBar(SnackBar(
        content: const Text('Lead created successfully'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      if (mounted) _phoneController.clear();
      widget.onOpportunityCreated?.call(); // refreshes Sales pipeline tab
    } else if (outcome == 'opportunity_created') {
      messenger.showSnackBar(SnackBar(
        content: const Text('Opportunity created — check the Pipeline tab'),
        backgroundColor: const Color(0xFF2490EF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      if (mounted) _phoneController.clear();
      widget.onOpportunityCreated?.call();
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    setSystemUIOverlay(context);
    final ac = context.ac;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: ac.bgBase,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, ac, isDark),
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
            _DashboardCharts(weeklyData: _weeklyData).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 16),
            _ManualLookupCard(
              controller: _phoneController,
              loading: _loading,
              onLookup: () {
                final phone = _phoneController.text.trim();
                if (phone.isEmpty) {
                  _showError('Please enter a phone number.');
                  return;
                }
                final digits = phone.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) {
                  _showError('Phone number must have at least 10 digits.');
                  return;
                }
                _doManualLookup(phone);
              },
            ),
            const SizedBox(height: 16),
            const _OverlayPermissionCard(),
            const SizedBox(height: 16),
            const _RecentNotesWidget(),
            if (_bgLogs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _LogsCard(logs: _bgLogs, onRefresh: _loadLogs),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AdaptiveColors ac, bool isDark) {
    final username = widget.user.username;
    return AppBar(
      backgroundColor: ac.bgBase.withValues(alpha: 0.94),
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: ac.bgBase.withValues(alpha: 0.94),
          border: Border(
            bottom: BorderSide(color: ac.border, width: 0.8),
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
          Text(
            'CRM Caller',
            style: TextStyle(
              color: ac.textPrimary,
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
            color: ac.bgCard,
            elevation: 10,
            shadowColor: Colors.black.withValues(alpha: 0.2),
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
                  username.isNotEmpty ? username[0].toUpperCase() : 'U',
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
                      username,
                      style: TextStyle(
                          color: ac.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text('Signed in',
                        style: TextStyle(color: ac.textTertiary, fontSize: 12)),
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
                final nav = Navigator.of(context);
                await StorageService.clearSession();
                nav.pushAndRemoveUntil(
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
// DASHBOARD CHARTS
// ════════════════════════════════════════════════════════════════════════════

class _DashboardCharts extends StatelessWidget {
  final List<double> weeklyData;
  const _DashboardCharts({required this.weeklyData});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    final isDark = context.isDark;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ac.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEEKLY VOLUME',
            style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.85),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      weeklyData.length,
                      (i) => FlSpot(i.toDouble(), weeklyData[i]),
                    ),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final ac = context.ac;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ac.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting row
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
                        color: AppColors.primary.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hello, $username 👋',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ac.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ],
                ),
              ),
              // Online badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.22)),
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
                            color: AppColors.success.withValues(alpha: 0.55),
                            blurRadius: 5,
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
          const SizedBox(height: 18),

          // Stats pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: ac.bgInput,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ac.border),
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
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Calls Today',
                          style: TextStyle(
                              color: ac.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '$callsToday',
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(10),
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

  static const _indigo     = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
  static const _indigoDark = Color(0xFF1A7FD4);

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;

    // Colours that flip with the theme
    final cardBg     = isDark ? const Color(0xFF0F1628)       : Colors.white;
    final cardBg2    = isDark ? const Color(0xFF0A0F1E)       : const Color(0xFFF5F7FF);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : _indigo.withValues(alpha: 0.14);
    final glowBlob   = isDark ? _indigo.withValues(alpha: 0.22)      : _indigo.withValues(alpha: 0.07);
    final badgeBg    = isDark ? _indigo.withValues(alpha: 0.22)      : _indigo.withValues(alpha: 0.10);
    final badgeBorder= isDark ? _indigo.withValues(alpha: 0.35)      : _indigo.withValues(alpha: 0.22);
    final badgeText  = isDark ? const Color(0xFF5BAAFF)               : _indigo;
    final titleColor = isDark ? Colors.white                          : const Color(0xFF0F1E33);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.45) : ac.textSecondary;
    final inputBg    = isDark ? Colors.white.withValues(alpha: 0.07) : ac.bgInput;
    final inputBorder= isDark ? Colors.white.withValues(alpha: 0.12) : ac.border;
    final inputIcon  = isDark ? Colors.white.withValues(alpha: 0.40) : ac.textTertiary;
    final inputText  = isDark ? Colors.white                          : ac.textPrimary;
    final inputHint  = isDark ? Colors.white.withValues(alpha: 0.28) : ac.textTertiary;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cardBg, cardBg2],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: _indigo.withValues(alpha: isDark ? 0.18 : 0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glow blob top-right
          Positioned(
            top: -30, right: -20,
            child: Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [glowBlob, _indigo.withValues(alpha: 0.0)]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badge ────────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: badgeBorder),
                    ),
                    child: Text(
                      'CALLER CHECK',
                      style: TextStyle(color: badgeText, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.6),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  'Contact Finder',
                  style: TextStyle(color: titleColor, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  'Trace any number in your CRM instantly',
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
                const SizedBox(height: 18),

                // ── Input ────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: inputBorder),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 14),
                    Icon(Icons.dialpad_rounded, color: inputIcon, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        onSubmitted: (_) => onLookup(),
                        style: TextStyle(color: inputText, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                        decoration: InputDecoration(
                          hintText: 'Enter a phone number…',
                          hintStyle: TextStyle(color: inputHint, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Look Up button ───────────────────────────────────────
                GestureDetector(
                  onTap: loading ? null : onLookup,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: loading
                            ? [_indigo.withValues(alpha: 0.45), _indigoDark.withValues(alpha: 0.45)]
                            : [_indigo, _indigoDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: loading
                          ? []
                          : [BoxShadow(color: _indigo.withValues(alpha: 0.38), blurRadius: 16, offset: const Offset(0, 5))],
                    ),
                    child: Center(
                      child: loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.person_search_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 9),
                              Text('Look Up Contact', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
                            ]),
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
// RECENT NOTES WIDGET
// ════════════════════════════════════════════════════════════════════════════

class _RecentNotesWidget extends StatefulWidget {
  const _RecentNotesWidget();

  @override
  State<_RecentNotesWidget> createState() => _RecentNotesWidgetState();
}

class _RecentNotesWidgetState extends State<_RecentNotesWidget> {
  final NotesRepository _notesRepo = NotesRepository();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await _notesRepo.getLatestNotes();
      if (mounted) setState(() { _notes = notes; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sticky_note_2_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Recent Call Notes',
                    style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
              ),
              GestureDetector(
                onTap: _loadNotes,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)),
            )
          else if (_notes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(Icons.notes_rounded, size: 28, color: ac.textMuted),
                const SizedBox(height: 8),
                Text('No recent call notes', style: TextStyle(color: ac.textTertiary, fontSize: 13)),
              ]),
            )
          else
            ..._notes.map((note) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ac.bgInput,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ac.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.phone_rounded, size: 12, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(note['phoneNumber'] ?? 'Unknown',
                          style: TextStyle(fontWeight: FontWeight.w600, color: ac.textPrimary, fontSize: 13)),
                    ]),
                    if ((note['content'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(note['content'] ?? '',
                          style: TextStyle(color: ac.textSecondary, fontSize: 13, height: 1.4),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            )),
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
      // If we can't check, assume not granted so user can try to open settings
      if (mounted) setState(() => _granted = false);
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Permission Required',
                style: TextStyle(
                  color: context.ac.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Grant "Display over other apps" so the CRM bubble appears during incoming calls.',
            style: TextStyle(
                color: context.ac.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: 'Grant Permission',
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
// BACKGROUND LOGS CARD
// ════════════════════════════════════════════════════════════════════════════

class _LogsCard extends StatefulWidget {
  final List<String> logs;
  final VoidCallback onRefresh;

  const _LogsCard({required this.logs, required this.onRefresh});

  @override
  State<_LogsCard> createState() => _LogsCardState();
}

class _LogsCardState extends State<_LogsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.border),
      ),
      child: Column(
        children: [
          // Header (always visible)
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.terminal_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Background Logs',
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                  ),
                  GestureDetector(
                    onTap: widget.onRefresh,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.refresh_rounded,
                          size: 18, color: ac.textSecondary),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: ac.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          // Expandable Logs
          if (_expanded) ...[
            Divider(height: 1, color: ac.border),
            Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                itemCount: widget.logs.length,
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (_, _) => Divider(
                    height: 10,
                    thickness: 0.5,
                    color: ac.border),
                itemBuilder: (context, index) {
                  final log = widget.logs[index];
                  final isError =
                      log.contains('❌') || log.contains('⚠️');
                  return Text(
                    log,
                    style: TextStyle(
                      color: isError
                          ? AppColors.danger
                          : ac.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LOOKUP RESULT SHEET
// ════════════════════════════════════════════════════════════════════════════

class _LookupResultSheet extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> result;
  const _LookupResultSheet({required this.phone, required this.result});

  @override
  State<_LookupResultSheet> createState() => _LookupResultSheetState();
}

class _LookupResultSheetState extends State<_LookupResultSheet> {
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool    _creatingLead = false;
  bool    _creatingOpp  = false;
  String? _error;

  // Set after a lead is saved — drives the "Create Opportunity" transition
  String _newLeadDocname     = '';
  String _newLeadDisplayName = '';

  late final bool   _found;
  late final String _displayName;
  late final String _docname;
  late final String _type;
  late final String _email;
  late final String _mobile;
  late final String _latestNote;

  static const _amber  = Color(0xFFF59E0B);
  static const _indigo = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
  static const _teal   = Color(0xFF14B8A6);
  static const _slate  = Color(0xFF94A3B8);
  static const _red    = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    final r    = widget.result;
    _found       = r['found'] == true;
    _displayName = r['name']     as String? ?? 'Unknown';
    _docname     = r['docname']  as String? ?? '';
    _type        = r['type']     as String? ?? '';
    _email       = r['email_id'] as String? ?? '';
    _mobile      = (r['mobile_no'] ?? r['phone'] ?? widget.phone) as String;
    _latestNote  = r['latest_note'] as String? ?? '';
    if (!_found) _nameCtrl.text = '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = _displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
  }

  Color get _typeColor {
    if (_type == 'Lead')     return _indigo;
    if (_type == 'Customer') return _teal;
    return _slate;
  }

  Future<void> _createOpportunity() async {
    setState(() { _creatingOpp = true; _error = null; });
    try {
      final lead = _newLeadDocname.isNotEmpty ? _newLeadDocname : _docname;
      final name = _newLeadDocname.isNotEmpty ? _newLeadDisplayName : _displayName;
      await SalesServiceOps.createOpportunity(
        leadDocname: lead,
        partyName:   name,
        amount:      0,
        stage:       'Prospecting',
      );
      if (!mounted) return;
      Navigator.pop(context, 'opportunity_created');
    } catch (e) {
      if (!mounted) return;
      setState(() { _creatingOpp = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _createLead() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Name is required'); return; }
    setState(() { _creatingLead = true; _error = null; });
    try {
      final result = await CallerService.createLead(
        firstName: name,
        email:  _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        mobile: widget.phone,
      );
      if (!mounted) return;
      // Transition to the "Create Opportunity" view rather than closing.
      // The Done / opportunity buttons handle the final pop.
      setState(() {
        _newLeadDocname     = result['lead_name']?.toString() ?? '';
        _newLeadDisplayName = name;
        _creatingLead       = false;
        _error              = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _creatingLead = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 24 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _indigo.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.manage_search_rounded, color: _indigo, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Lookup Result',
                            style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
                        Text(widget.phone, style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 18),

                  if (_newLeadDocname.isNotEmpty) ..._newLeadContent(ac, isDark)
                  else if (_found)               ..._foundContent(ac, isDark)
                  else                           ..._unknownContent(ac, isDark),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:  _red.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withValues(alpha: 0.28)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: _red, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _newLeadContent(AdaptiveColors ac, bool isDark) {
    final initial = _newLeadDisplayName.isNotEmpty ? _newLeadDisplayName[0].toUpperCase() : '?';
    return [
      // Success banner
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Lead saved — create an opportunity?',
              style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 14),

      // Lead card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF5BAAFF), Color(0xFF1A7FD4)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_newLeadDisplayName, style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _indigo.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _indigo.withValues(alpha: 0.28)),
                ),
                child: const Text('Lead', style: TextStyle(color: _indigo, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.phone_rounded, size: 12, color: _slate),
              const SizedBox(width: 4),
              Flexible(child: Text(widget.phone, style: const TextStyle(color: _slate, fontSize: 12), overflow: TextOverflow.ellipsis)),
            ]),
          ])),
        ]),
      ),
      const SizedBox(height: 20),

      // Create Opportunity button — shown only when setting is enabled
      if (AppSettingsService.current.enableOpportunityPopup)
        GestureDetector(
          onTap: _creatingOpp ? null : _createOpportunity,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2490EF), Color(0xFF1A7FD4)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: _creatingOpp
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Create Opportunity', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      const SizedBox(height: 8),

      // Done (just close, lead already saved)
      GestureDetector(
        onTap: () => Navigator.pop(context, 'lead_created'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : ac.bgInput,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
          ),
          child: Center(child: Text('Done', style: TextStyle(color: ac.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
        ),
      ),
    ];
  }

  List<Widget> _foundContent(AdaptiveColors ac, bool isDark) {
    final color  = _typeColor;
    final isLead = _type == 'Lead';
    return [
      // Contact card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Center(
              child: Text(_initials, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_displayName,
                  style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color:  color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(_type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(_docname, style: TextStyle(color: ac.textTertiary, fontSize: 11), overflow: TextOverflow.ellipsis)),
              ]),
              if (_mobile.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.phone_rounded, size: 12, color: ac.textTertiary),
                  const SizedBox(width: 5),
                  Text(_mobile, style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                ]),
              ],
              if (_email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.email_outlined, size: 12, color: ac.textTertiary),
                  const SizedBox(width: 5),
                  Flexible(child: Text(_email, style: TextStyle(color: ac.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),
        ]),
      ),

      // Latest note banner
      if (_latestNote.isNotEmpty) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color:  _amber.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _amber.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.sticky_note_2_rounded, color: _amber, size: 13),
              SizedBox(width: 6),
              Text('LAST NOTE', style: TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ]),
            const SizedBox(height: 6),
            Text(_latestNote, style: TextStyle(color: ac.textPrimary, fontSize: 13, height: 1.5), maxLines: 5, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ],

      // Convert to Opportunity — only for Leads, and only when setting is enabled
      if (isLead && AppSettingsService.current.enableOpportunityPopup) ...[
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _creatingOpp ? null : _createOpportunity,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2490EF), Color(0xFF1A7FD4)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: _creatingOpp
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Create Opportunity', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _unknownContent(AdaptiveColors ac, bool isDark) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _slate.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _slate.withValues(alpha: 0.28)),
              ),
              child: const Center(child: Icon(Icons.person_outline_rounded, color: _slate, size: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unknown Number', style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.phone_rounded, size: 12, color: _slate),
                    const SizedBox(width: 5),
                    Text(widget.phone, style: const TextStyle(color: _slate, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color:  _slate.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _slate.withValues(alpha: 0.25)),
                    ),
                    child: const Text('Not in CRM', style: TextStyle(color: _slate, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 20),
      Text('SAVE AS LEAD', style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : ac.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
        ),
        child: TextField(
          controller: _nameCtrl,
          enabled: !_creatingLead,
          style: TextStyle(color: ac.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Full name *',
            hintStyle: TextStyle(color: ac.textTertiary, fontSize: 13),
            prefixIcon: Icon(Icons.person_rounded, color: ac.textTertiary, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : ac.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
        ),
        child: TextField(
          controller: _emailCtrl,
          enabled: !_creatingLead,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: ac.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Email',
            hintStyle: TextStyle(color: ac.textTertiary, fontSize: 13),
            prefixIcon: Icon(Icons.email_outlined, color: ac.textTertiary, size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:  _indigo.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _indigo.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          const Icon(Icons.phone_rounded, size: 14, color: _indigo),
          const SizedBox(width: 8),
          Text(widget.phone, style: const TextStyle(color: _indigo, fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('Mobile', style: TextStyle(color: _indigo, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: _creatingLead ? null : _createLead,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_indigo, Color(0xFF1A7FD4)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Center(
            child: _creatingLead
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Save as Lead', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ),
    ];
  }
}
