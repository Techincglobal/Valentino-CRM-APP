import 'dart:convert';
import 'api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class CallerNote {
  final String note;
  final String owner;
  final String creation;

  const CallerNote({
    required this.note,
    required this.owner,
    required this.creation,
  });

  factory CallerNote.fromJson(Map<String, dynamic> j) => CallerNote(
    note:     j['note']?.toString() ?? j['content']?.toString() ?? '',
    owner:    j['owner']?.toString() ?? j['modified_by']?.toString() ?? '',
    creation: j['creation']?.toString() ?? '',
  );

  String get ownerLabel {
    final s = owner;
    if (s.isEmpty) return '';
    final i = s.indexOf('@');
    return i > 0 ? s.substring(0, i) : s;
  }

  String get timeLabel {
    if (creation.isEmpty) return '';
    try {
      final dt   = DateTime.parse(creation);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 30) return '${diff.inDays}d ago';
      return creation.length >= 10 ? creation.substring(0, 10) : creation;
    } catch (_) {
      return '';
    }
  }
}

class CallerContext {
  final bool   found;
  final String docname;
  final String displayName;
  final String doctype;
  final String email;
  final List<CallerNote> notes;

  const CallerContext({
    required this.found,
    required this.docname,
    required this.displayName,
    required this.doctype,
    required this.email,
    required this.notes,
  });

  static const empty = CallerContext(
    found: false, docname: '', displayName: '', doctype: '', email: '', notes: [],
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class CallerService {
  static const String _base = "/api/method/nxtgen_crm_mobile.api";

  // Get Caller Details
  static Future<Map<String, dynamic>> getCallerDetails(String phone) async {
    final response = await ApiService.post("$_base.get_caller_details", {
      "caller_number": phone,
    });

    try {
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data["message"];
      } else {
        throw Exception(data["message"] ?? "Failed to fetch caller details");
      }
    } catch (_) {
      // Return safe fallback so the overlay can still proceed gracefully instead of crashing
      return {"found": false, "name": "Unknown", "type": "Network/API Error"};
    }
  }

  // Create Lead With Optional Note
  static Future<Map<String, dynamic>> createLead({
    required String firstName,
    String? email,
    String? mobile,
    String? note,
  }) async {
    final cleanEmail = (email != null && email.contains('@') && email.contains('.')) ? email : null;
    final response = await ApiService.post("$_base.create_lead_with_note", {
      "first_name": firstName,
      "email_id": cleanEmail,
      "mobile_no": mobile,
      "note_content": note,
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["message"];
    } else {
      throw Exception(data["message"] ?? "Lead creation failed");
    }
  }

  // Add Note To Existing Lead / Opportunity
  static Future<void> addNote({
    required String doctype,
    required String docname,
    required String note,
  }) async {
    final response = await ApiService.post("$_base.add_call_note", {
      "doctype": doctype,
      "docname": docname,
      "note_content": note,
    });

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data["message"] ?? "Failed to add note");
    }
  }

  // Get Notes
  static Future<List<dynamic>> getNotes({
    required String doctype,
    required String docname,
  }) async {
    final response = await ApiService.post("$_base.get_notes", {
      "doctype": doctype,
      "docname": docname,
    });

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["message"] ?? [];
    } else {
      throw Exception(data["message"] ?? "Failed to fetch notes");
    }
  }

  /// Fetch caller details + notes in one shot. Never throws — returns
  /// [CallerContext.empty] on any error so callers don't need try/catch.
  static Future<CallerContext> getCallerContext(String phone) async {
    if (phone.isEmpty) return CallerContext.empty;
    try {
      final details = await getCallerDetails(phone);
      final found   = details['found'] == true;
      if (!found) return CallerContext.empty;

      final docname     = details['docname']?.toString() ?? '';
      final displayName = details['name']?.toString() ?? '';
      final doctype     = details['type']?.toString() ?? 'Lead';
      final email       = details['email_id']?.toString() ?? '';

      List<CallerNote> notes = [];
      if (docname.isNotEmpty) {
        try {
          final raw = await getNotes(doctype: doctype, docname: docname);
          notes = raw
              .whereType<Map<String, dynamic>>()
              .map(CallerNote.fromJson)
              .where((n) => n.note.isNotEmpty)
              .toList();
        } catch (_) {}
      }

      return CallerContext(
        found:       true,
        docname:     docname,
        displayName: displayName,
        doctype:     doctype,
        email:       email,
        notes:       notes,
      );
    } catch (_) {
      return CallerContext.empty;
    }
  }
}
