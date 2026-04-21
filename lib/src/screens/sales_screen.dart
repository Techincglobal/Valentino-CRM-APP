import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/sales_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — Liquid Glass palette
// ─────────────────────────────────────────────────────────────────────────────

const _amber  = Color(0xFFF59E0B);
const _indigo = Color(0xFF6366F1);

// ─────────────────────────────────────────────────────────────────────────────
// Mock data
// ─────────────────────────────────────────────────────────────────────────────

final _mockLeads = [
  CrmLead(name: 'LEAD-0001', displayName: 'Ashan Perera',   email: 'ashan@example.com', mobile: '+94 71 234 5678', status: 'Interested', modified: '2024-04-18'),
  CrmLead(name: 'LEAD-0002', displayName: 'Nimal Silva',    email: 'nimal@techco.lk',   mobile: '+94 77 890 1234', status: 'Contacted',  modified: '2024-04-17'),
  CrmLead(name: 'LEAD-0003', displayName: 'Priya Fernando', email: 'priya.f@gmail.com', mobile: '+94 76 555 9900', status: 'Lead',       modified: '2024-04-16'),
  CrmLead(name: 'LEAD-0004', displayName: 'Roshan Mendis',  email: '',                  mobile: '+94 70 112 3344', status: 'Lead',       modified: '2024-04-15'),
];

