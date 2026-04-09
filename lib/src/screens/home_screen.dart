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
import '../features/notes/notes_repository.dart';

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
    if (statuses[Permission.phone] == PermissionStatus.granted) {
      _startUiPhoneListener();
    }
  }

  void _startUiPhoneListener() {
    _phoneSubscription?.cancel();
    _phoneSubscription = PhoneState.stream.listen((event) {
      if (event.status == PhoneStateStatus.CALL_INCOMING) {
        final phone = event.number ?? '';
        if (phone.isEmpty) return;
        final now = DateTime.now();
        if (phone == _lastHandledPhone &&
            _lastHandledAt != null &&
            now.difference(_lastHandledAt!).inSeconds < 5) return;
        _lastHandledPhone = phone;
        _lastHandledAt = now;
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
    if (_workflowOpen) return;
    _workflowOpen = true;
    if (mounted) setState(() => _loading = true);
    unawaited(_incrementCallCount());
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
      if (mounted) setState(() => _loading = false);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forceShowOverlay(bool isKnown) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final name    = isKnown ? 'Test Caller' : 'Unknown Number';
      final type    = isKnown ? 'Test Contact' : '';
      final docname = isKnown ? 'TEST-CALLER' : '';

      await prefs.setString('crm_caller_phone', '+1 555 010 2026');
      await prefs.setString('crm_caller_name', name);
      await prefs.setString('crm_caller_type', type);
      await prefs.setString('crm_caller_docname', docname);
      await prefs.setBool('crm_caller_found', isKnown);

      final data = {
        'phone':    '+1 555 010 2026',
        'name':     name,
        'type':     type,
        'docname':  docname,
        'found':    isKnown,
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
      await _showNativeOverlay(data);
    } catch (e) {
      _showError('Could not show overlay: $e');
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
    if (!mounted) { _workflowOpen = false; return; }
    final data = {
      'phone':    phone,
      'name':     response['name'] ?? '',
      'type':     response['type'] ?? '',
      'docname':  response['docname'] ?? '',
      'found':    response['found'] == true,
      'event_id': DateTime.now().millisecondsSinceEpoch,
    };
    if (Platform.isAndroid) {
      var overlayGranted =
          await _nativeOverlayChannel.invokeMethod<bool>('canDrawOverlays') ??
          false;
      if (overlayGranted) {
        await _showNativeOverlay(data);
        _workflowOpen = false;
        return;
      }
    }
    await _showNativeOverlay(data);
    _workflowOpen = false;
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
            const _QuickActionCard(),
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

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ac.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
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
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.manage_search_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Manual Lookup',
                        style: TextStyle(
                            color: ac.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2)),
                    Text('Search any number in your CRM',
                        style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                              color: AppColors.primary.withValues(alpha: 0.38),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Call Notes', style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: Icon(Icons.refresh, color: AppColors.primary, size: 20), onPressed: _loadNotes),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_notes.isEmpty)
            Text('No recent notes.', style: TextStyle(color: ac.textSecondary, fontStyle: FontStyle.italic))
          else
            ..._notes.map((note) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ac.bgInput,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note['phoneNumber'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: ac.textPrimary)),
                    const SizedBox(height: 4),
                    Text(note['content'] ?? '', style: TextStyle(color: ac.textSecondary)),
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
// TEST OVERLAY CARD
// ════════════════════════════════════════════════════════════════════════════

class _TestOverlayCard extends StatelessWidget {
  final Future<void> Function(bool isKnown) onTest;
  const _TestOverlayCard({required this.onTest});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.flash_on_rounded,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test Native Overlay',
                        style: TextStyle(
                          color: ac.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        )),
                    Text('Preview the new UI architecture',
                        style:
                            TextStyle(color: ac.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildBtn(context, 'Test Unknown', () => onTest(false))),
              const SizedBox(width: 8),
              Expanded(child: _buildBtn(context, 'Test Known', () => onTest(true))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(BuildContext context, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.22)),
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
// QUICK ACTION CARD
// ════════════════════════════════════════════════════════════════════════════

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard();

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.border),
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text('Quick Actions',
                  style: TextStyle(
                    color: ac.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionItem(context, 'Sync Dashboard', Icons.sync_rounded, () {}),
          _buildActionItem(
              context, 'Recent Calls', Icons.history_rounded, () {}),
          _buildActionItem(
              context, 'Profile Settings', Icons.person_outline_rounded, () {}),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    final ac = context.ac;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: ac.textSecondary),
            const SizedBox(width: 14),
            Text(title,
                style: TextStyle(
                    color: ac.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 16, color: ac.border),
          ],
        ),
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




