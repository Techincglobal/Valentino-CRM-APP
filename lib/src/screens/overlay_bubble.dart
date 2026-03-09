import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// Overlay Bubble — Truecaller Style Floating Card
// ============================================================================

class OverlayBubble extends StatefulWidget {
  const OverlayBubble({super.key});

  @override
  State<OverlayBubble> createState() => _OverlayBubbleState();
}

class _OverlayBubbleState extends State<OverlayBubble>
    with SingleTickerProviderStateMixin {
  // Config
  static const double _bubbleSize = 64.0;
  static const double _cardWidth = 340.0;
  static const double _cardHeight = 220.0;

  // Caller data
  String _phone = '';
  String _name = '';
  String _type = '';
  String _docname = '';
  bool _found = false;

  // Notes
  String _latestNote = '';

  // Auth
  String? _baseUrl;
  String? _sid;

  // UI state
  bool _loaded = false;
  bool _isExpanded = true;
  bool _saving = false;
  String? _successMessage;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Animation
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );

    // Initial load
    _load();

    // Also listen to background updates (optional, for real-time)
    if (Platform.isAndroid) {
      FlutterOverlayWindow.overlayListener.listen((event) {
        if (event != null && event is Map) {
          if (event['command'] == 'collapse' && _isExpanded) {
            _toggleExpanded();
            return;
          }

          // Handle incoming caller data
          if (event.containsKey('phone')) {
            setState(() {
              _phone = event['phone'] ?? '';
              _name = event['name'] ?? '';
              _type = event['type'] ?? '';
              _docname = event['docname'] ?? '';
              _found = event['found'] ?? false;
              _loaded = true;
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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

    if (_found && _docname.isNotEmpty && _type.isNotEmpty) {
      _fetchLatestNote();
    }

    _animController.forward();
  }

  Future<void> _fetchLatestNote() async {
    if (_baseUrl == null || _sid == null) return;

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
    } catch (_) {}
  }

  Future<void> _addNote() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _saving = true);

    try {
      if (_baseUrl == null || _sid == null) throw Exception('Not authed');
      final url = Uri.parse(
        _baseUrl!,
      ).resolve('/api/method/nxtgen_crm_mobile.api.add_call_note');
      final response = await http.post(
        url,
        headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'doctype': _type.isNotEmpty ? _type : 'Lead',
          'docname': _docname,
          'note_content': note,
        }),
      );
      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Note saved!';
          _saving = false;
        });
        await Future.delayed(const Duration(seconds: 1));
        _closeOverlay();
      } else {
        throw Exception();
      }
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  Future<void> _createLead() async {
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) return;
    setState(() => _saving = true);

    try {
      if (_baseUrl == null || _sid == null) throw Exception('Not authed');
      final url = Uri.parse(
        _baseUrl!,
      ).resolve('/api/method/nxtgen_crm_mobile.api.create_lead_with_note');

      await http.post(
        url,
        headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': 'Unknown Caller',
          'mobile_no': _phone,
          'note_content': note,
        }),
      );
      setState(() {
        _successMessage = 'Lead created!';
        _saving = false;
      });
      await Future.delayed(const Duration(seconds: 1));
      _closeOverlay();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  void _toggleExpanded() async {
    setState(() => _isExpanded = !_isExpanded);
    if (!Platform.isAndroid) return;

    if (_isExpanded) {
      await FlutterOverlayWindow.resizeOverlay(
        _cardWidth.toInt(),
        _cardHeight.toInt(),
        true,
      );
    } else {
      await FlutterOverlayWindow.resizeOverlay(
        _bubbleSize.toInt(),
        _bubbleSize.toInt(),
        true,
      );
    }
  }

  void _closeOverlay() async {
    await _animController.reverse();
    if (Platform.isAndroid) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      // In iOS Test mode, pop the modal dialog
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Center(
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: _buildBubble(),
            secondChild: _buildCard(),
            layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(key: bottomKey, top: 0, child: bottomChild),
                  Positioned(key: topKey, child: topChild),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBubble() {
    final String initial = _name.isNotEmpty ? _name[0].toUpperCase() : '?';
    final Color ringColor = _found
        ? Colors.greenAccent.shade400
        : Colors.indigoAccent.shade200;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: _bubbleSize,
        height: _bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ringColor.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: ringColor, width: 2.5),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    final Color accentColor = _found
        ? Colors.greenAccent.shade400
        : Colors.indigoAccent.shade200;

    return Container(
      width: _cardWidth,
      height: _cardHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Accent Bar
              Container(height: 4, color: accentColor),

              // Content Area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.phone, color: accentColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _found && _name.isNotEmpty
                                      ? _name
                                      : 'Unknown Caller',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (_found && _type.isNotEmpty) ...[
                                      Text(
                                        _type,
                                        style: TextStyle(
                                          color: accentColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        '•',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      _phone,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      if (_latestNote.isNotEmpty &&
                          _successMessage == null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.notes,
                                color: Colors.white54,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _latestNote,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      if (_successMessage != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: accentColor),
                            const SizedBox(width: 8),
                            Text(
                              _successMessage!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ] else ...[
                        const SizedBox(height: 16),
                        // Note input
                        TextField(
                          controller: _noteCtrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: _found
                                ? 'Add a quick note...'
                                : 'Add note to create Lead...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            filled: true,
                            fillColor: Colors.black.withValues(alpha: 0.2),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const Spacer(),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                icon: _found ? Icons.save : Icons.add_circle,
                                label: _saving
                                    ? 'Saving...'
                                    : (_found ? 'Save Note' : 'New Lead'),
                                color: accentColor,
                                onTap: _saving
                                    ? () {}
                                    : (_found ? _addNote : _createLead),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              icon: Icons.compress,
                              label: 'Hide',
                              color: Colors.white24,
                              onTap: _toggleExpanded,
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _closeOverlay,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
