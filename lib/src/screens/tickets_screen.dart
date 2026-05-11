import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/ticket_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens
// ─────────────────────────────────────────────────────────────────────────────

const _violet = Color(0xFF8B5CF6);
const _teal   = Color(0xFF14B8A6);
const _slate  = Color(0xFF94A3B8);
const _green  = Color(0xFF10B981);
const _red    = Color(0xFFEF4444);
const _amber  = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

const _priorityColors = {
  'Low':    _slate,
  'Medium': _amber,
  'High':   _indigo,
  'Urgent': _red,
};

const _statusColors = {
  'Open':     _teal,
  'Replied':  _indigo,
  'Resolved': _green,
  'Closed':   _slate,
};

const _priorityIcons = {
  'Low':    Icons.arrow_downward_rounded,
  'Medium': Icons.remove_rounded,
  'High':   Icons.arrow_upward_rounded,
  'Urgent': Icons.priority_high_rounded,
};

// ─────────────────────────────────────────────────────────────────────────────
// TicketsScreen
// ─────────────────────────────────────────────────────────────────────────────

class TicketsScreen extends StatefulWidget {
  final UserModel user;
  const TicketsScreen({super.key, required this.user});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tab;

  final _tabs   = const ['Open', 'Resolved', 'All'];
  List<SupportTicket> _tickets = [];
  bool   _loading = false;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) _loadTickets(); });
    _loadTickets();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final status  = _tabs[_tab.index];
      final tickets = await TicketService.getTickets(status: status);
      if (!mounted) return;
      setState(() { _tickets = tickets; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CreateTicketSheet(userEmail: widget.user.username),
    );
    if (created == true) _loadTickets();
  }

  void _openDetail(SupportTicket ticket) async {
    final changed = await showModalBottomSheet<bool>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: ticket),
    );
    if (changed == true) _loadTickets();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F1E) : ac.bgBase,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(child: _buildHeader(ac, isDark)),
        ],
        body: Column(children: [
          _buildTabBar(ac, isDark),
          Expanded(child: _buildBody(ac, isDark, bottom)),
        ]),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader(AdaptiveColors ac, bool isDark) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_violet, Color(0xFF6D28D9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support Tickets',
                style: TextStyle(color: ac.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            Text('Frappe Issue Tracker',
                style: TextStyle(color: ac.textTertiary, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: _loadTickets,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
              ),
              child: _loading
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: _violet, strokeWidth: 2),
                    )
                  : Icon(Icons.refresh_rounded, color: ac.textSecondary, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        // Stats row
        if (!_loading && _error.isEmpty) _buildStats(ac, isDark),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildStats(AdaptiveColors ac, bool isDark) {
    final open     = _tickets.where((t) => t.status == 'Open').length;
    final replied  = _tickets.where((t) => t.status == 'Replied').length;
    final resolved = _tickets.where((t) => t.status == 'Resolved' || t.status == 'Closed').length;
    final urgent   = _tickets.where((t) => t.priority == 'Urgent' || t.priority == 'High').length;

    return Row(children: [
      _StatChip(label: 'Open',     value: '$open',     color: _teal,   isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'Replied',  value: '$replied',  color: _indigo, isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'Resolved', value: '$resolved', color: _green,  isDark: isDark, ac: ac),
      const SizedBox(width: 8),
      _StatChip(label: 'Urgent',   value: '$urgent',   color: _red,    isDark: isDark, ac: ac),
    ]);
  }

  Widget _buildTabBar(AdaptiveColors ac, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : ac.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [_violet, Color(0xFF6D28D9)]),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: ac.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        tabs: _tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget _buildBody(AdaptiveColors ac, bool isDark, double bottom) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5));
    }
    if (_error.isNotEmpty) {
      return _buildError(ac);
    }
    if (_tickets.isEmpty) {
      return _buildEmpty(ac, isDark);
    }
    return RefreshIndicator(
      onRefresh:   _loadTickets,
      color:       _violet,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 100),
        itemCount: _tickets.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _TicketCard(
            ticket: _tickets[i],
            onTap:  () => _openDetail(_tickets[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildError(AdaptiveColors ac) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: ac.textTertiary, size: 48),
        const SizedBox(height: 16),
        Text('Could not load tickets', style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_error, style: TextStyle(color: ac.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _loadTickets,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_violet, Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _violet.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
  );

  Widget _buildEmpty(AdaptiveColors ac, bool isDark) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _violet.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.inbox_rounded, color: _violet, size: 38),
      ),
      const SizedBox(height: 18),
      Text('No tickets here', style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text('Tap + to raise a new support ticket', style: TextStyle(color: ac.textSecondary, fontSize: 13)),
    ]),
  );

  Widget _buildFab() => GestureDetector(
    onTap: _openCreateSheet,
    child: Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_violet, Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: _violet.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final bool   isDark;
  final AdaptiveColors ac;

  const _StatChip({
    required this.label, required this.value, required this.color,
    required this.isDark, required this.ac,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: ac.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket card
// ─────────────────────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback  onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac          = context.ac;
    final isDark      = context.isDark;
    final statusColor = _statusColors[ticket.status]   ?? _slate;
    final priColor    = _priorityColors[ticket.priority] ?? _slate;
    final priIcon     = _priorityIcons[ticket.priority]  ?? Icons.remove_rounded;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : ac.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  ticket.initials,
                  style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ticket.subject,
                    style: TextStyle(color: ac.textPrimary, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(ticket.name,
                    style: TextStyle(color: ac.textTertiary, fontSize: 11)),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: ac.textTertiary, size: 18),
          ]),

          const SizedBox(height: 12),

          Row(children: [
            // Status chip
            _Chip(label: ticket.status, color: statusColor),
            const SizedBox(width: 6),
            // Priority chip with icon
            _Chip(label: ticket.priority, color: priColor, icon: priIcon),
            const Spacer(),
            // Time
            if (ticket.timeAgo.isNotEmpty)
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: ac.textTertiary),
                const SizedBox(width: 3),
                Text(ticket.timeAgo, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
              ]),
          ]),

          // Customer / raised by
          if (ticket.customerName.isNotEmpty || ticket.raisedBy.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (ticket.customerName.isNotEmpty) ...[
                Icon(Icons.business_rounded, size: 12, color: ac.textTertiary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(ticket.customerName,
                      style: TextStyle(color: ac.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 10),
              ],
              if (ticket.raisedBy.isNotEmpty) ...[
                Icon(Icons.person_outline_rounded, size: 12, color: ac.textTertiary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(ticket.raisedBy,
                      style: TextStyle(color: ac.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String    label;
  final Color     color;
  final IconData? icon;
  const _Chip({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: icon != null ? 7 : 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
      ],
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Ticket bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateTicketSheet extends StatefulWidget {
  final String userEmail;
  const _CreateTicketSheet({required this.userEmail});

  @override
  State<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends State<_CreateTicketSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _subjectCtrl  = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _customerCtrl = TextEditingController();
  late  final TextEditingController _emailCtrl;

  String _priority = 'Medium';
  bool   _submitting = false;
  String _error      = '';

  static const _priorities = ['Low', 'Medium', 'High', 'Urgent'];

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.userEmail);
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _customerCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _error = ''; });
    try {
      await TicketService.createTicket(
        subject:     _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        raisedBy:    _emailCtrl.text.trim(),
        priority:    _priority,
        customer:    _customerCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_violet, Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('New Support Ticket',
                style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.bgCard,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.close_rounded, color: ac.textSecondary, size: 18),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottom),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Subject
                _FieldLabel(label: 'SUBJECT', required: true, ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _subjectCtrl,
                  hint:       'Brief description of the issue',
                  isDark:     isDark,
                  ac:         ac,
                  validator:  (v) => (v?.trim().isEmpty ?? true) ? 'Subject is required' : null,
                ),

                const SizedBox(height: 16),

                // Description
                _FieldLabel(label: 'DESCRIPTION', required: true, ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _descCtrl,
                  hint:       'Describe the issue in detail...',
                  isDark:     isDark,
                  ac:         ac,
                  maxLines:   5,
                  validator:  (v) => (v?.trim().isEmpty ?? true) ? 'Description is required' : null,
                ),

                const SizedBox(height: 16),

                // Priority selector
                _FieldLabel(label: 'PRIORITY', ac: ac),
                const SizedBox(height: 8),
                Row(
                  children: _priorities.map((p) {
                    final color    = _priorityColors[p] ?? _slate;
                    final selected = _priority == p;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.only(right: p != _priorities.last ? 8 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : (isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(children: [
                            Icon(_priorityIcons[p] ?? Icons.remove_rounded,
                                color: selected ? color : ac.textTertiary, size: 16),
                            const SizedBox(height: 3),
                            Text(p,
                                style: TextStyle(
                                  color: selected ? color : ac.textSecondary,
                                  fontSize: 11,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ]),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Raised by (email)
                _FieldLabel(label: 'RAISED BY (EMAIL)', required: true, ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _emailCtrl,
                  hint:       'email@example.com',
                  isDark:     isDark,
                  ac:         ac,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'Email is required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v!.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Customer (optional)
                _FieldLabel(label: 'CUSTOMER (OPTIONAL)', ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _customerCtrl,
                  hint:       'Customer name or ID',
                  isDark:     isDark,
                  ac:         ac,
                ),

                const SizedBox(height: 24),

                // Error banner
                if (_error.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _red.withValues(alpha: 0.40)),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.error_outline_rounded, color: _red, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error,
                            style: const TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _error = ''),
                        child: const Icon(Icons.close_rounded, color: _red, size: 15),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // Submit button
                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _submitting
                          ? null
                          : const LinearGradient(
                              colors: [_violet, Color(0xFF6D28D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _submitting ? _violet.withValues(alpha: 0.40) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _submitting ? null : [
                        BoxShadow(color: _violet.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: _submitting
                        ? const Center(child: SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          ))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Submit Ticket',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                          ]),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _TicketDetailSheet extends StatefulWidget {
  final SupportTicket ticket;
  const _TicketDetailSheet({required this.ticket});

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  SupportTicketDetail? _detail;
  bool   _loading     = true;
  bool   _acting      = false;
  String _error       = '';
  String _actionError = '';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final d = await TicketService.getTicketDetail(widget.ticket.name);
      if (!mounted) return;
      setState(() { _detail = d; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() { _acting = true; _actionError = ''; });
    try {
      await TicketService.updateTicketStatus(widget.ticket.name, status);
      if (!mounted) return;
      _showSnack('Ticket $status', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _acting = false;
        _actionError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? _red : _green,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 6),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Flexible(
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5)),
                )
              : _error.isNotEmpty
                  ? _buildError(ac)
                  : _buildContent(ac, isDark, bottom),
        ),
      ]),
    );
  }

  Widget _buildError(AdaptiveColors ac) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: ac.textTertiary, size: 40),
      const SizedBox(height: 14),
      Text('Could not load ticket', style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(_error, style: TextStyle(color: ac.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _fetchDetail,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _violet.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _violet.withValues(alpha: 0.30)),
          ),
          child: const Text('Retry', style: TextStyle(color: _violet, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _buildContent(AdaptiveColors ac, bool isDark, double bottomInset) {
    final d           = _detail!;
    final statusColor = _statusColors[d.status]     ?? _slate;
    final priColor    = _priorityColors[d.priority] ?? _slate;
    final priIcon     = _priorityIcons[d.priority]  ?? Icons.remove_rounded;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(d.initials,
                  style: TextStyle(color: statusColor, fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.subject,
                  style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
              const SizedBox(height: 5),
              Row(children: [
                _Chip(label: d.status, color: statusColor),
                const SizedBox(width: 6),
                _Chip(label: d.priority, color: priColor, icon: priIcon),
              ]),
            ]),
          ),
        ]),

        const SizedBox(height: 18),

        // ── Details card ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
          ),
          child: Column(children: [
            _DetailRow(icon: Icons.tag_rounded, label: 'Ticket ID', value: d.name, ac: ac),
            _divider(isDark, ac),
            _DetailRow(icon: Icons.person_outline_rounded, label: 'Raised By', value: d.raisedBy.isNotEmpty ? d.raisedBy : '—', ac: ac),
            if (d.customerName.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(icon: Icons.business_rounded, label: 'Customer', value: d.customerName, ac: ac),
            ],
            if (d.issueType.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(icon: Icons.category_outlined, label: 'Type', value: d.issueType, ac: ac),
            ],
            if (d.openingDate.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(
                icon: Icons.calendar_today_rounded, label: 'Opened',
                value: d.openingDate.length >= 10 ? d.openingDate.substring(0, 10) : d.openingDate,
                ac: ac,
              ),
            ],
            if (d.resolutionDate.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(
                icon: Icons.check_circle_outline_rounded, label: 'Resolved',
                value: d.resolutionDate.length >= 10 ? d.resolutionDate.substring(0, 10) : d.resolutionDate,
                ac: ac,
              ),
            ],
          ]),
        ),

        // ── Description ──────────────────────────────────────────────────
        if (d.description.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionLabel(label: 'DESCRIPTION', ac: ac),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
            ),
            child: Text(
              // Strip basic HTML tags from Frappe rich text
              d.description.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
              style: TextStyle(color: ac.textPrimary, fontSize: 13, height: 1.6),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // ── Error banner ─────────────────────────────────────────────────
        if (_actionError.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red.withValues(alpha: 0.40)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded, color: _red, size: 17),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_actionError,
                    style: const TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w500)),
              ),
              GestureDetector(
                onTap: () => setState(() => _actionError = ''),
                child: const Icon(Icons.close_rounded, color: _red, size: 15),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Actions ──────────────────────────────────────────────────────
        if (_acting)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: const Center(child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5)),
          )
        else ...[
          if (d.status == 'Open' || d.status == 'Replied') ...[
            _ActionBtn(
              label: 'Mark as Resolved',
              icon:  Icons.check_circle_outline_rounded,
              color: _green,
              onTap: () => _updateStatus('Resolved'),
            ),
            const SizedBox(height: 10),
            _ActionBtn(
              label:    'Close Ticket',
              icon:     Icons.lock_outline_rounded,
              color:    _slate,
              outlined: true,
              onTap:    () => _updateStatus('Closed'),
            ),
          ] else if (d.status == 'Resolved') ...[
            _ActionBtn(
              label: 'Reopen Ticket',
              icon:  Icons.refresh_rounded,
              color: _violet,
              onTap: () => _updateStatus('Open'),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _divider(bool isDark, AdaptiveColors ac) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.borderLight),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final AdaptiveColors ac;
  const _DetailRow({required this.icon, required this.label, required this.value, required this.ac});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: ac.textSecondary),
    const SizedBox(width: 10),
    Text(label, style: TextStyle(color: ac.textSecondary, fontSize: 12)),
    const Spacer(),
    Flexible(
      child: Text(value,
          style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
    ),
  ]);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final AdaptiveColors ac;
  const _SectionLabel({required this.label, required this.ac});

  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4));
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final AdaptiveColors ac;
  const _FieldLabel({required this.label, required this.ac, this.required = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(color: ac.textTertiary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
    if (required) ...[
      const SizedBox(width: 4),
      const Text('*', style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  ]);
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool   isDark;
  final AdaptiveColors ac;
  final int    maxLines;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.ac,
    this.maxLines    = 1,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    maxLines:     maxLines,
    keyboardType: keyboardType,
    validator:    validator,
    style: TextStyle(color: ac.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(color: ac.textTertiary, fontSize: 14),
      filled:    true,
      fillColor: isDark ? const Color(0xFF1A2235) : ac.bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: _violet, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: _red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:   const BorderSide(color: _red, width: 1.5),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: maxLines > 1 ? 14 : 0),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      outlined;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label, required this.icon, required this.color, required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: outlined ? null : LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: outlined ? Border.all(color: color.withValues(alpha: 0.50)) : null,
        boxShadow: outlined ? null : [
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: outlined ? color : Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
              color: outlined ? color : Colors.white, fontSize: 15,
              fontWeight: FontWeight.w700, letterSpacing: -0.2,
            )),
      ]),
    ),
  );
}
