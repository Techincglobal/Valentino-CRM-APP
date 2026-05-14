import 'dart:convert';
import 'api_service.dart';

String _parseFrappeError(String body, String fallback) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return fallback;
    final rawMessages = decoded['_server_messages'];
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
    final exc = decoded['exception'];
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

class Opportunity {
  final String name;
  final String partyName;
  final String partyDocname;  // actual Frappe party docname (Lead/Customer)
  final String partyType;     // "Lead" or "Customer"
  final double amount;
  final String stage;
  final String status;
  final String expectedClosing;
  final String modified;

  const Opportunity({
    required this.name,
    required this.partyName,
    this.partyDocname = '',
    this.partyType = 'Lead',
    required this.amount,
    required this.stage,
    required this.status,
    required this.expectedClosing,
    required this.modified,
  });

  factory Opportunity.fromJson(Map<String, dynamic> j) {
    final customerName = j['customer_name']?.toString().trim() ?? '';
    final title        = j['title']?.toString().trim() ?? '';
    final partyName    = j['party_name']?.toString().trim() ?? '';
    return Opportunity(
      name:            j['name']?.toString() ?? '',
      partyName:       customerName.isNotEmpty ? customerName
                     : title.isNotEmpty        ? title
                     : partyName.isNotEmpty    ? partyName
                     : 'Unknown',
      partyDocname:    partyName,
      partyType:       j['opportunity_from']?.toString() ?? 'Lead',
      amount:          ((j['opportunity_amount'] ?? j['expected_revenue'] ?? 0) as num?)?.toDouble() ?? 0,
      stage:           j['stage']?.toString() ?? '',
      status:          j['status']?.toString() ?? 'Open',
      expectedClosing: j['expected_closing']?.toString() ?? '',
      modified:        j['modified']?.toString() ?? '',
    );
  }
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
    final first = j['first_name']?.toString() ?? '';
    final full  = j['lead_name']?.toString() ?? '';
    return CrmLead(
      name:        j['name']?.toString() ?? '',
      displayName: full.isNotEmpty ? full : (first.isNotEmpty ? first : 'Unknown'),
      email:       j['email_id']?.toString() ?? '',
      mobile:      j['mobile_no']?.toString() ?? '',
      status:      j['status']?.toString() ?? 'Lead',
      modified:    j['modified']?.toString() ?? '',
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
  final String currency;

  const Quotation({
    required this.name,
    required this.partyName,
    required this.grandTotal,
    required this.status,
    required this.modified,
    this.currency = 'LKR',
  });

  factory Quotation.fromJson(Map<String, dynamic> j) {
    final cn = j['customer_name']?.toString().trim() ?? '';
    return Quotation(
      name:       j['name']?.toString() ?? '',
      partyName:  cn.isNotEmpty ? cn : (j['party_name']?.toString() ?? 'Unknown'),
      grandTotal: ((j['grand_total'] ?? j['net_total'] ?? 0) as num?)?.toDouble() ?? 0,
      status:     j['status']?.toString() ?? 'Draft',
      modified:   j['modified']?.toString() ?? '',
      currency:   j['currency']?.toString() ?? 'LKR',
    );
  }

  String get initials {
    final parts = partyName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class QuotationItem {
  final String itemCode;
  final String itemName;
  final double qty;
  final double rate;
  final double amount;
  final String uom;
  final String warehouse;
  final String deliveryDate;

  const QuotationItem({
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.rate,
    required this.amount,
    this.uom          = '',
    this.warehouse    = '',
    this.deliveryDate = '',
  });

  factory QuotationItem.fromJson(Map<String, dynamic> j) => QuotationItem(
        itemCode:     j['item_code']?.toString() ?? '',
        itemName:     j['item_name']?.toString() ?? '',
        qty:          ((j['qty'] ?? 1) as num?)?.toDouble() ?? 1,
        rate:         ((j['rate'] ?? 0) as num?)?.toDouble() ?? 0,
        amount:       ((j['amount'] ?? 0) as num?)?.toDouble() ?? 0,
        uom:          j['uom']?.toString() ?? '',
        warehouse:    j['warehouse']?.toString() ?? '',
        deliveryDate: j['delivery_date']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'item_code': itemCode,
        'item_name': itemName,
        'qty':       qty,
        'rate':      rate,
      };
}

class QuotationDetail extends Quotation {
  final int    docstatus;
  final String validTill;
  final String terms;
  final List<QuotationItem> items;

  const QuotationDetail({
    required super.name,
    required super.partyName,
    required super.grandTotal,
    required super.status,
    required super.modified,
    required super.currency,
    required this.docstatus,
    required this.validTill,
    required this.terms,
    required this.items,
  });

  bool get isDraft      => docstatus == 0;
  bool get isSubmitted  => docstatus == 1;
  bool get isCancelled  => docstatus == 2;

  factory QuotationDetail.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] is List) ? j['items'] as List : <dynamic>[];
    final cn       = j['customer_name']?.toString().trim() ?? '';
    return QuotationDetail(
      name:       j['name']?.toString() ?? '',
      partyName:  cn.isNotEmpty ? cn : (j['party_name']?.toString() ?? 'Unknown'),
      grandTotal: ((j['grand_total'] ?? j['net_total'] ?? 0) as num?)?.toDouble() ?? 0,
      status:     j['status']?.toString() ?? 'Draft',
      modified:   j['modified']?.toString() ?? '',
      currency:   j['currency']?.toString() ?? 'LKR',
      docstatus:  (j['docstatus'] is int) ? j['docstatus'] as int : int.tryParse(j['docstatus']?.toString() ?? '') ?? 0,
      validTill:  j['valid_till']?.toString() ?? '',
      terms:      j['terms']?.toString() ?? '',
      items:      rawItems
          .whereType<Map<String, dynamic>>()
          .map(QuotationItem.fromJson)
          .toList(),
    );
  }
}

