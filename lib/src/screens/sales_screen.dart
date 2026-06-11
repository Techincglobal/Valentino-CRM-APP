import 'dart:async';
import 'package:flutter/material.dart';
import '../services/caller_service.dart';
import '../services/sales_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public interface — lets MainShell request a data refresh without exposing
// the private state class across files.
// ─────────────────────────────────────────────────────────────────────────────

abstract class SalesScreenController {
  void refreshPipeline();
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens
// ─────────────────────────────────────────────────────────────────────────────

const _amber  = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

// ─────────────────────────────────────────────────────────────────────────────
// Quote line-item model
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteItem {
  final itemCodeCtrl    = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final qtyCtrl         = TextEditingController(text: '1');
  final rateCtrl        = TextEditingController();

  double get amount {
    final q = double.tryParse(qtyCtrl.text.trim()) ?? 0;
    final r = double.tryParse(rateCtrl.text.trim()) ?? 0;
    return q * r;
  }

  Map<String, dynamic> toJson() => {
    'item_code':   itemCodeCtrl.text.trim(),
    'item_name':   descriptionCtrl.text.trim().isNotEmpty
                       ? descriptionCtrl.text.trim()
                       : itemCodeCtrl.text.trim(),
    'qty':         double.tryParse(qtyCtrl.text.trim())  ?? 1.0,
    'rate':        double.tryParse(rateCtrl.text.trim()) ?? 0.0,
  };

  void dispose() {
    itemCodeCtrl.dispose();
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// World currencies (ISO 4217)
// ─────────────────────────────────────────────────────────────────────────────

const _currencies = <(String, String)>[
  ('LKR', 'Sri Lankan Rupee'),
  ('USD', 'US Dollar'),
  ('EUR', 'Euro'),
  ('GBP', 'British Pound'),
  ('AUD', 'Australian Dollar'),
  ('CAD', 'Canadian Dollar'),
  ('CHF', 'Swiss Franc'),
  ('CNY', 'Chinese Yuan'),
  ('INR', 'Indian Rupee'),
  ('JPY', 'Japanese Yen'),
  ('SGD', 'Singapore Dollar'),
  ('AED', 'UAE Dirham'),
  ('SAR', 'Saudi Riyal'),
  ('MYR', 'Malaysian Ringgit'),
  ('THB', 'Thai Baht'),
  ('HKD', 'Hong Kong Dollar'),
  ('NZD', 'New Zealand Dollar'),
  ('NOK', 'Norwegian Krone'),
  ('SEK', 'Swedish Krona'),
  ('DKK', 'Danish Krone'),
  ('ZAR', 'South African Rand'),
  ('NGN', 'Nigerian Naira'),
  ('KES', 'Kenyan Shilling'),
  ('BDT', 'Bangladeshi Taka'),
  ('PKR', 'Pakistani Rupee'),
  ('IDR', 'Indonesian Rupiah'),
  ('PHP', 'Philippine Peso'),
  ('VND', 'Vietnamese Dong'),
  ('BRL', 'Brazilian Real'),
  ('MXN', 'Mexican Peso'),
  ('KRW', 'South Korean Won'),
  ('TWD', 'Taiwan Dollar'),
  ('RUB', 'Russian Ruble'),
  ('TRY', 'Turkish Lira'),
  ('EGP', 'Egyptian Pound'),
  ('QAR', 'Qatari Riyal'),
  ('KWD', 'Kuwaiti Dinar'),
  ('BHD', 'Bahraini Dinar'),
  ('OMR', 'Omani Rial'),
  ('MUR', 'Mauritian Rupee'),
];

// ─────────────────────────────────────────────────────────────────────────────
// Lead status & Opportunity stage options
// ─────────────────────────────────────────────────────────────────────────────

const _leadStatuses = ['Lead', 'Contacted', 'Interested', 'Converted', 'Do Not Contact'];
const _oppStages    = ['Prospecting', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost'];

// ─────────────────────────────────────────────────────────────────────────────
// SalesScreen
// ─────────────────────────────────────────────────────────────────────────────

class SalesScreen extends StatefulWidget {
  final VoidCallback? onGoToQuotes;
  const SalesScreen({super.key, this.onGoToQuotes});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin
    implements SalesScreenController {
  @override
  bool get wantKeepAlive => true;

  @override
  void refreshPipeline() => _loadFromApi();

  late final TabController _tab;

  // TEMP_DISABLE: mock fallback — restore List.of(_mockOpps/Leads) for dev
  List<Opportunity> _opps   = const [];
  List<CrmLead>     _leads  = const [];
  PipelineSummary   _summary = const PipelineSummary(total: 0, open: 0, won: 0, totalValue: 0);
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadFromApi();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadFromApi() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SalesService.getOpportunities(),
        SalesService.getLeads(),
      ]);
      if (!mounted) return;
      final opps  = results[0] as List<Opportunity>;
      final leads = results[1] as List<CrmLead>;
      setState(() {
        _opps    = opps;
        _leads   = leads;
        _summary = SalesService.summarise(_opps);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showCreateLeadForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _CreateLeadSheet(onCreated: _loadFromApi),
    );
  }

  void _showCreateOpportunityForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _CreateOppSheet(onCreated: (opp) {
        setState(() {
          _opps = [opp, ..._opps.where((o) => o.name != opp.name)];
          _summary = SalesService.summarise(_opps);
        });
        _tab.animateTo(1);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _loadFromApi();
        });
      }),
    );
  }

  void _showConvertForm(CrmLead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ConvertSheet(
        lead: lead,
        onConverted: (opp) {
          setState(() {
            _opps = [opp, ..._opps.where((o) => o.name != opp.name)];
            final idx = _leads.indexWhere((l) => l.name == lead.name);
            if (idx >= 0) {
              _leads[idx] = CrmLead(
                name: lead.name, displayName: lead.displayName,
                email: lead.email, mobile: lead.mobile,
                status: 'Converted', modified: lead.modified,
              );
            }
            _summary = SalesService.summarise(_opps);
          });
          _tab.animateTo(1);
          // Delay the refresh so Frappe has time to commit the new record
          // before we fetch the list — avoids the race that wipes the optimistic insert.
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _loadFromApi();
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
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _QuoteSheet(opp: opp, onGoToQuotes: widget.onGoToQuotes),
    );
  }

  Future<void> _updateLeadStatus(CrmLead lead, String status) async {
    try {
      await SalesServiceOps.updateLeadStatus(lead.name, status);
      _loadFromApi();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update status: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  Future<void> _updateOppStage(Opportunity opp, String stage) async {
    // Optimistic update
    setState(() {
      final idx = _opps.indexWhere((o) => o.name == opp.name);
      if (idx >= 0) {
        _opps[idx] = Opportunity(
          name: opp.name, partyName: opp.partyName,
          partyDocname: opp.partyDocname, partyType: opp.partyType,
          amount: opp.amount, stage: stage,
          status: opp.status, expectedClosing: opp.expectedClosing,
          modified: opp.modified,
        );
        _summary = SalesService.summarise(_opps);
      }
    });
    try {
      await SalesServiceOps.updateOpportunityStage(opp.name, stage);
    } catch (e) {
      _loadFromApi(); // roll back on failure
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to update stage: $e'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ac = context.ac;
    return Scaffold(
      backgroundColor: ac.bgBase,
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, _) {
          if (_tab.index == 0) {
            return FloatingActionButton.extended(
              onPressed: _showCreateLeadForm,
              backgroundColor: _indigo,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              label: const Text('New Lead',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            );
          }
          if (_tab.index == 1) {
            return FloatingActionButton.extended(
              onPressed: _showCreateOpportunityForm,
              backgroundColor: const Color(0xFF8B5CF6),
              icon: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 18),
              label: const Text('New Opportunity',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          SliverToBoxAdapter(child: _Header(summary: _summary)),
          SliverToBoxAdapter(child: _GlassTabBar(controller: _tab, leads: _leads.length, opps: _opps.length)),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _LeadsTab(
              leads: _leads, loading: _loading, onRetry: _loadFromApi,
              onConvert: _showConvertForm, onStatusUpdate: _updateLeadStatus,
            ),
            _OppsTab(
              opps: _opps, loading: _loading, onRetry: _loadFromApi,
              onQuote: _showQuoteForm, onStageUpdate: _updateOppStage,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — always dark gradient
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final PipelineSummary summary;
  const _Header({required this.summary});

  String _fmt(double v) {
    if (v >= 10000000) return 'Rs.${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return 'Rs.${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return 'Rs.${(v / 1000).toStringAsFixed(0)}K';
    return 'Rs.${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final top    = MediaQuery.of(context).padding.top;
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF0D1240), const Color(0xFF0A0F1E), const Color(0xFF110D2E)]
              : [const Color(0xFF3730A3), const Color(0xFF4F46E5), const Color(0xFF6366F1)],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(22, top + 22, 22, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                        ),
                        child: const Text('PIPELINE',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
                      ),
                      const SizedBox(height: 8),
                      const Text('Pipeline',
                          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.1)),
                      const SizedBox(height: 3),
                      Text('Leads · Opportunities',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.60), fontSize: 13)),
                    ],
                  ),
                ),
                _GlassIconBadge(icon: Icons.bar_chart_rounded, color: _indigo),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Row(children: [
              _GlassStatCard(label: 'Open',     value: '${summary.open}',         icon: Icons.radio_button_checked_rounded, color: const Color(0xFF818CF8)),
              const SizedBox(width: 10),
              _GlassStatCard(label: 'Won',      value: '${summary.won}',          icon: Icons.check_circle_rounded,         color: const Color(0xFF6EE7B7)),
              const SizedBox(width: 10),
              _GlassStatCard(label: 'Pipeline', value: _fmt(summary.totalValue),  icon: Icons.trending_up_rounded,          color: const Color(0xFFFCD34D), wide: true),
            ]),
          ),
        ],
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Color color; final bool wide;
  const _GlassStatCard({required this.label, required this.value, required this.icon, required this.color, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  final IconData icon; final Color color;
  const _GlassIconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass tab bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller; final int leads; final int opps;
  const _GlassTabBar({required this.controller, required this.leads, required this.opps});

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      color: ac.bgBase,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : ac.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.09) : ac.border),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: _indigo.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 3))],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(3),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: ac.textSecondary,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Leads'), const SizedBox(width: 6), _GlassBadge(leads, isDark: isDark),
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Opportunities'), const SizedBox(width: 6), _GlassBadge(opps, isDark: isDark),
            ])),
          ],
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final int count; final bool isDark;
  const _GlassBadge(this.count, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leads tab
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  final List<CrmLead>                            leads;
  final bool                                     loading;
  final VoidCallback                             onRetry;
  final void Function(CrmLead)                   onConvert;
  final void Function(CrmLead, String)           onStatusUpdate;
  const _LeadsTab({
    required this.leads, required this.loading, required this.onRetry,
    required this.onConvert, required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && leads.isEmpty) return const _LoadingState();
    if (leads.isEmpty) return _EmptyState(icon: Icons.person_add_outlined, title: 'No leads yet', subtitle: 'Leads created during calls will appear here', onRetry: onRetry);
    return RefreshIndicator(
      color: _indigo,
      backgroundColor: context.ac.bgCard,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: leads.length,
        itemBuilder: (_, i) => _LeadCard(lead: leads[i], onConvert: onConvert, onStatusUpdate: (s) => onStatusUpdate(leads[i], s)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead card
// ─────────────────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final CrmLead               lead;
  final void Function(CrmLead) onConvert;
  final void Function(String)  onStatusUpdate;
  const _LeadCard({required this.lead, required this.onConvert, required this.onStatusUpdate});

  static const _statusColors = {
    'Lead':           Color(0xFF8B5CF6),
    'Contacted':      Color(0xFF60A5FA),
    'Interested':     Color(0xFF10B981),
    'Converted':      Color(0xFF059669),
    'Do Not Contact': Color(0xFFEF4444),
  };
  Color get _color => _statusColors[lead.status] ?? const Color(0xFF8B5CF6);

  void _pickStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _QuickPickSheet(
        title: 'Update Lead Status',
        options: _leadStatuses,
        current: lead.status,
        colorMap: _statusColors,
        onPick: onStatusUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (lead.status == 'Converted') return _buildCompact(context);
    return _buildFull(context);
  }

  // Slim "done" row — no actions, visually archived.
  Widget _buildCompact(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF059669).withValues(alpha: 0.05)
            : const Color(0xFF059669).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.18)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Center(
            child: Text(lead.initials,
                style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(lead.displayName,
            style: TextStyle(color: ac.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF059669).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.22)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 11),
            SizedBox(width: 4),
            Text('Converted', style: TextStyle(color: Color(0xFF059669), fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildFull(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final color  = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? null : ac.bgCard,
        gradient: isDark ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF1A2235), const Color(0xFF0D1526)]) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Container(height: 1, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: isDark ? 0.12 : 0.40), Colors.transparent]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(children: [
            Row(children: [
              _GlassAvatar(initials: lead.initials, color: color),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lead.displayName,
                    style: TextStyle(color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (lead.mobile.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(lead.mobile, style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                ],
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickStatus(context),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _GlassChip(label: lead.status.isEmpty ? 'Lead' : lead.status, color: color),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, color: color.withValues(alpha: 0.55), size: 11),
                  ]),
                ),
              ])),
            ]),
            const SizedBox(height: 12),
            _GlassCTAButton(icon: Icons.trending_up_rounded, label: 'Convert to Opportunity', color: _indigo, onTap: () => onConvert(lead)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunities tab
// ─────────────────────────────────────────────────────────────────────────────

class _OppsTab extends StatelessWidget {
  final List<Opportunity>                        opps;
  final bool                                     loading;
  final VoidCallback                             onRetry;
  final void Function(Opportunity)               onQuote;
  final void Function(Opportunity, String)       onStageUpdate;
  const _OppsTab({
    required this.opps, required this.loading, required this.onRetry,
    required this.onQuote, required this.onStageUpdate,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && opps.isEmpty) return const _LoadingState();
    if (opps.isEmpty) return _EmptyState(icon: Icons.trending_up_rounded, title: 'No opportunities yet', subtitle: 'Convert a lead to create your first opportunity', onRetry: onRetry);
    return RefreshIndicator(
      color: _amber,
      backgroundColor: context.ac.bgCard,
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: opps.length,
        itemBuilder: (_, i) => _OppCard(opp: opps[i], onQuote: onQuote, onStageUpdate: (s) => onStageUpdate(opps[i], s)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunity card
// ─────────────────────────────────────────────────────────────────────────────

class _OppCard extends StatelessWidget {
  final Opportunity                opp;
  final void Function(Opportunity) onQuote;
  final void Function(String)      onStageUpdate;
  const _OppCard({required this.opp, required this.onQuote, required this.onStageUpdate});

  static const _stageColors = {
    'Prospecting':   Color(0xFF60A5FA),
    'Qualification': Color(0xFF8B5CF6),
    'Proposal':      Color(0xFFA78BFA),
    'Negotiation':   Color(0xFFF59E0B),
    'Closed Won':    Color(0xFF10B981),
    'Closed Lost':   Color(0xFFEF4444),
  };
  Color get _color => _stageColors[opp.stage] ?? const Color(0xFF8B5CF6);

  void _pickStage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _QuickPickSheet(
        title: 'Update Stage',
        options: _oppStages,
        current: opp.stage,
        colorMap: _stageColors,
        onPick: onStageUpdate,
      ),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    if (v >= 10000000) return 'Rs.${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return 'Rs.${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return 'Rs.${(v / 1000).toStringAsFixed(0)}K';
    return 'Rs.${v.toStringAsFixed(0)}';
  }

  String get _initials {
    final p = opp.partyName.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    if (p.length == 1) return p[0][0].toUpperCase();
    return '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final color  = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? null : ac.bgCard,
        gradient: isDark ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF1A2235), const Color(0xFF0D1526)]) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        Container(height: 1, decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withValues(alpha: isDark ? 0.12 : 0.40), Colors.transparent]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(children: [
            Row(children: [
              _GlassAvatar(initials: _initials, color: color),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(opp.partyName,
                    style: TextStyle(color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  // Tappable stage chip
                  GestureDetector(
                    onTap: () => _pickStage(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _GlassChip(label: opp.stage.isEmpty ? 'No Stage' : opp.stage, color: color),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, color: color.withValues(alpha: 0.55), size: 11),
                    ]),
                  ),
                  const Spacer(),
                  Text(_fmt(opp.amount), style: const TextStyle(color: _amber, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                ]),
                if (opp.expectedClosing.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 11, color: ac.textTertiary),
                    const SizedBox(width: 4),
                    Text(opp.expectedClosing, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                  ]),
                ],
              ])),
            ]),
            const SizedBox(height: 12),
            _GlassCTAButton(icon: Icons.receipt_long_rounded, label: 'Create Quote', color: _amber, onTap: () => onQuote(opp)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-pick bottom sheet (status / stage selector)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickPickSheet extends StatelessWidget {
  final String                           title;
  final List<String>                     options;
  final String                           current;
  final Map<String, Color>               colorMap;
  final void Function(String)            onPick;
  const _QuickPickSheet({
    required this.title, required this.options, required this.current,
    required this.colorMap, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14), width: 36, height: 4,
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.18) : ac.textMuted, borderRadius: BorderRadius.circular(2)),
        )),
        Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((opt) {
          final sel   = opt == current;
          final color = colorMap[opt] ?? _indigo;
          return GestureDetector(
            onTap: () { Navigator.pop(context); onPick(opt); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: sel ? LinearGradient(colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.14)]) : null,
                color: sel ? null : ac.bgInput,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? color.withValues(alpha: 0.55) : ac.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (sel) ...[
                  Icon(Icons.check_rounded, color: color, size: 12),
                  const SizedBox(width: 5),
                ],
                Text(opt, style: TextStyle(
                  color: sel ? color : ac.textSecondary,
                  fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                )),
              ]),
            ),
          );
        }).toList()),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convert to Opportunity sheet — wired to real API
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertSheet extends StatefulWidget {
  final CrmLead       lead;
  final void Function(Opportunity) onConverted;
  const _ConvertSheet({required this.lead, required this.onConverted});

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  final _valueCtrl   = TextEditingController();
  final _closingCtrl = TextEditingController();
  final _noteCtrl    = TextEditingController();
  String  _stage      = 'Prospecting';
  bool    _busy       = false;
  String? _error;
  String? _valueError;

  @override
  void initState() {
    super.initState();
    // Default closing date = 30 days from today
    final closing = DateTime.now().add(const Duration(days: 30));
    _closingCtrl.text =
        '${closing.year}-${closing.month.toString().padLeft(2, '0')}-${closing.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() { _valueCtrl.dispose(); _closingCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_closingCtrl.text) ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: _indigo, surface: Color(0xFF1A2235)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _closingCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    setState(() { _valueError = null; _error = null; });
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null || value < 0) {
      setState(() => _valueError = 'Enter a valid positive number');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final opp = await SalesServiceOps.createOpportunity(
        leadDocname: widget.lead.name,
        partyName:   widget.lead.displayName,
        amount:      value,
        stage:       _stage,
        closingDate: _closingCtrl.text.trim(),
        note:        _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onConverted(opp);
      ScaffoldMessenger.of(context).showSnackBar(
        _successSnack('Opportunity created for ${widget.lead.displayName}'),
      );
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final ac    = context.ac;
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            _SheetHeader(icon: Icons.trending_up_rounded, color: _indigo, title: 'Convert to Opportunity', subtitle: widget.lead.displayName),
            const SizedBox(height: 20),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 12)],
            _GlassField(
              controller: _valueCtrl, label: 'Expected Value *',
              keyboardType: TextInputType.number, enabled: !_busy,
              errorText: _valueError, onChanged: () => setState(() => _valueError = null),
            ),
            const SizedBox(height: 12),
            // Closing date picker
            GestureDetector(
              onTap: _busy ? null : _pickDate,
              child: AbsorbPointer(
                child: _GlassField(
                  controller: _closingCtrl,
                  label: 'Expected Closing Date',
                  enabled: !_busy,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Stage', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _oppStages.map((s) {
              final sel = s == _stage;
              return GestureDetector(
                onTap: _busy ? null : () => setState(() => _stage = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(colors: [_indigo.withValues(alpha: 0.30), _indigo.withValues(alpha: 0.14)]) : null,
                    color: sel ? null : ac.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _indigo.withValues(alpha: 0.55) : ac.border),
                  ),
                  child: Text(s, style: TextStyle(
                    color: sel ? Colors.white : ac.textSecondary,
                    fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                  )),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            _GlassField(controller: _noteCtrl, label: 'Note', maxLines: 2, enabled: !_busy),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _GlassOutlineBtn(label: 'Cancel', onTap: _busy ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _GlassFillBtn(label: _busy ? 'Creating…' : 'Convert', icon: Icons.trending_up_rounded, color: _indigo, loading: _busy, onTap: _busy ? null : _submit)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote sheet — with item search + default currency from Frappe
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteSheet extends StatefulWidget {
  final Opportunity  opp;
  final VoidCallback? onGoToQuotes;
  const _QuoteSheet({required this.opp, this.onGoToQuotes});

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _subjectCtrl  = TextEditingController();
  final _noteCtrl     = TextEditingController();
  final _validTillCtrl = TextEditingController();
  final _items        = <_QuoteItem>[];
  String  _currency         = 'LKR';
  String  _sellingPriceList = '';
  String  _partyEmail       = '';
  String  _partyPhone       = '';
  bool    _loadingDefaults  = true;
  bool    _busy             = false;
  String? _error;
  String? _subjectError;

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text = 'Quotation for ${widget.opp.partyName}';
    // Default valid till: 30 days from today
    final due = DateTime.now().add(const Duration(days: 30));
    _validTillCtrl.text =
        '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
    _items.add(_QuoteItem());
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final partyDocname = widget.opp.partyDocname.isNotEmpty
        ? widget.opp.partyDocname
        : widget.opp.name;
    final defaults = await SalesServiceOps.getQuotationDefaults(
      leadDocname: partyDocname,
      partyType:   widget.opp.partyType,
    );
    if (!mounted) return;
    setState(() {
      if (defaults.currency.isNotEmpty) _currency = defaults.currency;
      _sellingPriceList = defaults.sellingPriceList;
      _partyEmail       = defaults.partyEmail;
      _partyPhone       = defaults.partyPhone;
      if (defaults.termsContent.isNotEmpty && _noteCtrl.text.isEmpty) {
        _noteCtrl.text = defaults.termsContent;
      }
      _loadingDefaults = false;
    });
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _noteCtrl.dispose();
    _validTillCtrl.dispose();
    for (final item in _items) { item.dispose(); }
    super.dispose();
  }

  void _addItem() => setState(() => _items.add(_QuoteItem()));

  void _removeItem(int i) {
    setState(() { _items[i].dispose(); _items.removeAt(i); });
  }

  double get _grandTotal => _items.fold(0, (sum, item) => sum + item.amount);

  String _fmtAmt(double v) {
    if (v == 0) return '—';
    return '$_currency ${v.toStringAsFixed(2)}';
  }

  Future<void> _submit() async {
    final subject    = _subjectCtrl.text.trim();
    if (subject.isEmpty) { setState(() => _subjectError = 'Subject is required'); return; }
    final validItems = _items.where((i) => i.itemCodeCtrl.text.trim().isNotEmpty).toList();
    setState(() { _busy = true; _error = null; });
    try {
      final docname = await SalesService.createQuotation(
        leadDocname: widget.opp.partyDocname.isNotEmpty
            ? widget.opp.partyDocname
            : widget.opp.name,
        partyType:        widget.opp.partyType,
        subject:          subject,
        amount:           _grandTotal,
        note:             _noteCtrl.text.trim(),
        currency:         _currency,
        items:            validItems.map((e) => e.toJson()).toList(),
        sellingPriceList: _sellingPriceList,
        validTill:        _validTillCtrl.text.trim(),
      );
      if (!mounted) return;
      final goToQuotes = widget.onGoToQuotes;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(docname.isNotEmpty ? 'Quote created: $docname' : 'Quote created'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 4),
        action: goToQuotes != null
            ? SnackBarAction(label: 'View Quotes', textColor: Colors.white, onPressed: goToQuotes)
            : null,
      ));
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return _GlassSheet(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            Row(children: [
              Expanded(child: _SheetHeader(icon: Icons.receipt_long_rounded, color: _amber, title: 'Create Quotation', subtitle: widget.opp.partyName)),
              _GlassChip(label: widget.opp.stage, color: _amber),
            ]),
            const SizedBox(height: 14),
            // Recipient card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _amber.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('TO', style: TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loadingDefaults
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _amber))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.opp.partyName,
                                style: TextStyle(color: ac.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              if (_partyPhone.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Row(children: [
                                  Icon(Icons.phone_rounded, size: 11, color: _amber.withValues(alpha: 0.70)),
                                  const SizedBox(width: 4),
                                  Text(_partyPhone, style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                                ]),
                              ],
                              if (_partyEmail.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  Icon(Icons.email_outlined, size: 11, color: _amber.withValues(alpha: 0.70)),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(_partyEmail, style: TextStyle(color: ac.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ]),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 10)],
            _GlassField(
              controller: _subjectCtrl, label: 'Subject *', enabled: !_busy,
              errorText: _subjectError, onChanged: () => setState(() => _subjectError = null),
            ),
            const SizedBox(height: 12),
            // Currency picker — shows spinner while defaults are loading
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
              ),
              child: Row(children: [
                Icon(Icons.currency_exchange_rounded, color: _amber, size: 16),
                const SizedBox(width: 8),
                Text('Currency', style: TextStyle(color: ac.textSecondary, fontSize: 13)),
                const Spacer(),
                if (_loadingDefaults)
                  const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _amber))
                else
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _currencies.any((c) => c.$1 == _currency) ? _currency : 'LKR',
                      isDense: true,
                      style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      dropdownColor: isDark ? const Color(0xFF1A2235) : ac.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: ac.textSecondary, size: 18),
                      onChanged: _busy ? null : (v) => setState(() => _currency = v!),
                      items: _currencies.map((c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text('${c.$1} — ${c.$2}', style: TextStyle(color: ac.textPrimary, fontSize: 13)),
                      )).toList(),
                    ),
                  ),
              ]),
            ),
            // Show selling price list badge when available
            if (!_loadingDefaults && _sellingPriceList.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const SizedBox(width: 2),
                Icon(Icons.price_check_rounded, size: 11, color: ac.textTertiary),
                const SizedBox(width: 4),
                Text('Price list: $_sellingPriceList',
                    style: TextStyle(color: ac.textTertiary, fontSize: 11)),
              ]),
            ],
            const SizedBox(height: 14),
            // Line items header
            Row(children: [
              Text('LINE ITEMS', style: TextStyle(color: ac.textSecondary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
              const Spacer(),
              GestureDetector(
                onTap: _busy ? null : _addItem,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _indigo.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _indigo.withValues(alpha: 0.28)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded, color: _indigo, size: 13),
                    const SizedBox(width: 4),
                    const Text('Add Item', style: TextStyle(color: _indigo, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No items added yet. Tap "Add Item" to start.',
                    style: TextStyle(color: ac.textTertiary, fontSize: 12), textAlign: TextAlign.center),
              ),
            ..._items.asMap().entries.map((entry) => _ItemCard(
              no: entry.key + 1,
              item: entry.value,
              currency: _currency,
              priceList: _sellingPriceList,
              enabled: !_busy,
              onRemove: () => _removeItem(entry.key),
              onChanged: () => setState(() {}),
            )),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withValues(alpha: 0.22)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Grand Total', style: TextStyle(color: ac.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(_fmtAmt(_grandTotal), style: const TextStyle(color: _amber, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Valid Till date picker
            GestureDetector(
              onTap: _busy ? null : () async {
                final current = DateTime.tryParse(_validTillCtrl.text) ??
                    DateTime.now().add(const Duration(days: 30));
                final picked = await showDatePicker(
                  context: context,
                  initialDate: current,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: context.isDark
                          ? ColorScheme.dark(primary: _amber, surface: const Color(0xFF1A2235), onSurface: Colors.white)
                          : ColorScheme.light(primary: _amber, surface: Colors.white, onSurface: const Color(0xFF0F172A)),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _validTillCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: _amber),
                  const SizedBox(width: 10),
                  Text('Valid Till', style: TextStyle(color: ac.textSecondary, fontSize: 13)),
                  const Spacer(),
                  Text(
                    _validTillCtrl.text.isNotEmpty ? _validTillCtrl.text : 'Select date',
                    style: TextStyle(
                      color: _validTillCtrl.text.isNotEmpty ? ac.textPrimary : ac.textTertiary,
                      fontSize: 14, fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_rounded, size: 13, color: ac.textTertiary),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            _GlassField(controller: _noteCtrl, label: 'Terms & Notes', maxLines: 4, enabled: !_busy),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _GlassOutlineBtn(label: 'Cancel', onTap: _busy ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _GlassFillBtn(label: _busy ? 'Sending…' : 'Send Quote', icon: Icons.receipt_long_rounded, color: _amber, loading: _busy, onTap: _busy ? null : _submit)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item card (one line-item row) — with Frappe item search button
// ─────────────────────────────────────────────────────────────────────────────

class _ItemCard extends StatefulWidget {
  final int          no;
  final _QuoteItem   item;
  final String       currency;
  final String       priceList;
  final bool         enabled;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemCard({
    required this.no,
    required this.item,
    required this.currency,
    this.priceList = '',
    required this.enabled,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<_ItemCard> {
  List<FrappeItem> _suggestions  = [];
  bool             _searching    = false;
  Timer?           _debounce;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    widget.item.itemCodeCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    widget.item.itemCodeCtrl.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Short delay so a tap on a suggestion row registers before the dropdown closes
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _suggestions = []);
      });
    }
  }

  void _onTextChanged() {
    final q = widget.item.itemCodeCtrl.text.trim();
    _debounce?.cancel();
    if (q.isEmpty) {
      if (_suggestions.isNotEmpty || _searching) {
        setState(() { _suggestions = []; _searching = false; });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await SalesServiceOps.searchItems(
        q, limit: 8, priceList: widget.priceList,
      );
      if (!mounted) return;
      setState(() { _suggestions = results; _searching = false; });
    });
  }

  void _pick(FrappeItem picked) {
    // Temporarily remove listener so setting the text doesn't trigger another search
    widget.item.itemCodeCtrl.removeListener(_onTextChanged);
    widget.item.itemCodeCtrl.text = picked.itemCode;
    widget.item.itemCodeCtrl.addListener(_onTextChanged);
    widget.item.descriptionCtrl.text =
        picked.itemName.isNotEmpty ? picked.itemName : picked.itemCode;
    if (picked.standardRate > 0) {
      widget.item.rateCtrl.text = picked.standardRate.toStringAsFixed(2);
    }
    setState(() { _suggestions = []; _searching = false; });
    widget.onChanged();
    _focusNode.unfocus();
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<FrappeItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ItemSearchSheet(priceList: widget.priceList),
    );
    if (picked != null) _pick(picked);
  }

  @override
  Widget build(BuildContext context) {
    final ac          = context.ac;
    final isDark      = context.isDark;
    final amt         = widget.item.amount;
    final showDrop    = _searching || _suggestions.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : ac.bgCardAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Row 1: badge + item-code field + search button + delete ──
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(color: _indigo.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Center(child: Text('${widget.no}',
                style: const TextStyle(color: _indigo, fontSize: 10, fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TinyField(
              ctrl:      widget.item.itemCodeCtrl,
              hint:      'Item code or name…',
              focusNode: _focusNode,
              enabled:   widget.enabled,
              onChanged: widget.onChanged,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.enabled ? () => _openSearchSheet(context) : null,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _indigo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.search_rounded, color: _indigo, size: 13),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.enabled ? widget.onRemove : null,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 13),
            ),
          ),
        ]),

        // ── Inline autocomplete dropdown ──
        if (showDrop) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : ac.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : _indigo.withValues(alpha: 0.20),
              ),
              boxShadow: [
                BoxShadow(
                  color:      Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                  blurRadius: 14,
                  offset:     const Offset(0, 4),
                ),
              ],
            ),
            child: _searching && _suggestions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                    child: Row(children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: _indigo),
                      ),
                      SizedBox(width: 8),
                      Text('Searching…',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ]),
                  )
                : Column(
                    children: _suggestions.asMap().entries.map((e) {
                      final it     = e.value;
                      final isLast = e.key == _suggestions.length - 1;
                      final label  = it.itemName.isNotEmpty ? it.itemName : it.itemCode;
                      return GestureDetector(
                        onTap: () => _pick(it),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            border: isLast
                                ? null
                                : Border(bottom: BorderSide(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : ac.border)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.itemCode,
                                      style: TextStyle(
                                          color: ac.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  if (label != it.itemCode)
                                    Text(label,
                                        style: TextStyle(
                                            color: ac.textSecondary, fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            if (it.standardRate > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(it.standardRate.toStringAsFixed(2),
                                    style: const TextStyle(
                                        color: _amber,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],

        const SizedBox(height: 7),
        // ── Row 2: description ──
        _TinyField(ctrl: widget.item.descriptionCtrl, hint: 'Description', enabled: widget.enabled, onChanged: widget.onChanged),
        const SizedBox(height: 7),
        // ── Row 3: qty | rate | amount ──
        Row(children: [
          Expanded(child: _TinyField(ctrl: widget.item.qtyCtrl, hint: 'Qty', kbType: TextInputType.number, enabled: widget.enabled, onChanged: widget.onChanged, prefixText: 'Qty ')),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: _TinyField(ctrl: widget.item.rateCtrl, hint: 'Rate', kbType: TextInputType.number, enabled: widget.enabled, onChanged: widget.onChanged, prefixText: 'Rate ')),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: amt > 0 ? _amber.withValues(alpha: 0.10) : ac.bgInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: amt > 0 ? _amber.withValues(alpha: 0.25) : ac.border),
            ),
            child: Text(
              amt > 0 ? amt.toStringAsFixed(0) : '—',
              style: TextStyle(color: amt > 0 ? _amber : ac.textTertiary, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Item search bottom sheet — queries Frappe Item master
// ─────────────────────────────────────────────────────────────────────────────

class _ItemSearchSheet extends StatefulWidget {
  final String priceList;
  const _ItemSearchSheet({this.priceList = ''});

  @override
  State<_ItemSearchSheet> createState() => _ItemSearchSheetState();
}

class _ItemSearchSheetState extends State<_ItemSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<FrappeItem> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    final items = await SalesServiceOps.searchItems(q, priceList: widget.priceList);
    if (!mounted) return;
    setState(() { _results = items; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14), width: 36, height: 4,
          decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.18) : ac.textMuted, borderRadius: BorderRadius.circular(2)),
        )),
        Text('Select Item', style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _search,
          style: TextStyle(color: ac.textPrimary, fontSize: 14),
          cursorColor: _indigo,
          decoration: InputDecoration(
            hintText: 'Search items…',
            hintStyle: TextStyle(color: ac.textTertiary, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: ac.textSecondary, size: 18),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(color: _indigo, strokeWidth: 2),
          )
        else if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _searchCtrl.text.isEmpty ? 'No items in catalogue' : 'No items match "${_searchCtrl.text}"',
              style: TextStyle(color: ac.textSecondary, fontSize: 13),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (_, _) => Divider(color: ac.border, height: 1),
              itemBuilder: (_, i) {
                final item = _results[i];
                final label = item.itemName.isNotEmpty ? item.itemName : item.itemCode;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  title: Text(label,
                      style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: item.itemCode != label
                      ? Text(item.itemCode,
                            style: TextStyle(color: ac.textTertiary, fontSize: 11))
                      : null,
                  trailing: item.standardRate > 0
                      ? Text(item.standardRate.toStringAsFixed(2),
                            style: const TextStyle(color: _amber, fontWeight: FontWeight.w700, fontSize: 12))
                      : null,
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create Lead sheet — wired to CallerService.createLead → Frappe api.py
// ─────────────────────────────────────────────────────────────────────────────

class _CreateLeadSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateLeadSheet({required this.onCreated});

  @override
  State<_CreateLeadSheet> createState() => _CreateLeadSheetState();
}

class _CreateLeadSheetState extends State<_CreateLeadSheet> {
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _noteCtrl   = TextEditingController();
  bool    _busy       = false;
  String? _error;
  String? _nameError;
  String? _phoneError;
  String? _emailError;

  static final _emailRe = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _nameError = null; _phoneError = null; _emailError = null; _error = null; });

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Full name is required');
      return;
    }
    if (name.length < 2) {
      setState(() => _nameError = 'Name must be at least 2 characters');
      return;
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 10) {
        setState(() => _phoneError = 'Must have at least 10 digits');
        return;
      }
    }

    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) {
      if (!email.contains('@')) {
        setState(() => _emailError = 'Email must contain @');
        return;
      }
      if (!_emailRe.hasMatch(email)) {
        setState(() => _emailError = 'Enter a valid email (e.g. you@example.com)');
        return;
      }
    }

    setState(() { _busy = true; _error = null; });
    try {
      final result = await CallerService.createLead(
        firstName: name,
        email:     _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        mobile:    _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        note:      _noteCtrl.text.trim().isNotEmpty  ? _noteCtrl.text.trim()  : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      final leadName = result['lead_name'] as String? ?? '';
      final created  = result['created'] == true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(created
            ? 'Lead created: $leadName'
            : 'Lead already exists: $leadName'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    } catch (e) {
      setState(() {
        _busy  = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            _SheetHeader(
              icon: Icons.person_add_rounded,
              color: _indigo,
              title: 'New Lead',
              subtitle: 'Add a contact to your CRM',
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 12)],
            _GlassField(
              controller: _nameCtrl, label: 'Full Name *', enabled: !_busy,
              errorText: _nameError, onChanged: () => setState(() => _nameError = null),
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _phoneCtrl, label: 'Phone Number',
              keyboardType: TextInputType.phone, enabled: !_busy,
              errorText: _phoneError, onChanged: () => setState(() => _phoneError = null),
            ),
            const SizedBox(height: 12),
            _GlassField(
              controller: _emailCtrl, label: 'Email Address',
              keyboardType: TextInputType.emailAddress, enabled: !_busy,
              errorText: _emailError, onChanged: () => setState(() => _emailError = null),
            ),
            const SizedBox(height: 12),
            _GlassField(controller: _noteCtrl, label: 'Note', maxLines: 2, enabled: !_busy),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _GlassOutlineBtn(label: 'Cancel', onTap: _busy ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _GlassFillBtn(
                label:   _busy ? 'Creating…' : 'Create Lead',
                icon:    Icons.person_add_rounded,
                color:   _indigo,
                loading: _busy,
                onTap:   _busy ? null : _submit,
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared micro-components
// ─────────────────────────────────────────────────────────────────────────────

class _GlassAvatar extends StatelessWidget {
  final String initials; final Color color;
  const _GlassAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Center(child: Text(initials, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800))),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label; final Color color;
  const _GlassChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
    );
  }
}

class _GlassCTAButton extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _GlassCTAButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass sheet + shared sheet components
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.12) : ac.border)),
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        width: 36, height: 4,
        decoration: BoxDecoration(
          color: context.isDark ? Colors.white.withValues(alpha: 0.18) : context.ac.textMuted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon; final Color color; final String title; final String subtitle;
  const _SheetHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        Text(subtitle, style: TextStyle(color: ac.textSecondary, fontSize: 13)),
      ]),
    ]);
  }
}

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final int maxLines;
  final bool enabled;
  final String? errorText;
  final VoidCallback? onChanged;
  const _GlassField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac       = context.ac;
    final isDark   = context.isDark;
    final hasError = errorText != null;
    const red      = Color(0xFFEF4444);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged != null ? (_) => onChanged!() : null,
      style: TextStyle(color: ac.textPrimary, fontSize: 14),
      cursorColor: _indigo,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hasError ? red : ac.textSecondary, fontSize: 13),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: hasError ? red : (isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: hasError ? red : _indigo, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: red, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: red, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.05) : ac.border.withValues(alpha: 0.4))),
        errorText: errorText,
        errorStyle: const TextStyle(color: red, fontSize: 11, height: 1.3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
  }
}

