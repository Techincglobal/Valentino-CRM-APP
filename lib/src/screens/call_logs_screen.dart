import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/call_log_service.dart';
import '../services/caller_service.dart';
import '../services/sales_service.dart';
import '../services/ticket_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens
// ─────────────────────────────────────────────────────────────────────────────

const _blue   = Color(0xFF3B82F6);
const _green  = Color(0xFF22C55E);
const _slate  = Color(0xFF94A3B8);
const _indigo = Color(0xFF6366F1);
const _amber  = Color(0xFFF59E0B);
const _rose   = Color(0xFFF43F5E);

// ─────────────────────────────────────────────────────────────────────────────
// Controller interface — lets MainShell call refreshLogs()
// ─────────────────────────────────────────────────────────────────────────────

abstract class CallLogsScreenController {
  void refreshLogs();
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen>
    with AutomaticKeepAliveClientMixin
    implements CallLogsScreenController {
  @override
  bool get wantKeepAlive => true;

  @override
  void refreshLogs() => _load();

  List<CallLog> _logs = [];
  bool   _loading = false;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _showLogCallForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _LogCallSheet(onCreated: _load),
    );
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final logs = await CallLogService.getCallLogs();
      if (!mounted) return;
      setState(() {
        _logs    = logs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error   = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : ac.bgBase,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogCallForm,
        backgroundColor: _blue,
        icon: const Icon(Icons.add_call, color: Colors.white, size: 18),
        label: const Text('Log Call',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverToBoxAdapter(child: _buildHeader(ac, isDark)),
        ],
        body: _buildBody(ac, isDark, bottom),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(AdaptiveColors ac, bool isDark) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF60A5FA), _blue, Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _blue.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: _blue.withValues(alpha: 0.20), blurRadius: 4,  offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.call_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Call Logs',
                style: TextStyle(
                  color:       ac.textPrimary,
                  fontSize:    26,
                  fontWeight:  FontWeight.w900,
                  letterSpacing: -0.8,
                )),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:        _blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border:       Border.all(color: _blue.withValues(alpha: 0.3)),
              ),
              child: Text('LOGGED CALLS',
                  style: TextStyle(
                    color:         _blue,
                    fontSize:      9,
                    fontWeight:    FontWeight.w800,
                    letterSpacing: 1.2,
                  )),
            ),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: _load,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:  isDark ? const Color(0xFF131A2A) : ac.bgCard,
                shape:  BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : ac.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset:     const Offset(0, 4),
                  ),
                ],
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5),
                    )
                  : Icon(Icons.refresh_rounded, color: ac.textSecondary, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        if (!_loading && _error.isEmpty && _logs.isNotEmpty)
          _buildStats(ac, isDark),
        if (!_loading && _error.isEmpty && _logs.isNotEmpty)
          const SizedBox(height: 16),
      ]),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStats(AdaptiveColors ac, bool isDark) {
    final total    = _logs.length;
    final whatsapp = _logs.where((l) => l.isWhatsApp).length;
    final regular  = total - whatsapp;
    final totalMin = _logs.fold<int>(0, (s, l) => s + l.durationSeconds) ~/ 60;

    return Row(children: [
      _StatChip(label: 'Total',    value: '$total',    color: _blue,   isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'Regular',  value: '$regular',  color: _indigo, isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'WhatsApp', value: '$whatsapp', color: _green,  isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'Min',      value: '$totalMin', color: _amber,  isDark: isDark, ac: ac),
    ]);
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(AdaptiveColors ac, bool isDark, double bottom) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2.5));
    }
    if (_error.isNotEmpty) {
      return _buildError(ac, isDark);
    }
    if (_logs.isEmpty) {
      return _buildEmpty(ac, isDark);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color:     _blue,
      child: ListView.builder(
        padding:   EdgeInsets.fromLTRB(20, 0, 20, bottom + 100),
        itemCount: _logs.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CallLogCard(log: _logs[i]),
        ),
      ),
    );
  }

  String _friendlyError(String raw) {
    if (raw.isEmpty) return 'Something went wrong. Please try again.';
    final lower = raw.toLowerCase();
    // Any of these patterns = internal Frappe / Python error the user shouldn't see
    if (raw.length > 150 ||
        raw.contains('{') ||
        raw.contains('\\n') ||
        lower.contains('traceback') ||
        lower.contains('no attribute') ||
        lower.contains('get method') ||
        lower.contains('validationerror') ||
        lower.contains('attributeerror') ||
        lower.contains('file "') ||
        lower.contains('nxtgen_crm_mobile')) {
      return 'Call logs are unavailable right now.\nPlease contact your administrator.';
    }
    return raw;
  }

  Widget _buildError(AdaptiveColors ac, bool isDark) => SingleChildScrollView(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 32),
      Icon(Icons.wifi_off_rounded, color: ac.textTertiary, size: 48),
      const SizedBox(height: 16),
      Text('Could not load call logs',
          style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(
          _friendlyError(_error),
          style: TextStyle(color: ac.textSecondary, fontSize: 13),
          textAlign: TextAlign.center),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: _load,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_blue, Color(0xFF1D4ED8)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Text('Retry',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]),
  );

  Widget _buildEmpty(AdaptiveColors ac, bool isDark) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color:  _blue.withValues(alpha: 0.10),
          shape:  BoxShape.circle,
        ),
        child: const Icon(Icons.call_outlined, color: _blue, size: 38),
      ),
      const SizedBox(height: 18),
      Text('No calls logged yet',
          style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap "Log Call" in the overlay during a call',
          style: TextStyle(color: ac.textSecondary, fontSize: 13)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatChip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String       label;
  final String       value;
  final Color        color;
  final bool         isDark;
  final AdaptiveColors ac;

  const _StatChip({
    required this.label, required this.value, required this.color,
    required this.isDark, required this.ac,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
              color:         color,
              fontSize:      20,
              fontWeight:    FontWeight.w900,
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              color:         ac.textSecondary,
              fontSize:      11,
              fontWeight:    FontWeight.w700,
              letterSpacing: 0.3,
            )),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _CallLogCard  — tappable, shows all key fields
// ─────────────────────────────────────────────────────────────────────────────

class _CallLogCard extends StatelessWidget {
  final CallLog log;
  const _CallLogCard({required this.log});

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CallDetailSheet(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final isWA   = log.isWhatsApp;
    final accent = isWA ? _green : _blue;
    final isOutgoing = log.sentOrReceived.toLowerCase() == 'sent';

    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        isDark ? const Color(0xFF131A2A) : ac.bgCard,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border,
          ),
          boxShadow: [
            BoxShadow(
              color:      accent.withValues(alpha: 0.07),
              blurRadius: 16,
              offset:     const Offset(0, 6),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Row 1: avatar + name + direction icon + time ─────────────────
          Row(children: [
            // Avatar
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.10)],
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                ),
                shape:  BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  log.initials,
                  style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(log.callerLabel,
                    style: TextStyle(
                      color: ac.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700, letterSpacing: -0.3,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  if (log.phoneNo.isNotEmpty) ...[
                    Icon(Icons.phone_outlined, size: 11, color: ac.textTertiary),
                    const SizedBox(width: 3),
                    Text(log.phoneNo,
                        style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                    const SizedBox(width: 8),
                  ],
                  Icon(
                    isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                    size: 11,
                    color: isOutgoing ? _rose : _green,
                  ),
                  const SizedBox(width: 3),
                  Text(log.sentOrReceived,
                      style: TextStyle(
                        color: isOutgoing ? _rose : _green,
                        fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(log.timeLabel,
                  style: TextStyle(color: ac.textTertiary, fontSize: 11, fontWeight: FontWeight.w500)),
              if (log.durationLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.timer_outlined, size: 11, color: _amber),
                  const SizedBox(width: 3),
                  Text(log.durationLabel,
                      style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ],
            ]),
          ]),

          // ── Divider ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: accent.withValues(alpha: 0.12)),
          ),

          // ── Row 2: type chip + reference tag ──────────────────────────────
          Row(children: [
            _Chip(
              icon:  isWA ? Icons.chat_rounded : Icons.phone_rounded,
              label: isWA ? 'WhatsApp' : 'Regular',
              color: accent,
            ),
            if (log.referenceDoctype.isNotEmpty) ...[
              const SizedBox(width: 6),
              _Chip(
                icon:  Icons.link_rounded,
                label: log.referenceDoctype,
                color: _indigo,
              ),
            ],
            if (log.referenceName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: _Chip(
                  icon:  Icons.tag_rounded,
                  label: log.referenceName,
                  color: _slate,
                ),
              ),
            ],
            const Spacer(),
            // "View details" hint
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Details',
                  style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(width: 3),
              Icon(Icons.chevron_right_rounded, color: ac.textTertiary, size: 14),
            ]),
          ]),

          // ── Row 3: content preview ────────────────────────────────────────
          if (log.content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color:        accent.withValues(alpha: isDark ? 0.10 : 0.07),
                borderRadius: BorderRadius.circular(10),
                border:       Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.notes_rounded, size: 13, color: accent),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(log.content,
                      style: TextStyle(
                        color: isDark ? Colors.white.withValues(alpha: 0.75) : ac.textPrimary,
                        fontSize: 12, fontWeight: FontWeight.w500, height: 1.4,
                      ),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CallDetailSheet  — full detail popup with caller history (tickets + notes)
// ─────────────────────────────────────────────────────────────────────────────

class _CallDetailSheet extends StatefulWidget {
  final CallLog log;
  const _CallDetailSheet({required this.log});

  @override
  State<_CallDetailSheet> createState() => _CallDetailSheetState();
}

class _CallDetailSheetState extends State<_CallDetailSheet> {
  CallerContext _ctx        = CallerContext.empty;
  List<SupportTicket> _tickets = [];
  bool _ctxLoading          = true;

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final phone = widget.log.phoneNo;
    if (phone.isEmpty) {
      if (mounted) setState(() => _ctxLoading = false);
      return;
    }
    try {
      final ctx = await CallerService.getCallerContext(phone);
      List<SupportTicket> tickets = [];
      if (ctx.email.isNotEmpty) {
        tickets = await TicketService.getTicketsByEmail(ctx.email);
      }
      if (!mounted) return;
      setState(() {
        _ctx        = ctx;
        _tickets    = tickets;
        _ctxLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _ctxLoading = false);
    }
  }

  void _openCreateLead() {
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _CreateLeadSheet(log: widget.log),
      );
    });
  }

  void _copyPhone() {
    if (widget.log.phoneNo.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.log.phoneNo));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Phone number copied'),
      backgroundColor: _blue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final log    = widget.log;
    final isWA   = log.isWhatsApp;
    final accent = isWA ? _green : _blue;
    final isOutgoing = log.sentOrReceived.toLowerCase() == 'sent';
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottom + 16),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF131A2A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: ac.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        // ── Scrollable content ────────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Header: avatar + name + phone + direction ─────────────────
              Row(children: [
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0.12)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    shape:  BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
                  ),
                  child: Center(
                    child: Text(log.initials,
                        style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.callerLabel,
                        style: TextStyle(
                          color: ac.textPrimary, fontSize: 18,
                          fontWeight: FontWeight.w800, letterSpacing: -0.4,
                        )),
                    const SizedBox(height: 5),
                    if (log.phoneNo.isNotEmpty)
                      GestureDetector(
                        onTap: _copyPhone,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.phone_outlined, size: 13, color: _blue),
                          const SizedBox(width: 4),
                          Text(log.phoneNo,
                              style: const TextStyle(color: _blue, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_outlined, size: 11, color: _blue),
                        ]),
                      ),
                    if (_ctx.found && _ctx.docname.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.link_rounded, size: 11, color: _indigo),
                        const SizedBox(width: 4),
                        Text('${_ctx.doctype}: ${_ctx.docname}',
                            style: const TextStyle(color: _indigo, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ],
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isOutgoing ? _rose : _green).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (isOutgoing ? _rose : _green).withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                      size: 13, color: isOutgoing ? _rose : _green,
                    ),
                    const SizedBox(width: 4),
                    Text(log.sentOrReceived,
                        style: TextStyle(
                          color: isOutgoing ? _rose : _green,
                          fontSize: 11, fontWeight: FontWeight.w700,
                        )),
                  ]),
                ),
              ]),

              const SizedBox(height: 20),

              // ── Call Details ──────────────────────────────────────────────
              _DetailSection(
                title: 'Call Details', icon: Icons.info_outline_rounded,
                accent: accent, ac: ac, isDark: isDark,
                children: [
                  _DetailRow(label: 'Type', value: log.callType,
                      icon: isWA ? Icons.chat_rounded : Icons.phone_rounded,
                      color: accent, ac: ac, isDark: isDark),
                  _DetailRow(label: 'Direction', value: log.sentOrReceived,
                      icon: isOutgoing ? Icons.call_made_rounded : Icons.call_received_rounded,
                      color: isOutgoing ? _rose : _green, ac: ac, isDark: isDark),
                  if (log.durationLabel.isNotEmpty)
                    _DetailRow(label: 'Duration', value: log.durationLabel,
                        icon: Icons.timer_rounded, color: _amber, ac: ac, isDark: isDark),
                  _DetailRow(label: 'Date & Time', value: log.fullDateLabel,
                      icon: Icons.calendar_today_rounded, color: _indigo, ac: ac, isDark: isDark),
                  if (log.name.isNotEmpty)
                    _DetailRow(label: 'Log ID', value: log.name,
                        icon: Icons.fingerprint_rounded, color: _slate, ac: ac, isDark: isDark),
                ],
              ),

              const SizedBox(height: 14),

              // ── Subject ───────────────────────────────────────────────────
              if (log.subject.isNotEmpty) ...[
                _DetailSection(
                  title: 'Subject', icon: Icons.subject_rounded,
                  accent: _indigo, ac: ac, isDark: isDark,
                  children: [_TextBlock(text: log.subject, ac: ac, isDark: isDark)],
                ),
                const SizedBox(height: 14),
              ],

              // ── Reference ─────────────────────────────────────────────────
              if (log.referenceDoctype.isNotEmpty || log.referenceName.isNotEmpty) ...[
                _DetailSection(
                  title: 'Linked To', icon: Icons.link_rounded,
                  accent: _indigo, ac: ac, isDark: isDark,
                  children: [
                    if (log.referenceDoctype.isNotEmpty)
                      _DetailRow(label: 'Doctype', value: log.referenceDoctype,
                          icon: Icons.folder_outlined, color: _indigo, ac: ac, isDark: isDark),
                    if (log.referenceName.isNotEmpty)
                      _DetailRow(label: 'Record', value: log.referenceName,
                          icon: Icons.tag_rounded, color: _slate, ac: ac, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // ── Call Notes ────────────────────────────────────────────────
              if (log.content.isNotEmpty) ...[
                _DetailSection(
                  title: 'Call Notes', icon: Icons.notes_rounded,
                  accent: accent, ac: ac, isDark: isDark,
                  children: [_TextBlock(text: log.content, ac: ac, isDark: isDark, maxLines: null)],
                ),
                const SizedBox(height: 14),
              ],

              // ── Caller History (tickets + CRM notes) ──────────────────────
              _buildCallerHistory(ac, isDark),

              const SizedBox(height: 20),
            ]),
          ),
        ),

        // ── Action buttons ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0A0F1E) : ac.bgBase,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ac.border),
                  ),
                  child: Center(child: Text('Close',
                      style: TextStyle(color: ac.textSecondary, fontSize: 14, fontWeight: FontWeight.w700))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _openCreateLead,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        blurRadius: 14, offset: const Offset(0, 5))],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text('Create Lead',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Caller history section ─────────────────────────────────────────────────

  Widget _buildCallerHistory(AdaptiveColors ac, bool isDark) {
    if (_ctxLoading) {
      return _DetailSection(
        title: 'Caller History', icon: Icons.history_rounded,
        accent: _indigo, ac: ac, isDark: isDark,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(color: _indigo, strokeWidth: 2.5),
            )),
          ),
        ],
      );
    }

    final hasTickets = _tickets.isNotEmpty;
    final hasNotes   = _ctx.notes.isNotEmpty;

    if (!_ctx.found && !hasTickets) {
      return _DetailSection(
        title: 'Caller History', icon: Icons.history_rounded,
        accent: _slate, ac: ac, isDark: isDark,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(children: [
              Icon(Icons.person_search_rounded, size: 14, color: ac.textTertiary),
              const SizedBox(width: 8),
              Text('No CRM record found for this number',
                  style: TextStyle(color: ac.textTertiary, fontSize: 12)),
            ]),
          ),
        ],
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Linked CRM record banner ─────────────────────────────────────────
      if (_ctx.found) ...[
        _DetailSection(
          title: 'CRM Record', icon: Icons.account_circle_outlined,
          accent: _indigo, ac: ac, isDark: isDark,
          children: [
            _DetailRow(label: 'Name',    value: _ctx.displayName,
                icon: Icons.person_outline_rounded,  color: _indigo, ac: ac, isDark: isDark),
            _DetailRow(label: 'Type',    value: _ctx.doctype,
                icon: Icons.folder_outlined,          color: _slate,  ac: ac, isDark: isDark),
            if (_ctx.email.isNotEmpty)
              _DetailRow(label: 'Email', value: _ctx.email,
                  icon: Icons.email_outlined,         color: _blue,   ac: ac, isDark: isDark),
          ],
        ),
        const SizedBox(height: 14),
      ],

      // ── Recent tickets ───────────────────────────────────────────────────
      if (hasTickets) ...[
        _DetailSection(
          title: 'Recent Tickets (${_tickets.length})',
          icon: Icons.confirmation_number_outlined,
          accent: _rose, ac: ac, isDark: isDark,
          children: _tickets.map((t) => _TicketRow(ticket: t, ac: ac, isDark: isDark)).toList(),
        ),
        const SizedBox(height: 14),
      ],

      // ── CRM Notes ────────────────────────────────────────────────────────
      if (hasNotes)
        _DetailSection(
          title: 'CRM Notes (${_ctx.notes.length})',
          icon: Icons.sticky_note_2_outlined,
          accent: _amber, ac: ac, isDark: isDark,
          children: _ctx.notes.take(5).map((n) => _NoteRow(note: n, ac: ac, isDark: isDark)).toList(),
        ),
    ]);
  }
}

