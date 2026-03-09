import 'dart:async';
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

  StreamSubscription? _overlaySub;

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
      try {
        _overlaySub = FlutterOverlayWindow.overlayListener.listen((event) {
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
      } catch (e) {
        debugPrint("Overlay Listener Error: $e");
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
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _successMessage = 'Name is required!');
      await Future.delayed(const Duration(seconds: 2));
      setState(() => _successMessage = null);
      return;
    }

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
          'first_name': name,
          if (email.isNotEmpty) 'email_id': email,
          'mobile_no': _phone,
          if (note.isNotEmpty) 'note_content': note,
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
        WindowSize.matchParent,
        _found ? 380 : 520,
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
        ? Colors.green.shade600
        : Colors.indigo.shade600;

    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: _bubbleSize,
        height: _bubbleSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.85),
                border: Border.all(
                  color: ringColor.withValues(alpha: 0.8),
                  width: 2.5,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    color: ringColor,
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
        ? const Color(0xFF32D74B) // iOS Green
        : const Color(0xFF0A84FF); // iOS Blue

    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF23252A).withValues(alpha: 0.85),
                  const Color(0xFF131417).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Minimal Top Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Content Area
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (_found && _type.isNotEmpty) ...[
                                          Text(
                                            _type,
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '•',
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          _phone,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.3,
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
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.notes_rounded,
                                    color: Colors.white60,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _latestNote,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        height: 1.4,
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
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: accentColor,
                                  size: 28,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ] else ...[
                            const SizedBox(height: 16),
                            if (!_found) ...[
                              _buildInputField(
                                controller: _nameCtrl,
                                hint: 'Full Name...',
                                icon: Icons.person_outline_rounded,
                              ),
                              const SizedBox(height: 12),
                              _buildInputField(
                                controller: _emailCtrl,
                                hint: 'Email Address (Optional)...',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 12),
                            ],
                            // Note input
                            _buildInputField(
                              controller: _noteCtrl,
                              hint: _found
                                  ? 'Add a quick note...'
                                  : 'Initial note (Optional)...',
                              icon: Icons.edit_note_rounded,
                            ),

                            const SizedBox(height: 20),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    icon: _found
                                        ? Icons.save_rounded
                                        : Icons.person_add_rounded,
                                    label: _saving
                                        ? 'Saving...'
                                        : (_found
                                              ? 'Save Note'
                                              : 'Create Lead'),
                                    color: Colors.white,
                                    bgColor: accentColor,
                                    onTap: _saving
                                        ? () {}
                                        : (_found ? _addNote : _createLead),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                  icon: Icons.keyboard_arrow_up_rounded,
                                  label: 'Hide',
                                  color: Colors.white,
                                  bgColor: Colors.white.withValues(alpha: 0.15),
                                  onTap: _toggleExpanded,
                                ),
                                const SizedBox(width: 12),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _closeOverlay,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFFF453A,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFFF453A,
                                          ).withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Color(0xFFFF453A),
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
                ),
              ],
            ),
          ),
        ),
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54, size: 20),
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}