class _GlassOutlineBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap;
  const _GlassOutlineBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.12) : ac.border),
        ),
        child: Center(child: Text(label, style: TextStyle(color: ac.textSecondary, fontSize: 14, fontWeight: FontWeight.w600))),
      ),
    );
  }
}

class _GlassFillBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final bool loading; final VoidCallback? onTap;
  const _GlassFillBtn({required this.label, required this.icon, required this.color, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: onTap != null
                ? [color, Color.lerp(color, Colors.black, 0.20)!]
                : [color.withValues(alpha: 0.35), color.withValues(alpha: 0.20)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: onTap != null ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))] : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
      ]),
    );
  }
}

class _TinyField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType kbType;
  final bool enabled;
  final VoidCallback onChanged;
  final String? prefixText;
  final FocusNode? focusNode;
  const _TinyField({required this.ctrl, required this.hint, this.kbType = TextInputType.text, required this.enabled, required this.onChanged, this.prefixText, this.focusNode});

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      keyboardType: kbType,
      enabled: enabled,
      onChanged: (_) => onChanged(),
      style: TextStyle(color: ac.textPrimary, fontSize: 12),
      cursorColor: _indigo,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        prefixStyle: TextStyle(color: ac.textTertiary, fontSize: 11),
        hintStyle: TextStyle(color: ac.textTertiary, fontSize: 12),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : ac.bgInput,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border)),
        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10)), borderSide: BorderSide(color: _indigo, width: 1.5)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / loading states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: _indigo, strokeWidth: 2));
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onRetry;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: [_indigo.withValues(alpha: 0.16), Colors.transparent]),
            shape: BoxShape.circle,
            border: Border.all(color: _indigo.withValues(alpha: 0.20)),
          ),
          child: Icon(icon, color: _indigo, size: 36),
        ),
        const SizedBox(height: 18),
        Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: ac.textSecondary, fontSize: 13)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _indigo.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _indigo.withValues(alpha: 0.30)),
            ),
            child: const Text('Refresh', style: TextStyle(color: _indigo, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

SnackBar _successSnack(String msg) => SnackBar(
  content: Text(msg),
  backgroundColor: const Color(0xFF10B981),
  behavior: SnackBarBehavior.floating,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
);

// ─────────────────────────────────────────────────────────────────────────────
// Create Opportunity sheet — searches leads by name and creates a new opp
// ─────────────────────────────────────────────────────────────────────────────

class _CreateOppSheet extends StatefulWidget {
  final void Function(Opportunity) onCreated;
  const _CreateOppSheet({required this.onCreated});

  @override
  State<_CreateOppSheet> createState() => _CreateOppSheetState();
}

class _CreateOppSheetState extends State<_CreateOppSheet> {
  final _searchCtrl  = TextEditingController();
  final _valueCtrl   = TextEditingController();
  final _closingCtrl = TextEditingController();
  final _noteCtrl    = TextEditingController();

  List<CrmLead> _suggestions = [];
  CrmLead?      _selected;
  bool          _searching = false;
  String        _stage     = 'Prospecting';
  bool          _busy      = false;
  String?       _error;
  String?       _valueError;
  String?       _leadError;

  @override
  void initState() {
    super.initState();
    final closing = DateTime.now().add(const Duration(days: 30));
    _closingCtrl.text =
        '${closing.year}-${closing.month.toString().padLeft(2, '0')}-${closing.day.toString().padLeft(2, '0')}';
    // Pre-load suggestions
    _searchLeads('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _valueCtrl.dispose();
    _closingCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchLeads(String q) async {
    setState(() => _searching = true);
    try {
      final all = await SalesService.getLeads();
      if (!mounted) return;
      final lower = q.toLowerCase();
      setState(() {
        _suggestions = q.isEmpty
            ? all.take(20).toList()
            : all.where((l) =>
                l.displayName.toLowerCase().contains(lower) ||
                l.mobile.contains(q) ||
                l.email.toLowerCase().contains(lower)).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_closingCtrl.text) ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF8B5CF6), surface: Color(0xFF1A2235)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _closingCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    setState(() { _leadError = null; _valueError = null; _error = null; });
    if (_selected == null) {
      setState(() => _leadError = 'Select a lead first');
      return;
    }
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null || value < 0) {
      setState(() => _valueError = 'Enter a valid positive number');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      final opp = await SalesServiceOps.createOpportunity(
        leadDocname: _selected!.name,
        partyName:   _selected!.displayName,
        amount:      value,
        stage:       _stage,
        closingDate: _closingCtrl.text.trim(),
        note:        _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated(opp);
      ScaffoldMessenger.of(context).showSnackBar(
        _successSnack('Opportunity created for ${_selected!.displayName}'),
      );
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset  = MediaQuery.of(context).viewInsets.bottom;
    final ac     = context.ac;
    const purple = Color(0xFF8B5CF6);
    return _GlassSheet(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 0, 22, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetHandle(),
            _SheetHeader(icon: Icons.trending_up_rounded, color: purple, title: 'New Opportunity', subtitle: 'Link to an existing lead'),
            const SizedBox(height: 20),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 12)],

            // Lead picker
            Text('Select Lead *', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            if (_selected != null)
              GestureDetector(
                onTap: () => setState(() { _selected = null; _searchCtrl.clear(); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: purple.withValues(alpha: 0.40)),
                  ),
                  child: Row(children: [
                    Icon(Icons.person_rounded, color: purple, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_selected!.displayName, style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600))),
                    Icon(Icons.close_rounded, color: ac.textSecondary, size: 16),
                  ]),
                ),
              )
            else ...[
              _GlassField(
                controller: _searchCtrl,
                label: 'Search lead name…',
                enabled: !_busy,
                errorText: _leadError,
                onChanged: () {
                  setState(() => _leadError = null);
                  _searchLeads(_searchCtrl.text.trim());
                },
              ),
              if (_searching)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: purple))))
              else if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 160),
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
                        onTap: () => setState(() { _selected = l; _suggestions = []; }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.displayName, style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                            if (l.mobile.isNotEmpty)
                              Text(l.mobile, style: TextStyle(color: ac.textSecondary, fontSize: 11)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 14),
            _GlassField(
              controller: _valueCtrl, label: 'Expected Value *',
              keyboardType: TextInputType.number, enabled: !_busy,
              errorText: _valueError, onChanged: () => setState(() => _valueError = null),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _busy ? null : _pickDate,
              child: AbsorbPointer(child: _GlassField(controller: _closingCtrl, label: 'Expected Closing Date', enabled: !_busy)),
            ),
            const SizedBox(height: 16),
            Text('Stage', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _oppStages.map((s) {
              final sel = s == _stage;
              return GestureDetector(
                onTap: _busy ? null : () => setState(() => _stage = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(colors: [purple.withValues(alpha: 0.30), purple.withValues(alpha: 0.14)]) : null,
                    color: sel ? null : ac.bgInput,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? purple.withValues(alpha: 0.55) : ac.border),
                  ),
                  child: Text(s, style: TextStyle(color: sel ? Colors.white : ac.textSecondary, fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            _GlassField(controller: _noteCtrl, label: 'Note', maxLines: 2, enabled: !_busy),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _GlassOutlineBtn(label: 'Cancel', onTap: _busy ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _GlassFillBtn(label: _busy ? 'Creating…' : 'Create Opportunity', icon: Icons.trending_up_rounded, color: purple, loading: _busy, onTap: _busy ? null : _submit)),
            ]),
          ],
        ),
      ),
    );
  }
}
