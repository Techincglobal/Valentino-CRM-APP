import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

// ─── Color palette (blue-only) ───────────────────────────────────────────────
const _kAccent     = Color(0xFF6366F1); // indigo primary
const _kAccentDark = Color(0xFF4338CA); // indigo dark
const _kAccentMid  = Color(0xFF818CF8); // indigo light
const _kBg         = Color(0xFF0F172A);
const _kCard       = Color(0xFF1E293B);
const _kBorder     = Color(0xFF334155);
const _kTextPrim   = Colors.white;
const _kTextSec    = Color(0xFF94A3B8);

// ─── Bubble dimensions ────────────────────────────────────────────────────────
const _kBubbleSize = 68.0;

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
    with TickerProviderStateMixin {
  // ── CRM data ─────────────────────────────────────────────────────────────
  String _phone   = '';
  String _name    = '';
  String _type    = '';
  String _docname = '';
  bool   _found   = false;
  String _latestNote = '';
  String? _baseUrl;
  String? _sid;
  bool _loaded = false;
  bool _saving = false;
  String? _successMessage;

  // ── Form ─────────────────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _leadNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();

  // ── Timer ─────────────────────────────────────────────────────────────────
  Timer? _callTimer;
  int _elapsed = 0;
  String get _formattedTime {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_elapsed  % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Expand / collapse ─────────────────────────────────────────────────────
  bool _expanded = false;

  late AnimationController _expandCtrl;
  late Animation<double>   _expandScale;
  late Animation<double>   _expandFade;

  // ── Bubble entry animation ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late Animation<double>   _entryScale;

  // ── Drag position ─────────────────────────────────────────────────────────
  // starts near top-right; adjusted in didChangeDependencies once we have size
  Offset _pos = const Offset(double.infinity, 100); // sentinel
  bool   _posInitialized = false;

  // ── Overlay listener ──────────────────────────────────────────────────────
  StreamSubscription? _overlaySub;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Entry pop animation for the bubble
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _entryScale = CurvedAnimation(parent: _entryCtrl, curve: Curves.elasticOut);

    // Expand / collapse animation
    _expandCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _expandScale = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOutBack);
    _expandFade  = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOut);

    // Populate from initial payload if available
    if (widget.initialPayload != null) {
      _applyPayload(widget.initialPayload!);
      _loaded = true;
    }

    _load();

    // Android system-overlay event stream
    if (Platform.isAndroid && widget.useSystemOverlay) {
      try {
        _overlaySub = FlutterOverlayWindow.overlayListener.listen((event) {
          if (event != null && event is Map && event.containsKey('phone')) {
            if (mounted) {
              setState(() {
                _applyPayload(Map<String, dynamic>.from(event));
                _loaded = true;
              });
              _resetTimer();
            }
          }
        });
      } catch (e) {
        debugPrint('Overlay Listener Error: $e');
      }
    }
  }

  void _applyPayload(Map<String, dynamic> p) {
    _phone   = p['phone']   as String? ?? '';
    _name    = p['name']    as String? ?? '';
    _type    = p['type']    as String? ?? '';
    _docname = p['docname'] as String? ?? '';
    _found   = p['found']   == true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialise drag position once we have MediaQuery
    if (!_posInitialized) {
      final sw = MediaQuery.of(context).size.width;
      _pos = Offset(sw - _kBubbleSize - 20, 100);
      _posInitialized = true;
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _overlaySub?.cancel();
    _entryCtrl.dispose();
    _expandCtrl.dispose();
    _nameCtrl.dispose();
    _leadNameCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        if (!widget.useSystemOverlay || _phone.isEmpty) {
          _phone   = prefs.getString('crm_caller_phone')   ?? _phone;
          _name    = prefs.getString('crm_caller_name')    ?? _name;
          _type    = prefs.getString('crm_caller_type')    ?? _type;
          _docname = prefs.getString('crm_caller_docname') ?? _docname;
          _found   = prefs.getBool('crm_caller_found')     ?? _found;
        }
        _baseUrl = prefs.getString('crm_base_url');
        _sid     = prefs.getString('crm_sid');
        _loaded  = true;
      });
    }
    if (_found && _docname.isNotEmpty) _fetchLatestNote();
    _resetTimer();
    _entryCtrl.forward();
  }

  void _resetTimer() {
    _callTimer?.cancel();
    if (mounted) setState(() => _elapsed = 0);
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  Future<void> _fetchLatestNote() async {
    if (_baseUrl == null || _sid == null) return;
    try {
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.get_notes');
      final res = await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({'doctype': _type, 'docname': _docname}));
      if (res.statusCode == 200 && mounted) {
        final data  = jsonDecode(res.body);
        final notes = data['message'] as List? ?? [];
        if (notes.isNotEmpty) {
          setState(() =>
              _latestNote = (notes[0]['content'] as String? ?? '').trim());
        }
      }
    } catch (_) {}
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  Future<void> _addNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _saving = true);
    try {
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.add_call_note');
      final res = await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'doctype': _type.isNotEmpty ? _type : 'Lead',
            'docname': _docname,
            'note_content': note,
          }));
      if (res.statusCode == 200) {
        setState(() { _successMessage = 'Note saved!'; _saving = false; });
        await Future.delayed(const Duration(milliseconds: 1400));
        _closeOverlay();
      } else { throw Exception(); }
    } catch (_) { setState(() => _saving = false); }
  }

  Future<void> _createLead() async {
    final name  = _nameCtrl.text.trim();
    final leadName = _leadNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final note  = _noteCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _successMessage = 'Name is required!');
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _successMessage = null);
      return;
    }
    setState(() => _saving = true);
    try {
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.create_lead_with_note');
      await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'first_name': name,
            if (leadName.isNotEmpty) 'lead_name': leadName,
            if (email.isNotEmpty) 'email_id': email,
            'mobile_no': _phone,
            if (note.isNotEmpty) 'note_content': note,
          }));
      setState(() { _successMessage = 'Lead created!'; _saving = false; });
      await Future.delayed(const Duration(milliseconds: 1400));
      _closeOverlay();
    } catch (_) { setState(() => _saving = false); }
  }

  Future<void> _toggleExpand() async {
    if (!_expanded) {
      setState(() => _expanded = true);
      _expandCtrl.forward();
    } else {
      await _expandCtrl.reverse();
      if (mounted) setState(() => _expanded = false);
    }
  }

  Future<void> _closeOverlay() async {
    await _expandCtrl.reverse();
    await _entryCtrl.reverse();
    if (Platform.isAndroid && widget.useSystemOverlay) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  // ── Drag helpers ──────────────────────────────────────────────────────────
  void _onPanUpdate(DragUpdateDetails d) {
    if (_expanded) return; // lock position while expanded
    setState(() => _pos += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_expanded) return;
    final size = MediaQuery.of(context).size;
    // Snap to nearest horizontal edge
    const margin = 18.0;
    final midX = size.width / 2;
    final targetX = (_pos.dx + _kBubbleSize / 2) < midX
        ? margin
        : size.width - _kBubbleSize - margin;
    // Clamp vertical
    final targetY = _pos.dy.clamp(
        MediaQuery.of(context).padding.top + 10,
        size.height - _kBubbleSize - 80);
    setState(() => _pos = Offset(targetX, targetY));
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            // ── EXPANDED PANEL ──────────────────────────────────────────────
            if (_expanded)
              _buildExpandedPanel(),

            // ── FLOATING BUBBLE ─────────────────────────────────────────────
            if (!_expanded)
              _buildDraggableBubble(),
          ],
        ),
      ),
    );
  }

  // ── COLLAPSED BUBBLE ─────────────────────────────────────────────────────

  Widget _buildDraggableBubble() {
    return Positioned(
      left: _pos.dx,
      top:  _pos.dy,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd:    _onPanEnd,
        onTap:       _expanded ? null : _toggleExpand,
        child: ScaleTransition(
          scale: _entryScale,
          child: _BubbleWidget(
            name:    _name,
            found:   _found,
            elapsed: _formattedTime,
          ),
        ),
      ),
    );
  }

  // ── EXPANDED PANEL ────────────────────────────────────────────────────────

  Widget _buildExpandedPanel() {
    final mediaData = MediaQuery.of(context);
    return Positioned(
      left: 0,
      right: 0,
      top: mediaData.padding.top + 12,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            14, 0, 14, mediaData.viewInsets.bottom + 12),
        child: ScaleTransition(
          scale: _expandScale,
          child: FadeTransition(
            opacity: _expandFade,
            child: _buildPanelContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _kAccent.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────
            _buildPanelHeader(),
            const SizedBox(height: 18),

            // ── Success banner ─────────────────────────────────────────
            if (_successMessage != null)
              _buildSuccessMessage()
            else ...[
              // ── Latest note chip ────────────────────────────────────
              if (_latestNote.isNotEmpty) ...[
                _buildNoteChip(),
                const SizedBox(height: 16),
              ],
              // ── Divider / section label ─────────────────────────────
              _buildSectionLabel(_found ? 'Add Call Note' : 'Create Lead'),
              const SizedBox(height: 12),

              // ── Form fields ─────────────────────────────────────────
              if (!_found) ...[
                _buildField(_nameCtrl, 'Contact Name',
                    Icons.person_outline_rounded),
                const SizedBox(height: 10),
                _buildField(_leadNameCtrl, 'Short Lead Name',
                    Icons.business_rounded),
                const SizedBox(height: 10),
                _buildField(_emailCtrl, 'Email Address',
                    Icons.alternate_email_rounded,
                    type: TextInputType.emailAddress),
                const SizedBox(height: 10),
                _buildField(TextEditingController(text: _phone),
                    'Phone Number', Icons.phone_outlined,
                    readOnly: true),
                const SizedBox(height: 10),
              ],
              _buildField(_noteCtrl,
                  _found ? 'Discussion notes…' : 'Add context or notes…',
                  Icons.edit_note_rounded,
                  maxLines: 3),
              const SizedBox(height: 20),

              // ── Action buttons ──────────────────────────────────────
              _buildActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Row(
      children: [
        // Avatar circle
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [_kAccentMid, _kAccent, _kAccentDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _kAccent.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              _found && _name.isNotEmpty ? initials(_name) : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _found && _name.isNotEmpty ? _name : 'Unknown Caller',
                      style: const TextStyle(
                        color: _kTextPrim,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_found && _type.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _TypeChip(label: _type),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 12, color: _kTextSec),
                  const SizedBox(width: 4),
                  Text(_phone,
                      style: const TextStyle(
                          color: _kTextSec, fontSize: 12)),
                  const SizedBox(width: 10),
                  // Live timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: _kAccentMid,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(_formattedTime,
                            style: const TextStyle(
                              color: _kAccentMid,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Collapse / close button
        GestureDetector(
          onTap: _toggleExpand,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.keyboard_arrow_up_rounded,
                color: _kTextSec, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAccent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_edu_rounded,
              color: _kAccentMid, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _latestNote,
              style: const TextStyle(
                  color: _kTextSec, fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Row(
      children: [
        Container(width: 3, height: 16,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(2),
            )),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
              color: _kTextPrim,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            )),
      ],
    );
  }

  Widget _buildField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType? type,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(
            color: _kTextPrim, fontSize: 14, fontWeight: FontWeight.w500),
        cursorColor: _kAccentMid,
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(icon, color: _kTextSec, size: 18),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 38, minHeight: 0),
          hintText: hint,
          hintStyle:
              const TextStyle(color: _kBorder, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        // Close
        GestureDetector(
          onTap: _closeOverlay,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.close_rounded,
                color: _kTextSec, size: 22),
          ),
        ),
        const SizedBox(width: 10),
        // Primary action
        Expanded(
          child: GestureDetector(
            onTap: _saving ? null : (_found ? _addNote : _createLead),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kAccentMid, _kAccent, _kAccentDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _kAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _found
                                ? Icons.save_alt_rounded
                                : Icons.person_add_alt_1_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _found ? 'Save Note' : 'Create Lead',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    final isError = _successMessage!.contains('required');
    final color = isError ? Colors.redAccent : _kAccentMid;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError ? Icons.error_outline_rounded : Icons.check_rounded,
              color: color,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _successMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLLAPSED BUBBLE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _BubbleWidget extends StatefulWidget {
  final String name;
  final bool found;
  final String elapsed;

  const _BubbleWidget({
    required this.name,
    required this.found,
    required this.elapsed,
  });

  @override
  State<_BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<_BubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label =
        widget.found && widget.name.isNotEmpty ? initials(widget.name) : '?';

    return ScaleTransition(
      scale: _pulseAnim,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main circular bubble
          Container(
            width: _kBubbleSize,
            height: _kBubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_kAccentMid, _kAccent, _kAccentDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Timer pill below bubble
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kBg.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: _kBorder.withValues(alpha: 0.6)),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      color: _kAccentMid, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  widget.elapsed,
                  style: const TextStyle(
                    color: _kTextPrim,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

// ─────────────────────────────────────────────────────────────────────────────
// TYPE CHIP
// ─────────────────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _kAccentMid,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
