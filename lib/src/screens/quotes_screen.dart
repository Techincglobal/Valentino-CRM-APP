import 'package:flutter/material.dart';
import '../services/sales_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens — always legible on the dark header
// ─────────────────────────────────────────────────────────────────────────────

const _amber = Color(0xFFF59E0B);
const _teal  = Color(0xFF14B8A6);
const _slate = Color(0xFF94A3B8);

// ─────────────────────────────────────────────────────────────────────────────
// Mock data (used when API returns nothing)
// ─────────────────────────────────────────────────────────────────────────────

final _mockQuotes = [
  Quotation(name: 'QTN-2024-00001', partyName: 'Ashan Perera',      grandTotal: 450000,   status: 'Draft',     modified: '2024-04-18'),
  Quotation(name: 'QTN-2024-00002', partyName: 'TechCo Solutions',  grandTotal: 1200000,  status: 'Submitted', modified: '2024-04-17'),
  Quotation(name: 'QTN-2024-00003', partyName: 'Sunset Interiors',  grandTotal: 185000,   status: 'Expired',   modified: '2024-04-14'),
  Quotation(name: 'QTN-2024-00004', partyName: 'Nimal Silva',        grandTotal: 78500,    status: 'Draft',     modified: '2024-04-12'),
];

final _mockOrders = [
  SalesOrder(name: 'SAL-ORD-2024-00001', customerName: 'TechCo Solutions', grandTotal: 1200000, status: 'To Deliver',  deliveryStatus: 'Not Delivered',   modified: '2024-04-16'),
  SalesOrder(name: 'SAL-ORD-2024-00002', customerName: 'Ashan Perera',     grandTotal: 320000,  status: 'Completed',  deliveryStatus: 'Fully Delivered', modified: '2024-04-10'),
  SalesOrder(name: 'SAL-ORD-2024-00003', customerName: 'Priya Fernando',   grandTotal: 95000,   status: 'Draft',      deliveryStatus: 'Not Delivered',   modified: '2024-04-08'),
];

// ─────────────────────────────────────────────────────────────────────────────
// QuotesScreen
// ─────────────────────────────────────────────────────────────────────────────

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tab;

  List<Quotation>  _quotes  = List.of(_mockQuotes);
  List<SalesOrder> _orders  = List.of(_mockOrders);
  QuotesSummary    _summary = SalesService.summariseQuotes(_mockQuotes, _mockOrders);
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

  Future<void> _openQuoteDetail(Quotation quote) async {
    final refreshed = await showModalBottomSheet<bool>(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder:           (_) => _QuoteDetailSheet(quote: quote),
    );
    if (refreshed == true) _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SalesService.getQuotations(),
        SalesService.getSalesOrders(),
      ]);
      if (!mounted) return;
      final quotes = results[0] as List<Quotation>;
      final orders = results[1] as List<SalesOrder>;
      setState(() {
        _quotes  = quotes.isNotEmpty ? quotes : List.of(_mockQuotes);
        _orders  = orders.isNotEmpty ? orders : List.of(_mockOrders);
        _summary = SalesService.summariseQuotes(_quotes, _orders);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
            child: _GlassTabBar(
              controller: _tab,
              quoteCount: _quotes.length,
              orderCount: _orders.length,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tab,
          children: [
            _QuotesTab(quotes: _quotes, loading: _loading, onRetry: _loadFromApi, onTap: _openQuoteDetail),
            _OrdersTab(orders: _orders, loading: _loading, onRetry: _loadFromApi),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — always dark gradient (brand section)
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final QuotesSummary summary;
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
          colors: [Color(0xFF1A1200), Color(0xFF0A0F1E), Color(0xFF001A1A)],
          stops:  [0.0, 0.55, 1.0],
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
                          color:  _amber.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _amber.withValues(alpha: 0.28)),
                        ),
                        child: const Text(
                          'DOCUMENTS',
                          style: TextStyle(
                            color: _amber, fontSize: 9,
                            fontWeight: FontWeight.w900, letterSpacing: 1.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quotes & Orders',
                        style: TextStyle(
                          color: Colors.white, fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8, height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Quotations · Sales Orders',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _GlassIconBadge(icon: Icons.receipt_long_rounded, color: _amber),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
            child: Row(
              children: [
                _GlassStatCard(
                  label: 'Quotes',
                  value: '${summary.totalQuotes}',
                  icon:  Icons.description_rounded,
                  color: _amber,
                ),
                const SizedBox(width: 10),
                _GlassStatCard(
                  label: 'Drafts',
                  value: '${summary.draftQuotes}',
                  icon:  Icons.edit_note_rounded,
                  color: _slate,
                ),
                const SizedBox(width: 10),
                _GlassStatCard(
                  label: 'Pipeline',
                  value: _fmt(summary.totalValue),
                  icon:  Icons.trending_up_rounded,
                  color: _teal,
                  wide:  true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassStatCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color   color;
  final bool    wide;
  const _GlassStatCard({
    required this.label, required this.value,
    required this.icon,  required this.color, this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: wide ? 2 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w800, letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 10, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassIconBadge extends StatelessWidget {
  final IconData icon;
  final Color    color;
  const _GlassIconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Adaptive glass tab bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final TabController controller;
  final int quoteCount;
  final int orderCount;
  const _GlassTabBar({
    required this.controller,
    required this.quoteCount,
    required this.orderCount,
  });

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Container(
      color: ac.bgBase,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : ac.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.09)
                : ac.border,
          ),
        ),
        child: TabBar(
              controller: controller,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color:      _amber.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset:     const Offset(0, 3),
                  ),
                ],
              ),
              indicatorSize:    TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(3),
              dividerColor:     Colors.transparent,
              labelColor:       Colors.white,
              unselectedLabelColor: ac.textSecondary,
              labelStyle:   const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Quotations'),
                    const SizedBox(width: 6),
                    _GlassBadge(quoteCount, isDark: isDark),
                  ]),
                ),
                Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Sales Orders'),
                    const SizedBox(width: 6),
                    _GlassBadge(orderCount, isDark: isDark),
                  ]),
                ),
              ],
            ),
          ),
        );
  }
}