// ── Ticket row inside the history section ─────────────────────────────────

class _TicketRow extends StatelessWidget {
  final SupportTicket ticket;
  final AdaptiveColors ac;
  final bool isDark;

  const _TicketRow({required this.ticket, required this.ac, required this.isDark});

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':        return _rose;
      case 'replied':
      case 'in progress': return _amber;
      case 'resolved':
      case 'closed':      return _green;
      default:            return _slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(ticket.status);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.confirmation_number_outlined, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ticket.subject,
                style: TextStyle(color: ac.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(ticket.status,
                    style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
              if (ticket.priority.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text('· ${ticket.priority}',
                    style: TextStyle(color: ac.textTertiary, fontSize: 10)),
              ],
              const Spacer(),
              Text(ticket.timeAgo,
                  style: TextStyle(color: ac.textTertiary, fontSize: 10)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Note row inside the history section ───────────────────────────────────

class _NoteRow extends StatelessWidget {
  final CallerNote note;
  final AdaptiveColors ac;
  final bool isDark;

  const _NoteRow({required this.note, required this.ac, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.sticky_note_2_outlined, size: 13, color: _amber),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note.note,
                style: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.80) : ac.textPrimary,
                  fontSize: 12, fontWeight: FontWeight.w500, height: 1.4,
                ),
                maxLines: 3, overflow: TextOverflow.ellipsis),
            if (note.ownerLabel.isNotEmpty || note.timeLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                if (note.ownerLabel.isNotEmpty) ...[
                  Icon(Icons.person_outline_rounded, size: 10, color: ac.textTertiary),
                  const SizedBox(width: 3),
                  Text(note.ownerLabel,
                      style: TextStyle(color: ac.textTertiary, fontSize: 10)),
                  const SizedBox(width: 6),
                ],
                if (note.timeLabel.isNotEmpty)
                  Text(note.timeLabel,
                      style: TextStyle(color: ac.textTertiary, fontSize: 10)),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ── Section wrapper ────────────────────────────────────────────────────────

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final AdaptiveColors ac;
  final bool isDark;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.ac,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF0A0F1E) : ac.bgBase,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                  color: accent, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5,
                )),
          ]),
        ),
        Divider(height: 1, color: accent.withValues(alpha: 0.12)),
        ...children,
      ]),
    );
  }
}

