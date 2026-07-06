import 'dart:convert';
import 'api_service.dart';

String _parseFrappeError(String body, String fallback) {
  try {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return fallback;
    if (trimmed.startsWith('<')) return fallback;

    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) return fallback;

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

    final exc = decoded['exception']?.toString() ?? '';
    if (exc.isNotEmpty) {
      final idx = exc.indexOf(': ');
      final msg = (idx >= 0 ? exc.substring(idx + 2) : exc)
          .split('\n')
          .first
          .trim();
      if (msg.isNotEmpty && !_looksInternal(msg)) return msg;
    }

    final excType = decoded['exc_type']?.toString().trim() ?? '';
    if (excType.isNotEmpty) return excType;
  } catch (_) {}
  return fallback;
}

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
  final String phoneNumber;
  final String callerName;
  final String direction;    // Inbound / Outbound
  final String callType;     // Regular / WhatsApp
  final String callDatetime;
  final int durationSeconds;
  final String status;       // Answered / Missed / etc
  final String callOutcome;
  final String linkedDoctype;
  final String linkedDocname;
  final String agent;
  final String notes;
  final String creation;

  const CallLog({
    required this.name,
    required this.phoneNumber,
    required this.callerName,
    required this.direction,
    required this.callType,
    required this.callDatetime,
    required this.durationSeconds,
    required this.status,
    required this.callOutcome,
    required this.linkedDoctype,
    required this.linkedDocname,
    required this.agent,
    required this.notes,
    required this.creation,
  });

  factory CallLog.fromJson(Map<String, dynamic> j) => CallLog(
        name:            j['name']?.toString() ?? '',
        phoneNumber:     j['phone_number']?.toString() ?? '',
        callerName:      j['caller_name']?.toString() ?? '',
        direction:       j['direction']?.toString() ?? 'Inbound',
        callType:        j['call_type']?.toString() ?? 'Regular',
        callDatetime:    j['call_datetime']?.toString() ?? '',
        durationSeconds: int.tryParse(j['duration']?.toString() ?? '0') ?? 0,
        status:          j['status']?.toString() ?? '',
        callOutcome:     j['call_outcome']?.toString() ?? '',
        linkedDoctype:   j['linked_doctype']?.toString() ?? '',
        linkedDocname:   j['linked_docname']?.toString() ?? '',
        agent:           j['agent']?.toString() ?? '',
        notes:           j['notes']?.toString() ?? '',
        creation:        j['creation']?.toString() ?? '',
      );

  bool get isWhatsApp => callType == 'WhatsApp';
  bool get isInbound  => direction == 'Inbound';
  bool get isMissed   => status == 'Missed';

  CallLog copyWith({
    String? notes,
    String? status,
    String? callOutcome,
    String? linkedDoctype,
    String? linkedDocname,
  }) => CallLog(
    name:            name,
    phoneNumber:     phoneNumber,
    callerName:      callerName,
    direction:       direction,
    callType:        callType,
    callDatetime:    callDatetime,
    durationSeconds: durationSeconds,
    status:          status          ?? this.status,
    callOutcome:     callOutcome     ?? this.callOutcome,
    linkedDoctype:   linkedDoctype   ?? this.linkedDoctype,
    linkedDocname:   linkedDocname   ?? this.linkedDocname,
    agent:           agent,
    notes:           notes           ?? this.notes,
    creation:        creation,
  );

  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  String get timeLabel {
    final src = callDatetime.isNotEmpty ? callDatetime : creation;
    if (src.isEmpty) return '';
    try {
      final dt = DateTime.parse(src);
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
    final src = callDatetime.isNotEmpty ? callDatetime : creation;
    if (src.isEmpty) return '';
    try {
      final dt = DateTime.parse(src);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  •  $h:$m';
    } catch (_) {
      return src;
    }
  }

  String get callerLabel =>
      callerName.isNotEmpty ? callerName : phoneNumber;

  String get initials {
    final parts = callerLabel.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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
    String status = 'Answered',
    String callOutcome = '',
    String notes = '',
    String? linkedDoctype,
    String? linkedDocname,
    String? recordingUrl,
  }) async {
    final payload = <String, dynamic>{
      'phone_number': phone,
      'caller_name':  callerName,
      'duration':     durationSeconds,
      'direction':    direction,
      'call_type':    callType,
      'status':       status,
      'notes':        notes,
    };
    if (callOutcome.isNotEmpty) payload['call_outcome'] = callOutcome;
    if (linkedDoctype != null && linkedDoctype.isNotEmpty) {
      payload['linked_doctype'] = linkedDoctype;
    }
    if (linkedDocname != null && linkedDocname.isNotEmpty) {
      payload['linked_docname'] = linkedDocname;
    }
    if (recordingUrl != null && recordingUrl.isNotEmpty) {
      payload['recording_url'] = recordingUrl;
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

  static Future<void> updateCallLog({
    required String name,
    String? notes,
    String? status,
    String? callOutcome,
    String? linkedDoctype,
    String? linkedDocname,
  }) async {
    final payload = <String, dynamic>{'name': name};
    if (notes       != null) payload['notes']          = notes;
    if (status      != null) payload['status']         = status;
    if (callOutcome != null) payload['call_outcome']   = callOutcome;
    if (linkedDoctype != null) payload['linked_doctype'] = linkedDoctype;
    if (linkedDocname != null) payload['linked_docname'] = linkedDocname;
    final resp = await ApiService.post(
        '/api/method/nxtgen_crm_mobile.api.update_call_log', payload);
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Could not update call log (${resp.statusCode})'));
    }
  }
}
