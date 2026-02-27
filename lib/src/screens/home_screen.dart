import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:phone_state/phone_state.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/caller_service.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';

// ── Frappe-inspired palette ──────────────────────────────────────────────────
const _primary = Color(0xFF2490EF);
const _primaryDark = Color(0xFF1A6EC7);
const _bgPage = Color(0xFFF0F4F8);
const _cardBg = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF1F272B);
const _textSecondary = Color(0xFF687076);
const _success = Color(0xFF2DB04B);
const _danger = Color(0xFFE03636);
const _border = Color(0xFFE2E8F0);
const _inputBg = Color(0xFFF8FAFC);
const _unknownColor = Color(0xFFD97706);
// ────────────────────────────────────────────────────────────────────────────

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
  bool _popupOpen = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePhoneListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  Future<void> _initializePhoneListener() async {
    if (!Platform.isAndroid) return;
    await Permission.phone.request();
    _phoneSubscription = PhoneState.stream.listen((PhoneState event) {
      if (event.status == PhoneStateStatus.CALL_ENDED &&
          event.number != null &&
          event.number!.isNotEmpty) {
        _handleIncomingNumber(event.number!);
      }
    });
  }

  Future<void> _handleIncomingNumber(String phone) async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final response = await CallerService.getCallerDetails(phone);
      if (!mounted) return;

      if (_lifecycleState == AppLifecycleState.resumed) {
        // App is visible — show the inline bottom sheet
        _showCallPopup(phone, response);
      } else {
        // App is backgrounded — write data and pop up a system overlay window
        await _saveCallerDataToPrefs(phone, response);
        await FlutterOverlayWindow.showOverlay(
          height: WindowSize.matchParent,
          width: WindowSize.matchParent,
          enableDrag: false,
          overlayTitle: 'CRM Caller',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Lookup failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Persists caller data to SharedPreferences so the overlay widget can read it.
  /// Keys mirror what CallService.kt and overlay_bubble.dart use (flutter.* prefix
  /// is added automatically by the shared_preferences plugin).
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

  void _showCallPopup(String phone, Map<String, dynamic> result) {
    if (_popupOpen) return;
    _popupOpen = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        if (result['found'] == false) {
          return _CreateLeadSheet(phone: phone);
        }
        return _KnownCallerSheet(phone: phone, result: result);
      },
    ).whenComplete(() => _popupOpen = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WelcomeCard(username: widget.user.username),
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
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _cardBg,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone_in_talk_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'CRM Caller',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          offset: const Offset(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: _border),
          ),
          color: _cardBg,
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: _Avatar(name: widget.user.username),
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
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  const Text('Signed in',
                      style:
                          TextStyle(color: _textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            PopupMenuItem(
              value: 'logout',
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: const Row(
                children: [
                  Icon(Icons.logout_rounded, size: 16, color: _danger),
                  SizedBox(width: 10),
                  Text('Sign out',
                      style: TextStyle(
                          color: _danger,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
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
      ],
    );
  }
}

// ── Home screen cards ────────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String username;
  const _WelcomeCard({required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, _primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome back,',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text(
                  username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Color(0xFF4ADE80), size: 7),
                SizedBox(width: 5),
                Text('Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
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
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search_rounded, color: _primary, size: 18),
              SizedBox(width: 8),
              Text('Manual Lookup',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 3),
          const Text('Search a phone number in CRM',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  onSubmitted: (_) => onLookup(),
                  style: const TextStyle(
                      color: _textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '+91 98765 43210',
                    hintStyle: const TextStyle(
                        color: _textSecondary, fontSize: 13),
                    prefixIcon: const Icon(Icons.phone_outlined,
                        color: _textSecondary, size: 18),
                    filled: true,
                    fillColor: _inputBg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : onLookup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lookup',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors_rounded, color: _primary, size: 18),
              SizedBox(width: 8),
              Text('Auto Detection',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _StatusRow(
            dot: const Color(0xFF4ADE80),
            text: 'Listening for incoming & outgoing calls',
          ),
          const SizedBox(height: 8),
          _StatusRow(
            dot: _primary,
            text: 'CRM lookup runs automatically on call end',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Color dot;
  final String text;
  const _StatusRow({required this.dot, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration:
              BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style:
                  const TextStyle(color: _textSecondary, fontSize: 13)),
        ),
      ],
    );
  }
}

// ── Overlay permission card ───────────────────────────────────────────────────

class _OverlayPermissionCard extends StatefulWidget {
  const _OverlayPermissionCard();

  @override
  State<_OverlayPermissionCard> createState() =>
      _OverlayPermissionCardState();
}

class _OverlayPermissionCardState extends State<_OverlayPermissionCard>
    with WidgetsBindingObserver {
  bool _granted = true; // optimistic — hides card if already granted

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
    try {
      final granted = await FlutterOverlayWindow.isPermissionGranted();
      if (mounted) setState(() => _granted = granted);
    } catch (_) {
      // Plugin error or unsupported — hide the card
      if (mounted) setState(() => _granted = true);
    }
  }

  Future<void> _request() async {
    try {
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted) return const SizedBox.shrink();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bubble_chart_outlined,
                  color: _unknownColor, size: 18),
              SizedBox(width: 8),
              Text('Background Bubble',
                  style: TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Grant "Display over other apps" so the CRM bubble appears when a call ends, even when the app is closed.',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _request,
              icon: const Icon(Icons.security_rounded, size: 16),
              label: const Text('Grant Permission',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _unknownColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheets ─────────────────────────────────────────────────────────────

class _CreateLeadSheet extends StatefulWidget {
  final String phone;
  const _CreateLeadSheet({required this.phone});

  @override
  State<_CreateLeadSheet> createState() => _CreateLeadSheetState();
}

class _CreateLeadSheetState extends State<_CreateLeadSheet> {
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Lead name is required', _danger);
      return;
    }

    setState(() => _saving = true);

    try {
      await CallerService.createLead(
        firstName: name,
        mobile: widget.phone,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      _showSnack('Lead created successfully', _success,
          icon: Icons.check_circle_outline_rounded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', _danger);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return _BottomSheetContainer(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          _SheetHeader(
            icon: Icons.person_add_alt_1_rounded,
            iconBg: const Color(0xFFFEF3C7),
            iconColor: const Color(0xFFD97706),
            title: 'Unknown Caller',
            subtitle: widget.phone,
          ),
          const SizedBox(height: 20),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 20),

          // Name
          const _FieldLabel(label: 'Lead Name', required: true),
          const SizedBox(height: 6),
          _FrappeField(
            controller: _nameCtrl,
            hint: 'Enter full name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 16),

          // Note
          const _FieldLabel(label: 'Call Note'),
          const SizedBox(height: 6),
          _FrappeField(
            controller: _noteCtrl,
            hint: 'Briefly describe this call…',
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // Actions
          Row(children: [
            Expanded(
              child: _OutlineBtn(
                label: 'Cancel',
                onTap: _saving ? null : () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: _PrimaryBtn(
                label: 'Create Lead',
                icon: Icons.add_rounded,
                loading: _saving,
                onTap: _saving ? null : _submit,
              ),
            ),
          ]),
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

  String get _initials {
    final name =
        (widget.result['customer_name'] as String? ?? '').trim();
    final parts = name.split(' ');
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _typeColor {
    switch ((widget.result['type'] as String? ?? '').toLowerCase()) {
      case 'lead':
        return const Color(0xFF7C3AED);
      case 'opportunity':
        return const Color(0xFF059669);
      case 'customer':
        return _primary;
      default:
        return _textSecondary;
    }
  }

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
      _showSnack('Note added successfully', _success,
          icon: Icons.check_circle_outline_rounded);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showSnack('Error: $e', _danger);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.result['customer_name'] as String? ?? 'Unknown';
    final type = widget.result['type'] as String? ?? '-';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return _BottomSheetContainer(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),

          // Caller row
          Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _primary.withValues(alpha: 0.1),
              child: Text(
                _initials,
                style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                  const SizedBox(height: 4),
                  Row(children: [
                    _TypeChip(label: type, color: _typeColor),
                    const SizedBox(width: 8),
                    const Icon(Icons.phone_outlined,
                        size: 12, color: _textSecondary),
                    const SizedBox(width: 3),
                    Text(widget.phone,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12)),
                  ]),
                ],
              ),
            ),
            _CloseBtn(),
          ]),

          const SizedBox(height: 20),
          const Divider(color: _border, height: 1),
          const SizedBox(height: 16),

          if (!_showNoteField)
            SizedBox(
              width: double.infinity,
              child: _PrimaryBtn(
                label: 'Add Call Note',
                icon: Icons.note_add_outlined,
                onTap: () => setState(() => _showNoteField = true),
              ),
            )
          else ...[
            const _FieldLabel(label: 'Call Note'),
            const SizedBox(height: 6),
            _FrappeField(
              controller: _noteCtrl,
              hint: 'Describe this call…',
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _OutlineBtn(
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
                child: _PrimaryBtn(
                  label: 'Save Note',
                  icon: Icons.save_outlined,
                  loading: _saving,
                  onTap: _saving ? null : _saveNote,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Shared UI atoms ───────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

class _BottomSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _BottomSheetContainer(
      {required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: _border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _SheetHeader(
      {required this.icon,
      required this.iconBg,
      required this.iconColor,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: iconBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 17)),
          Text(subtitle,
              style:
                  const TextStyle(color: _textSecondary, fontSize: 13)),
        ]),
      ),
      _CloseBtn(),
    ]);
  }
}

class _CloseBtn extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: _inputBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.all(6),
        minimumSize: const Size(34, 34),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: _primary.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
            color: _primary, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
            color: _textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 12),
        children: required
            ? const [
                TextSpan(
                    text: ' *',
                    style: TextStyle(
                        color: _danger, fontWeight: FontWeight.w700))
              ]
            : [],
      ),
    );
  }
}

class _FrappeField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final bool autofocus;

  const _FrappeField({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      autofocus: autofocus,
      style: const TextStyle(color: _textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _textSecondary, fontSize: 13),
        prefixIcon: icon != null
            ? Icon(icon, color: _textSecondary, size: 18)
            : null,
        filled: true,
        fillColor: _inputBg,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 14, vertical: maxLines > 1 ? 14 : 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _primary, width: 1.5)),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryBtn(
      {required this.label,
      this.icon,
      this.loading = false,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _primary.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[
                Icon(icon, size: 17),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
            ]),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _OutlineBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textSecondary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 14)),
    );
  }
}
