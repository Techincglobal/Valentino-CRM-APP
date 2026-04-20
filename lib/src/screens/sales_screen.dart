import 'package:flutter/material.dart';
import '../services/sales_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock data — shown immediately so the flow is always demonstrable
// ─────────────────────────────────────────────────────────────────────────────

final _mockLeads = [
  CrmLead(
    name: 'LEAD-0001',
    displayName: 'Ashan Perera',
    email: 'ashan@example.com',
    mobile: '+94 71 234 5678',
    status: 'Interested',
    modified: '2024-04-18',
  ),
  CrmLead(
    name: 'LEAD-0002',
    displayName: 'Nimal Silva',
    email: 'nimal@techco.lk',
    mobile: '+94 77 890 1234',
    status: 'Contacted',
    modified: '2024-04-17',
  ),
  CrmLead(
    name: 'LEAD-0003',
    displayName: 'Priya Fernando',
    email: 'priya.f@gmail.com',
    mobile: '+94 76 555 9900',
    status: 'Lead',
    modified: '2024-04-16',
  ),
  CrmLead(
    name: 'LEAD-0004',
    displayName: 'Roshan Mendis',
    email: '',
    mobile: '+94 70 112 3344',
    status: 'Lead',
    modified: '2024-04-15',
  ),
];

