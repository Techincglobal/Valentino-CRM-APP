import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

const _indigo = Color(0xFF2490EF); // brand accent (kept name for minimal diff)
const _blue   = _indigo; // collapsed into the single brand blue
const _green  = Color(0xFF10B981);
const _amber  = Color(0xFFF59E0B);
const _red    = Color(0xFFEF4444);
const _slate  = Color(0xFF64748B);
const _purple = Color(0xFF1A7FD4); // collapsed into the single brand blue

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  StreamSubscription<LogEntry>? _sub;
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();

  List<LogEntry> _entries = [];
  LogLevel? _filterLevel;
  String _search = '';
  bool _autoScroll = true;
  String? _serverUrl;
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _entries = List.of(AppLogger.entries);
    _sub = AppLogger.stream.listen((entry) {
      if (!mounted) return;
      setState(() => _entries.add(entry));
      if (_autoScroll && _tabCtrl.index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    final url  = await StorageService.getBaseUrl();
    final name = await StorageService.getFullName();
    if (mounted) setState(() { _serverUrl = url; _fullName = name; });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _sub?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LogEntry> get _filtered {
    var list = _entries;
    if (_filterLevel != null) list = list.where((e) => e.level == _filterLevel).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((e) =>
        e.tag.toLowerCase().contains(q) ||
        e.message.toLowerCase().contains(q) ||
        (e.detail?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  int _count(LogLevel l) => _entries.where((e) => e.level == l).length;

  Map<String, int> get _tagCounts {
    final m = <String, int>{};
    for (final e in _entries) { m[e.tag] = (m[e.tag] ?? 0) + 1; }
    final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  Map<int, int> get _hourlyErrors {
    final now = DateTime.now();
    final m = <int, int>{};
    for (var i = 0; i < 12; i++) { m[i] = 0; }
    for (final e in _entries) {
      if (e.level != LogLevel.error && e.level != LogLevel.warn) continue;
      final diff = now.difference(e.timestamp).inHours;
      if (diff < 12) m[11 - diff] = (m[11 - diff] ?? 0) + 1;
    }
    return m;
  }

  void _copyAll() {
    final text = _filtered.map((e) => e.toPlainText()).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _snack('Logs copied to clipboard', _green);
  }

  void _signOut() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Exit the admin panel and return to the login screen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            child: const Text('Sign Out', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('This will clear all in-memory logs. Cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              AppLogger.clear();
              setState(() => _entries = []);
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  Color _levelColor(LogLevel l) => switch (l) {
    LogLevel.debug => _slate,
    LogLevel.info  => _blue,
    LogLevel.warn  => _amber,
    LogLevel.error => _red,
  };

  Color _levelBg(LogLevel l) => switch (l) {
    LogLevel.debug => _slate.withValues(alpha: 0.08),
    LogLevel.info  => _blue.withValues(alpha: 0.08),
    LogLevel.warn  => _amber.withValues(alpha: 0.10),
    LogLevel.error => _red.withValues(alpha: 0.10),
  };

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Scaffold(
      backgroundColor: ac.bgBase,
      body: Column(
        children: [
          _Header(
            entryCount: _entries.length,
            serverUrl: _serverUrl,
            fullName: _fullName,
            tabCtrl: _tabCtrl,
            onCopy: _copyAll,
            onClear: _clearLogs,
            onBack: () => Navigator.pop(context),
            onSignOut: _signOut,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _LogsTab(
                  entries: _filtered,
                  filterLevel: _filterLevel,
                  search: _search,
                  autoScroll: _autoScroll,
                  searchCtrl: _searchCtrl,
                  scrollCtrl: _scrollCtrl,
                  levelColor: _levelColor,
                  levelBg: _levelBg,
                  onFilterChanged: (l) => setState(() => _filterLevel = l),
                  onSearchChanged: (v) => setState(() => _search = v),
                  onSearchClear: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  onAutoScrollToggle: () => setState(() => _autoScroll = !_autoScroll),
                ),
                _ChartsTab(
                  entries: _entries,
                  debugCount: _count(LogLevel.debug),
                  infoCount:  _count(LogLevel.info),
                  warnCount:  _count(LogLevel.warn),
                  errorCount: _count(LogLevel.error),
                  tagCounts:  _tagCounts,
                  hourlyErrors: _hourlyErrors,
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
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int entryCount;
  final String? serverUrl;
  final String? fullName;
  final TabController tabCtrl;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final VoidCallback onBack;
  final VoidCallback onSignOut;

  const _Header({
    required this.entryCount,
    required this.serverUrl,
    required this.fullName,
    required this.tabCtrl,
    required this.onCopy,
    required this.onClear,
    required this.onBack,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF14528C), Color(0xFF1A7FD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Color(0x404F46E5), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: top + 12),

          // ── Title row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                ),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Panel',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Text('$entryCount entries in memory',
                        style: const TextStyle(color: Color(0xFFBFBFF8), fontSize: 12)),
                    ],
                  ),
                ),
                _HeaderBtn(icon: Icons.copy_rounded, tooltip: 'Copy', onTap: onCopy),
                const SizedBox(width: 6),
                _HeaderBtn(icon: Icons.delete_outline_rounded, tooltip: 'Clear', onTap: onClear),
                const SizedBox(width: 6),
                _HeaderBtn(icon: Icons.logout_rounded, tooltip: 'Sign Out', onTap: onSignOut),
              ],
            ),
          ),

          // ── Server info pill ───────────────────────────────────────────────
          if (serverUrl != null || fullName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                ),
                child: Row(children: [
                  const Icon(Icons.cloud_done_outlined, color: Colors.white, size: 14),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(serverUrl ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (fullName != null) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.person_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 5),
                    Text(fullName!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),

          const SizedBox(height: 12),

          // ── Tab bar ────────────────────────────────────────────────────────
          TabBar(
            controller: tabCtrl,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: const Color(0xFFBFBFF8),
            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Logs'),
              Tab(icon: Icon(Icons.bar_chart_rounded, size: 18), text: 'Charts'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logs Tab
// ─────────────────────────────────────────────────────────────────────────────

class _LogsTab extends StatelessWidget {
  final List<LogEntry> entries;
  final LogLevel? filterLevel;
  final String search;
  final bool autoScroll;
  final TextEditingController searchCtrl;
  final ScrollController scrollCtrl;
  final Color Function(LogLevel) levelColor;
  final Color Function(LogLevel) levelBg;
  final void Function(LogLevel?) onFilterChanged;
  final void Function(String) onSearchChanged;
  final VoidCallback onSearchClear;
  final VoidCallback onAutoScrollToggle;

  const _LogsTab({
    required this.entries,
    required this.filterLevel,
    required this.search,
    required this.autoScroll,
    required this.searchCtrl,
    required this.scrollCtrl,
    required this.levelColor,
    required this.levelBg,
    required this.onFilterChanged,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.onAutoScrollToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Column(
      children: [
        // ── Search + filters ────────────────────────────────────────────────
        Container(
          color: ac.bgCard,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(children: [
            // Search bar
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: ac.bgBase,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ac.border),
              ),
              child: TextField(
                controller: searchCtrl,
                style: TextStyle(color: ac.textPrimary, fontSize: 14),
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search tag, message, detail…',
                  hintStyle: TextStyle(color: ac.textTertiary, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: ac.textTertiary, size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  suffixIcon: search.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: ac.textTertiary, size: 16),
                          onPressed: onSearchClear,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Filter chips row
            SizedBox(
              height: 30,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _LevelChip(
                    label: 'All',
                    active: filterLevel == null,
                    activeColor: _indigo,
                    inactiveColor: ac.textSecondary,
                    activeBg: ac.bgBase,
                    onTap: () => onFilterChanged(null),
                  ),
                  const SizedBox(width: 6),
                  for (final lvl in LogLevel.values) ...[
                    _LevelChip(
                      label: lvl.name.toUpperCase(),
                      active: filterLevel == lvl,
                      activeColor: levelColor(lvl),
                      inactiveColor: ac.textSecondary,
                      activeBg: ac.bgBase,
                      onTap: () => onFilterChanged(filterLevel == lvl ? null : lvl),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: onAutoScrollToggle,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: autoScroll ? _green.withValues(alpha: 0.12) : ac.bgBase,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: autoScroll ? _green.withValues(alpha: 0.5) : ac.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.vertical_align_bottom_rounded, size: 13, color: autoScroll ? _green : ac.textTertiary),
                        const SizedBox(width: 4),
                        Text('Auto-scroll',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: autoScroll ? _green : ac.textTertiary)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // ── Log list ────────────────────────────────────────────────────────
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.notes_rounded, size: 44, color: ac.textTertiary),
                    const SizedBox(height: 10),
                    Text('No logs', style: TextStyle(color: ac.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(search.isNotEmpty ? 'Try a different search' : 'Logs will appear as the app runs',
                        style: TextStyle(color: ac.textTertiary, fontSize: 13)),
                  ]),
                )
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _LogRow(
                    entry: entries[i],
                    levelColor: levelColor(entries[i].level),
                    levelBg: levelBg(entries[i].level),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final Color activeBg;
  final VoidCallback onTap;
  const _LevelChip({
    required this.label, required this.active, required this.activeColor,
    required this.inactiveColor, required this.activeBg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : activeBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? activeColor.withValues(alpha: 0.5) : ac.border),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: active ? activeColor : inactiveColor)),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  final Color    levelColor;
  final Color    levelBg;
  const _LogRow({required this.entry, required this.levelColor, required this.levelBg});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: entry.toPlainText()));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Entry copied'),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 1),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: levelBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: levelColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _Badge(text: entry.levelLabel, color: levelColor),
              const SizedBox(width: 6),
              _Badge(text: entry.tag, color: _slate),
              const Spacer(),
              Text(entry.timeLabel,
                style: TextStyle(color: ac.textTertiary, fontSize: 10, fontFamily: 'monospace')),
            ]),
            const SizedBox(height: 5),
            Text(entry.message,
              style: TextStyle(color: ac.textPrimary, fontSize: 12.5, fontFamily: 'monospace')),
            if (entry.detail != null && entry.detail!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(entry.detail!,
                style: TextStyle(color: ac.textTertiary, fontSize: 11, fontFamily: 'monospace'),
                maxLines: 5,
                overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color  color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Charts Tab
// ─────────────────────────────────────────────────────────────────────────────

class _ChartsTab extends StatelessWidget {
  final List<LogEntry> entries;
  final int debugCount;
  final int infoCount;
  final int warnCount;
  final int errorCount;
  final Map<String, int> tagCounts;
  final Map<int, int>    hourlyErrors;

  const _ChartsTab({
    required this.entries,
    required this.debugCount,
    required this.infoCount,
    required this.warnCount,
    required this.errorCount,
    required this.tagCounts,
    required this.hourlyErrors,
  });

  int get _total => debugCount + infoCount + warnCount + errorCount;

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Stat cards ───────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(label: 'Total',  value: '$_total',     color: _indigo, icon: Icons.list_alt_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Errors', value: '$errorCount', color: _red,    icon: Icons.error_outline_rounded)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _StatCard(label: 'Warnings', value: '$warnCount',  color: _amber, icon: Icons.warning_amber_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(label: 'Info',     value: '$infoCount',  color: _blue,  icon: Icons.info_outline_rounded)),
        ]),

        const SizedBox(height: 20),

        // ── Log level distribution (pie) ────────────────────────────────────
        _ChartCard(
          title: 'Log Level Distribution',
          subtitle: '$_total total entries',
          legend: _total == 0 ? null : Wrap(spacing: 12, runSpacing: 6, children: [
            if (debugCount > 0) _LegendDot(label: 'Debug ($debugCount)', color: _slate),
            if (infoCount  > 0) _LegendDot(label: 'Info ($infoCount)',   color: _blue),
            if (warnCount  > 0) _LegendDot(label: 'Warn ($warnCount)',   color: _amber),
            if (errorCount > 0) _LegendDot(label: 'Error ($errorCount)', color: _red),
          ]),
          child: _total == 0
              ? _EmptyChart(ac: ac)
              : SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    sections: [
                      if (debugCount > 0) _pie('Debug', debugCount, _slate),
                      if (infoCount  > 0) _pie('Info',  infoCount,  _blue),
                      if (warnCount  > 0) _pie('Warn',  warnCount,  _amber),
                      if (errorCount > 0) _pie('Error', errorCount, _red),
                    ],
                  )),
                ),
        ),

        const SizedBox(height: 16),

        // ── Errors + Warnings over last 12 hours ────────────────────────────
        _ChartCard(
          title: 'Issues (Last 12 Hours)',
          subtitle: 'Errors & warnings by hour',
          child: hourlyErrors.values.every((v) => v == 0)
              ? _EmptyChart(ac: ac, message: 'No errors or warnings yet')
              : SizedBox(
                  height: 180,
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (hourlyErrors.values.reduce((a, b) => a > b ? a : b) + 1).toDouble(),
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i == 0) return const _AxisLabel('-12h');
                          if (i == 5) return const _AxisLabel('-6h');
                          if (i == 11) return const _AxisLabel('now');
                          return const SizedBox.shrink();
                        },
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => _AxisLabel(v.toInt().toString()),
                      )),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.15), strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(12, (i) => BarChartGroupData(
                      x: i,
                      barRods: [BarChartRodData(
                        toY: (hourlyErrors[i] ?? 0).toDouble(),
                        color: (hourlyErrors[i] ?? 0) > 0 ? _red : _slate.withValues(alpha: 0.3),
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      )],
                    )),
                  )),
                ),
        ),

        const SizedBox(height: 16),

        // ── Top tags horizontal bar chart ────────────────────────────────────
        if (tagCounts.isNotEmpty)
          _ChartCard(
            title: 'Top Services',
            subtitle: 'Log count by source tag',
            child: Column(
              children: tagCounts.entries.map((e) {
                final max = tagCounts.values.first;
                final frac = max > 0 ? e.value / max : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(e.key,
                          style: TextStyle(color: context.ac.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                        Text('${e.value}',
                          style: TextStyle(color: context.ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 4),
                      LayoutBuilder(builder: (_, c) => Stack(children: [
                        Container(height: 7, width: c.maxWidth,
                          decoration: BoxDecoration(
                            color: _indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          )),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          height: 7,
                          width: c.maxWidth * frac,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [_indigo, _purple]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ])),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  PieChartSectionData _pie(String title, int count, Color color) {
    final pct = _total > 0 ? (count / _total * 100).toStringAsFixed(0) : '0';
    return PieChartSectionData(
      value: count.toDouble(),
      color: color,
      radius: 52,
      title: '$pct%',
      titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chart helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? legend;
  const _ChartCard({required this.title, required this.subtitle, this.legend, required this.child});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: ac.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: ac.textTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          child,
          if (legend != null) ...[
            const SizedBox(height: 12),
            legend!,
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;
  final IconData icon;
  const _StatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ac.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: ac.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,  style: TextStyle(color: ac.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color  color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(color: context.ac.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class _EmptyChart extends StatelessWidget {
  final AdaptiveColors ac;
  final String message;
  const _EmptyChart({required this.ac, this.message = 'No data yet'});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.bar_chart_rounded, size: 36, color: ac.textTertiary),
      const SizedBox(height: 6),
      Text(message, style: TextStyle(color: ac.textTertiary, fontSize: 12)),
    ])),
  );
}

class _AxisLabel extends StatelessWidget {
  final String text;
  const _AxisLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: context.ac.textTertiary, fontSize: 9, fontWeight: FontWeight.w500));
}
