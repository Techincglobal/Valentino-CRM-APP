import 'dart:async';
import 'dart:collection';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  final DateTime   timestamp;
  final LogLevel   level;
  final String     tag;
  final String     message;
  final String?    detail; // stack trace or extra JSON

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.detail,
  });

  String get levelLabel => switch (level) {
    LogLevel.debug => 'DBG',
    LogLevel.info  => 'INF',
    LogLevel.warn  => 'WRN',
    LogLevel.error => 'ERR',
  };

  String get timeLabel {
    final h  = timestamp.hour.toString().padLeft(2, '0');
    final m  = timestamp.minute.toString().padLeft(2, '0');
    final s  = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toPlainText() {
    final buf = StringBuffer('[${timestamp.toIso8601String()}] [$levelLabel] [$tag] $message');
    if (detail != null && detail!.isNotEmpty) {
      buf.write('\n  $detail');
    }
    return buf.toString();
  }
}

class AppLogger {
  AppLogger._();
  static final AppLogger _instance = AppLogger._();

  static const int _maxEntries = 2000;

  final Queue<LogEntry> _entries = Queue();
  final StreamController<LogEntry> _controller =
      StreamController<LogEntry>.broadcast();

  static Stream<LogEntry> get stream => _instance._controller.stream;
  static List<LogEntry>   get entries => List.unmodifiable(_instance._entries);

  static void debug(String tag, String message, [String? detail]) =>
      _instance._add(LogLevel.debug, tag, message, detail);

  static void info(String tag, String message, [String? detail]) =>
      _instance._add(LogLevel.info, tag, message, detail);

  static void warn(String tag, String message, [String? detail]) =>
      _instance._add(LogLevel.warn, tag, message, detail);

  static void error(String tag, String message, [Object? err]) {
    final detail = err?.toString();
    _instance._add(LogLevel.error, tag, message, detail);
  }

  void _add(LogLevel level, String tag, String message, String? detail) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level:     level,
      tag:       tag,
      message:   message,
      detail:    detail,
    );
    _entries.addLast(entry);
    if (_entries.length > _maxEntries) _entries.removeFirst();
    _controller.add(entry);
  }

  static void clear() {
    _instance._entries.clear();
  }

  static String exportAll() =>
      _instance._entries.map((e) => e.toPlainText()).join('\n');
}