class _GlassBadge extends StatelessWidget {
  final int  count;
  final bool isDark;
  const _GlassBadge(this.count, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quotations tab
// ─────────────────────────────────────────────────────────────────────────────

class _QuotesTab extends StatelessWidget {
  final List<Quotation>           quotes;
  final bool                      loading;
  final VoidCallback              onRetry;
  final void Function(Quotation)  onTap;
  const _QuotesTab({
    required this.quotes,
    required this.loading,
    required this.onRetry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && quotes.isEmpty) return const _LoadingState();
    if (quotes.isEmpty) {
      return _EmptyState(
        icon:     Icons.description_outlined,
        title:    'No quotations yet',
        subtitle: 'Quotations created from opportunities will appear here',
        onRetry:  onRetry,
      );
    }
    return RefreshIndicator(
      color:           _amber,
      backgroundColor: context.ac.bgCard,
      onRefresh:       () async => onRetry(),
      child: ListView.builder(
        padding:     const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount:   quotes.length,
        itemBuilder: (_, i) => _QuoteCard(quote: quotes[i], onTap: onTap),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quotation card
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final Quotation                 quote;
  final void Function(Quotation)  onTap;
  const _QuoteCard({required this.quote, required this.onTap});

  static const _statusColors = {
    'Draft':     Color(0xFF94A3B8),
    'Submitted': Color(0xFF6366F1),
    'Ordered':   Color(0xFF10B981),
    'Expired':   Color(0xFFF59E0B),
    'Cancelled': Color(0xFFEF4444),
  };
  Color get _color => _statusColors[quote.status] ?? const Color(0xFF94A3B8);

  String _fmt(double v) {
    if (v == 0) return '—';
    final c = quote.currency.isNotEmpty ? quote.currency : 'Rs.';
    if (v >= 10000000) return '$c ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '$c ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '$c ${(v / 1000).toStringAsFixed(0)}K';
    return '$c ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final color  = _color;
    return GestureDetector(
      onTap: () => onTap(quote),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? null : ac.bgCard,
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2235), Color(0xFF0D1526)],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : ac.border,
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
            BoxShadow(
              color:      Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
              blurRadius: 12, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: isDark ? 0.12 : 0.40),
                  Colors.transparent,
                ]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  _GlassAvatar(initials: quote.initials, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.partyName,
                          style: TextStyle(
                            color: ac.textPrimary, fontSize: 15,
                            fontWeight: FontWeight.w700, letterSpacing: -0.3,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          quote.name,
                          style: TextStyle(
                            color: ac.textTertiary, fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          _GlassChip(label: quote.status, color: color),
                          const Spacer(),
                          Text(
                            _fmt(quote.grandTotal),
                            style: const TextStyle(
                              color: _amber, fontSize: 15,
                              fontWeight: FontWeight.w800, letterSpacing: -0.4,
                            ),
                          ),
                        ]),
                        if (quote.modified.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.access_time_rounded, size: 11, color: ac.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              quote.modified.length >= 10
                                  ? quote.modified.substring(0, 10)
                                  : quote.modified,
                              style: TextStyle(color: ac.textTertiary, fontSize: 11),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: ac.textTertiary, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sales Orders tab
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final List<SalesOrder> orders;
  final bool             loading;
  final VoidCallback     onRetry;
  const _OrdersTab({required this.orders, required this.loading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) return const _LoadingState();
    if (orders.isEmpty) {
      return _EmptyState(
        icon:     Icons.local_shipping_outlined,
        title:    'No sales orders yet',
        subtitle: 'Sales orders will appear here once created',
        onRetry:  onRetry,
      );
    }
    return RefreshIndicator(
      color:           _teal,
      backgroundColor: context.ac.bgCard,
      onRefresh:       () async => onRetry(),
      child: ListView.builder(
        padding:     const EdgeInsets.fromLTRB(16, 12, 16, 120),
        itemCount:   orders.length,
        itemBuilder: (_, i) => _OrderCard(order: orders[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sales Order card
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final SalesOrder order;
  const _OrderCard({required this.order});

  static const _statusColors = {
    'Draft':      Color(0xFF94A3B8),
    'To Deliver': Color(0xFF6366F1),
    'To Bill':    Color(0xFFF59E0B),
    'Completed':  Color(0xFF10B981),
    'Cancelled':  Color(0xFFEF4444),
  };
  static const _deliveryColors = {
    'Not Delivered':   Color(0xFF94A3B8),
    'Partly Delivered':Color(0xFFF59E0B),
    'Fully Delivered': Color(0xFF10B981),
  };

  Color get _color => _statusColors[order.status] ?? const Color(0xFF94A3B8);
  Color get _dColor =>
      _deliveryColors[order.deliveryStatus] ?? const Color(0xFF94A3B8);

  String _fmt(double v) {
    if (v == 0) return '—';
    if (v >= 10000000) return 'Rs.${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return 'Rs.${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return 'Rs.${(v / 1000).toStringAsFixed(0)}K';
    return 'Rs.${v.toStringAsFixed(0)}';
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
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1A2235), Color(0xFF0D1526)],
              )
            : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : ac.border,
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 6)),
          BoxShadow(
            color:      Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 12, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Specular highlight
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: isDark ? 0.12 : 0.40),
                Colors.transparent,
              ]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                _GlassAvatar(initials: order.initials, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: TextStyle(
                          color: ac.textPrimary, fontSize: 15,
                          fontWeight: FontWeight.w700, letterSpacing: -0.3,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.name,
                        style: TextStyle(
                          color: ac.textTertiary, fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        _GlassChip(label: order.status, color: color),
                        const SizedBox(width: 6),
                        if (order.deliveryStatus.isNotEmpty)
                          _GlassChip(label: order.deliveryStatus, color: _dColor),
                        const Spacer(),
                        Text(
                          _fmt(order.grandTotal),
                          style: const TextStyle(
                            color: _teal, fontSize: 15,
                            fontWeight: FontWeight.w800, letterSpacing: -0.4,
                          ),
                        ),
                      ]),
                      if (order.modified.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.access_time_rounded, size: 11, color: ac.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            order.modified.length >= 10
                                ? order.modified.substring(0, 10)
                                : order.modified,
                            style: TextStyle(color: ac.textTertiary, fontSize: 11),
                          ),
                        ]),
                      ],
                    ],
                  ),
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
// Quote detail / edit sheet
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteDetailSheet extends StatefulWidget {
  final Quotation quote;
  const _QuoteDetailSheet({required this.quote});

  @override
  State<_QuoteDetailSheet> createState() => _QuoteDetailSheetState();
}

class _QuoteDetailSheetState extends State<_QuoteDetailSheet> {
  QuotationDetail? _detail;
  bool   _loadingDetail = true;
  bool   _acting        = false;
  String _error         = '';

  final _validTillCtrl = TextEditingController();
  final _termsCtrl     = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _validTillCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() { _loadingDetail = true; _error = ''; });
    try {
      final d = await SalesService.getQuotationDetail(widget.quote.name);
      if (!mounted) return;
      setState(() {
        _detail        = d;
        _loadingDetail = false;
        _validTillCtrl.text = d.validTill;
        _termsCtrl.text     = d.terms;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingDetail = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    final d = _detail;
    if (d == null || !d.isDraft) return;
    setState(() => _acting = true);
    try {
      await SalesService.updateQuotation(d.name, {
        'valid_till': _validTillCtrl.text.trim(),
        'terms':      _termsCtrl.text.trim(),
      });
      if (!mounted) return;
      _showSnack('Changes saved', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Save failed: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _submit() async {
    final d = _detail;
    if (d == null) return;
    final confirmed = await _confirm(
      title:   'Submit quotation?',
      body:    'Once submitted, it cannot be edited. The customer will receive the final quote.',
      label:   'Submit',
      color:   const Color(0xFF6366F1),
    );
    if (!confirmed || !mounted) return;
    setState(() => _acting = true);
    try {
      await SalesService.submitQuotation(d.name);
      if (!mounted) return;
      _showSnack('Quotation submitted', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Submit failed: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    final d = _detail;
    if (d == null) return;
    final confirmed = await _confirm(
      title: 'Cancel quotation?',
      body:  'This will cancel ${d.name}. This action cannot be undone.',
      label: 'Cancel Quote',
      color: const Color(0xFFEF4444),
    );
    if (!confirmed || !mounted) return;
    setState(() => _acting = true);
    try {
      await SalesService.cancelQuotation(d.name);
      if (!mounted) return;
      _showSnack('Quotation cancelled', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Cancel failed: $e');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String label,
    required Color  color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: title, body: body, confirmLabel: label, confirmColor: color,
        onCancel:  () => Navigator.pop(ctx, false),
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    return result == true;
  }

  void _showSnack(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final c = (_detail?.currency.isNotEmpty == true) ? _detail!.currency : 'Rs.';
    if (v >= 10000000) return '$c ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '$c ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '$c ${(v / 1000).toStringAsFixed(0)}K';
    return '$c ${v.toStringAsFixed(0)}';
  }

  static const _statusColors = {
    'Draft':     Color(0xFF94A3B8),
    'Submitted': Color(0xFF6366F1),
    'Ordered':   Color(0xFF10B981),
    'Expired':   Color(0xFFF59E0B),
    'Cancelled': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final ac      = context.ac;
    final isDark  = context.isDark;
    final bottom  = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final maxH    = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : ac.border,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Flexible(
            child: _loadingDetail
                ? _buildLoading()
                : _error.isNotEmpty
                    ? _buildError()
                    : _buildContent(ac, isDark, bottom),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Center(child: CircularProgressIndicator(color: _amber, strokeWidth: 2.5)),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: context.ac.textTertiary, size: 40),
      const SizedBox(height: 14),
      Text('Could not load quotation', style: TextStyle(color: context.ac.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(_error, style: TextStyle(color: context.ac.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _fetchDetail,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _amber.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _amber.withValues(alpha: 0.30)),
          ),
          child: const Text('Retry', style: TextStyle(color: _amber, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _buildContent(AdaptiveColors ac, bool isDark, double bottomInset) {
    final d = _detail!;
    final statusColor = _statusColors[d.status] ?? _slate;
    final canEdit   = d.isDraft;
    final canCancel = d.isDraft || d.isSubmitted;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(children: [
            _GlassAvatar(initials: d.initials, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.partyName,
                    style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  _GlassChip(label: d.status, color: statusColor),
                  const SizedBox(width: 8),
                  Text(d.name,
                      style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(d.grandTotal),
                  style: const TextStyle(color: _amber, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text(d.currency,
                  style: TextStyle(color: ac.textTertiary, fontSize: 11)),
            ]),
          ]),

          const SizedBox(height: 22),

          // ── Line items ───────────────────────────────────────────────────
          if (d.items.isNotEmpty) ...[
            _SectionHeader(label: 'LINE ITEMS', ac: ac),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color:        isDark ? const Color(0xFF1A2235) : ac.bgCard,
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
              ),
              child: Column(
                children: d.items.asMap().entries.map((e) {
                  final i    = e.key;
                  final item = e.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      border: i < d.items.length - 1
                          ? Border(bottom: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : ac.borderLight,
                            ))
                          : null,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.itemName.isNotEmpty ? item.itemName : item.itemCode,
                              style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (item.itemCode.isNotEmpty && item.itemName.isNotEmpty)
                            Text(item.itemCode, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_fmt(item.amount),
                            style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 1)} × ${_fmt(item.rate)}',
                            style: TextStyle(color: ac.textTertiary, fontSize: 10)),
                      ]),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Valid Till ───────────────────────────────────────────────────
          _SectionHeader(label: 'VALID TILL', ac: ac),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: canEdit ? () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.tryParse(_validTillCtrl.text) ?? DateTime.now().add(const Duration(days: 30)),
                firstDate:   DateTime.now(),
                lastDate:    DateTime.now().add(const Duration(days: 365)),
                builder:     (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary:   _amber,
                      surface:   isDark ? const Color(0xFF1A2235) : ac.bgCard,
                      onSurface: ac.textPrimary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                _validTillCtrl.text =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              }
            } : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color:        isDark ? const Color(0xFF1A2235) : ac.bgInput,
                borderRadius: BorderRadius.circular(14),
                border:       Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: ac.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _validTillCtrl.text.isNotEmpty ? _validTillCtrl.text : 'Not set',
                    style: TextStyle(
                      color: _validTillCtrl.text.isNotEmpty ? ac.textPrimary : ac.textTertiary,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (canEdit)
                  Icon(Icons.edit_rounded, size: 14, color: ac.textTertiary),
              ]),
            ),
          ),

          const SizedBox(height: 16),

          // ── Terms / Notes ────────────────────────────────────────────────
          _SectionHeader(label: 'TERMS & NOTES', ac: ac),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color:        isDark ? const Color(0xFF1A2235) : ac.bgInput,
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
            ),
            child: TextField(
              controller:  _termsCtrl,
              enabled:     canEdit,
              minLines:    3,
              maxLines:    6,
              style:       TextStyle(color: ac.textPrimary, fontSize: 14),
              decoration:  InputDecoration(
                hintText:    canEdit ? 'Add terms, notes, or special conditions…' : 'No terms added',
                hintStyle:   TextStyle(color: ac.textTertiary, fontSize: 13),
                border:      InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Actions ──────────────────────────────────────────────────────
          if (_acting)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(color: _amber, strokeWidth: 2.5),
            ))
          else ...[
            if (canEdit) ...[
              _ActionButton(
                label:   'Save Changes',
                icon:    Icons.save_rounded,
                color:   _amber,
                onTap:   _save,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label:   'Submit Quotation',
                icon:    Icons.send_rounded,
                color:   const Color(0xFF6366F1),
                onTap:   _submit,
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 10),
              _ActionButton(
                label:     'Cancel Quotation',
                icon:      Icons.cancel_outlined,
                color:     const Color(0xFFEF4444),
                outlined:  true,
                onTap:     _cancel,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sheet helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final AdaptiveColors ac;
  const _SectionHeader({required this.label, required this.ac});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: ac.textTertiary, fontSize: 10,
      fontWeight: FontWeight.w800, letterSpacing: 1.4,
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final bool      outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: outlined ? null : LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.18)!],
          ),
          color:        outlined ? Colors.transparent : null,
          borderRadius: BorderRadius.circular(16),
          border:       outlined ? Border.all(color: color.withValues(alpha: 0.50)) : null,
          boxShadow:    outlined ? null : [
            BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: outlined ? color : Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color:      outlined ? color : Colors.white,
              fontSize:   15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String     title;
  final String     body;
  final String     confirmLabel;
  final Color      confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  const _ConfirmDialog({
    required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor,
    required this.onCancel, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.50 : 0.12), blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: ac.textSecondary, fontSize: 14, height: 1.5)),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.bgInput,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.10) : ac.border),
                    ),
                    child: Center(child: Text('Keep it', style: TextStyle(color: ac.textSecondary, fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [confirmColor, Color.lerp(confirmColor, Colors.black, 0.18)!]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: confirmColor.withValues(alpha: 0.30), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Center(child: Text(confirmLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
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
  final String initials;
  final Color  color;
  const _GlassAvatar({required this.initials, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color, fontSize: 15, fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final Color  color;
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
      child: Text(
        label,
        style: TextStyle(
          color: color, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading / empty states
// ─────────────────────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5, color: _amber,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading…',
            style: TextStyle(
              color: context.ac.textSecondary, fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final String       subtitle;
  final VoidCallback onRetry;
  const _EmptyState({
    required this.icon, required this.title,
    required this.subtitle, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color:        ac.bgCard,
                shape:        BoxShape.circle,
                border:       Border.all(color: ac.border),
              ),
              child: Icon(icon, color: ac.textTertiary, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: ac.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ac.textSecondary, fontSize: 13, height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                  color:        ac.bgCard,
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(color: ac.border),
                ),
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: ac.textSecondary, fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
