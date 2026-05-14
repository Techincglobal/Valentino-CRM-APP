import 'dart:convert';
import 'api_service.dart';

String _parseFrappeError(String body, String fallback) {
  try {
    final json = jsonDecode(body);
    if (json is! Map) return fallback;
    final rawMessages = json['_server_messages'];
    if (rawMessages is String && rawMessages.isNotEmpty) {
      try {
        final list = jsonDecode(rawMessages);
        if (list is List && list.isNotEmpty) {
          try {
            final inner = jsonDecode(list.first.toString());
            if (inner is Map) {
              final msg = inner['message'];
              if (msg != null && msg.toString().isNotEmpty) return msg.toString();
            }
          } catch (_) {
            final s = list.first.toString();
            if (s.isNotEmpty) return s;
          }
        }
      } catch (_) {}
    }
    final exc = json['exception'];
    if (exc != null) {
      final s = exc.toString();
      if (s.isNotEmpty) {
        final i = s.indexOf(': ');
        return i >= 0 ? s.substring(i + 2).trim() : s;
      }
    }
  } catch (_) {}
  return fallback;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class SupportTicket {
  final String name;
  final String subject;
  final String status;
  final String priority;
  final String raisedBy;
  final String ticketType;
  final String agentGroup;
  final String creation;
  final String modified;

  const SupportTicket({
    required this.name,
    required this.subject,
    required this.status,
    required this.priority,
    required this.raisedBy,
    this.ticketType = '',
    this.agentGroup = '',
    required this.creation,
    required this.modified,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
    name:       j['name']?.toString() ?? '',
    subject:    j['subject']?.toString() ?? '(no subject)',
    status:     j['status']?.toString() ?? 'Open',
    priority:   j['priority']?.toString() ?? 'Medium',
    raisedBy:   j['raised_by']?.toString() ?? '',
    ticketType: j['ticket_type']?.toString() ?? '',
    agentGroup: j['agent_group']?.toString() ?? '',
    creation:   j['creation']?.toString() ?? '',
    modified:   j['modified']?.toString() ?? '',
  );

  String get initials {
    final w = subject.trim().split(RegExp(r'\s+'));
    if (w.isEmpty) return '?';
    if (w.length == 1) return w[0][0].toUpperCase();
    return '${w[0][0]}${w[1][0]}'.toUpperCase();
  }

  String get timeAgo {
    if (creation.isEmpty) return '';
    final dt = DateTime.tryParse(creation);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 30)    return '${diff.inDays}d ago';
    return creation.length >= 10 ? creation.substring(0, 10) : creation;
  }
}

class SupportTicketDetail extends SupportTicket {
  final String description;

  const SupportTicketDetail({
    required super.name,
    required super.subject,
    required super.status,
    required super.priority,
    required super.raisedBy,
    required super.ticketType,
    required super.agentGroup,
    required super.creation,
    required super.modified,
    this.description = '',
  });

  factory SupportTicketDetail.fromJson(Map<String, dynamic> j) =>
      SupportTicketDetail(
        name:        j['name']?.toString() ?? '',
        subject:     j['subject']?.toString() ?? '(no subject)',
        status:      j['status']?.toString() ?? 'Open',
        priority:    j['priority']?.toString() ?? 'Medium',
        raisedBy:    j['raised_by']?.toString() ?? '',
        ticketType:  j['ticket_type']?.toString() ?? '',
        agentGroup:  j['agent_group']?.toString() ?? '',
        creation:    j['creation']?.toString() ?? '',
        modified:    j['modified']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
      );
}

class CustomerResult {
  final String name;
  final String customerName;
  const CustomerResult({required this.name, required this.customerName});
  factory CustomerResult.fromJson(Map<String, dynamic> j) => CustomerResult(
    name:         j['name']?.toString() ?? '',
    customerName: j['customer_name']?.toString() ?? (j['name']?.toString() ?? ''),
  );
  String get display => customerName.isNotEmpty ? customerName : name;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class TicketService {
  static Future<List<SupportTicket>> getTickets({String? status}) async {
    final payload = <String, dynamic>{};
    if (status != null && status != 'All') payload['status'] = status;
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_support_tickets',
      payload,
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to load tickets (${resp.statusCode})'));
    }
    final decoded = jsonDecode(resp.body);
    final msg     = (decoded is Map) ? decoded['message'] : null;
    final list    = (msg is List) ? msg : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }

  static Future<SupportTicketDetail> getTicketDetail(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_ticket_detail',
      {'ticket_name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to load ticket (${resp.statusCode})'));
    }
    final decoded = jsonDecode(resp.body);
    final msg     = (decoded is Map && decoded['message'] is Map)
        ? Map<String, dynamic>.from(decoded['message'] as Map)
        : <String, dynamic>{};
    return SupportTicketDetail.fromJson(msg);
  }

  static Future<SupportTicket> createTicket({
    required String subject,
    required String description,
    required String raisedBy,
    String priority   = 'Medium',
    String ticketType = '',
    String agentGroup = '',
  }) async {
    final payload = <String, dynamic>{
      'subject':     subject,
      'description': description,
      'raised_by':   raisedBy,
      'priority':    priority,
    };
    if (ticketType.isNotEmpty) payload['ticket_type']  = ticketType;
    if (agentGroup.isNotEmpty) payload['agent_group']  = agentGroup;

    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.create_support_ticket',
      payload,
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to create ticket (${resp.statusCode})'));
    }
    final decoded = jsonDecode(resp.body);
    final msg     = (decoded is Map && decoded['message'] is Map)
        ? Map<String, dynamic>.from(decoded['message'] as Map)
        : <String, dynamic>{};
    return SupportTicket.fromJson(msg);
  }

  static Future<void> updateTicketStatus(String name, String status) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.update_ticket_status',
      {'ticket_name': name, 'status': status},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to update ticket (${resp.statusCode})'));
    }
  }

  static Future<List<CustomerResult>> searchCustomers(String query) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.search_customers',
      {'query': query, 'limit': 15},
    );
    if (resp.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(resp.body);
      final msg  = (decoded is Map) ? decoded['message'] : null;
      final list = (msg is List) ? msg : <dynamic>[];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CustomerResult.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<String>> getTicketTypes() async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_ticket_types',
      {},
    );
    if (resp.statusCode != 200) return [];
    try {
      final decoded = jsonDecode(resp.body);
      final msg  = (decoded is Map) ? decoded['message'] : null;
      final list = (msg is List) ? msg : <dynamic>[];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }
}
