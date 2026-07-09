import 'package:flutter/material.dart';
import '../services/sales_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public interface — lets MainShell trigger a data refresh cross-file.
// ─────────────────────────────────────────────────────────────────────────────

abstract class QuotesScreenController {
  void refreshQuotes();
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand tokens — always legible on the dark header
// ─────────────────────────────────────────────────────────────────────────────

const _amber  = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
const _teal   = _amber; // collapsed into the single brand blue
const _slate  = Color(0xFF94A3B8);
const _indigo = _amber; // collapsed into the single brand blue

// ─────────────────────────────────────────────────────────────────────────────
// QuotesScreen
// ─────────────────────────────────────────────────────────────────────────────

class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin
    implements QuotesScreenController {
  @override
  bool get wantKeepAlive => true;

  @override
  void refreshQuotes() => _loadFromApi();

  late final TabController _tab;

  List<Quotation>  _quotes  = const [];
  List<SalesOrder> _orders  = const [];
  QuotesSummary    _summary = const QuotesSummary(totalQuotes: 0, draftQuotes: 0, openOrders: 0, totalValue: 0);
  bool   _loading = false;
  String _error   = '';

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

  void _showCreateQuoteForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _NewQuoteSheet(onCreated: _loadFromApi),
    );
  }

  Future<void> _openQuoteDetail(Quotation quote) async {
    final result = await showModalBottomSheet<dynamic>(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      builder:           (_) => _QuoteDetailSheet(quote: quote),
    );
    if (result == 'order') {
      _tab.animateTo(1);
      _loadFromApi();
    } else if (result == true) {
      _loadFromApi();
    }
  }

  Future<void> _openOrderDetail(SalesOrder order) async {
    final refreshed = await showModalBottomSheet<bool>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder:            (_) => _SODetailSheet(order: order),
    );
    if (refreshed == true) _loadFromApi();
  }

  Future<void> _loadFromApi() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final results = await Future.wait([
        SalesService.getQuotations(),
        SalesService.getSalesOrders(),
      ]);
      if (!mounted) return;
      final quotes = results[0] as List<Quotation>;
      final orders = results[1] as List<SalesOrder>;
      setState(() {
        _quotes  = quotes;
        _orders  = orders;
        _summary = SalesService.summariseQuotes(_quotes, _orders);
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
    final ac = context.ac;
    return Scaffold(
      backgroundColor: ac.bgBase,
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, _) => _tab.index == 0
            ? FloatingActionButton.extended(
                onPressed: _showCreateQuoteForm,
                backgroundColor: _amber,
                icon: const Icon(Icons.description_rounded, color: Colors.white, size: 18),
                label: const Text('New Quote',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              )
            : const SizedBox.shrink(),
      ),
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
            _QuotesTab(quotes: _quotes, loading: _loading, error: _error, onRetry: _loadFromApi, onTap: _openQuoteDetail),
            _OrdersTab(orders: _orders, loading: _loading, error: _error, onRetry: _loadFromApi, onTap: _openOrderDetail),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — compact adaptive style, consistent with every other screen
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
    final ac     = context.ac;
    final isDark = context.isDark;
    final top    = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5BAAFF), _amber, Color(0xFF1A7FD4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _amber.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                BoxShadow(color: _amber.withValues(alpha: 0.20), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Quotes & Orders',
                style: TextStyle(color: ac.textPrimary, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _amber.withValues(alpha: 0.3)),
              ),
              child: Text('DOCUMENTS',
                  style: TextStyle(color: _amber, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
          ]),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          _StatChip(label: 'Quotes',   value: '${summary.totalQuotes}', color: _amber, ac: ac, isDark: isDark),
          const SizedBox(width: 8),
          _StatChip(label: 'Drafts',   value: '${summary.draftQuotes}', color: _slate, ac: ac, isDark: isDark),
          const SizedBox(width: 8),
          _StatChip(label: 'Pipeline', value: _fmt(summary.totalValue), color: _amber, ac: ac, isDark: isDark),
        ]),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final AdaptiveColors ac;
  final bool isDark;
  const _StatChip({
    required this.label, required this.value, required this.color,
    required this.ac, required this.isDark,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2235) : ac.bgCardAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: ac.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  );
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
                    colors: [Color(0xFF2490EF), Color(0xFF1A7FD4)]),
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
  final String                    error;
  final VoidCallback              onRetry;
  final void Function(Quotation)  onTap;
  const _QuotesTab({
    required this.quotes,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && quotes.isEmpty) return const _LoadingState();
    if (quotes.isEmpty) {
      return _EmptyState(
        icon:     Icons.description_outlined,
        title:    error.isNotEmpty ? 'Could not load quotations' : 'No quotations yet',
        subtitle: error.isNotEmpty ? error : 'Quotations created from opportunities will appear here',
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
  final List<SalesOrder>          orders;
  final bool                      loading;
  final String                    error;
  final VoidCallback              onRetry;
  final void Function(SalesOrder) onTap;
  const _OrdersTab({
    required this.orders,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && orders.isEmpty) return const _LoadingState();
    if (orders.isEmpty) {
      return _EmptyState(
        icon:     Icons.local_shipping_outlined,
        title:    error.isNotEmpty ? 'Could not load sales orders' : 'No sales orders yet',
        subtitle: error.isNotEmpty ? error : 'Sales orders will appear here once created',
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
        itemBuilder: (_, i) => _OrderCard(order: orders[i], onTap: onTap),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sales Order card
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final SalesOrder                order;
  final void Function(SalesOrder) onTap;
  const _OrderCard({required this.order, required this.onTap});

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
    return GestureDetector(
      onTap: () => onTap(order),
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

  Future<void> _makeSalesOrder() async {
    final d = _detail;
    if (d == null) return;
    final confirmed = await _confirm(
      title: 'Create Sales Order?',
      body:  'This will convert ${d.name} into a confirmed Sales Order.',
      label: 'Create Order',
      color: const Color(0xFF10B981),
    );
    if (!confirmed || !mounted) return;
    setState(() => _acting = true);
    try {
      final soName = await SalesServiceOps.makeSOFromQuotation(d.name);
      if (!mounted) return;
      _showSnack('Sales Order created: $soName', isError: false);
      Navigator.pop(context, 'order');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed: ${e.toString().replaceFirst("Exception: ", "")}');
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
            if (d.isSubmitted && d.status != 'Ordered') ...[
              const SizedBox(height: 10),
              _ActionButton(
                label:  'Make Sales Order',
                icon:   Icons.shopping_cart_checkout_rounded,
                color:  const Color(0xFF10B981),
                onTap:  _makeSalesOrder,
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
// Sales Order detail sheet
// ─────────────────────────────────────────────────────────────────────────────

class _SODetailSheet extends StatefulWidget {
  final SalesOrder order;
  const _SODetailSheet({required this.order});

  @override
  State<_SODetailSheet> createState() => _SODetailSheetState();
}

class _SODetailSheetState extends State<_SODetailSheet> {
  SalesOrderDetail? _detail;
  bool   _loadingDetail = true;
  bool   _acting        = false;
  String _error         = '';
  String _actionError   = '';

  // Editable delivery date (for Draft SOs)
  final _deliveryCtrl = TextEditingController();

  static const _statusColors = {
    'Draft':      Color(0xFF94A3B8),
    'To Deliver': Color(0xFF6366F1),
    'To Bill':    Color(0xFFF59E0B),
    'Completed':  Color(0xFF10B981),
    'Cancelled':  Color(0xFFEF4444),
  };
  static const _deliveryColors = {
    'Not Delivered':    Color(0xFF94A3B8),
    'Partly Delivered': Color(0xFFF59E0B),
    'Fully Delivered':  Color(0xFF10B981),
  };
  static const _billingColors = {
    'Not Billed':    Color(0xFF94A3B8),
    'Partly Billed': Color(0xFFF59E0B),
    'Fully Billed':  Color(0xFF10B981),
  };

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _deliveryCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
    setState(() { _loadingDetail = true; _error = ''; _actionError = ''; });
    try {
      final d = await SalesServiceOps.getSalesOrderDetail(widget.order.name);
      if (!mounted) return;
      // Pre-fill delivery date: use existing value or default 14 days out
      final existing = d.deliveryDate.length >= 10 ? d.deliveryDate.substring(0, 10) : d.deliveryDate;
      _deliveryCtrl.text = existing.isNotEmpty
          ? existing
          : DateTime.now().add(const Duration(days: 14)).toIso8601String().substring(0, 10);
      setState(() { _detail = d; _loadingDetail = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loadingDetail = false; _error = e.toString(); });
    }
  }

  Future<void> _pickDeliveryDate() async {
    final current = DateTime.tryParse(_deliveryCtrl.text) ?? DateTime.now().add(const Duration(days: 14));
    final isDark  = context.isDark;
    final picked  = await showDatePicker(
      context:      context,
      initialDate:  current,
      firstDate:    DateTime.now(),
      lastDate:     DateTime.now().add(const Duration(days: 730)),
      builder: (ctx, child) => Theme(
        data: isDark
            ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _teal))
            : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: _teal)),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _deliveryCtrl.text = picked.toIso8601String().substring(0, 10);
        _actionError = '';
      });
    }
  }

  Future<void> _submit() async {
    final d = _detail;
    if (d == null) return;

    // Validate delivery date
    final deliveryDate = _deliveryCtrl.text.trim();
    if (deliveryDate.isEmpty) {
      setState(() => _actionError = 'Delivery date is required before confirming the order.');
      return;
    }
    setState(() => _actionError = '');

    final confirmed = await _confirm(
      title: 'Confirm Sales Order?',
      body:  'This will lock ${d.name} and send it to the customer. Make sure the delivery date is correct.',
      label: 'Confirm',
      color: const Color(0xFF10B981),
    );
    if (!confirmed || !mounted) return;
    setState(() => _acting = true);
    try {
      // Save delivery date first if it changed
      final existing = d.deliveryDate.length >= 10 ? d.deliveryDate.substring(0, 10) : d.deliveryDate;
      if (deliveryDate != existing) {
        await SalesServiceOps.updateSalesOrder(d.name, {'delivery_date': deliveryDate});
      }
      await SalesServiceOps.submitSalesOrder(d.name);
      if (!mounted) return;
      _showSnack('Sales Order confirmed', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() { _acting = false; _actionError = msg; });
    } finally {
      if (mounted && _acting) setState(() => _acting = false);
    }
  }

  Future<void> _cancel() async {
    final d = _detail;
    if (d == null) return;
    final confirmed = await _confirm(
      title: 'Cancel Sales Order?',
      body:  'This will cancel ${d.name}. This action cannot be undone.',
      label: 'Cancel Order',
      color: const Color(0xFFEF4444),
    );
    if (!confirmed || !mounted) return;
    setState(() { _acting = true; _actionError = ''; });
    try {
      await SalesServiceOps.cancelSalesOrder(d.name);
      if (!mounted) return;
      _showSnack('Sales Order cancelled', isError: false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() { _acting = false; _actionError = msg; });
    } finally {
      if (mounted && _acting) setState(() => _acting = false);
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

  String _fmt(double v, {String? currency}) {
    if (v == 0) return '—';
    final c = currency ?? _detail?.currency ?? 'Rs.';
    if (v >= 10000000) return '$c ${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000)   return '$c ${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)     return '$c ${(v / 1000).toStringAsFixed(0)}K';
    return '$c ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final bottom = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;
    final maxH   = MediaQuery.of(context).size.height * 0.92;

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
    child: Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5)),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.error_outline_rounded, color: context.ac.textTertiary, size: 40),
      const SizedBox(height: 14),
      Text('Could not load sales order', style: TextStyle(color: context.ac.textPrimary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(_error, style: TextStyle(color: context.ac.textSecondary, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: _fetchDetail,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _teal.withValues(alpha: 0.30)),
          ),
          child: const Text('Retry', style: TextStyle(color: _teal, fontWeight: FontWeight.w600)),
        ),
      ),
    ]),
  );

  Widget _buildContent(AdaptiveColors ac, bool isDark, double bottomInset) {
    final d           = _detail!;
    final statusColor = _statusColors[d.status] ?? _slate;
    final dColor      = _deliveryColors[d.deliveryStatus] ?? _slate;
    final bColor      = _billingColors[d.billingStatus] ?? _slate;
    final hasTaxes    = d.totalTaxes > 0;

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
                Text(d.customerName,
                    style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                if (d.company.isNotEmpty)
                  Text(d.company, style: TextStyle(color: ac.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  _GlassChip(label: d.status, color: statusColor),
                  const SizedBox(width: 6),
                  Text(d.name, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmt(d.grandTotal),
                  style: const TextStyle(color: _teal, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              Text(d.currency, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
            ]),
          ]),

          const SizedBox(height: 16),

          // ── Delivery / billing status chips ─────────────────────────────
          if (d.deliveryStatus.isNotEmpty || d.billingStatus.isNotEmpty) ...[
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (d.deliveryStatus.isNotEmpty)
                _GlassChip(label: 'Delivery: ${d.deliveryStatus}', color: dColor),
              if (d.billingStatus.isNotEmpty)
                _GlassChip(label: 'Billing: ${d.billingStatus}', color: bColor),
              if (d.orderType.isNotEmpty)
                _GlassChip(label: d.orderType, color: _indigo),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Order details card ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        isDark ? const Color(0xFF1A2235) : ac.bgCard,
              borderRadius: BorderRadius.circular(16),
              border:       Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
            ),
            child: Column(children: [
              if (d.transactionDate.isNotEmpty)
                _DetailRow(
                  icon:  Icons.receipt_long_rounded,
                  label: 'Order Date',
                  value: d.transactionDate.length >= 10 ? d.transactionDate.substring(0, 10) : d.transactionDate,
                  ac:    ac,
                ),
              if (d.transactionDate.isNotEmpty) _divider(isDark, ac),
              _DetailRow(
                icon:  Icons.currency_exchange_rounded,
                label: 'Currency',
                value: d.currency,
                ac:    ac,
              ),
              if (d.sellingPriceList.isNotEmpty) ...[
                _divider(isDark, ac),
                _DetailRow(
                  icon:  Icons.price_change_outlined,
                  label: 'Price List',
                  value: d.sellingPriceList,
                  ac:    ac,
                ),
              ],
              if (d.contactDisplay.isNotEmpty) ...[
                _divider(isDark, ac),
                _DetailRow(
                  icon:  Icons.person_outline_rounded,
                  label: 'Contact',
                  value: d.contactDisplay,
                  ac:    ac,
                ),
              ],
            ]),
          ),

          const SizedBox(height: 16),

          // ── Delivery Date (editable if Draft) ────────────────────────────
          _SectionHeader(label: 'DELIVERY DATE', ac: ac),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: d.isDraft ? _pickDeliveryDate : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _actionError.toLowerCase().contains('delivery date')
                      ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                      : d.isDraft
                          ? _teal.withValues(alpha: 0.35)
                          : isDark ? Colors.white.withValues(alpha: 0.07) : ac.border,
                  width: _actionError.toLowerCase().contains('delivery date') ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(Icons.local_shipping_outlined,
                    size: 18,
                    color: d.isDraft ? _teal : ac.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _deliveryCtrl.text.isNotEmpty ? _deliveryCtrl.text : 'Tap to set delivery date',
                      style: TextStyle(
                        color: _deliveryCtrl.text.isNotEmpty ? ac.textPrimary : ac.textTertiary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (d.isDraft)
                      Text('Tap to change', style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                  ]),
                ),
                if (d.isDraft)
                  Icon(Icons.edit_calendar_rounded, size: 16, color: _teal.withValues(alpha: 0.7)),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // ── Line items ───────────────────────────────────────────────────
          if (d.items.isNotEmpty) ...[
            _SectionHeader(label: 'LINE ITEMS  (${d.items.length})', ac: ac),
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
                  final uomLabel = item.uom.isNotEmpty ? item.uom : 'unit';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: i < d.items.length - 1
                          ? Border(bottom: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : ac.borderLight,
                            ))
                          : null,
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(Icons.inventory_2_outlined, size: 17, color: _teal),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.itemName.isNotEmpty ? item.itemName : item.itemCode,
                              style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          if (item.itemCode.isNotEmpty && item.itemName.isNotEmpty)
                            Text(item.itemCode, style: TextStyle(color: ac.textTertiary, fontSize: 11)),
                          const SizedBox(height: 2),
                          Text(
                            '${item.qty.toStringAsFixed(item.qty % 1 == 0 ? 0 : 1)} $uomLabel  ×  ${_fmt(item.rate)}',
                            style: TextStyle(color: ac.textSecondary, fontSize: 11),
                          ),
                          if (item.warehouse.isNotEmpty)
                            Text('Warehouse: ${item.warehouse}',
                                style: TextStyle(color: ac.textTertiary, fontSize: 10),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      const SizedBox(width: 12),
                      Text(_fmt(item.amount),
                          style: TextStyle(color: ac.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),

            // ── Totals breakdown ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A2235) : ac.bgCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border),
              ),
              child: Column(children: [
                if (hasTaxes) ...[
                  Row(children: [
                    Text('Net Total', style: TextStyle(color: ac.textSecondary, fontSize: 12)),
                    const Spacer(),
                    Text(_fmt(d.netTotal), style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Text(
                      d.taxesAndCharges.isNotEmpty ? d.taxesAndCharges : 'Tax',
                      style: TextStyle(color: ac.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text('+ ${_fmt(d.totalTaxes)}', style: TextStyle(color: const Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),
                  Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.borderLight),
                  const SizedBox(height: 10),
                ],
                Row(children: [
                  Text('GRAND TOTAL',
                      style: TextStyle(color: ac.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const Spacer(),
                  Text(_fmt(d.grandTotal),
                      style: const TextStyle(color: _teal, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
          ],

          // ── Inline action error banner ────────────────────────────────────
          if (_actionError.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:        const Color(0xFFEF4444).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.40)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_actionError,
                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _actionError = ''),
                  child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16),
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
              child: const Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2.5)),
            )
          else ...[
            if (d.isDraft) ...[
              _ActionButton(
                label:  'Confirm Sales Order',
                icon:   Icons.check_circle_outline_rounded,
                color:  const Color(0xFF10B981),
                onTap:  _submit,
              ),
              const SizedBox(height: 10),
              _ActionButton(
                label:    'Discard / Cancel',
                icon:     Icons.cancel_outlined,
                color:    const Color(0xFFEF4444),
                outlined: true,
                onTap:    _cancel,
              ),
            ] else if (d.isSubmitted) ...[
              _ActionButton(
                label:    'Cancel Order',
                icon:     Icons.cancel_outlined,
                color:    const Color(0xFFEF4444),
                outlined: true,
                onTap:    _cancel,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _divider(bool isDark, AdaptiveColors ac) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Divider(
      height: 1,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : ac.borderLight,
    ),
  );
}

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
    Text(value, style: TextStyle(color: ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
  ]);
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

// ─────────────────────────────────────────────────────────────────────────────
// New Quote sheet — searches leads and creates a new draft quotation
// ─────────────────────────────────────────────────────────────────────────────

class _NewQuoteSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _NewQuoteSheet({required this.onCreated});

  @override
  State<_NewQuoteSheet> createState() => _NewQuoteSheetState();
}

class _QuoteLineDraft {
  final itemCodeCtrl = TextEditingController();
  final qtyCtrl      = TextEditingController(text: '1');
  final rateCtrl     = TextEditingController();
  String itemName    = '';
  List<FrappeItem> suggestions = [];
  bool searching     = false;

  double get qty    => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get rate   => double.tryParse(rateCtrl.text.trim()) ?? 0;
  double get amount => qty * rate;

  void dispose() {
    itemCodeCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

class _NewQuoteSheetState extends State<_NewQuoteSheet> {
  final _searchCtrl  = TextEditingController();
  final _noteCtrl    = TextEditingController();

  List<CrmLead> _suggestions = [];
  CrmLead?      _selected;
  bool          _searching   = false;
  String        _partyType   = 'Lead';
  String        _currency    = 'LKR';
  String        _validTill   = '';
  bool          _busy        = false;
  String?       _error;
  String?       _leadError;

  String  _company          = '';
  String  _sellingPriceList = '';
  bool    _fetchingDefaults = false;

  final List<_QuoteLineDraft> _items = [_QuoteLineDraft()];

  List<_QuoteLineDraft> get _validItems =>
      _items.where((d) => d.itemCodeCtrl.text.trim().isNotEmpty && d.qty > 0).toList();
  double get _totalQty   => _validItems.fold(0.0, (s, d) => s + d.qty);
  double get _grandTotal => _validItems.fold(0.0, (s, d) => s + d.amount);

  @override
  void initState() {
    super.initState();
    _searchLeads('');
  }

  /// Pulls the real company/currency/price-list defaults for the selected
  /// lead from Frappe, instead of guessing with a hardcoded currency.
  Future<void> _fetchQuotationDefaults() async {
    final lead = _selected;
    if (lead == null) return;
    setState(() => _fetchingDefaults = true);
    try {
      final defaults = await SalesServiceOps.getQuotationDefaults(
        leadDocname: lead.name,
        partyType:   _partyType,
      );
      if (!mounted) return;
      setState(() {
        _company          = defaults.company;
        _sellingPriceList = defaults.sellingPriceList;
        if (defaults.currency.isNotEmpty) _currency = defaults.currency;
        _fetchingDefaults = false;
      });
    } catch (_) {
      if (mounted) setState(() => _fetchingDefaults = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItemRow() => setState(() => _items.add(_QuoteLineDraft()));

  void _removeItemRow(int index) => setState(() {
        _items[index].dispose();
        _items.removeAt(index);
      });

  /// Empty query still hits the backend — it returns a browse-all list
  /// (matching the "%%" wildcard server-side), same UX as the Lead search
  /// showing an initial list before the user types anything.
  Future<void> _searchItemsFor(_QuoteLineDraft draft, String query) async {
    setState(() => draft.searching = true);
    final results = await SalesServiceOps.searchItems(query.trim());
    if (!mounted) return;
    setState(() {
      draft.suggestions = results;
      draft.searching   = false;
    });
  }

  Future<void> _pickValidTill() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _validTill =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
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

  Future<void> _submit() async {
    setState(() { _leadError = null; _error = null; });

    if (_selected == null) {
      setState(() => _leadError = 'Select a lead first');
      return;
    }
    final validItems = _validItems;
    if (validItems.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }

    setState(() { _busy = true; _error = null; });
    try {
      await SalesService.createQuotation(
        leadDocname: _selected!.name,
        partyType:   _partyType,
        subject:     'Quotation for ${_selected!.displayName}',
        amount:      _grandTotal,
        note:        _noteCtrl.text.trim(),
        currency:    _currency,
        validTill:   _validTill,
        sellingPriceList: _sellingPriceList,
        items: validItems.map((d) => {
          'item_code': d.itemCodeCtrl.text.trim(),
          'item_name': d.itemName.isNotEmpty ? d.itemName : d.itemCodeCtrl.text.trim(),
          'qty':       d.qty,
          'rate':      d.rate,
        }).toList(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Quotation created for ${_selected!.displayName}'),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ));
    } catch (e) {
      setState(() { _busy = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac     = context.ac;
    final isDark = context.isDark;
    final inset  = MediaQuery.of(context).viewInsets.bottom;
    final maxH   = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : ac.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : ac.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        Flexible(child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(22, 8, 22, 20 + inset),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: _amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _amber.withValues(alpha: 0.30)),
                ),
                child: const Icon(Icons.description_rounded, color: _amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('New Quotation', style: TextStyle(color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                Text('Create a draft quote linked to a lead', style: TextStyle(color: ac.textSecondary, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 20),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.30))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // ── Party & Lead ─────────────────────────────────────────────────
            Text('PARTY', style: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            Text('Party Type', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Row(children: ['Lead', 'Customer'].map((t) {
              final sel = t == _partyType;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: t == 'Lead' ? 6 : 0, left: t == 'Customer' ? 6 : 0),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _partyType = t);
                    if (_selected != null) _fetchQuotationDefaults();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _amber.withValues(alpha: 0.15) : ac.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? _amber.withValues(alpha: 0.50) : ac.border),
                    ),
                    child: Center(child: Text(t, style: TextStyle(color: sel ? _amber : ac.textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, fontSize: 13))),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Lead search / selected chip
            Text('Select Lead *', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            if (_selected != null)
              GestureDetector(
                onTap: () => setState(() { _selected = null; _company = ''; _sellingPriceList = ''; _searchCtrl.clear(); _searchLeads(''); }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: _amber.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: _amber.withValues(alpha: 0.40))),
                  child: Row(children: [
                    const Icon(Icons.person_rounded, color: _amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_selected!.displayName, style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600)),
                      if (_fetchingDefaults)
                        Text('Fetching company defaults…', style: TextStyle(color: ac.textSecondary, fontSize: 11))
                      else if (_company.isNotEmpty)
                        Text(_company, style: TextStyle(color: ac.textSecondary, fontSize: 11)),
                    ])),
                    if (_fetchingDefaults)
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _amber))
                    else
                      Icon(Icons.close_rounded, color: ac.textSecondary, size: 16),
                  ]),
                ),
              )
            else ...[
              TextField(
                controller: _searchCtrl,
                enabled: !_busy,
                onChanged: (v) {
                  setState(() => _leadError = null);
                  _searchLeads(v.trim());
                },
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or email…',
                  hintStyle: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 13),
                  errorText: _leadError,
                  filled: true,
                  fillColor: ac.bgInput,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ac.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ac.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _amber, width: 1.5)),
                  prefixIcon: const Icon(Icons.search_rounded, color: _slate, size: 18),
                ),
              ),
              if (_searching)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _amber))))
              else if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(color: ac.bgInput, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.border)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) {
                      final l = _suggestions[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() { _selected = l; _suggestions = []; });
                          _fetchQuotationDefaults();
                        },
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
            const SizedBox(height: 20),

            // ── Pricing ──────────────────────────────────────────────────────
            Text('PRICING', style: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 10),
            Text('Currency', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            Row(children: ['USD', 'LKR', 'EUR', 'GBP', 'INR'].map((code) {
              final sel = code == _currency;
              return Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: _busy ? null : () => setState(() => _currency = code),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? _amber.withValues(alpha: 0.15) : ac.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? _amber.withValues(alpha: 0.50) : ac.border),
                    ),
                    child: Center(child: Text(code, style: TextStyle(color: sel ? _amber : ac.textSecondary, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, fontSize: 12))),
                  ),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),

            // Valid Till
            GestureDetector(
              onTap: _busy ? null : _pickValidTill,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: ac.bgInput, borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.border)),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 15, color: _amber),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Valid Till', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700)),
                    Text(_validTill.isEmpty ? 'Tap to set an expiry date' : _validTill,
                        style: TextStyle(color: _validTill.isEmpty ? ac.textSecondary : ac.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // ── Items — table style: No. | Item Code | Qty | Rate | Amount ────
            Text('ITEMS', style: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: ac.border)),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(color: ac.bgInput, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                  child: Row(children: [
                    SizedBox(width: 20, child: Text('No.', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
                    Expanded(child: Text('Item Code', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
                    SizedBox(width: 44, child: Text('Qty', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
                    SizedBox(width: 64, child: Text('Rate ($_currency)', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
                    SizedBox(width: 68, child: Text('Amount ($_currency)', style: TextStyle(color: ac.textSecondary, fontSize: 9, fontWeight: FontWeight.w700))),
                  ]),
                ),
                for (var i = 0; i < _items.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: ac.border),
                  _QuoteItemRow(
                    rowNumber: i + 1,
                    draft: _items[i],
                    ac: ac,
                    isDark: isDark,
                    onChanged: () => setState(() {}),
                    onQueryChanged: (q) => _searchItemsFor(_items[i], q),
                    onPick: (item) => setState(() {
                      _items[i].itemCodeCtrl.text = item.itemCode;
                      _items[i].itemName = item.itemName;
                      if (item.standardRate > 0) _items[i].rateCtrl.text = item.standardRate.toStringAsFixed(2);
                      _items[i].suggestions = [];
                    }),
                    onRemove: _items.length > 1 ? () => _removeItemRow(i) : null,
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _addItemRow,
              icon: const Icon(Icons.add_rounded, color: _amber, size: 16),
              label: const Text('Add Item', style: TextStyle(color: _amber, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            const SizedBox(height: 8),

            // Totals
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Quantity', style: TextStyle(color: ac.textSecondary, fontSize: 12)),
              Text('$_totalQty', style: TextStyle(color: ac.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Grand Total', style: TextStyle(color: ac.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('$_currency ${_grandTotal.toStringAsFixed(2)}', style: const TextStyle(color: _amber, fontSize: 16, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 14),

            // Note
            Text('Note', style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            TextField(
              controller: _noteCtrl,
              enabled: !_busy,
              maxLines: 3,
              style: TextStyle(color: ac.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Optional note for this quotation…',
                hintStyle: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 13),
                filled: true, fillColor: ac.bgInput,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ac.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ac.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _amber, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: ac.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: TextStyle(color: ac.textSecondary, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _amber,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.description_rounded, color: Colors.white, size: 18),
                label: Text(_busy ? 'Creating…' : 'Create Quote',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              )),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One row inside the New Quote items table (No. | Item Code | Qty | Rate | Amount)
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteItemRow extends StatelessWidget {
  final int rowNumber;
  final _QuoteLineDraft draft;
  final AdaptiveColors ac;
  final bool isDark;
  final VoidCallback onChanged;
  final void Function(String) onQueryChanged;
  final void Function(FrappeItem) onPick;
  final VoidCallback? onRemove;

  const _QuoteItemRow({
    required this.rowNumber,
    required this.draft,
    required this.ac,
    required this.isDark,
    required this.onChanged,
    required this.onQueryChanged,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox(width: 20, child: Text('$rowNumber', style: TextStyle(color: ac.textSecondary, fontSize: 12))),
          SizedBox(
            width: 44,
            child: TextField(
              controller: draft.qtyCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ac.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true, fillColor: ac.bgInput,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 64,
            child: TextField(
              controller: draft.rateCtrl,
              onChanged: (_) => onChanged(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: ac.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                filled: true, fillColor: ac.bgInput,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 68,
            child: Text(
              draft.amount.toStringAsFixed(2),
              style: const TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRemove != null)
            SizedBox(
              width: 22,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: Icon(Icons.close_rounded, color: ac.textSecondary),
                onPressed: onRemove,
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Focus(
          // Fetch a browse-all list the moment the field is focused —
          // matches the Lead search, which shows results before typing.
          onFocusChange: (hasFocus) {
            if (hasFocus && draft.itemCodeCtrl.text.trim().isEmpty) {
              onQueryChanged('');
            }
          },
          child: TextField(
            controller: draft.itemCodeCtrl,
            onChanged: onQueryChanged,
            style: TextStyle(color: ac.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: draft.itemName.isNotEmpty ? draft.itemName : 'Search item…',
              hintStyle: TextStyle(color: ac.textSecondary.withValues(alpha: 0.60), fontSize: 12),
              isDense: true,
              filled: true, fillColor: ac.bgInput,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ac.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ac.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _amber, width: 1.5)),
            ),
          ),
        ),
        if (draft.searching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _amber))),
          )
        else if (draft.suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 140),
            decoration: BoxDecoration(color: ac.bgInput, borderRadius: BorderRadius.circular(10), border: Border.all(color: ac.border)),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: draft.suggestions.length,
              itemBuilder: (_, i) {
                final item = draft.suggestions[i];
                return InkWell(
                  onTap: () => onPick(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.itemCode, style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
                      Text(
                        item.standardRate > 0 ? '${item.itemName} · ${item.standardRate.toStringAsFixed(2)}' : item.itemName,
                        style: TextStyle(color: ac.textSecondary, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}
