import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:io';
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
    with TickerProviderStateMixin {
  String _phone = '';
  String _name = '';
  String _type = '';
  String _docname = '';
  bool _found = false;
  String _latestNote = '';
  String? _baseUrl;
  String? _sid;
  bool _loaded = false;
  bool _saving = false;
  String? _successMessage;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription? _overlaySub;
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    // Fade IN animation
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeOutQuart);

    // Continuous Pulse animation for Avatar
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));
    _pulseController.repeat(reverse: true);

    if (widget.initialPayload != null) {
      _phone = widget.initialPayload!['phone'] ?? '';
      _name = widget.initialPayload!['name'] ?? '';
      _type = widget.initialPayload!['type'] ?? '';
      _docname = widget.initialPayload!['docname'] ?? '';
      _found = widget.initialPayload!['found'] == true;
      _loaded = true;
    }

    _load();

    if (Platform.isAndroid && widget.useSystemOverlay) {
      try {
        _overlaySub = FlutterOverlayWindow.overlayListener.listen((event) {
          if (event != null && event is Map && event.containsKey('phone')) {
            if (mounted) {
              setState(() {
                _phone = event['phone'] ?? '';
                _name = event['name'] ?? '';
                _type = event['type'] ?? '';
                _docname = event['docname'] ?? '';
                _found = event['found'] == true;
                _loaded = true;
              });
              _resetAndStartTimer();
            }
          }
        });
      } catch (e) {
        debugPrint("Overlay Listener Error: $e");
      }
    }
  }

  void _resetAndStartTimer() {
    _timer?.cancel();
    setState(() {
      _secondsElapsed = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String get _formattedDuration {
    final minutes = (_secondsElapsed / 60).floor().toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _overlaySub?.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (!widget.useSystemOverlay || _phone.isEmpty) {
        _phone = prefs.getString('crm_caller_phone') ?? _phone;
        _name = prefs.getString('crm_caller_name') ?? _name;
        _type = prefs.getString('crm_caller_type') ?? _type;
        _docname = prefs.getString('crm_caller_docname') ?? _docname;
        _found = prefs.getBool('crm_caller_found') ?? _found;
      }
      _baseUrl = prefs.getString('crm_base_url');
      _sid = prefs.getString('crm_sid');
      _loaded = true;
    });
    if (_found && _docname.isNotEmpty && _type.isNotEmpty) {
      _fetchLatestNote();
    }
    _resetAndStartTimer();
    _fadeController.forward();
  }

  Future<void> _fetchLatestNote() async {
    if (_baseUrl == null || _sid == null) return;
    try {
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.get_notes');
      final response = await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({'doctype': _type, 'docname': _docname}));
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
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.add_call_note');
      final response = await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'doctype': _type.isNotEmpty ? _type : 'Lead',
            'docname': _docname,
            'note_content': note,
          }));
      if (response.statusCode == 200) {
        setState(() {
          _successMessage = 'Note saved successfully';
          _saving = false;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
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
      final url = Uri.parse(_baseUrl!)
          .resolve('/api/method/nxtgen_crm_mobile.api.create_lead_with_note');
      await http.post(url,
          headers: {'Cookie': 'sid=$_sid', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'first_name': name,
            if (email.isNotEmpty) 'email_id': email,
            'mobile_no': _phone,
            if (note.isNotEmpty) 'note_content': note,
          }));
      setState(() {
        _successMessage = 'Lead created successfully';
        _saving = false;
      });
      await Future.delayed(const Duration(milliseconds: 1500));
      _closeOverlay();
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  void _closeOverlay() async {
    await _fadeController.reverse();
    if (Platform.isAndroid && widget.useSystemOverlay) {
      await FlutterOverlayWindow.closeOverlay();
    } else {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // Dark-mode premium neon palette mapping
    final Color accentGlow = _found ? Colors.tealAccent.shade400 : Colors.cyanAccent.shade400;
    final Color badgeGlow = _found ? Colors.tealAccent.shade700 : Colors.cyanAccent.shade700;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Align(
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(210), // Ultra dark backdrop
              borderRadius: BorderRadius.circular(44),
              border: Border.all(
                color: Colors.white.withAlpha(20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(150),
                  blurRadius: 40,
                  spreadRadius: 10,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: accentGlow.withAlpha(25),
                  blurRadius: 30,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // HUGE Glowing Timer
                        Text(
                          _formattedDuration,
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 54,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 2.0,
                            color: Colors.white,
                            height: 1.0,
                            shadows: [
                              Shadow(
                                color: Colors.white.withAlpha(80),
                                blurRadius: 30,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Animated Pulsing Avatar
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse ring
                              ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accentGlow.withAlpha(30),
                                  ),
                                ),
                              ),
                              // Core Avatar
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      badgeGlow.withAlpha(180),
                                      accentGlow.withAlpha(90),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withAlpha(200),
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentGlow.withAlpha(60),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    _found && _name.isNotEmpty
                                        ? initials(_name)
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                ),
                              ),
                              if (_found)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: accentGlow.withAlpha(100),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.verified_rounded,
                                      color: accentGlow,
                                      size: 26,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Contact Name & Phone HUD
                        Text(
                          _found && _name.isNotEmpty
                              ? _name.toUpperCase()
                              : 'UNKNOWN CALLER',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _phone,
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.0,
                          ),
                        ),
                        if (_found && _type.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: accentGlow.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: accentGlow.withAlpha(60),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _type.toUpperCase(),
                              style: TextStyle(
                                color: accentGlow,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Form & HUD Actions
                        if (_successMessage != null) ...[
                          _buildSuccessNeon(accentGlow),
                        ] else ...[
                          if (_latestNote.isNotEmpty) ...[
                            _buildNeonNoteCard(),
                            const SizedBox(height: 20),
                          ],

                          if (!_found) ...[
                            _buildDarkInput(_nameCtrl, 'ENTER NAME', Icons.person),
                            const SizedBox(height: 12),
                            _buildDarkInput(_emailCtrl, 'ENTER EMAIL', Icons.email,
                                TextInputType.emailAddress),
                            const SizedBox(height: 12),
                          ],
                          _buildDarkInput(_noteCtrl, 'ADD MISSION NOTE',
                              Icons.edit_document),

                          const SizedBox(height: 32),

                          // Floating Pill Dock Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPillAction(
                                icon: Icons.close_rounded,
                                color: Colors.white60,
                                bgColor: Colors.white.withAlpha(20),
                                borderColor: Colors.transparent,
                                onTap: _closeOverlay,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildPrimaryActionDock(accentGlow),
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
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryActionDock(Color accentGlow) {
    return GestureDetector(
      onTap: _saving ? null : (_found ? _addNote : _createLead),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              accentGlow.withAlpha(_saving ? 100 : 255),
              accentGlow.withAlpha(_saving ? 50 : 150),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            if (!_saving)
              BoxShadow(
                color: accentGlow.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_saving)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(Icons.flash_on_rounded, color: Colors.black87, size: 20),
            const SizedBox(width: 10),
            Text(
              _saving ? 'UPLOADING...' : (_found ? 'SAVE NOTE' : 'SAVE LEAD'),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillAction({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          border: Border.all(color: borderColor),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildDarkInput(TextEditingController controller, String hint, IconData icon,
      [TextInputType? type]) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha(30),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withAlpha(100),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildNeonNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withAlpha(30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes_rounded, color: Colors.cyanAccent.withAlpha(200), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _latestNote,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessNeon(Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: accentColor.withAlpha(15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withAlpha(50)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: accentColor, size: 28),
          const SizedBox(width: 16),
          Text(
            _successMessage!.toUpperCase(),
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
