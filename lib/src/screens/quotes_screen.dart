import 'dart:ui';
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
      body: Stack(
        children: [
          // ── Background mesh glows ─────────────────────────────────────────
          Positioned(
            top: -80, right: -60,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _amber.withValues(alpha: 0.14),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            top: 200, left: -70,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _teal.withValues(alpha: 0.10),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(child: _Header(summary: _summary)),
              SliverToBoxAdapter(
                child: _GlassTabBar(
                  controller:   _tab,
                  quoteCount:   _quotes.length,
                  orderCount:   _orders.length,
                ),
              ),
            ],
            body: TabBarView(
              controller: _tab,
              children: [
                _QuotesTab(
                  quotes:   _quotes,
                  loading:  _loading,
                  onRetry:  _loadFromApi,
                ),
                _OrdersTab(
                  orders:  _orders,
                  loading: _loading,
                  onRetry: _loadFromApi,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              boxShadow: [
                BoxShadow(
                  color:      color.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset:     const Offset(0, 4),
                ),
              ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : ac.bgCard.withValues(alpha: 0.90),
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
  final List<Quotation> quotes;
  final bool            loading;
  final VoidCallback    onRetry;
  const _QuotesTab({required this.quotes, required this.loading, required this.onRetry});

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
        itemBuilder: (_, i) => _QuoteCard(quote: quotes[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quotation card
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final Quotation quote;
  const _QuoteCard({required this.quote});

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
              ],
            ),
          ),
        ],
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
