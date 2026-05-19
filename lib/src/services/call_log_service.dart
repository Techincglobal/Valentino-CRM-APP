import 'dart:convert';
import 'api_service.dart';

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
        durationSeconds:   ((j['duration'] ?? 0) as num?)?.toInt() ?? 0,
        sentOrReceived:    j['sent_or_received']?.toString() ?? 'Received',
        callType:          j['communication_medium']?.toString() ?? 'Regular',
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
    try {
      final resp = await ApiService.post(
          '/api/method/nxtgen_crm_mobile.api.get_call_logs', {});
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['message'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CallLog.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
