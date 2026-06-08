import 'dart:convert';
import 'api_service.dart';

String _parseFrappeError(String body, String fallback) {
  try {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return fallback;
    // HTML error page (nginx/apache) — never show to user
    if (trimmed.startsWith('<')) return fallback;

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return fallback;

    // 1. _server_messages — the most user-readable field Frappe provides
    final raw = decoded['_server_messages'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List && list.isNotEmpty) {
          try {
            final inner = jsonDecode(list.first.toString());
            if (inner is Map) {
              final msg = inner['message']?.toString().trim();
              if (msg != null && msg.isNotEmpty && !_looksInternal(msg)) return msg;
            }
          } catch (_) {
            final s = list.first.toString().trim();
            if (s.isNotEmpty && !_looksInternal(s)) return s;
          }
        }
      } catch (_) {}
    }

    // 2. exception field — strip the Python class prefix, keep the human message
    final exc = decoded['exception']?.toString() ?? '';
    if (exc.isNotEmpty) {
      // "frappe.exceptions.SomeError: The human message here"
      final idx = exc.indexOf(': ');
      final msg = (idx >= 0 ? exc.substring(idx + 2) : exc)
          .split('\n')
          .first
          .trim();
      if (msg.isNotEmpty && !_looksInternal(msg)) return msg;
    }

    // 3. exc_type as last resort — still better than raw JSON
    final excType = decoded['exc_type']?.toString().trim() ?? '';
    if (excType.isNotEmpty) return excType;
  } catch (_) {}
  return fallback;
}

/// Returns true if [msg] is a Python/Frappe internal message that should
/// never be shown directly to the user.
bool _looksInternal(String msg) {
  final lower = msg.toLowerCase();
  return msg.length > 200 ||
      lower.contains('traceback') ||
      lower.contains('get_attr') ||
      lower.contains('no attribute') ||
      lower.contains('file "') ||
      lower.contains('line ') ||
      msg.contains('{') ||
      msg.contains('\\n');
}

class CallLog {
  final String name;
  final String subject;
  final String content;
  final String phoneNo;
  final int durationSeconds;
  final String sentOrReceived;
  final String callType;       // "Regular" or "WhatsApp"
  final String referenceDoctype;
  final String referenceName;
  final String creation;

  const CallLog({
    required this.name,
    required this.subject,
    required this.content,
    required this.phoneNo,
    required this.durationSeconds,
    required this.sentOrReceived,
    required this.callType,
    required this.referenceDoctype,
    required this.referenceName,
    required this.creation,
  });

  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
        name:              j['name']?.toString() ?? '',
        subject:           j['subject']?.toString() ?? '',
        content:           j['content']?.toString() ?? '',
        phoneNo:           j['phone_no']?.toString() ?? '',
        durationSeconds:   int.tryParse(j['duration']?.toString() ?? '0') ?? 0,
        sentOrReceived:    j['sent_or_received']?.toString() ?? 'Received',
        callType:          j['call_type']?.toString() ?? 'Regular',
        referenceDoctype:  j['reference_doctype']?.toString() ?? '',
        referenceName:     j['reference_name']?.toString() ?? '',
        creation:          j['creation']?.toString() ?? '',
      );

  bool get isWhatsApp => callType == 'WhatsApp';

  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  String get timeLabel {
    if (creation.isEmpty) return '';
    try {
      final dt = DateTime.parse(creation);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      if (diff.inDays < 7)     return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  String get fullDateLabel {
    if (creation.isEmpty) return '';
    try {
      final dt = DateTime.parse(creation);
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  •  $h:$m';
    } catch (_) {
      return creation;
    }
  }

  String get callerLabel {
    // Subject is like "📞 Call — John Doe" or "📱 WhatsApp Call — Jane"
    final parts = subject.split('— ');
    if (parts.length > 1) return parts.last.trim();
    return phoneNo.isNotEmpty ? phoneNo : subject;
  }

  String get initials {
    final name = callerLabel.trim().split(RegExp(r'\s+'));
    if (name.isEmpty) return '?';
    if (name.length == 1) return name[0].isNotEmpty ? name[0][0].toUpperCase() : '?';
    return '${name[0][0]}${name[1][0]}'.toUpperCase();
  }
}

class CallLogService {
  static Future<List<CallLog>> getCallLogs() async {
    final resp = await ApiService.post(
        '/api/method/nxtgen_crm_mobile.api.get_call_logs', {});
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Could not load call logs (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (body['message'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(CallLog.fromJson)
        .toList();
  }

  static Future<String> createCallLog({
    required String phone,
    required String callerName,
    required int durationSeconds,
    required String direction,
    required String callType,
    String notes = '',
    String? leadDocname,
  }) async {
    final payload = <String, dynamic>{
      'phone':        phone,
      'caller_name':  callerName,
      'duration':     durationSeconds,
      'notes':        notes,
      'call_type':    callType,
      'direction':    direction,
    };
    if (leadDocname != null && leadDocname.isNotEmpty) {
      payload['lead_docname'] = leadDocname;
    }
    final resp = await ApiService.post(
        '/api/method/nxtgen_crm_mobile.api.create_call_log', payload);
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Could not create call log (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
    return msg['name']?.toString() ?? '';
  }
}
