import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/ticket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens
// ─────────────────────────────────────────────────────────────────────────────

const _violet = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
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
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<SupportTicket> _tickets = [];
  bool   _loading = false;
  String _error   = '';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final tickets = await TicketService.getTickets();
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
        body: _buildBody(ac, isDark, bottom),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5BAAFF), _violet, Color(0xFF1A7FD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _violet.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: _violet.withValues(alpha: 0.20), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Support Tickets',
                style: TextStyle(color: ac.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _violet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _violet.withValues(alpha: 0.3)),
              ),
              child: Text('FRAPPE ISSUE TRACKER',
                  style: TextStyle(color: _violet, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: _loadTickets,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A2A) : ac.bgCard,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : ac.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: _violet, strokeWidth: 2.5),
                    )
                  : Icon(Icons.refresh_rounded, color: ac.textSecondary, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 24),
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


  Widget _buildBody(AdaptiveColors ac, bool isDark, double bottom) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.only(top: 20), child: SkeletonList());
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
              gradient: const LinearGradient(colors: [_violet, Color(0xFF1A7FD4)]),
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
          colors: [_violet, Color(0xFF1A7FD4)],
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
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: ac.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131A2A) : ac.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor.withValues(alpha: 0.25), statusColor.withValues(alpha: 0.10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  ticket.initials,
                  style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.w900),
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

          const SizedBox(height: 10),

          // Email row — prominent
          if (ticket.raisedBy.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: _violet.withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _violet.withValues(alpha: 0.22)),
              ),
              child: Row(children: [
                Icon(Icons.email_outlined, size: 13, color: _violet),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ticket.raisedBy,
                    style: TextStyle(
                      color: _violet,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (ticket.ticketType.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _slate.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(ticket.ticketType,
                        style: TextStyle(color: ac.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ]),
            ),

          const SizedBox(height: 10),

          Row(children: [
            _Chip(label: ticket.status, color: statusColor),
            const SizedBox(width: 6),
            _Chip(label: ticket.priority, color: priColor, icon: priIcon),
            const Spacer(),
            if (ticket.timeAgo.isNotEmpty)
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: ac.textTertiary),
                const SizedBox(width: 3),
                Text(ticket.timeAgo, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
              ]),
          ]),
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
  final _subjectCtrl = TextEditingController();
  final _descCtrl    = TextEditingController();

  // Customer search
  final _customerSearchCtrl = TextEditingController();
  String _selectedCustomerName = '';
  String _selectedCustomerDocname = '';
  List<CustomerResult> _customerResults = [];
  bool   _searchingCustomers = false;
  bool   _showCustomerDropdown = false;

  // Ticket type
  List<String> _ticketTypes     = [];
  String       _selectedType    = '';
  bool         _loadingTypes    = false;

  String _priority   = 'Medium';
  bool   _submitting = false;
  String _error      = '';

  static const _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _loadTicketTypes();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTicketTypes() async {
    setState(() => _loadingTypes = true);
    final types = await TicketService.getTicketTypes();
    if (mounted) setState(() { _ticketTypes = types; _loadingTypes = false; });
  }

  Future<void> _onCustomerSearch(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() { _customerResults = []; _showCustomerDropdown = false; });
      return;
    }
    setState(() { _searchingCustomers = true; _showCustomerDropdown = true; });
    final results = await TicketService.searchCustomers(query);
    if (mounted) {
      setState(() { _customerResults = results; _searchingCustomers = false; });
    }
  }

  void _selectCustomer(CustomerResult c) {
    setState(() {
      _selectedCustomerName    = c.display;
      _selectedCustomerDocname = c.name;
      _customerSearchCtrl.text = c.display;
      _showCustomerDropdown    = false;
      _customerResults         = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomerName    = '';
      _selectedCustomerDocname = '';
      _customerSearchCtrl.clear();
      _showCustomerDropdown    = false;
      _customerResults         = [];
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _submitting = true; _error = ''; });
    try {
      await TicketService.createTicket(
        subject:     _subjectCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        raisedBy:    widget.userEmail,
        priority:    _priority,
        ticketType:  _selectedType,
        customer:    _selectedCustomerDocname,
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
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.94),
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
                gradient: const LinearGradient(colors: [_violet, Color(0xFF1A7FD4)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 18),
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

                // ── Subject ───────────────────────────────────────────────
                _FieldLabel(label: 'SUBJECT', required: true, ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _subjectCtrl,
                  hint:      'Brief title for the issue',
                  isDark:    isDark, ac: ac,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Subject is required' : null,
                ),

                const SizedBox(height: 16),

                // ── Priority ──────────────────────────────────────────────
                _FieldLabel(label: 'PRIORITY', ac: ac),
                const SizedBox(height: 8),
                Row(children: _priorities.map((p) {
                  final color    = _priorityColors[p] ?? _slate;
                  final selected = _priority == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: EdgeInsets.only(right: p != _priorities.last ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
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
                          Text(p, style: TextStyle(
                            color: selected ? color : ac.textSecondary,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          )),
                        ]),
                      ),
                    ),
                  );
                }).toList()),

                const SizedBox(height: 16),

                // ── Ticket Type ───────────────────────────────────────────
                _FieldLabel(label: 'TICKET TYPE', ac: ac),
                const SizedBox(height: 6),
                if (_loadingTypes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: _violet, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Loading types…', style: TextStyle(color: ac.textTertiary, fontSize: 13)),
                    ]),
                  )
                else if (_ticketTypes.isEmpty)
                  _InputField(
                    controller: TextEditingController(text: _selectedType),
                    hint: 'e.g. Bug, Feature Request',
                    isDark: isDark, ac: ac,
                    onChanged: (v) => _selectedType = v,
                  )
                else
                  _TypeDropdown(
                    types:    _ticketTypes,
                    selected: _selectedType,
                    isDark:   isDark,
                    ac:       ac,
                    onSelect: (t) => setState(() => _selectedType = t),
                  ),

                const SizedBox(height: 16),

                // ── Customer Search ───────────────────────────────────────
                _FieldLabel(label: 'CUSTOMER', ac: ac),
                const SizedBox(height: 6),
                _CustomerSearchField(
                  controller:          _customerSearchCtrl,
                  selectedName:        _selectedCustomerName,
                  results:             _customerResults,
                  searching:           _searchingCustomers,
                  showDropdown:        _showCustomerDropdown,
                  isDark:              isDark,
                  ac:                  ac,
                  onSearch:            _onCustomerSearch,
                  onSelect:            _selectCustomer,
                  onClear:             _clearCustomer,
                  onDismissDropdown:   () => setState(() => _showCustomerDropdown = false),
                ),

                const SizedBox(height: 16),

                // ── Description ───────────────────────────────────────────
                _FieldLabel(label: 'DESCRIPTION', required: true, ac: ac),
                const SizedBox(height: 6),
                _InputField(
                  controller: _descCtrl,
                  hint:       'Describe the issue in detail…',
                  isDark:     isDark, ac: ac,
                  maxLines:   5,
                  validator:  (v) => (v?.trim().isEmpty ?? true) ? 'Description is required' : null,
                ),

                const SizedBox(height: 24),

                // ── Error banner ──────────────────────────────────────────
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
                      Expanded(child: Text(_error, style: const TextStyle(color: _red, fontSize: 13, fontWeight: FontWeight.w500))),
                      GestureDetector(
                        onTap: () => setState(() => _error = ''),
                        child: const Icon(Icons.close_rounded, color: _red, size: 15),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Submit ────────────────────────────────────────────────
                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: _submitting ? null : const LinearGradient(
                        colors: [_violet, Color(0xFF1A7FD4)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      color: _submitting ? _violet.withValues(alpha: 0.40) : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _submitting ? null : [
                        BoxShadow(color: _violet.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: _submitting
                        ? const Center(child: SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Submit Ticket',
                                style: TextStyle(color: Colors.white, fontSize: 15,
                                    fontWeight: FontWeight.w700, letterSpacing: -0.2)),
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

  Future<void> _openFeedbackSheet() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<_FeedbackResult>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _FeedbackSheet(ticketSubject: widget.ticket.subject),
    );
    if (result == null) return;
    setState(() { _acting = true; _actionError = ''; });
    try {
      await TicketService.resolveWithFeedback(
        widget.ticket.name,
        feedback: result.feedback,
      );
      messenger.showSnackBar(SnackBar(
        content: const Text('Ticket resolved — thank you for your feedback!'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
      nav.pop(true);
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

        // ── Raised By — prominent email block ────────────────────────────
        if (d.raisedBy.isNotEmpty) ...[
          const SizedBox(height: 14),
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: d.raisedBy));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Email copied'),
                backgroundColor: _violet,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_violet.withValues(alpha: 0.15), _violet.withValues(alpha: 0.06)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _violet.withValues(alpha: 0.30), width: 1.5),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: _violet.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.email_outlined, color: _violet, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('RAISED BY',
                        style: TextStyle(color: _violet.withValues(alpha: 0.70), fontSize: 9,
                            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 3),
                    Text(d.raisedBy,
                        style: TextStyle(color: _violet, fontSize: 14,
                            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ]),
                ),
                Icon(Icons.copy_rounded, size: 14, color: _violet.withValues(alpha: 0.45)),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 14),

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
            if (d.ticketType.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(icon: Icons.label_outline_rounded, label: 'Type', value: d.ticketType, ac: ac),
            ],
            if (d.agentGroup.isNotEmpty) ...[
              _divider(isDark, ac),
              _DetailRow(icon: Icons.group_outlined, label: 'Team', value: d.agentGroup, ac: ac),
            ],
            _divider(isDark, ac),
            _DetailRow(
              icon: Icons.calendar_today_rounded, label: 'Created',
              value: d.creation.length >= 10 ? d.creation.substring(0, 10) : d.creation,
              ac: ac,
            ),
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
              d.description.replaceAll(RegExp(r'<[^>]+>'), '').trim(),
              style: TextStyle(color: ac.textPrimary, fontSize: 13, height: 1.6),
            ),
          ),
        ],

        // ── Conversation thread ───────────────────────────────────────────
        if (d.replies.isNotEmpty) ...[
          const SizedBox(height: 22),
          Row(children: [
            _SectionLabel(label: 'CONVERSATION', ac: ac),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _violet.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('${d.replies.length}',
                  style: const TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 12),
          ...d.replies.map((r) => _ReplyBubble(reply: r, isDark: isDark, ac: ac)),
        ],

        // ── Resolution message ────────────────────────────────────────────
        if ((d.status == 'Resolved' || d.status == 'Closed') &&
            (d.resolutionDetails.isNotEmpty || d.resolvedBy.isNotEmpty)) ...[
          const SizedBox(height: 20),
          _SectionLabel(label: 'RESOLUTION', ac: ac),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_green.withValues(alpha: isDark ? 0.14 : 0.09),
                         _green.withValues(alpha: 0.04)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withValues(alpha: 0.30), width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Resolved by + date row
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: _green, size: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      d.resolvedBy.isNotEmpty ? 'Resolved by ${d.resolvedByLabel}' : 'Resolved',
                      style: const TextStyle(
                        color: _green, fontSize: 13, fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (d.resolutionDate.isNotEmpty)
                      Text(
                        d.resolutionDate.length >= 10
                            ? d.resolutionDate.substring(0, 10)
                            : d.resolutionDate,
                        style: TextStyle(color: ac.textTertiary, fontSize: 11),
                      ),
                  ]),
                ),
              ]),
              // Resolution details text
              if (d.resolutionDetails.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: _green.withValues(alpha: 0.18)),
                const SizedBox(height: 12),
                Text(
                  d.resolutionDetails,
                  style: TextStyle(color: ac.textPrimary, fontSize: 13, height: 1.6),
                ),
              ],
            ]),
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
              onTap: _openFeedbackSheet,
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
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.isDark,
    required this.ac,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:   controller,
    maxLines:  maxLines,
    validator: validator,
    onChanged:    onChanged,
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