final _mockOpps = [
  Opportunity(name: 'OPP-0001', partyName: 'Ashan Perera',    amount: 450000,  stage: 'Proposal',      status: 'Open', expectedClosing: '2024-05-30', modified: '2024-04-18'),
  Opportunity(name: 'OPP-0002', partyName: 'TechCo Solutions', amount: 1200000, stage: 'Negotiation',   status: 'Open', expectedClosing: '2024-06-15', modified: '2024-04-17'),
  Opportunity(name: 'OPP-0003', partyName: 'Sunset Interiors', amount: 320000,  stage: 'Qualification', status: 'Open', expectedClosing: '2024-05-10', modified: '2024-04-14'),
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

  List<Opportunity> _opps   = List.of(_mockOpps);
  List<CrmLead>     _leads  = List.of(_mockLeads);
  PipelineSummary   _summary = SalesService.summarise(_mockOpps);
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
        _opps    = opps.isNotEmpty  ? opps  : List.of(_mockOpps);
        _leads   = leads.isNotEmpty ? leads : List.of(_mockLeads);
        _summary = SalesService.summarise(_opps);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showConvertForm(CrmLead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _ConvertSheet(
        lead: lead,
        onConverted: (opp) => setState(() {
          _opps    = [opp, ..._opps];
          _summary = SalesService.summarise(_opps);
        }),
      ),
    );
  }

  void _showQuoteForm(Opportunity opp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _QuoteSheet(opp: opp),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: Stack(
        children: [
          // ── Background mesh glow ──────────────────────────────────────────
          Positioned(
            top: -80, left: -60,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF4F46E5).withValues(alpha: 0.18),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            top: 160, right: -80,
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          // ── Content ───────────────────────────────────────────────────────
          NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(child: _Header(summary: _summary)),
              SliverToBoxAdapter(child: _GlassTabBar(controller: _tab, leads: _leads.length, opps: _opps.length)),
            ],
            body: TabBarView(
              controller: _tab,
              children: [
                _LeadsTab(leads: _leads, loading: _loading, onRetry: _loadFromApi, onConvert: _showConvertForm),
                _OppsTab(opps: _opps, loading: _loading, onRetry: _loadFromApi, onQuote: _showQuoteForm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — premium dark gradient + glass stat cards
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
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1240), Color(0xFF0A0F1E), Color(0xFF110D2E)],
          stops: [0.0, 0.55, 1.0],
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
                      // eyebrow
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _indigo.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _indigo.withValues(alpha: 0.28)),
                        ),
                        child: const Text(
                          'PIPELINE',
                          style: TextStyle(color: _indigo, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.0,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Leads · Opportunities · Quotes',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Icon badge
                _GlassIconBadge(
                  icon: Icons.bar_chart_rounded,
                  color: _indigo,
                ),
              ],
            ),
          ),
          // ── Glass stat cards row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Row(
              children: [
                _GlassStatCard(label: 'Open',    value: '${summary.open}', icon: Icons.radio_button_checked_rounded, color: _indigo),
                const SizedBox(width: 10),
                _GlassStatCard(label: 'Won',     value: '${summary.won}',  icon: Icons.check_circle_rounded,         color: const Color(0xFF10B981)),
                const SizedBox(width: 10),
                _GlassStatCard(label: 'Pipeline', value: _fmt(summary.totalValue), icon: Icons.trending_up_rounded, color: _amber, wide: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;
  const _GlassStatCard({required this.label, required this.value, required this.icon, required this.color, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 15),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(label,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.50), fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GlassIconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass tab bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  final int leads;
  final int opps;
  const _GlassTabBar({required this.controller, required this.leads, required this.opps});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF070B14),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            ),
            child: TabBar(
              controller: controller,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(color: _indigo.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 3)),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.45),
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Leads'),
                  const SizedBox(width: 6),
                  _GlassBadge(leads),
                ])),
                Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Opportunities'),
                  const SizedBox(width: 6),
                  _GlassBadge(opps),
                ])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  final int count;
  const _GlassBadge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('$count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leads tab
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  final List<CrmLead>           leads;
  final bool                    loading;
  final VoidCallback            onRetry;
  final void Function(CrmLead)  onConvert;
  const _LeadsTab({required this.leads, required this.loading, required this.onRetry, required this.onConvert});

  @override
  Widget build(BuildContext context) {
    if (loading && leads.isEmpty) return _LoadingState();
    if (leads.isEmpty) return _EmptyState(icon: Icons.person_add_outlined, title: 'No leads yet', subtitle: 'Leads created during calls will appear here', onRetry: onRetry);
    return RefreshIndicator(
      color: _indigo,
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: leads.length,
        itemBuilder: (_, i) => _LeadCard(lead: leads[i], onConvert: onConvert),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead card — glass morphic
// ─────────────────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final CrmLead               lead;
  final void Function(CrmLead) onConvert;
  const _LeadCard({required this.lead, required this.onConvert});

  static const _statusColors = {
    'Lead':           Color(0xFF8B5CF6),
    'Contacted':      Color(0xFF60A5FA),
    'Interested':     Color(0xFF10B981),
    'Converted':      Color(0xFF059669),
    'Do Not Contact': Color(0xFFEF4444),
  };
  Color get _color => _statusColors[lead.status] ?? const Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF161F30), const Color(0xFF0F1726)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Top specular line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    // Glassy avatar
                    _GlassAvatar(initials: lead.initials, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (lead.mobile.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(lead.mobile,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12)),
                          ],
                          const SizedBox(height: 6),
                          _GlassChip(label: lead.status.isEmpty ? 'Lead' : lead.status, color: color),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Convert button
                _GlassCTAButton(
                  icon: Icons.trending_up_rounded,
                  label: 'Convert to Opportunity',
                  color: _indigo,
                  onTap: () => onConvert(lead),
                ),
              ],
            ),
          ),
        ],
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
  final VoidCallback                onRetry;
  final void Function(Opportunity)  onQuote;
  const _OppsTab({required this.opps, required this.loading, required this.onRetry, required this.onQuote});

  @override
  Widget build(BuildContext context) {
    if (loading && opps.isEmpty) return _LoadingState();
    if (opps.isEmpty) return _EmptyState(icon: Icons.trending_up_rounded, title: 'No opportunities yet', subtitle: 'Convert a lead to create your first opportunity', onRetry: onRetry);
    return RefreshIndicator(
      color: _amber,
      backgroundColor: const Color(0xFF1E293B),
      onRefresh: () async => onRetry(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount: opps.length,
        itemBuilder: (_, i) => _OppCard(opp: opps[i], onQuote: onQuote),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Opportunity card — glass with amber/stage glow
// ─────────────────────────────────────────────────────────────────────────────

class _OppCard extends StatelessWidget {
  final Opportunity                opp;
  final void Function(Opportunity) onQuote;
  const _OppCard({required this.opp, required this.onQuote});

  static const _stageColors = {
    'Prospecting':   Color(0xFF60A5FA),
    'Qualification': Color(0xFF8B5CF6),
    'Proposal':      Color(0xFFA78BFA),
    'Negotiation':   Color(0xFFF59E0B),
    'Closed Won':    Color(0xFF10B981),
    'Closed Lost':   Color(0xFFEF4444),
  };
  Color get _color => _stageColors[opp.stage] ?? const Color(0xFF8B5CF6);

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
    final color = _color;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF161F30), const Color(0xFF0F1726)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Top specular
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.12),
                Colors.transparent,
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _GlassAvatar(initials: _initials, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opp.partyName,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Row(children: [
                            _GlassChip(label: opp.stage.isEmpty ? 'No Stage' : opp.stage, color: color),
                            const Spacer(),
                            Text(_fmt(opp.amount),
                                style: TextStyle(
                                    color: _amber,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4)),
                          ]),
                          if (opp.expectedClosing.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(children: [
                              Icon(Icons.calendar_today_rounded, size: 11, color: Colors.white.withValues(alpha: 0.30)),
                              const SizedBox(width: 4),
                              Text(opp.expectedClosing,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GlassCTAButton(
                  icon: Icons.receipt_long_rounded,
                  label: 'Create Quote',
                  color: _amber,
                  onTap: () => onQuote(opp),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared micro-components
// ─────────────────────────────────────────────────────────────────────────────

class _GlassAvatar extends StatelessWidget {
  final String initials;
  final Color color;
  const _GlassAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.10)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Center(
        child: Text(initials,
            style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final Color color;
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
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
    );
  }
}

class _GlassCTAButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _GlassCTAButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -0.1)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Convert to Opportunity sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ConvertSheet extends StatefulWidget {
  final CrmLead                 lead;
  final void Function(Opportunity) onConverted;
  const _ConvertSheet({required this.lead, required this.onConverted});

  @override
  State<_ConvertSheet> createState() => _ConvertSheetState();
}

class _ConvertSheetState extends State<_ConvertSheet> {
  final _valueCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();
  String _stage    = 'Prospecting';
  bool   _busy     = false;
  String? _error;

  static const _stages = ['Prospecting', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won'];

  @override
  void dispose() { _valueCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null) { setState(() => _error = 'Enter a valid number'); return; }
    setState(() { _busy = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 600));
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
    ScaffoldMessenger.of(context).showSnackBar(_successSnack('Opportunity created for ${widget.lead.displayName}'));
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
            _SheetHeader(icon: Icons.trending_up_rounded, color: _indigo, title: 'Convert to Opportunity', subtitle: widget.lead.displayName),
            const SizedBox(height: 20),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 12)],
            _GlassField(controller: _valueCtrl, label: 'Expected Value (Rs.) *', keyboardType: TextInputType.number, enabled: !_busy),
            const SizedBox(height: 16),
            Text('Stage', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _stages.map((s) {
              final sel = s == _stage;
              return GestureDetector(
                onTap: _busy ? null : () => setState(() => _stage = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: sel ? LinearGradient(colors: [_indigo.withValues(alpha: 0.30), _indigo.withValues(alpha: 0.14)]) : null,
                    color: sel ? null : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? _indigo.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(s, style: TextStyle(color: sel ? Colors.white : Colors.white.withValues(alpha: 0.50), fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),
            _GlassField(controller: _noteCtrl, label: 'Note (optional)', maxLines: 2, enabled: !_busy),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _GlassOutlineBtn(label: 'Cancel', onTap: _busy ? null : () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _GlassFillBtn(label: _busy ? 'Saving…' : 'Convert', icon: Icons.trending_up_rounded, color: _indigo, loading: _busy, onTap: _busy ? null : _submit)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote sheet
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteSheet extends StatefulWidget {
  final Opportunity opp;
  const _QuoteSheet({required this.opp});

  @override
  State<_QuoteSheet> createState() => _QuoteSheetState();
}

class _QuoteSheetState extends State<_QuoteSheet> {
  final _subjectCtrl = TextEditingController();
  final _amountCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();
  bool   _busy    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectCtrl.text = 'Quotation for ${widget.opp.partyName}';
    if (widget.opp.amount > 0) _amountCtrl.text = widget.opp.amount.toStringAsFixed(0);
  }

  @override
  void dispose() { _subjectCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    if (subject.isEmpty) { setState(() => _error = 'Subject is required'); return; }
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    setState(() { _busy = true; _error = null; });
    try {
      final docname = await SalesService.createQuotation(
        leadDocname: widget.opp.name, partyType: 'Lead',
        subject: subject, amount: amount, note: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          _successSnack(docname.isNotEmpty ? 'Quote created: $docname' : 'Quote created'));
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
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
            Row(children: [
              Expanded(child: _SheetHeader(icon: Icons.receipt_long_rounded, color: _amber, title: 'Create Quotation', subtitle: widget.opp.partyName)),
              _GlassChip(label: widget.opp.stage, color: _amber),
            ]),
            const SizedBox(height: 20),
            if (_error != null) ...[_ErrorBanner(message: _error!), const SizedBox(height: 12)],
            _GlassField(controller: _subjectCtrl, label: 'Subject *', enabled: !_busy),
            const SizedBox(height: 12),
            _GlassField(controller: _amountCtrl, label: 'Amount (Rs.)', keyboardType: TextInputType.number, enabled: !_busy),
            const SizedBox(height: 12),
            _GlassField(controller: _noteCtrl, label: 'Note', maxLines: 3, enabled: !_busy),
            const SizedBox(height: 20),
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
// Glass sheet + shared sheet components
// ─────────────────────────────────────────────────────────────────────────────

class _GlassSheet extends StatelessWidget {
  final Widget child;
  const _GlassSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A2235).withValues(alpha: 0.95),
                const Color(0xFF0D1526).withValues(alpha: 0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          child: child,
        ),
      ),
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
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _SheetHeader({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
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
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
        Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
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
  const _GlassField({required this.controller, required this.label, this.keyboardType = TextInputType.text, this.maxLines = 1, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _indigo,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.10))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _indigo, width: 1.5)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
  }
}

class _GlassOutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GlassOutlineBtn({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Center(child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 14, fontWeight: FontWeight.w600))),
      ),
    );
  }
}

class _GlassFillBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _GlassFillBtn({required this.label, required this.icon, required this.color, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty / loading states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
      child: CircularProgressIndicator(color: _indigo, strokeWidth: 2));
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRetry;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.40), fontSize: 13)),
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
