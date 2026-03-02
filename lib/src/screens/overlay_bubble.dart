import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Overlay Bubble — Frosted Glass iOS Design
// Runs in a separate Flutter engine; no BackdropFilter (isolated window).
// Glass effect is simulated with gradients, borders, and shadows.
// ============================================================================

// ── Palette ─────────────────────────────────────────────────────────────────
const _primary = Color(0xFF2563EB); // Deep Blue
const _primaryDark = Color(0xFF1E40AF); // Deeper Blue
const _primaryLight = Color(0xFF60A5FA);
const _textPrimary = Color(0xFF0F172A);
const _textSecondary = Color(0xFF64748B);
const _textTertiary = Color(0xFF94A3B8);
const _success = Color(0xFF10B981);
const _danger = Color(0xFFEF4444);
const _warning = Color(0xFFF59E0B);
const _border = Color(0xFFE2E8F0);
const _inputBg = Color(0xFFF8FAFC);

const _lead = Color(0xFF8B5CF6);
const _opportunity = Color(0xFF10B981);
const _customer = Color(0xFF3B82F6);

// ── Sizes ───────────────────────────────────────────────────────────────────
const _bubbleSize = 68;
const _compactHeight = 360;
const _expandedHeight = 520;

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  // Caller data
  String _phone = '';
  String _name = '';
  String _type = '';
  String _docname = '';
  bool _found = false;

  // Notes
  String _latestNote = '';
  bool _loadingNotes = false;

  // Auth
  String? _baseUrl;
  String? _sid;

  // UI state
  bool _loaded = false;
  bool _isMinimized = false;
  bool _showForm = false;
  bool _saving = false;
  String? _successMessage;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phone = prefs.getString('crm_caller_phone') ?? '';
      _name = prefs.getString('crm_caller_name') ?? '';
      _type = prefs.getString('crm_caller_type') ?? '';
      _docname = prefs.getString('crm_caller_docname') ?? '';
      _found = prefs.getBool('crm_caller_found') ?? false;
      _baseUrl = prefs.getString('crm_base_url');
      _sid = prefs.getString('crm_sid');
      _loaded = true;
    });

    try {
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        _compactHeight,
        false,
      );
    } catch (_) {}

    // Fetch latest note for known callers
    if (_found && _docname.isNotEmpty && _type.isNotEmpty) {
      _fetchLatestNote();
    }
  }

  // ── Notes fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchLatestNote() async {
    if (_baseUrl == null || _sid == null) return;
    setState(() => _loadingNotes = true);

    try {
      final url = Uri.parse(
        _baseUrl!,
      ).resolve('/api/method/nxtgen_crm_mobile.api.get_notes');
      final response = await http.post(
        url,
        headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
        body: jsonEncode({'doctype': _type, 'docname': _docname}),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final notes = data['message'] as List? ?? [];
        if (notes.isNotEmpty) {
          setState(() {
            _latestNote = (notes[0]['content'] as String? ?? '').trim();
          });
        }
      }
    } catch (_) {
      // Silently fail — notes are supplementary
    } finally {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  // ── API helpers ─────────────────────────────────────────────────────────────

  Future<void> _createLead() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    try {
      final noteText = _noteCtrl.text.trim();
      final emailText = _emailCtrl.text.trim();
      await _post('/api/method/nxtgen_crm_mobile.api.create_lead_with_note', {
        'first_name': name,
        'mobile_no': _phone,
        if (emailText.isNotEmpty) 'email_id': emailText,
        if (noteText.isNotEmpty) 'note_content': noteText,
      });
      setState(() {
        _successMessage = 'Lead created!';
        _saving = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  Future<void> _addNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _saving = true);

    try {
      await _post('/api/method/nxtgen_crm_mobile.api.add_call_note', {
        'doctype': _type.isNotEmpty ? _type : 'Lead',
        'docname': _docname,
        'note_content': note,
      });
      setState(() {
        _successMessage = 'Note saved!';
        _saving = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    if (_baseUrl == null || _sid == null) throw Exception('Not authenticated');
    final url = Uri.parse(_baseUrl!).resolve(endpoint);
    final response = await http.post(
      url,
      headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }
  }

  // ── Overlay resize ──────────────────────────────────────────────────────────

  Future<void> _expand() async {
    await FlutterOverlayWindow.resizeOverlay(
      WindowSize.matchParent,
      _compactHeight,
      false,
    );
    setState(() {
      _isMinimized = false;
      _showForm = false;
    });
  }

  Future<void> _minimize() async {
    await FlutterOverlayWindow.resizeOverlay(_bubbleSize, _bubbleSize, true);
    setState(() {
      _isMinimized = true;
      _showForm = false;
    });
  }

  Future<void> _openForm() async {
    await FlutterOverlayWindow.resizeOverlay(
      WindowSize.matchParent,
      _expandedHeight,
      false,
    );
    setState(() => _showForm = true);
  }

  Future<void> _closeForm() async {
    await FlutterOverlayWindow.resizeOverlay(
      WindowSize.matchParent,
      _compactHeight,
      false,
    );
    setState(() {
      _showForm = false;
      _saving = false;
      _successMessage = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _noteCtrl.clear();
    });
  }

  // ── Display helpers ─────────────────────────────────────────────────────────

  String get _initials {
    if (!_found || _name.isEmpty) return '?';
    final parts = _name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _avatarColor => _found ? _primary : _warning;

  Color get _typeColor {
    switch (_type.toLowerCase()) {
      case 'lead':
        return _lead;
      case 'opportunity':
        return _opportunity;
      case 'customer':
        return _customer;
      default:
        return _textSecondary;
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    if (_isMinimized) return _buildBubble();
    return _buildCard();
  }

  // ── Minimized Bubble ────────────────────────────────────────────────────────

  Widget _buildBubble() {
    return GestureDetector(
      onTap: _expand,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final glowOpacity = 0.15 + (_pulseCtrl.value * 0.15);
          return Container(
            width: _bubbleSize.toDouble(),
            height: _bubbleSize.toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary, Color(0xFF60A5FA), _primaryDark],
              ),
              border: Border.all(color: Colors.white, width: 3.5),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: glowOpacity * 1.5),
                  blurRadius: 28,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phone_callback_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                if (_found && _name.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      _name.split(' ')[0],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Expanded Card ───────────────────────────────────────────────────────────

  Widget _buildCard() {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.12),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top accent line
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _found
                              ? [_primary, _primaryLight]
                              : [_warning, const Color(0xFFFCD34D)],
                        ),
                      ),
                    ),
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(
                        color: _border.withValues(alpha: 0.6),
                        height: 1,
                      ),
                    ),
                    if (_successMessage != null)
                      _buildSuccess()
                    else if (_showForm)
                      _buildForm()
                    else
                      _buildBody(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _avatarColor.withValues(alpha: 0.15),
                  _avatarColor.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: _avatarColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                _initials,
                style: TextStyle(
                  color: _avatarColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _found && _name.isNotEmpty ? _name : 'Unknown Caller',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (_found && _type.isNotEmpty) ...[
                      _TypeBadge(label: _type, color: _typeColor),
                      const SizedBox(width: 8),
                    ],
                    Icon(Icons.phone_outlined, size: 12, color: _textTertiary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _phone,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Controls
          _IconBtn(icon: Icons.remove_rounded, onTap: _minimize),
          const SizedBox(width: 4),
          _IconBtn(
            icon: Icons.close_rounded,
            onTap: () => FlutterOverlayWindow.closeOverlay(),
          ),
        ],
      ),
    );
  }

  // ── Body (known/unknown) ────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_found) return _buildKnownBody();
    return _buildUnknownBody();
  }

  Widget _buildKnownBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Latest note preview
          if (_loadingNotes)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading notes...',
                    style: TextStyle(color: _textTertiary, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (_latestNote.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_outlined,
                        size: 13,
                        color: _primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Latest Note',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _latestNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Add Note button
          SizedBox(
            width: double.infinity,
            child: _GradientBtn(
              label: 'Add Call Note',
              icon: Icons.edit_note_rounded,
              onTap: _openForm,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Info box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _warning.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This number isn\'t saved in your CRM yet. Save it to keep track of this interaction.',
                    style: TextStyle(
                      color: const Color(0xFF92400E),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _GlassBtn(
                  label: 'Dismiss',
                  icon: Icons.close_rounded,
                  onTap: () => FlutterOverlayWindow.closeOverlay(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _GradientBtn(
                  label: 'Save Contact',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: _openForm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Form ────────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name field (only for unknown callers)
          if (!_found) ...[
            _Label(label: 'Contact Name', required: true),
            const SizedBox(height: 6),
            _Field(
              controller: _nameCtrl,
              hint: 'Full name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 14),

            _Label(label: 'Email (Optional)'),
            const SizedBox(height: 6),
            _Field(
              controller: _emailCtrl,
              hint: 'email@example.com',
              icon: Icons.alternate_email_rounded,
            ),
            const SizedBox(height: 14),
          ],
          // Note field
          _Label(label: _found ? 'Call Note' : 'Note (optional)'),
          const SizedBox(height: 6),
          _Field(
            controller: _noteCtrl,
            hint: 'Briefly describe the call...',
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            children: [
              Expanded(
                child: _GlassBtn(
                  label: 'Cancel',
                  onTap: _saving ? null : _closeForm,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _GradientBtn(
                  label: _found ? 'Save Note' : 'Create Lead',
                  icon: _found ? Icons.check_rounded : Icons.add_rounded,
                  loading: _saving,
                  onTap: _saving ? null : (_found ? _addNote : _createLead),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Success state ───────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: _success, size: 26),
          ),
          const SizedBox(height: 12),
          Text(
            _successMessage!,
            style: const TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Local Widgets (self-contained for overlay engine)
// ============================================================================

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: _textSecondary, size: 16),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  final bool required;
  const _Label({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: _textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
          letterSpacing: -0.1,
        ),
        children: required
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: _danger, fontWeight: FontWeight.w700),
                ),
              ]
            : [],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 14,
        letterSpacing: -0.1,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textTertiary, fontSize: 13),
        prefixIcon: icon != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Icon(icon, color: _textTertiary, size: 18),
              )
            : null,
        prefixIconConstraints: icon != null
            ? const BoxConstraints(minWidth: 38)
            : null,
        filled: true,
        fillColor: _inputBg,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: maxLines > 1 ? 12 : 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
      ),
    );
  }
}

class _GradientBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientBtn({
    required this.label,
    this.icon,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: onTap == null
                ? [
                    _primary.withValues(alpha: 0.3),
                    _primaryDark.withValues(alpha: 0.3),
                  ]
                : [_primaryLight, _primary],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _GlassBtn({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _textSecondary, size: 14),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