// ─────────────────────────────────────────────────────────────────────────────
// Ticket type dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _TypeDropdown extends StatelessWidget {
  final List<String> types;
  final String       selected;
  final bool         isDark;
  final AdaptiveColors ac;
  final ValueChanged<String> onSelect;

  const _TypeDropdown({
    required this.types, required this.selected, required this.isDark,
    required this.ac, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected.isEmpty ? null : (types.contains(selected) ? selected : null),
          hint: Text('Select ticket type', style: TextStyle(color: ac.textTertiary, fontSize: 14)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: ac.textSecondary),
          dropdownColor: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          borderRadius: BorderRadius.circular(14),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text('None', style: TextStyle(color: ac.textTertiary, fontSize: 14)),
            ),
            ...types.map((t) => DropdownMenuItem(
              value: t,
              child: Text(t, style: TextStyle(color: ac.textPrimary, fontSize: 14)),
            )),
          ],
          onChanged: (v) => onSelect(v ?? ''),
          style: TextStyle(color: ac.textPrimary, fontSize: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Customer search field with live dropdown
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String               selectedName;
  final List<CustomerResult> results;
  final bool                 searching;
  final bool                 showDropdown;
  final bool                 isDark;
  final AdaptiveColors       ac;
  final ValueChanged<String> onSearch;
  final ValueChanged<CustomerResult> onSelect;
  final VoidCallback         onClear;
  final VoidCallback         onDismissDropdown;

  const _CustomerSearchField({
    required this.controller, required this.selectedName, required this.results,
    required this.searching, required this.showDropdown, required this.isDark,
    required this.ac, required this.onSearch, required this.onSelect,
    required this.onClear, required this.onDismissDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedName.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Input row
      Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasSelection
                ? _violet.withValues(alpha: 0.50)
                : isDark ? Colors.white.withValues(alpha: 0.10) : ac.border,
            width: hasSelection ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          const SizedBox(width: 14),
          Icon(
            hasSelection ? Icons.business_rounded : Icons.search_rounded,
            size: 18,
            color: hasSelection ? _violet : ac.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller:  controller,
              onChanged:   onSearch,
              enabled:     !hasSelection,
              style: TextStyle(color: ac.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText:        hasSelection ? selectedName : 'Search by customer name…',
                hintStyle:       TextStyle(
                  color: hasSelection ? ac.textPrimary : ac.textTertiary,
                  fontSize: 14,
                  fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                ),
                border:          InputBorder.none,
                isDense:         true,
                contentPadding:  const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (searching)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: _violet, strokeWidth: 2)),
            )
          else if (hasSelection)
            GestureDetector(
              onTap: onClear,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.close_rounded, size: 18, color: ac.textTertiary),
              ),
            ),
        ]),
      ),

      // Dropdown results
      if (showDropdown && results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap:   true,
            padding:      const EdgeInsets.symmetric(vertical: 6),
            itemCount:    results.length,
            separatorBuilder: (_, i2) => Divider(
              height: 1,
              color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.borderLight,
            ),
            itemBuilder: (_, i) {
              final c = results[i];
              return GestureDetector(
                onTap: () => onSelect(c),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _violet.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          c.display.isNotEmpty ? c.display[0].toUpperCase() : '?',
                          style: const TextStyle(color: _violet, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.display,
                            style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (c.name != c.display)
                          Text(c.name, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                      ]),
                    ),
                    Icon(Icons.add_circle_outline_rounded, size: 16, color: _violet.withValues(alpha: 0.60)),
                  ]),
                ),
              );
            },
          ),
        )
      else if (showDropdown && !searching && results.isEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
          ),
          child: Text('No customers found', style: TextStyle(color: ac.textTertiary, fontSize: 13)),
        ),
    ]);
  }
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

