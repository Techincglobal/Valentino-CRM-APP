import 'dart:convert';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class Opportunity {
  final String name;
  final String partyName;
  final double amount;
  final String stage;
  final String status;
  final String expectedClosing;
  final String modified;

  const Opportunity({
    required this.name,
    required this.partyName,
    required this.amount,
    required this.stage,
    required this.status,
    required this.expectedClosing,
    required this.modified,
  });

  factory Opportunity.fromJson(Map<String, dynamic> j) => Opportunity(
        name: j['name'] as String? ?? '',
        partyName: (j['customer_name'] as String?)?.trim().isNotEmpty == true
            ? j['customer_name'] as String
            : (j['lead_name'] as String?) ?? 'Unknown',
        amount: ((j['opportunity_amount'] ?? j['expected_revenue'] ?? 0) as num)
            .toDouble(),
        stage: j['stage'] as String? ?? '',
        status: j['status'] as String? ?? 'Open',
        expectedClosing: j['expected_closing'] as String? ?? '',
        modified: j['modified'] as String? ?? '',
      );
}

class CrmLead {
  final String name;        // Frappe docname
  final String displayName;
  final String email;
  final String mobile;
  final String status;
  final String modified;

  const CrmLead({
    required this.name,
    required this.displayName,
    required this.email,
    required this.mobile,
    required this.status,
    required this.modified,
  });

  factory CrmLead.fromJson(Map<String, dynamic> j) {
    final first = (j['first_name'] as String?) ?? '';
    final full  = (j['lead_name'] as String?) ?? '';
    return CrmLead(
      name:        j['name'] as String? ?? '',
      displayName: full.isNotEmpty ? full : (first.isNotEmpty ? first : 'Unknown'),
      email:       j['email_id'] as String? ?? '',
      mobile:      j['mobile_no'] as String? ?? '',
      status:      j['status'] as String? ?? 'Lead',
      modified:    j['modified'] as String? ?? '',
    );
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class Quotation {
  final String name;
  final String partyName;
  final double grandTotal;
  final String status;
  final String modified;

  const Quotation({
    required this.name,
    required this.partyName,
    required this.grandTotal,
    required this.status,
    required this.modified,
  });

  factory Quotation.fromJson(Map<String, dynamic> j) => Quotation(
        name:       j['name'] as String? ?? '',
        partyName:  (j['customer_name'] as String?)?.isNotEmpty == true
            ? j['customer_name'] as String
            : (j['party_name'] as String?) ?? 'Unknown',
        grandTotal: ((j['grand_total'] ?? j['net_total'] ?? 0) as num).toDouble(),
        status:     j['status'] as String? ?? 'Draft',
        modified:   j['modified'] as String? ?? '',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SalesService
// ─────────────────────────────────────────────────────────────────────────────

class SalesService {
  static const _oppFields =
      '["name","lead_name","customer_name","opportunity_amount",'
      '"stage","status","expected_closing","modified"]';

  static const _leadFields =
      '["name","first_name","lead_name","email_id","mobile_no","status","modified"]';

  static const _quoteFields =
      '["name","customer_name","party_name","grand_total","net_total","status","modified"]';

  /// Fetch open opportunities from Frappe (latest 50, newest first).
  static Future<List<Opportunity>> getOpportunities() async {
    try {
      final resp = await ApiService.get(
        '/api/resource/Opportunity'
        '?fields=$_oppFields'
        '&limit=50'
        '&order_by=modified%20desc',
      );
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Opportunity.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch leads from Frappe (latest 50, newest first).
  static Future<List<CrmLead>> getLeads() async {
    try {
      final resp = await ApiService.get(
        '/api/resource/Lead'
        '?fields=$_leadFields'
        '&limit=50'
        '&order_by=modified%20desc',
      );
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CrmLead.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetch quotations from Frappe (latest 50, newest first).
  static Future<List<Quotation>> getQuotations() async {
    try {
      final resp = await ApiService.get(
        '/api/resource/Quotation'
        '?fields=$_quoteFields'
        '&limit=50'
        '&order_by=modified%20desc',
      );
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(Quotation.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Create a quotation linked to a lead or customer.
  static Future<String> createQuotation({
    required String leadDocname,
    required String partyType,
    required String subject,
    required double amount,
    String note = '',
  }) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.create_quotation',
      {
        'lead_docname': leadDocname,
        'party_type':   partyType,
        'subject':      subject,
        'amount':       amount,
        'note':         note,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to create quotation (${resp.statusCode})');
    }
    final body    = jsonDecode(resp.body) as Map<String, dynamic>;
    final message = body['message'] as Map<String, dynamic>? ?? body;
    return message['name'] as String? ?? '';
  }

  /// Pipeline summary derived from opportunities list.
  static PipelineSummary summarise(List<Opportunity> list) {
    final open  = list.where((o) => o.status == 'Open').length;
    final won   = list.where((o) => o.status == 'Won').length;
    final total = list.fold<double>(0, (s, o) => s + o.amount);
    return PipelineSummary(open: open, won: won, total: list.length, totalValue: total);
  }
}

class PipelineSummary {
  final int open;
  final int won;
  final int total;
  final double totalValue;
  const PipelineSummary({
    required this.open,
    required this.won,
    required this.total,
    required this.totalValue,
  });
}