class SalesOrder {
  final String name;
  final String customerName;
  final double grandTotal;
  final String status;
  final String deliveryStatus;
  final String billingStatus;
  final String currency;
  final String transactionDate;
  final String modified;

  const SalesOrder({
    required this.name,
    required this.customerName,
    required this.grandTotal,
    required this.status,
    required this.deliveryStatus,
    this.billingStatus    = '',
    this.currency         = 'LKR',
    this.transactionDate  = '',
    required this.modified,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> j) {
    final cn = j['customer_name']?.toString().trim() ?? '';
    return SalesOrder(
      name:            j['name']?.toString() ?? '',
      customerName:    cn.isNotEmpty ? cn : 'Unknown',
      grandTotal:      ((j['grand_total'] ?? 0) as num?)?.toDouble() ?? 0,
      status:          j['status']?.toString() ?? 'Draft',
      deliveryStatus:  j['delivery_status']?.toString() ?? '',
      billingStatus:   j['billing_status']?.toString() ?? '',
      currency:        j['currency']?.toString() ?? 'LKR',
      transactionDate: j['transaction_date']?.toString() ?? '',
      modified:        j['modified']?.toString() ?? '',
    );
  }

  String get initials {
    final parts = customerName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

class SalesOrderDetail extends SalesOrder {
  final int    docstatus;
  final String deliveryDate;
  final String company;
  final String orderType;
  final double netTotal;
  final double totalTaxes;
  final String taxesAndCharges;
  final String sellingPriceList;
  final String contactDisplay;
  final List<QuotationItem> items;

  const SalesOrderDetail({
    required super.name,
    required super.customerName,
    required super.grandTotal,
    required super.status,
    required super.deliveryStatus,
    required super.billingStatus,
    required super.currency,
    required super.transactionDate,
    required super.modified,
    required this.docstatus,
    this.deliveryDate     = '',
    this.company          = '',
    this.orderType        = '',
    this.netTotal         = 0,
    this.totalTaxes       = 0,
    this.taxesAndCharges  = '',
    this.sellingPriceList = '',
    this.contactDisplay   = '',
    required this.items,
  });

  bool get isDraft     => docstatus == 0;
  bool get isSubmitted => docstatus == 1;
  bool get isCancelled => docstatus == 2;

  factory SalesOrderDetail.fromJson(Map<String, dynamic> j) {
    final rawItems = (j['items'] is List) ? j['items'] as List : <dynamic>[];
    final cn       = j['customer_name']?.toString().trim() ?? '';
    return SalesOrderDetail(
      name:             j['name']?.toString() ?? '',
      customerName:     cn.isNotEmpty ? cn : 'Unknown',
      grandTotal:       ((j['grand_total'] ?? 0) as num?)?.toDouble() ?? 0,
      netTotal:         ((j['net_total'] ?? 0) as num?)?.toDouble() ?? 0,
      totalTaxes:       ((j['total_taxes_and_charges'] ?? 0) as num?)?.toDouble() ?? 0,
      status:           j['status']?.toString() ?? 'Draft',
      deliveryStatus:   j['delivery_status']?.toString() ?? '',
      billingStatus:    j['billing_status']?.toString() ?? '',
      currency:         j['currency']?.toString() ?? 'LKR',
      transactionDate:  j['transaction_date']?.toString() ?? '',
      modified:         j['modified']?.toString() ?? '',
      docstatus:        (j['docstatus'] is int) ? j['docstatus'] as int : int.tryParse(j['docstatus']?.toString() ?? '') ?? 0,
      deliveryDate:     j['delivery_date']?.toString() ?? '',
      company:          j['company']?.toString() ?? '',
      orderType:        j['order_type']?.toString() ?? '',
      taxesAndCharges:  j['taxes_and_charges']?.toString() ?? '',
      sellingPriceList: j['selling_price_list']?.toString() ?? '',
      contactDisplay:   j['contact_display']?.toString() ?? '',
      items:            rawItems
          .whereType<Map<String, dynamic>>()
          .map(QuotationItem.fromJson)
          .toList(),
    );
  }
}

class QuotesSummary {
  final int    totalQuotes;
  final int    draftQuotes;
  final int    openOrders;
  final double totalValue;
  const QuotesSummary({
    required this.totalQuotes,
    required this.draftQuotes,
    required this.openOrders,
    required this.totalValue,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SalesService
// ─────────────────────────────────────────────────────────────────────────────

class SalesService {
  static const _oppFields =
      '["name","title","customer_name","party_name","opportunity_from","opportunity_amount",'
      '"stage","status","expected_closing","modified"]';

  static const _leadFields =
      '["name","first_name","lead_name","email_id","mobile_no","status","modified"]';

  static const _quoteFields =
      '["name","customer_name","party_name","grand_total","net_total","status","modified","currency"]';

  static const _orderFields =
      '["name","customer_name","grand_total","status","delivery_status","billing_status","currency","transaction_date","modified"]';

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

  /// Fetch sales orders from Frappe (latest 50, newest first).
  static Future<List<SalesOrder>> getSalesOrders() async {
    try {
      final resp = await ApiService.get(
        '/api/resource/Sales%20Order'
        '?fields=$_orderFields'
        '&limit=50'
        '&order_by=modified%20desc',
      );
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['data'] as List?) ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(SalesOrder.fromJson)
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
    String currency = 'LKR',
    List<Map<String, dynamic>> items = const [],
    String sellingPriceList = '',
    String validTill = '',
  }) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.create_quotation',
      {
        'lead_docname':        leadDocname,
        'party_type':          partyType,
        'subject':             subject,
        'amount':              amount,
        'note':                note,
        'currency':            currency,
        'items':               items,
        'selling_price_list':  sellingPriceList,
        'valid_till':          validTill,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to create quotation (${resp.statusCode})'));
    }
    final body    = jsonDecode(resp.body) as Map<String, dynamic>;
    final message = body['message'] as Map<String, dynamic>? ?? body;
    return message['name'] as String? ?? '';
  }

  /// Fetch full quotation detail including line items.
  static Future<QuotationDetail> getQuotationDetail(String name) async {
    final resp = await ApiService.get('/api/resource/Quotation/${Uri.encodeComponent(name)}');
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to load quotation (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return QuotationDetail.fromJson(data);
  }

  /// Update editable fields on a draft quotation.
  static Future<void> updateQuotation(
      String name, Map<String, dynamic> data) async {
    final resp = await ApiService.put(
      '/api/resource/Quotation/${Uri.encodeComponent(name)}',
      data,
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to update quotation (${resp.statusCode})'));
    }
  }

  /// Submit a draft quotation (docstatus 0 → 1).
  static Future<void> submitQuotation(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.submit_quotation',
      {'name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to submit quotation (${resp.statusCode})'));
    }
  }

  /// Cancel a submitted quotation (docstatus 1 → 2).
  static Future<void> cancelQuotation(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.cancel_quotation',
      {'name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to cancel quotation (${resp.statusCode})'));
    }
  }

  /// Quotes & Orders summary.
  static QuotesSummary summariseQuotes(
      List<Quotation> quotes, List<SalesOrder> orders) {
    final draft = quotes.where((q) => q.status == 'Draft').length;
    final openOrd = orders
        .where((o) => o.status != 'Completed' && o.status != 'Cancelled')
        .length;
    final totalVal = quotes.fold<double>(0, (s, q) => s + q.grandTotal) +
        orders.fold<double>(0, (s, o) => s + o.grandTotal);
    return QuotesSummary(
      totalQuotes: quotes.length,
      draftQuotes: draft,
      openOrders:  openOrd,
      totalValue:  totalVal,
    );
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

// ─────────────────────────────────────────────────────────────────────────────
// New models
// ─────────────────────────────────────────────────────────────────────────────

class CompanyDefaults {
  final String company;
  final String currency;
  final String symbol;
  const CompanyDefaults({
    required this.company,
    required this.currency,
    required this.symbol,
  });
  factory CompanyDefaults.fromJson(Map<String, dynamic> j) => CompanyDefaults(
        company:  j['company']?.toString() ?? '',
        currency: j['currency']?.toString() ?? 'LKR',
        symbol:   j['symbol']?.toString() ?? 'Rs.',
      );
}

class QuotationDefaults {
  final String company;
  final String currency;
  final String symbol;
  final String sellingPriceList;
  final String termsContent;
  final String partyName;
  final String partyEmail;
  final String partyPhone;

  const QuotationDefaults({
    required this.company,
    required this.currency,
    required this.symbol,
    required this.sellingPriceList,
    required this.termsContent,
    required this.partyName,
    required this.partyEmail,
    required this.partyPhone,
  });

  factory QuotationDefaults.fromJson(Map<String, dynamic> j) => QuotationDefaults(
        company:           j['company']?.toString() ?? '',
        currency:          j['currency']?.toString() ?? 'LKR',
        symbol:            j['symbol']?.toString() ?? 'Rs.',
        sellingPriceList:  j['selling_price_list']?.toString() ?? '',
        termsContent:      j['terms_content']?.toString() ?? '',
        partyName:         j['party_name']?.toString() ?? '',
        partyEmail:        j['party_email']?.toString() ?? '',
        partyPhone:        j['party_phone']?.toString() ?? '',
      );

  static const empty = QuotationDefaults(
    company: '', currency: 'LKR', symbol: 'Rs.',
    sellingPriceList: '', termsContent: '',
    partyName: '', partyEmail: '', partyPhone: '',
  );
}

class FrappeItem {
  final String itemCode;
  final String itemName;
  final String description;
  final double standardRate;
  const FrappeItem({
    required this.itemCode,
    required this.itemName,
    required this.description,
    required this.standardRate,
  });
  factory FrappeItem.fromJson(Map<String, dynamic> j) => FrappeItem(
        itemCode:     j['name']?.toString() ?? '',
        itemName:     j['item_name']?.toString() ?? '',
        description:  j['description']?.toString() ?? '',
        standardRate: ((j['standard_rate'] ?? 0) as num?)?.toDouble() ?? 0,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Additional SalesService methods
// ─────────────────────────────────────────────────────────────────────────────

extension SalesServiceExtended on SalesService {
  // Static methods can't be in extensions, so they are added inline below.
}

// Stand-alone functions grouped with SalesService for convenience.
// (Dart doesn't allow adding static methods via extension, so these are
// top-level helpers — called as SalesServiceOps.method())
class SalesServiceOps {
  /// Fetch company defaults (currency, company name).
  static Future<CompanyDefaults> getCompanyDefaults() async {
    try {
      final resp = await ApiService.post(
          '/api/method/nxtgen_crm_mobile.api.get_company_defaults', {});
      if (resp.statusCode != 200) {
        return const CompanyDefaults(company: '', currency: 'LKR', symbol: 'Rs.');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg  = body['message'] as Map<String, dynamic>? ?? {};
      return CompanyDefaults.fromJson(msg);
    } catch (_) {
      return const CompanyDefaults(company: '', currency: 'LKR', symbol: 'Rs.');
    }
  }

  /// Fetch everything the Create Quotation form needs in a single call:
  /// currency, selling price list, default terms, and party contact info.
  static Future<QuotationDefaults> getQuotationDefaults({
    required String leadDocname,
    required String partyType,
  }) async {
    try {
      final resp = await ApiService.post(
        '/api/method/nxtgen_crm_mobile.api.get_quotation_defaults',
        {'lead_docname': leadDocname, 'party_type': partyType},
      );
      if (resp.statusCode != 200) return QuotationDefaults.empty;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final msg  = body['message'] as Map<String, dynamic>? ?? {};
      return QuotationDefaults.fromJson(msg);
    } catch (_) {
      return QuotationDefaults.empty;
    }
  }

  /// Convert a submitted Quotation into a Draft Sales Order; returns the new SO docname.
  static Future<String> makeSOFromQuotation(String quotationName) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.make_sales_order',
      {'quotation_name': quotationName},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to create sales order (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
    return msg['name'] as String? ?? '';
  }

  /// Fetch full Sales Order detail including line items.
  static Future<SalesOrderDetail> getSalesOrderDetail(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.get_sales_order_detail',
      {'sales_order_name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to load sales order (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
    return SalesOrderDetail.fromJson(msg);
  }

  /// Submit a Draft Sales Order (docstatus 0 → 1).
  static Future<void> submitSalesOrder(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.submit_sales_order',
      {'sales_order_name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to submit sales order (${resp.statusCode})'));
    }
  }

  /// Cancel a submitted Sales Order (docstatus 1 → 2).
  static Future<void> cancelSalesOrder(String name) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.cancel_sales_order',
      {'sales_order_name': name},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to cancel sales order (${resp.statusCode})'));
    }
  }

  /// Update fields on a Draft Sales Order (e.g. delivery_date) before submitting.
  static Future<void> updateSalesOrder(String name, Map<String, dynamic> data) async {
    final resp = await ApiService.put(
      '/api/resource/Sales%20Order/${Uri.encodeComponent(name)}',
      data,
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to update sales order (${resp.statusCode})'));
    }
  }

  /// Create an Opportunity from a Lead; returns the new Opportunity object.
  static Future<Opportunity> createOpportunity({
    required String leadDocname,
    required String partyName,
    required double amount,
    required String stage,
    String closingDate = '',
    String note = '',
  }) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.create_opportunity',
      {
        'lead_docname':       leadDocname,
        'opportunity_amount': amount,
        'stage':              stage,
        'expected_closing':   closingDate,
        'note':               note,
      },
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to create opportunity (${resp.statusCode})'));
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final msg  = body['message'] as Map<String, dynamic>? ?? {};
    return Opportunity(
      name:            msg['name']               as String? ?? '',
      partyName:       msg['customer_name']       as String? ?? partyName,
      partyDocname:    leadDocname,                // always the actual Lead docname
      partyType:       'Lead',
      amount:          ((msg['opportunity_amount'] ?? 0) as num).toDouble(),
      stage:           msg['stage']               as String? ?? stage,
      status:          msg['opp_status']           as String? ?? 'Open',
      expectedClosing: msg['expected_closing']     as String? ?? closingDate,
      modified:        msg['modified']             as String? ?? DateTime.now().toIso8601String().substring(0, 10),
    );
  }

  /// Update a Lead's status.
  static Future<void> updateLeadStatus(String docname, String status) async {
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.update_lead',
      {'docname': docname, 'status': status},
    );
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to update lead status'));
    }
  }

