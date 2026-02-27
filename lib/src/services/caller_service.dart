import 'dart:convert';
import 'api_service.dart';

class CallerService {
  static const String _base = "/api/method/nxtgen_crm_mobile.api";

  static Future<Map<String, dynamic>> getCallerDetails(String phone) async {
    final response = await ApiService.post(
      "$_base.get_caller_details",
      {"caller_number": phone},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["message"];
    } else {
      throw Exception(data["message"] ?? "Failed to fetch caller details");
    }
  }

  static Future<Map<String, dynamic>> createLead({
    required String firstName,
    String? email,
    String? mobile,
    String? note,
  }) async {
    final response = await ApiService.post(
      "$_base.create_lead_with_note",
      {
        "first_name": firstName,
        "email_id": email,
        "mobile_no": mobile,
        "note_content": note,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["message"];
    } else {
      throw Exception(data["message"] ?? "Lead creation failed");
    }
  }

  static Future<void> addNote({
    required String doctype,
    required String docname,
    required String note,
  }) async {
    final response = await ApiService.post(
      "$_base.add_call_note",
      {
        "doctype": doctype,
        "docname": docname,
        "note_content": note,
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data["message"] ?? "Failed to add note");
    }
  }

  static Future<List<dynamic>> getNotes({
    required String doctype,
    required String docname,
  }) async {
    final response = await ApiService.post(
      "$_base.get_notes",
      {
        "doctype": doctype,
        "docname": docname,
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data["message"] ?? [];
    } else {
      throw Exception(data["message"] ?? "Failed to fetch notes");
    }
  }
}