// ─────────────────────────────────────────────────────────────────────────────
// Feedback result value object
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackResult {
  final String feedback;
  const _FeedbackResult({required this.feedback});
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback sheet — shown before resolving
// ─────────────────────────────────────────────────────────────────────────────

class _FeedbackSheet extends StatefulWidget {
  final String ticketSubject;
  const _FeedbackSheet({required this.ticketSubject});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _feedbackCtrl = TextEditingController();

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border,
        )),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottom),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Title
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_green, Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Resolve Ticket',
                        style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(widget.ticketSubject,
                        style: TextStyle(color: ac.textSecondary, fontSize: 12),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),

              const SizedBox(height: 22),

              Text('FEEDBACK',
                  style: TextStyle(color: ac.textTertiary, fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              TextFormField(
                controller:  _feedbackCtrl,
                maxLines:    4,
                autofocus:   false,
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText:  'How was the issue resolved? Any comments…',
                  hintStyle: TextStyle(color: ac.textTertiary, fontSize: 14),
                  filled:    true,
                  fillColor: isDark ? const Color(0xFF1A2235) : ac.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _green, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),

              const SizedBox(height: 20),

              // Submit button
              GestureDetector(
                onTap: () => Navigator.pop(
                  context,
                  _FeedbackResult(feedback: _feedbackCtrl.text.trim()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_green, Color(0xFF059669)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: _green.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text('Submit & Resolve',
                        style: TextStyle(color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : ac.border),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: TextStyle(color: ac.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reply bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ReplyBubble extends StatelessWidget {
  final TicketReply    reply;
  final bool           isDark;
  final AdaptiveColors ac;

  const _ReplyBubble({required this.reply, required this.isDark, required this.ac});

  @override
  Widget build(BuildContext context) {
    final isAgent  = reply.isAgent;
    final color    = isAgent ? _violet : _teal;
    final bgAlpha  = isDark ? 0.13 : 0.08;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar dot
          Container(
            margin: const EdgeInsets.only(top: 2, right: 10),
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Center(
              child: Text(
                reply.senderLabel.isNotEmpty ? reply.senderLabel[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Sender + timestamp
              Row(children: [
                Expanded(
                  child: Text(
                    reply.senderLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (reply.timeLabel.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(reply.timeLabel,
                      style: TextStyle(color: ac.textTertiary, fontSize: 10)),
                ],
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    isAgent ? 'AGENT' : 'CUSTOMER',
                    style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              // Message bubble
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: bgAlpha),
                  borderRadius: const BorderRadius.only(
                    topRight:    Radius.circular(14),
                    bottomLeft:  Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.20)),
                ),
                child: Text(
                  reply.message,
                  style: TextStyle(color: ac.textPrimary, fontSize: 13, height: 1.55),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