  /// Update an Opportunity's stage (and optionally amount / closing date).
  static Future<void> updateOpportunityStage(
      String docname, String stage, {double? amount, String? closingDate}) async {
    final payload = <String, dynamic>{'docname': docname, 'stage': stage};
    if (amount      != null) payload['opportunity_amount'] = amount;
    if (closingDate != null) payload['expected_closing']   = closingDate;
    final resp = await ApiService.post(
      '/api/method/nxtgen_crm_mobile.api.update_opportunity', payload);
    if (resp.statusCode != 200) {
      throw Exception(_parseFrappeError(resp.body, 'Failed to update opportunity'));
    }
  }

  /// Search Frappe Item master; returns up to [limit] matching items.
  /// Pass [priceList] to get the selling price list rate instead of standard_rate.
  static Future<List<FrappeItem>> searchItems(
    String query, {
    int limit = 15,
    String priceList = '',
  }) async {
    try {
      final body = <String, dynamic>{'query': query, 'limit': limit};
      if (priceList.isNotEmpty) body['price_list'] = priceList;
      final resp = await ApiService.post(
        '/api/method/nxtgen_crm_mobile.api.search_items', body);
      if (resp.statusCode != 200) return [];
      final respBody = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (respBody['message'] as List?) ?? [];
      return list.whereType<Map<String, dynamic>>().map(FrappeItem.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a document (must be draft / not submitted).
  static Future<void> deleteDocument(String doctype, String docname) async {
    final resp = await ApiService.delete(
        '/api/resource/${Uri.encodeComponent(doctype)}/${Uri.encodeComponent(docname)}');
    if (resp.statusCode != 202 && resp.statusCode != 200) {
      throw Exception('Failed to delete $doctype $docname');
    }
  }
}
