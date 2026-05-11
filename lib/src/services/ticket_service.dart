import 'dart:convert';
import 'api_service.dart';

String _parseFrappeError(String body, String fallback) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final raw  = json['_server_messages'] as String?;
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List?;
      if (list != null && list.isNotEmpty) {
        try {
          final inner = jsonDecode(list.first as String) as Map?;
          final msg   = inner?['message'] as String?;
          if (msg != null && msg.isNotEmpty) return msg;
        } catch (_) {
          final s = list.first.toString();
          if (s.isNotEmpty) return s;
        }
      }
    }
    final exc = json['exception'] as String?;
    if (exc != null && exc.isNotEmpty) {
      final i = exc.indexOf(': ');
      return i >= 0 ? exc.substring(i + 2).trim() : exc;
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
    name:       j['name'] as String? ?? '',
    subject:    j['subject'] as String? ?? '(no subject)',
    status:     j['status'] as String? ?? 'Open',
    priority:   j['priority'] as String? ?? 'Medium',
    raisedBy:   j['raised_by'] as String? ?? '',
    ticketType: j['ticket_type'] as String? ?? '',
    agentGroup: j['agent_group'] as String? ?? '',
    creation:   j['creation'] as String? ?? '',
    modified:   j['modified'] as String? ?? '',
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
        name:        j['name'] as String? ?? '',
        subject:     j['subject'] as String? ?? '(no subject)',
        status:      j['status'] as String? ?? 'Open',
        priority:    j['priority'] as String? ?? 'Medium',
        raisedBy:    j['raised_by'] as String? ?? '',
        ticketType:  j['ticket_type'] as String? ?? '',
        agentGroup:  j['agent_group'] as String? ?? '',
        creation:    j['creation'] as String? ?? '',
        modified:    j['modified'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );
}

class CustomerResult {
  final String name;
  final String customerName;
  const CustomerResult({required this.name, required this.customerName});
  factory CustomerResult.fromJson(Map<String, dynamic> j) => CustomerResult(
    name:         j['name'] as String? ?? '',
    customerName: j['customer_name'] as String? ?? (j['name'] as String? ?? ''),
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
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (body['message'] as List?) ?? [];
    return list.map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<SupportTicketDetail> getTicketDetail(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_ticket_detail',
      {'ticket_name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to load ticket (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
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
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
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
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (body['message'] as List?) ?? [];
    return list.map((e) => CustomerResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<String>> getTicketTypes() async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_ticket_types',
      {},
    );
    if (resp.statusCode != 200) return [];
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (body['message'] as List?) ?? [];
    return list.map((e) => e.toString()).toList();
  }
}
