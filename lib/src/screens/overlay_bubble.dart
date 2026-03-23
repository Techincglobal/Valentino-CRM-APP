import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class OverlayBubble extends StatefulWidget {
  final Map<String, dynamic>? initialPayload;
  final bool useSystemOverlay;

  const OverlayBubble({
    super.key,
    this.initialPayload,
    this.useSystemOverlay = true,
  });

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  static const int _compactOverlayWidth = 288;
  static const int _compactOverlayHeight = 104;
  static const int _expandedKnownOverlayHeight = 470;
  static const int _expandedUnknownOverlayHeight = 640;

  String _phone = '';
  String _name = '';
  String _type = '';
  String _docname = '';
  String _latestNote = '';
  String? _baseUrl;
  String? _sid;
  String? _statusMessage;
  int? _eventId;
  bool _found = false;
  bool _loaded = false;
  bool _saving = false;
  bool _isExpanded = false;
  bool _latestNoteLoading = false;
  bool _statusIsError = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  StreamSubscription? _overlaySub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    if (widget.initialPayload != null) {
      _loaded = true;
      _applyOverlayPayload(widget.initialPayload!, callerChanged: true);
      unawaited(_loadAuthState());
      _animController.forward();
    } else if (Platform.isAndroid && widget.useSystemOverlay) {
      _loaded = true;
      _animController.forward();
    } else {
      _load();
    }

    if (Platform.isAndroid && widget.useSystemOverlay) {
      try {
        _overlaySub = FlutterOverlayWindow.overlayListener.listen(
          _handleOverlayEvent,
        );
      } catch (e) {
        debugPrint('Overlay Listener Error: $e');
      }
    }
  }

  @override
  void dispose() {
    _overlaySub?.cancel();
    _animController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _phone = prefs.getString('crm_caller_phone') ?? '';
      _name = prefs.getString('crm_caller_name') ?? '';
      _type = prefs.getString('crm_caller_type') ?? '';
      _docname = prefs.getString('crm_caller_docname') ?? '';
      _found = prefs.getBool('crm_caller_found') ?? false;
      _baseUrl = prefs.getString('crm_base_url');
      _sid = prefs.getString('crm_sid');
      _loaded = true;
      _isExpanded = false;
    });

    if (_found && _docname.isNotEmpty && _type.isNotEmpty) {
      unawaited(_fetchLatestNote());
    }

    _animController.forward();
    unawaited(_syncOverlayLayout());
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _baseUrl = prefs.getString('crm_base_url');
      _sid = prefs.getString('crm_sid');
    });
  }

  void _handleOverlayEvent(dynamic event) {
    final payload = _normalizeOverlayPayload(event);
    if (payload == null || !payload.containsKey('phone') || !mounted) {
      return;
    }

    final nextPhone = '${payload['phone'] ?? ''}';
    final nextType = '${payload['type'] ?? ''}';
    final nextDocname = '${payload['docname'] ?? ''}';
    final nextEventId = payload['event_id'] as int?;
    final callerChanged = nextEventId != _eventId ||
        nextPhone != _phone ||
        nextDocname != _docname ||
        nextType != _type;

    _applyOverlayPayload(payload, callerChanged: callerChanged);
    unawaited(_syncOverlayLayout());
  }

  void _applyOverlayPayload(
    Map<dynamic, dynamic> payload, {
    required bool callerChanged,
  }) {
    if (!mounted) return;

    setState(() {
      _phone = '${payload['phone'] ?? ''}';
      _name = '${payload['name'] ?? ''}';
      _type = '${payload['type'] ?? ''}';
      _docname = '${payload['docname'] ?? ''}';
      _found = payload['found'] == true;
      _eventId = payload['event_id'] as int?;
      _loaded = true;
      _saving = false;
      _statusMessage = null;
      _statusIsError = false;

      if (callerChanged) {
        _latestNote = '';
        _latestNoteLoading = false;
        _isExpanded = false;
        _nameCtrl.clear();
        _emailCtrl.clear();
        _noteCtrl.clear();
      }
    });
  }

  Map<dynamic, dynamic>? _normalizeOverlayPayload(dynamic event) {
    if (event is Map) return event;

    if (event is String && event.isNotEmpty) {
      try {
        final decoded = jsonDecode(event);
        if (decoded is Map) {
          return decoded;
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> _syncOverlayLayout() async {
    if (!Platform.isAndroid || !_loaded || !widget.useSystemOverlay) return;

    final targetWidth =
        _isExpanded ? WindowSize.matchParent : _compactOverlayWidth;
    final targetHeight = _isExpanded
        ? (_found ? _expandedKnownOverlayHeight : _expandedUnknownOverlayHeight)
        : _compactOverlayHeight;

    try {
      await FlutterOverlayWindow.resizeOverlay(targetWidth, targetHeight, true);
    } catch (_) {}
  }

  Future<void> _expandOverlay() async {
    if (_isExpanded) return;

    setState(() => _isExpanded = true);
    await _syncOverlayLayout();

    if (_found &&
        _latestNote.isEmpty &&
        !_latestNoteLoading &&
        _docname.isNotEmpty &&
        _type.isNotEmpty) {
      unawaited(_fetchLatestNote());
    }
  }

  Future<void> _collapseOverlay() async {
    if (!_isExpanded) return;

    FocusScope.of(context).unfocus();
    setState(() => _isExpanded = false);
    await _syncOverlayLayout();
  }

  Future<void> _fetchLatestNote() async {
    if (_baseUrl == null || _sid == null || !_found) return;

    setState(() => _latestNoteLoading = true);

    try {
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.get_notes');
      final response = await http.post(
        url,
        headers: {
          'Cookie': 'sid=$_sid',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'doctype': _type,
          'docname': _docname,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notes = data['message'] as List? ?? [];
        setState(() {
          _latestNote = notes.isNotEmpty
              ? (notes.first['content'] as String? ?? '').trim()
              : '';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _latestNoteLoading = false);
      }
    }
  }

  Future<void> _addNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      _showStatus('Enter a note first.', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      if (_baseUrl == null || _sid == null) throw Exception('Not authed');
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.add_call_note');
      final response = await http.post(
        url,
        headers: {
          'Cookie': 'sid=$_sid',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'doctype': _type.isNotEmpty ? _type : 'Lead',
          'docname': _docname,
          'note_content': note,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save note');
      }

      _showStatus('Note saved');
      await _fetchLatestNote();
      _noteCtrl.clear();
      await Future.delayed(const Duration(milliseconds: 900));
      await _collapseOverlay();
    } catch (_) {
      _showStatus('Could not save note', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _createLead() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (name.isEmpty) {
      _showStatus('Name is required', isError: true);
      return;
    }

    setState(() => _saving = true);

    try {
      if (_baseUrl == null || _sid == null) throw Exception('Not authed');
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.create_lead_with_note');
      final response = await http.post(
        url,
        headers: {
          'Cookie': 'sid=$_sid',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'first_name': name,
          if (email.isNotEmpty) 'email_id': email,
          'mobile_no': _phone,
          if (note.isNotEmpty) 'note_content': note,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create lead');
      }

      _showStatus('Lead created');
      await Future.delayed(const Duration(milliseconds: 900));
      _closeOverlay();
    } catch (_) {
      _showStatus('Could not create lead', isError: true);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showStatus(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _closeOverlay() async {
    await _animController.reverse();
    if (Platform.isAndroid) {
      await FlutterOverlayWindow.closeOverlay();
    } else if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedWidth = constraints.hasBoundedWidth;
          final hasBoundedHeight = constraints.hasBoundedHeight;
          final width =
              hasBoundedWidth ? constraints.maxWidth : _compactOverlayWidth.toDouble();
          final height = hasBoundedHeight
              ? constraints.maxHeight
              : (_isExpanded
                    ? (_found
                          ? _expandedKnownOverlayHeight.toDouble()
                          : _expandedUnknownOverlayHeight.toDouble())
                    : _compactOverlayHeight.toDouble());

          return SizedBox(
            width: width,
            height: height,
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(scale: animation, child: child),
                        );
                      },
                      child:
                          _isExpanded ? _buildExpandedCard() : _buildCompactCard(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactCard() {
    final accentColor = _found ? AppColors.success : AppColors.primary;

    return GestureDetector(
      key: const ValueKey('compact'),
      onTap: _expandOverlay,
      child: Container(
        width: _compactOverlayWidth.toDouble(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(228),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withAlpha(170),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(38),
              blurRadius: 28,
              spreadRadius: -8,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Row(
              children: [
                _buildAvatar(accentColor, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _found && _name.isNotEmpty ? _name : 'Unknown Caller',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _found ? Icons.verified_rounded : Icons.person_add_alt_1,
                        color: accentColor,
                        size: 18,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _found ? 'View' : 'Lead',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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

  Widget _buildExpandedCard() {
    final accentColor = _found ? AppColors.success : AppColors.primary;

    return Container(
      key: const ValueKey('expanded'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(224),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: Colors.white.withAlpha(156),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 44,
            spreadRadius: -8,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const Spacer(),
                    _buildHeaderIconButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onTap: _collapseOverlay,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderIconButton(
                      icon: Icons.close_rounded,
                      onTap: _closeOverlay,
                      tone: const Color(0xFFFF5F57),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(accentColor, size: 64),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _found && _name.isNotEmpty
                                    ? _name
                                    : 'Unknown Caller',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                              _buildTypeChip(accentColor),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _phone,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildInfoChip(
                                icon: _found
                                    ? Icons.verified_user_rounded
                                    : Icons.person_search_rounded,
                                label: _found
                                    ? 'Identified in CRM'
                                    : 'Not in CRM yet',
                                color: accentColor,
                              ),
                              _buildInfoChip(
                                icon: Icons.drag_indicator_rounded,
                                label: 'Drag anywhere',
                                color: Colors.black87,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (_statusMessage != null) ...[
                  _buildStatusBanner(accentColor),
                  const SizedBox(height: 16),
                ],
                if (_found) ...[
                  _buildSectionTitle('Recent note'),
                  const SizedBox(height: 10),
                  _buildLatestNoteCard(),
                  const SizedBox(height: 18),
                ],
                _buildSectionTitle(
                  _found ? 'Quick follow-up' : 'Create a lead instantly',
                ),
                const SizedBox(height: 12),
                if (!_found) ...[
                  _buildInputField(
                    controller: _nameCtrl,
                    hint: 'Full name',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildInputField(
                    controller: _emailCtrl,
                    hint: 'Email address',
                    icon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildInputField(
                  controller: _noteCtrl,
                  hint: _found
                      ? 'Add a quick note from this call'
                      : 'Lead note or context',
                  icon: Icons.edit_note_rounded,
                  maxLines: _found ? 3 : 2,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        icon: _found
                            ? Icons.check_rounded
                            : Icons.person_add_rounded,
                        label: _saving
                            ? 'Saving...'
                            : (_found ? 'Save Note' : 'Create Lead'),
                        color: Colors.white,
                        bgColor: accentColor,
                        onTap: _saving
                            ? () {}
                            : (_found ? _addNote : _createLead),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildSecondaryAction(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onTap: _collapseOverlay,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color accentColor, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            accentColor,
            accentColor.withAlpha(176),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(70),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _found && _name.isNotEmpty ? initials(_name) : '?',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color tone = Colors.black87,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: tone.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tone.withAlpha(35),
            ),
          ),
          child: Icon(icon, color: tone, size: 20),
        ),
      ),
    );
  }

  Widget _buildTypeChip(Color accentColor) {
    final label = _found
        ? (_type.isNotEmpty ? _type : 'CRM Match')
        : 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(Color accentColor) {
    final color = _statusIsError ? const Color(0xFFD64545) : accentColor;
    final icon = _statusIsError
        ? Icons.error_outline_rounded
        : Icons.check_circle_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(28)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage!,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestNoteCard() {
    if (_latestNoteLoading) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withAlpha(16),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading latest note...',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withAlpha(16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.blueAccent.withAlpha(22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withAlpha(24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sticky_note_2_rounded,
              color: Colors.blueAccent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _latestNote.isNotEmpty
                  ? _latestNote
                  : 'No call note found for this contact yet.',
              style: TextStyle(
                color:
                    _latestNote.isNotEmpty ? Colors.black87 : Colors.black54,
                fontSize: 13,
                height: 1.45,
                fontWeight:
                    _latestNote.isNotEmpty ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: bgColor.withAlpha(72),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withAlpha(18)),
          ),
          child: Icon(icon, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha(220),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: _expandOverlay,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Icon(icon, color: Colors.black45, size: 20),
            ),
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.black38,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 15,
            ),
          ),
        ),
      ),
    );
  }
}