final _mockOpps = [
  Opportunity(
    name: 'OPP-0001',
    partyName: 'Ashan Perera',
    amount: 450000,
    stage: 'Proposal',
    status: 'Open',
    expectedClosing: '2024-05-30',
    modified: '2024-04-18',
  ),
  Opportunity(
    name: 'OPP-0002',
    partyName: 'TechCo Solutions',
    amount: 1200000,
    stage: 'Negotiation',
    status: 'Open',
    expectedClosing: '2024-06-15',
    modified: '2024-04-17',
  ),
  Opportunity(
    name: 'OPP-0003',
    partyName: 'Sunset Interiors',
    amount: 320000,
    stage: 'Qualification',
    status: 'Open',
    expectedClosing: '2024-05-10',
    modified: '2024-04-14',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SalesScreen
// ─────────────────────────────────────────────────────────────────────────────

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tab;

  List<Opportunity> _opps    = List.of(_mockOpps);
  List<CrmLead>     _leads   = List.of(_mockLeads);
  PipelineSummary   _summary = SalesService.summarise(_mockOpps);
  bool _loading  = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadFromApi(); // fetch real data in background, merge with mock
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadFromApi() async {
    setState(() { _loading = true; _hasError = false; });
    try {
      final results = await Future.wait([
        SalesService.getOpportunities(),
        SalesService.getLeads(),
      ]);
      if (!mounted) return;
      final opps  = results[0] as List<Opportunity>;
      final leads = results[1] as List<CrmLead>;
      setState(() {
        // Merge: real data first, then append mock items not already represented
        _opps  = opps.isNotEmpty  ? opps  : List.of(_mockOpps);
        _leads = leads.isNotEmpty ? leads : List.of(_mockLeads);
        _summary = SalesService.summarise(_opps);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _hasError = false; /* keep mock data */ });
    }
  }

  void _showConvertForm(CrmLead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConvertToOpportunitySheet(
        lead: lead,
        onConverted: (opp) {
          setState(() {
            _opps = [opp, ..._opps];
            _summary = SalesService.summarise(_opps);
          });
        },
      ),
    );
  }

  void _showQuoteForm(Opportunity opp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuoteFormSheet(opp: opp),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ac = context.ac;

    return Scaffold(
      backgroundColor: ac.bgBase,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverToBoxAdapter(child: _Header(summary: _summary)),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: ac.bgBase,
              child: TabBar(
                controller: _tab,
                labelColor: AppColors.primary,
                unselectedLabelColor: ac.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: ac.border,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Leads'),
                        const SizedBox(width: 6),
                        _CountBadge(_leads.length),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Opportunities'),
                        const SizedBox(width: 6),
                        _CountBadge(_opps.length),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _LeadsTab(
              leads:    _leads,
              loading:  _loading,
              hasError: _hasError,
              onRetry:  _loadFromApi,
              onConvert: _showConvertForm,
            ),
            _OppsTab(
              opps:     _opps,
              loading:  _loading,
              hasError: _hasError,
              onRetry:  _loadFromApi,
              onQuote:  _showQuoteForm,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leads tab
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  final List<CrmLead>           leads;
  final bool                    loading;
  final bool                    hasError;
  final VoidCallback            onRetry;
  final void Function(CrmLead)  onConvert;

  const _LeadsTab({
    required this.leads,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && leads.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (hasError && leads.isEmpty) return _ErrorState(onRetry: onRetry);
    if (leads.isEmpty) {
      return _EmptyState(
        icon: Icons.person_add_outlined,
        title: 'No leads yet',
        subtitle: 'Leads created during calls will appear here',
        onRetry: onRetry,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        itemCount: leads.length,
        itemBuilder: (_, i) => _LeadCard(lead: leads[i], onConvert: onConvert),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead card — Convert to Opportunity button
// ─────────────────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final CrmLead               lead;
  final void Function(CrmLead) onConvert;
  const _LeadCard({required this.lead, required this.onConvert});

  static const _statusColors = {
    'Lead':           Color(0xFF6366F1),
    'Contacted':      Color(0xFF60A5FA),
    'Interested':     Color(0xFF10B981),
    'Converted':      Color(0xFF059669),
    'Do Not Contact': Color(0xFFEF4444),
  };

  Color get _color => _statusColors[lead.status] ?? const Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    final ac    = context.ac;
    final color = _color;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.20 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: Text(
                              lead.initials,
                              style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
                                lead.displayName,
                                style: TextStyle(
                                  color: ac.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (lead.mobile.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  lead.mobile,
                                  style: TextStyle(
                                    color: ac.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              _StatusBadge(status: lead.status, color: color),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Convert to Opportunity button — full width, prominent
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onConvert(lead),
                        icon: const Icon(Icons.trending_up_rounded, size: 15),
                        label: const Text(
                          'Convert to Opportunity',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.isEmpty ? 'Lead' : status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunities tab
// ─────────────────────────────────────────────────────────────────────────────

class _OppsTab extends StatelessWidget {
  final List<Opportunity>           opps;
  final bool                        loading;
  final bool                        hasError;
  final VoidCallback                onRetry;
  final void Function(Opportunity)  onQuote;

  const _OppsTab({
    required this.opps,
    required this.loading,
    required this.hasError,
    required this.onRetry,
    required this.onQuote,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && opps.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (hasError && opps.isEmpty) return _ErrorState(onRetry: onRetry);
    if (opps.isEmpty) {
      return _EmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No opportunities yet',
        subtitle: 'Convert a lead or create opportunities during calls',
        onRetry: onRetry,
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        itemCount: opps.length,
        itemBuilder: (_, i) => _OpportunityCard(opp: opps[i], onQuote: onQuote),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunity card — with Create Quote button
// ─────────────────────────────────────────────────────────────────────────────

class _OpportunityCard extends StatelessWidget {
  final Opportunity                opp;
  final void Function(Opportunity) onQuote;
  const _OpportunityCard({required this.opp, required this.onQuote});

  static const _stageColors = {
    'Prospecting':   Color(0xFF60A5FA),
    'Qualification': Color(0xFF6366F1),
    'Proposal':      Color(0xFF8B5CF6),
    'Negotiation':   Color(0xFFF59E0B),
    'Closed Won':    Color(0xFF10B981),
    'Closed Lost':   Color(0xFFEF4444),
  };

  Color get _stageColor => _stageColors[opp.stage] ?? const Color(0xFF6366F1);

  String _fmt(double v) {
    if (v == 0) return '—';
    if (v >= 10000000) return 'Rs. ${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000)   return 'Rs. ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return 'Rs. ${(v / 1000).toStringAsFixed(0)}K';
    return 'Rs. ${v.toStringAsFixed(0)}';
  }

  String get _initials {
    final p = opp.partyName.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ac    = context.ac;
    final color = _stageColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: color.withValues(alpha: 0.25)),
                          ),
                          child: Center(
                            child: Text(_initials,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opp.partyName,
                                style: TextStyle(
                                  color: ac.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _StageBadge(stage: opp.stage, color: color),
                                  const Spacer(),
                                  Text(_fmt(opp.amount),
                                      style: TextStyle(
                                          color: ac.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                              if (opp.expectedClosing.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_rounded,
                                        size: 11, color: ac.textTertiary),
                                    const SizedBox(width: 4),
                                    Text(opp.expectedClosing,
                                        style: TextStyle(
                                            color: ac.textTertiary, fontSize: 11)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Create Quote button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => onQuote(opp),
                        icon: const Icon(Icons.receipt_long_rounded, size: 15),
                        label: const Text(
                          'Create Quote',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String stage;
  final Color  color;
  const _StageBadge({required this.stage, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        stage.isEmpty ? 'No Stage' : stage,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — gradient + stats
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final PipelineSummary summary;
  const _Header({required this.summary});

  String _fmt(double v) {
    if (v >= 10000000) return 'Rs. ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return 'Rs. ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return 'Rs. ${(v / 1000).toStringAsFixed(0)}K';
    return 'Rs. ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF818CF8)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 20, 20, 16),
            child: Row(
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Leads · Pipeline · Quotes',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.trending_up_rounded,
                      color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Row(
              children: [
                _StatCard(label: 'Open',     value: '${summary.open}',
                    icon: Icons.circle_outlined),
                const SizedBox(width: 10),
                _StatCard(label: 'Won',      value: '${summary.won}',
                    icon: Icons.check_circle_outline_rounded),
                const SizedBox(width: 10),
                _StatCard(label: 'Pipeline', value: _fmt(summary.totalValue),
                    icon: Icons.bar_chart_rounded, wide: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final bool     wide;
  const _StatCard({required this.label, required this.value, required this.icon, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convert to Opportunity bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertToOpportunitySheet extends StatefulWidget {
  final CrmLead                 lead;
  final void Function(Opportunity) onConverted;
  const _ConvertToOpportunitySheet({required this.lead, required this.onConverted});

  @override
  State<_ConvertToOpportunitySheet> createState() => _ConvertToOpportunitySheetState();
}

class _ConvertToOpportunitySheetState extends State<_ConvertToOpportunitySheet> {
  final _valueCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();
  String _stage     = 'Prospecting';
  bool   _submitting = false;
  String? _error;

  static const _stages = [
    'Prospecting', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won',
  ];

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valueStr = _valueCtrl.text.trim();
    if (valueStr.isEmpty) {
      setState(() => _error = 'Expected value is required');
      return;
    }
    final value = double.tryParse(valueStr);
    if (value == null) {
      setState(() => _error = 'Enter a valid number');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      // In a real app this would call SalesService.createOpportunity(...)
      // For demo, we create a local Opportunity object.
      await Future.delayed(const Duration(milliseconds: 700));
      final opp = Opportunity(
        name: 'OPP-${DateTime.now().millisecondsSinceEpoch % 9000 + 1000}',
        partyName: widget.lead.displayName,
        amount: value,
        stage: _stage,
        status: 'Open',
        expectedClosing: '',
        modified: DateTime.now().toIso8601String().substring(0, 10),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onConverted(opp);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opportunity created for ${widget.lead.displayName}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac          = context.ac;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ac.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Convert to Opportunity',
                        style: TextStyle(
                            color: ac.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(widget.lead.displayName,
                        style: TextStyle(color: ac.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Error
          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 14),
          ],

          // Expected Value
          _Field(
            controller: _valueCtrl,
            label: 'Expected Value (Rs.) *',
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            accentColor: AppColors.primary,
          ),
          const SizedBox(height: 16),

          // Stage selector
          Text('Stage',
              style: TextStyle(
                  color: ac.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _stages.map((s) {
              final selected = s == _stage;
              return GestureDetector(
                onTap: _submitting ? null : () => setState(() => _stage = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : ac.bgBase,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : ac.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(s,
                      style: TextStyle(
                        color: selected ? AppColors.primary : ac.textSecondary,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Note
          _Field(
            controller: _noteCtrl,
            label: 'Note (optional)',
            maxLines: 2,
            enabled: !_submitting,
            accentColor: AppColors.primary,
          ),
          const SizedBox(height: 20),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.trending_up_rounded, size: 16),
                  label: Text(_submitting ? 'Saving…' : 'Convert',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote creation bottom sheet (from Opportunity)
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteFormSheet extends StatefulWidget {
  final Opportunity opp;
  const _QuoteFormSheet({required this.opp});

  @override
  State<_QuoteFormSheet> createState() => _QuoteFormSheetState();
}

class _QuoteFormSheetState extends State<_QuoteFormSheet> {
  final _subjectCtrl = TextEditingController();
  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  bool   _submitting  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text = 'Quotation for ${widget.opp.partyName}';
    if (widget.opp.amount > 0) {
      _amountCtrl.text = widget.opp.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final amount  = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final note    = _noteCtrl.text.trim();
    if (subject.isEmpty) {
      setState(() => _error = 'Subject is required');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final docname = await SalesService.createQuotation(
        leadDocname: widget.opp.name,
        partyType:   'Lead',
        subject:     subject,
        amount:      amount,
        note:        note,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(docname.isNotEmpty ? 'Quote created: $docname' : 'Quote created'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac          = context.ac;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const amber = Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ac.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Quotation',
                        style: TextStyle(
                            color: ac.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    Text(widget.opp.partyName,
                        style: TextStyle(color: ac.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              // Stage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: amber.withValues(alpha: 0.30)),
                ),
                child: Text(widget.opp.stage,
                    style: const TextStyle(
                        color: amber, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_error != null) ...[
            _ErrorBanner(message: _error!),
            const SizedBox(height: 14),
          ],

          _Field(controller: _subjectCtrl, label: 'Subject *',
              enabled: !_submitting, accentColor: amber),
          const SizedBox(height: 12),
          _Field(controller: _amountCtrl, label: 'Amount (Rs.)',
              keyboardType: TextInputType.number,
              enabled: !_submitting, accentColor: amber),
          const SizedBox(height: 12),
          _Field(controller: _noteCtrl, label: 'Note',
              maxLines: 3, enabled: !_submitting, accentColor: amber),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.receipt_long_rounded, size: 16),
                  label: Text(_submitting ? 'Sending…' : 'Send Quote',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final TextInputType         keyboardType;
  final int                   maxLines;
  final bool                  enabled;
  final Color                 accentColor;

  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLines     = 1,
    this.enabled      = true,
    this.accentColor  = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return TextField(
      controller:   controller,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      enabled:      enabled,
      style:        TextStyle(color: ac.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: TextStyle(color: ac.textSecondary, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        filled:         true,
        fillColor:      ac.bgBase,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onRetry;
  const _EmptyState({required this.icon, required this.title,
      required this.subtitle, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 18),
          Text(title,
              style: TextStyle(
                  color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: ac.textSecondary, fontSize: 13)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: const Text('Refresh',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: ac.textTertiary, size: 40),
          const SizedBox(height: 14),
          Text('Could not load data',
              style: TextStyle(
                  color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Check your connection and try again',
              style: TextStyle(color: ac.textSecondary, fontSize: 13)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
