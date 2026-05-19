import 'package:flutter/material.dart';
import '../services/call_log_service.dart';
import '../theme/app_theme.dart';

class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<CallLog> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final logs = await CallLogService.getCallLogs();
      if (mounted) setState(() { _logs = logs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ac     = context.ac;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: ac.bgBase,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: ac.bgBase,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Call Logs',
              style: TextStyle(
                color:      ac.textPrimary,
                fontSize:   20,
                fontWeight: FontWeight.w800,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: ac.textSecondary),
                onPressed: _load,
              ),
            ],
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: _ErrorState(message: _error!, onRetry: _load),
            )
          else if (_logs.isEmpty)
            const SliverFillRemaining(
              child: _EmptyState(),
            )
          else ...[
            // Summary card
            SliverToBoxAdapter(
              child: _SummaryCard(logs: _logs, isDark: isDark),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: SliverList.builder(
                itemCount: _logs.length,
                itemBuilder: (_, i) => _CallLogCard(log: _logs[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final List<CallLog> logs;
  final bool isDark;
  const _SummaryCard({required this.logs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total     = logs.length;
    final whatsapp  = logs.where((l) => l.isWhatsApp).length;
    final regular   = total - whatsapp;
    final totalSecs = logs.fold<int>(0, (s, l) => s + l.durationSeconds);
    final totalMins = totalSecs ~/ 60;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      const Color(0xFF3B82F6).withValues(alpha: 0.35),
            blurRadius: 20,
            offset:     const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          _Stat(label: 'Total',    value: '$total',      icon: Icons.call_rounded),
          const SizedBox(width: 16),
          _Stat(label: 'Regular',  value: '$regular',    icon: Icons.phone_rounded),
          const SizedBox(width: 16),
          _Stat(label: 'WhatsApp', value: '$whatsapp',   icon: Icons.chat_rounded),
          const SizedBox(width: 16),
          _Stat(label: 'Minutes',  value: '$totalMins',  icon: Icons.timer_rounded),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.80), size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Call log card
// ─────────────────────────────────────────────────────────────────────────────

class _CallLogCard extends StatelessWidget {
  final CallLog log;
  const _CallLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final ac      = context.ac;
    final isDark  = context.isDark;
    final isWA    = log.isWhatsApp;
    final accent  = isWA ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? null : ac.bgCard,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [const Color(0xFF1A2235), const Color(0xFF0D1526)],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : ac.border,
        ),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 10,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                log.initials,
                style: TextStyle(
                  color:      accent,
                  fontSize:   14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      log.callerLabel,
                      style: TextStyle(
                        color:      ac.textPrimary,
                        fontSize:   14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isWA) ...[
                    const SizedBox(width: 6),
                    _Badge('WhatsApp', const Color(0xFF22C55E)),
                  ],
                ]),
                const SizedBox(height: 3),
                if (log.content.isNotEmpty)
                  Text(
                    log.content,
                    style: TextStyle(color: ac.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.call_received_rounded,
                      size: 11, color: ac.textSecondary.withValues(alpha: 0.6)),
                  const SizedBox(width: 3),
                  Text(
                    log.sentOrReceived,
                    style: TextStyle(
                        color: ac.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                  ),
                  if (log.durationLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.timer_rounded,
                        size: 11, color: ac.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text(
                      log.durationLabel,
                      style: TextStyle(
                          color: ac.textSecondary.withValues(alpha: 0.6), fontSize: 11),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    log.timeLabel,
                    style: TextStyle(
                        color: ac.textSecondary.withValues(alpha: 0.55), fontSize: 11),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.call_outlined, size: 52, color: ac.textSecondary.withValues(alpha: 0.35)),
        const SizedBox(height: 12),
        Text('No calls logged yet',
            style: TextStyle(
                color: ac.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Tap "Log Call" in the overlay during a call',
            style: TextStyle(color: ac.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ac = context.ac;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded,
            size: 48, color: Colors.red.withValues(alpha: 0.60)),
        const SizedBox(height: 12),
        Text('Failed to load call logs',
            style: TextStyle(color: ac.textPrimary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(message,
            style: TextStyle(color: ac.textSecondary, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}
