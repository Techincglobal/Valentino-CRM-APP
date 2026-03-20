import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

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
    final becomingExpanded = !_isExpanded;

    if (Platform.isAndroid) {
      if (becomingExpanded) {
        // Expand to full height to avoid keyboard overflow
        await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent,
          WindowSize.matchParent,
          true,
        );
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    if (mounted) {
      setState(() => _isExpanded = becomingExpanded);
    }

    if (Platform.isAndroid && !becomingExpanded) {
      await Future.delayed(const Duration(milliseconds: 200));
      await FlutterOverlayWindow.resizeOverlay(
        (_bubbleSize + 40).toInt(),
        (_bubbleSize + 48).toInt(),
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
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 20),
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: _buildBubble(),
              secondChild: _buildCard(),
              layoutBuilder: (topChild, topKey, bottomChild, bottomKey) {
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Align(
                      key: bottomKey,
                      alignment: Alignment.topCenter,
                      child: bottomChild,
                    ),
                    Align(
                      key: topKey,
                      alignment: Alignment.topCenter,
                      child: topChild,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble() {
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
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
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
    final Color accentColor = _found ? AppColors.success : AppColors.primary;

    return Container(
      width: MediaQuery.of(context).size.width,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Minimal Top Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor,
                              accentColor.withValues(alpha: 0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _found && _name.isNotEmpty ? initials(_name) : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _found && _name.isNotEmpty
                                        ? _name
                                        : 'Unknown Caller',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                if (_found) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (_found && _type.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _type,
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    _phone,
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_latestNote.isNotEmpty && _successMessage == null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent.withValues(alpha: 0.08),
                            Colors.blueAccent.withValues(alpha: 0.03),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)
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
                              _latestNote,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_successMessage != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: accentColor,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _successMessage!,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 24),
                    if (!_found) ...[
                      _buildInputField(
                        controller: _nameCtrl,
                        hint: 'Full Name...',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildInputField(
                        controller: _emailCtrl,
                        hint: 'Email Address...',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Note input
                    _buildInputField(
                      controller: _noteCtrl,
                      hint: _found ? 'Add a quick note...' : 'Initial note (Optional)...',
                      icon: Icons.edit_note_rounded,
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: _found ? Icons.check_rounded : Icons.person_add_rounded,
                            label: _saving ? 'Saving...' : (_found ? 'Save Note' : 'Create Lead'),
                            color: Colors.white,
                            bgColor: accentColor,
                            onTap: _saving ? () {} : (_found ? _addNote : _createLead),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: Icons.keyboard_arrow_up_rounded,
                          label: 'Hide',
                          color: Colors.black87,
                          bgColor: Colors.black.withValues(alpha: 0.05),
                          onTap: _toggleExpanded,
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _closeOverlay,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFFF453A).withValues(alpha: 0.2),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Color(0xFFFF453A),
                                size: 22,
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
              color: Colors.black.withValues(alpha: 0.05),
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
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black45, size: 20),
            hintText: hint,
            hintStyle: const TextStyle(
              color: Colors.black38,
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
