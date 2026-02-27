import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Palette (mirrors home_screen.dart) ──────────────────────────────────────
const _primary = Color(0xFF2490EF);
const _cardBg = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF1F272B);
const _textSecondary = Color(0xFF687076);
const _danger = Color(0xFFE03636);
const _border = Color(0xFFE2E8F0);
const _inputBg = Color(0xFFF8FAFC);
const _unknownColor = Color(0xFFD97706);
// ────────────────────────────────────────────────────────────────────────────

const _compactHeight = 220;
const _expandedHeight = 390;

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble> {
  // Caller data
  String _phone = '';
  String _name = '';
  String _type = '';
  String _docname = '';
  bool _found = false;

  // Auth (read from SharedPreferences — written by StorageService)
  String? _baseUrl;
  String? _sid;

  // UI state
  bool _loaded = false;
  bool _showForm = false; // add note / create lead form
  bool _saving = false;

  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
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
    // Snap to compact height so overlay doesn't cover the full screen on open
    try {
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, _compactHeight, false);
    } catch (_) {}
  }

  // ── API helpers ────────────────────────────────────────────────────────────

  Future<void> _createLead() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);

    try {
      final noteText = _noteCtrl.text.trim();
      await _post(
        '/api/method/nxtgen_crm_mobile.api.create_lead_with_note',
        {
          'first_name': name,
          'mobile_no': _phone,
          if (noteText.isNotEmpty) 'note_content': noteText,
        },
      );
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
      await _post(
        '/api/method/nxtgen_crm_mobile.api.add_call_note',
        {
          'doctype': _type.isNotEmpty ? _type : 'Lead',
          'docname': _docname,
          'note_content': note,
        },
      );
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  Future<void> _post(String endpoint, Map<String, dynamic> body) async {
    if (_baseUrl == null || _sid == null) {
      throw Exception('Not authenticated');
    }
    final url = Uri.parse(_baseUrl!).resolve(endpoint);
    final response = await http.post(
      url,
      headers: {
        'Cookie': 'sid=$_sid',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}');
    }
  }

  // ── Overlay resize helpers ─────────────────────────────────────────────────

  Future<void> _openForm() async {
    await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent, _expandedHeight, false);
    setState(() => _showForm = true);
  }

  Future<void> _closeForm() async {
    await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent, _compactHeight, false);
    setState(() {
      _showForm = false;
      _saving = false;
      _nameCtrl.clear();
      _noteCtrl.clear();
    });
  }

  // ── Derived display helpers ────────────────────────────────────────────────

  String get _initials {
    if (!_found || _name.isEmpty) return '?';
    final parts = _name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Color get _avatarColor => _found ? _primary : _unknownColor;

  Color get _typeColor {
    switch (_type.toLowerCase()) {
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: _border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const Divider(color: _border, height: 1, indent: 16, endIndent: 16),
                  _showForm ? _buildForm() : _buildActions(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _avatarColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials,
                style: TextStyle(
                  color: _avatarColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _found && _name.isNotEmpty ? _name : 'Unknown Caller',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (_found && _type.isNotEmpty) ...[
                      _TypeChip(label: _type, color: _typeColor),
                      const SizedBox(width: 6),
                    ],
                    const Icon(Icons.phone_outlined,
                        size: 11, color: _textSecondary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _phone,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close
          IconButton(
            onPressed: () => FlutterOverlayWindow.closeOverlay(),
            icon: const Icon(Icons.close_rounded,
                color: _textSecondary, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: _inputBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(6),
              minimumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (_found) {
      // Known caller: Add Note
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: _PrimaryBtn(
            label: 'Add Call Note',
            icon: Icons.note_add_outlined,
            onTap: _openForm,
          ),
        ),
      );
    } else {
      // Unknown caller: Create Lead or dismiss
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _OutlineBtn(
                label: 'Not a lead',
                icon: Icons.block_rounded,
                onTap: () => FlutterOverlayWindow.closeOverlay(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _PrimaryBtn(
                label: 'Create Lead',
                icon: Icons.person_add_alt_1_rounded,
                onTap: _openForm,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Name field (only for create lead)
          if (!_found) ...[
            _FieldLabel(label: 'Lead Name', required: true),
            const SizedBox(height: 5),
            _FrappeField(
              controller: _nameCtrl,
              hint: 'Full name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
          ],
          // Note field
          _FieldLabel(
              label: _found ? 'Call Note' : 'Note (optional)'),
          const SizedBox(height: 5),
          _FrappeField(
            controller: _noteCtrl,
            hint: 'Briefly describe the call…',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          // Action row
          Row(children: [
            Expanded(
              child: _OutlineBtn(
                label: 'Cancel',
                onTap: _saving ? null : _closeForm,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _PrimaryBtn(
                label: _found ? 'Save Note' : 'Create Lead',
                icon: _found
                    ? Icons.save_outlined
                    : Icons.add_rounded,
                loading: _saving,
                onTap: _saving
                    ? null
                    : (_found ? _addNote : _createLead),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Shared atoms ──────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
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
            fontSize: 11),
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

  const _FrappeField({
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
      style: const TextStyle(color: _textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _textSecondary, fontSize: 12),
        prefixIcon: icon != null
            ? Icon(icon, color: _textSecondary, size: 16)
            : null,
        filled: true,
        fillColor: _inputBg,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 12, vertical: maxLines > 1 ? 12 : 10),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide:
                const BorderSide(color: _primary, width: 1.5)),
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
      {required this.label, this.icon, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _primary.withValues(alpha: 0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
      ),
      child: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[
                Icon(icon, size: 15),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const _OutlineBtn({required this.label, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _textSecondary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (icon != null) ...[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w500, fontSize: 13)),
      ]),
    );
  }
}
