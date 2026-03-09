import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ApiService {
  static Future<http.Response> get(String endpoint) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid = await StorageService.getSessionId();

    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url = Uri.parse(baseUrl).resolve(endpoint);

    return await http.get(
      url,
      headers: {"Cookie": "sid=$sid", "Content-Type": "application/json"},
    );
  }

  static Future<http.Response> post(String endpoint, Map body) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid = await StorageService.getSessionId();

    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url = Uri.parse(baseUrl).resolve(endpoint);

    return await http.post(
      url,
      headers: {"Cookie": "sid=$sid", "Content-Type": "application/json"},
      body: jsonEncode(body),
    );
  }
}