// ── Detail row ─────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AdaptiveColors ac;
  final bool isDark;

  const _DetailRow({
    required this.label, required this.value, required this.icon,
    required this.color, required this.ac, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                color: ac.textSecondary, fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                color: ac.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }
}

// ── Text block for notes / subject ─────────────────────────────────────────

class _TextBlock extends StatelessWidget {
  final String text;
  final AdaptiveColors ac;
  final bool isDark;
  final int? maxLines;

  const _TextBlock({required this.text, required this.ac, required this.isDark, this.maxLines = 6});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Text(text,
          style: TextStyle(
            color:      isDark ? Colors.white.withValues(alpha: 0.80) : ac.textPrimary,
            fontSize:   13,
            height:     1.55,
            fontWeight: FontWeight.w500,
          ),
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CreateLeadSheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateLeadSheet extends StatefulWidget {
  final CallLog log;
  const _CreateLeadSheet({required this.log});

  @override
  State<_CreateLeadSheet> createState() => _CreateLeadSheetState();
}

class _CreateLeadSheetState extends State<_CreateLeadSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _noteCtrl;
  bool _loading = false;

  static bool _looksLikeName(String s) =>
      s.isNotEmpty && !RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(s);

  @override
  void initState() {
    super.initState();
    final label = widget.log.callerLabel;
    _nameCtrl  = TextEditingController(text: _looksLikeName(label) ? label : '');
    _phoneCtrl = TextEditingController(text: widget.log.phoneNo);
    _emailCtrl = TextEditingController();
    _noteCtrl  = TextEditingController(text: widget.log.content);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a name for the lead.', _amber);
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await SalesService.createLeadFromCall(
        firstName:   name,
        mobileNo:    _phoneCtrl.text.trim(),
        email:       _emailCtrl.text.trim(),
        noteContent: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      // Capture messenger before Navigator.pop disposes the sheet's context.
      final sm = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      sm.showSnackBar(SnackBar(
        content: Text(result.created
            ? 'Lead created: ${result.leadName}'
            : 'Lead already exists — note added to ${result.leadName}'),
        backgroundColor: result.created ? _green : _amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), Colors.red.shade600);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac      = context.ac;
    final isDark  = context.isDark;
    final bottom  = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom + 24),
      decoration: BoxDecoration(
        color:        isDark ? const Color(0xFF131A2A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: ac.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),

        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create Lead',
                style: TextStyle(color: ac.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            Text('From call with ${widget.log.callerLabel}',
                style: TextStyle(color: ac.textSecondary, fontSize: 12)),
          ]),
        ]),

        const SizedBox(height: 22),

        _SheetField(
          ctrl: _nameCtrl, label: 'Full Name *',
          hint: 'e.g. John Smith',
          icon: Icons.person_outline_rounded,
          ac: ac, isDark: isDark,
        ),
        const SizedBox(height: 12),

        _SheetField(
          ctrl: _phoneCtrl, label: 'Phone Number',
          hint: '+1 555 000 0000',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          ac: ac, isDark: isDark,
        ),
        const SizedBox(height: 12),

        _SheetField(
          ctrl: _emailCtrl, label: 'Email',
          hint: 'lead@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          ac: ac, isDark: isDark,
        ),
        const SizedBox(height: 12),

        _SheetField(
          ctrl: _noteCtrl, label: 'Note',
          hint: 'Call summary or follow-up…',
          icon: Icons.notes_rounded,
          maxLines: 3,
          ac: ac, isDark: isDark,
        ),

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _loading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _loading
                      ? [const Color(0xFF6366F1).withValues(alpha: 0.5), const Color(0xFF4F46E5).withValues(alpha: 0.5)]
                      : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _loading ? [] : [
                  BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 14, offset: const Offset(0, 5)),
                ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text('Create Lead',
                            style: TextStyle(color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;
  final AdaptiveColors ac;
  final bool isDark;

  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    required this.ac,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color:        isDark ? const Color(0xFF0A0F1E) : ac.bgBase,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: ac.border),
        ),
        child: TextField(
          controller:   ctrl,
          keyboardType: keyboardType,
          maxLines:     maxLines,
          style:        TextStyle(color: ac.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText:        hint,
            hintStyle:       TextStyle(color: ac.textTertiary, fontSize: 13),
            prefixIcon:      Icon(icon, color: ac.textTertiary, size: 17),
            border:          InputBorder.none,
            contentPadding:  const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Chip — small pill used in card footer
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border:       Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
            color:      color,
            fontSize:   10,
            fontWeight: FontWeight.w700,
          )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _LogCallSheet  — manually create a call log entry
// ─────────────────────────────────────────────────────────────────────────────

class _LogCallSheet extends StatefulWidget {
  final Future<void> Function() onCreated;
  const _LogCallSheet({required this.onCreated});

  @override
  State<_LogCallSheet> createState() => _LogCallSheetState();
}

class _LogCallSheetState extends State<_LogCallSheet> {
  final _phoneCtrl    = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _minsCtrl     = TextEditingController(text: '0');
  final _secsCtrl     = TextEditingController(text: '0');
  final _notesCtrl    = TextEditingController();

  String  _direction  = 'Inbound';
  String  _callType   = 'Regular';
  bool    _busy       = false;
  String? _error;
  String? _phoneError;

  // Lead lookup
  List<CrmLead> _suggestions = [];
  CrmLead?      _selectedLead;
  bool          _searching   = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    _minsCtrl.dispose();
    _secsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchLeads(String q) async {
    if (q.isEmpty) { setState(() => _suggestions = []); return; }
    setState(() => _searching = true);
    try {
      final all = await SalesService.getLeads();
      if (!mounted) return;
      final lower = q.toLowerCase();
      setState(() {
        _suggestions = all.where((l) =>
            l.displayName.toLowerCase().contains(lower) ||
            l.mobile.contains(q)).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    setState(() { _error = null; _phoneError = null; });

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = 'Phone number is required');
      return;
    }

    final name  = _nameCtrl.text.trim();
    final mins  = int.tryParse(_minsCtrl.text.trim()) ?? 0;
    final secs  = int.tryParse(_secsCtrl.text.trim()) ?? 0;
    final total = mins * 60 + secs;

    setState(() { _busy = true; _error = null; });
    try {
      await CallLogService.createCallLog(
        phone:           phone,
        callerName:      name.isNotEmpty ? name : phone,
        durationSeconds: total,
        direction:       _direction,
        callType:        _callType,
        notes:           _notesCtrl.text.trim(),
        leadDocname:     _selectedLead?.name,
      );
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Call log created'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      }
    } catch (e) {
      setState(() {
        _busy  = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final inset  = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
            top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : ac.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 8, 22, 20 + inset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _blue.withValues(alpha: 0.30)),
                  ),
                  child: const Icon(Icons.add_call, color: _blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Log a Call', style: TextStyle(
                      color: ac.textPrimary, fontSize: 17,
                      fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  Text('Manually record a call in the CRM',
                      style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                ])),
              ]),
              const SizedBox(height: 20),

              // Error banner
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _rose.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _rose.withValues(alpha: 0.30)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: _rose, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: TextStyle(color: _rose, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 12),
              ],

              // Direction + Call type toggles
              Row(children: [
                Expanded(child: _buildToggleGroup(
                  ac: ac, isDark: isDark,
                  label: 'Direction',
                  options: const ['Inbound', 'Outbound'],
                  selected: _direction,
                  color: _blue,
                  onSelect: (v) => setState(() => _direction = v),
                )),
                const SizedBox(width: 12),
                Expanded(child: _buildToggleGroup(
                  ac: ac, isDark: isDark,
                  label: 'Type',
                  options: const ['Regular', 'WhatsApp'],
                  selected: _callType,
                  color: _green,
                  onSelect: (v) => setState(() => _callType = v),
                )),
              ]),
              const SizedBox(height: 14),

              // Phone number
              _buildLabel(ac, 'Phone Number *'),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() => _phoneError = null),
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                decoration: _fieldDecor(ac, isDark,
                    hint: '+94 71 234 5678',
                    prefix: const Icon(Icons.phone_rounded, size: 16, color: _slate),
                    errorText: _phoneError),
              ),
              const SizedBox(height: 12),

              // Caller name
              _buildLabel(ac, 'Caller Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                enabled: !_busy,
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                decoration: _fieldDecor(ac, isDark,
                    hint: 'Auto-filled or enter manually',
                    prefix: const Icon(Icons.person_rounded, size: 16, color: _slate)),
              ),
              const SizedBox(height: 12),

              // Duration row
              _buildLabel(ac, 'Duration'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: _minsCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ac.textPrimary, fontSize: 14),
                  decoration: _fieldDecor(ac, isDark,
                      hint: '0', suffix: Text('min',
                          style: TextStyle(color: ac.textSecondary, fontSize: 12))),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextField(
                  controller: _secsCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: ac.textPrimary, fontSize: 14),
                  decoration: _fieldDecor(ac, isDark,
                      hint: '0', suffix: Text('sec',
                          style: TextStyle(color: ac.textSecondary, fontSize: 12))),
                )),
              ]),
              const SizedBox(height: 12),

              // Link to Lead (optional search)
              _buildLabel(ac, 'Linked Lead (optional)'),
              const SizedBox(height: 8),
              if (_selectedLead != null)
                GestureDetector(
                  onTap: () => setState(() { _selectedLead = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _indigo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _indigo.withValues(alpha: 0.40)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, color: _indigo, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_selectedLead!.displayName,
                          style: TextStyle(color: ac.textPrimary,
                              fontWeight: FontWeight.w600))),
                      Icon(Icons.close_rounded, color: ac.textSecondary, size: 16),
                    ]),
                  ),
                )
              else
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    enabled: !_busy,
                    onChanged: _searchLeads,
                    style: TextStyle(color: ac.textPrimary, fontSize: 14),
                    decoration: _fieldDecor(ac, isDark,
                        hint: 'Search lead name…',
                        prefix: const Icon(Icons.search_rounded,
                            size: 16, color: _slate)),
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _indigo))),
                    )
                  else if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: ac.bgInput,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: ac.border),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (_, i) {
                          final l = _suggestions[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() {
                              _selectedLead = l;
                              _suggestions  = [];
                              if (_nameCtrl.text.trim().isEmpty) {
                                _nameCtrl.text = l.displayName;
                              }
                              if (_phoneCtrl.text.trim().isEmpty &&
                                  l.mobile.isNotEmpty) {
                                _phoneCtrl.text = l.mobile;
                              }
                            }),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.displayName,
                                      style: TextStyle(
                                          color: ac.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  if (l.mobile.isNotEmpty)
                                    Text(l.mobile,
                                        style: TextStyle(
                                            color: ac.textSecondary,
                                            fontSize: 11)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ]),
              const SizedBox(height: 12),

              // Notes
              _buildLabel(ac, 'Notes'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                enabled: !_busy,
                maxLines: 3,
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                decoration: _fieldDecor(ac, isDark,
                    hint: 'What was discussed…'),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: ac.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          color: ac.textSecondary,
                          fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_call, color: Colors.white, size: 18),
                  label: Text(_busy ? 'Saving…' : 'Save Log',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                )),
              ]),
            ],
          ),
        )),
      ]),
    );
  }

  Widget _buildLabel(AdaptiveColors ac, String text) => Text(text,
      style: TextStyle(
          color: ac.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4));

  Widget _buildToggleGroup({
    required AdaptiveColors ac,
    required bool isDark,
    required String label,
    required List<String> options,
    required String selected,
    required Color color,
    required void Function(String) onSelect,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: ac.textSecondary, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 0.4)),
      const SizedBox(height: 8),
      Row(children: options.map((o) {
        final sel = o == selected;
        return Expanded(child: Padding(
          padding: EdgeInsets.only(
              right: o == options.first ? 4 : 0,
              left:  o == options.last  ? 4 : 0),
          child: GestureDetector(
            onTap: _busy ? null : () => onSelect(o),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: sel ? color.withValues(alpha: 0.14) : ac.bgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? color.withValues(alpha: 0.50) : ac.border),
              ),
              child: Center(child: Text(o,
                  style: TextStyle(
                      color: sel ? color : ac.textSecondary,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400))),
            ),
          ),
        ));
      }).toList()),
    ]);
  }

  InputDecoration _fieldDecor(
    AdaptiveColors ac,
    bool isDark, {
    required String hint,
    Widget? prefix,
    Widget? suffix,
    String? errorText,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: ac.textSecondary.withValues(alpha: 0.55), fontSize: 13),
        errorText: errorText,
        filled: true,
        fillColor: ac.bgInput,
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: prefix)
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        suffixIcon: suffix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: suffix)
            : null,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ac.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _blue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rose)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _rose, width: 1.5)),
      );
}
