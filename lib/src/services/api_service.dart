import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

class ApiService {
  // Fires whenever any request gets a 401 — app listens and redirects to login
  static final _sessionExpiredController = StreamController<void>.broadcast();
  static Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  static Future<void> _handleUnauthorised() async {
    await StorageService.clearAll();
    _sessionExpiredController.add(null);
    throw const SessionExpiredException();
  }

  static Future<http.Response> get(String endpoint) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    if (baseUrl == null || sid == null) throw Exception("Not authenticated");

    final url  = Uri.parse('$baseUrl$endpoint');
    final resp = await http
        .get(url, headers: {"Cookie": "sid=$sid", "Content-Type": "application/json"})
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> post(String endpoint, Map body) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) throw Exception("Not authenticated");

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    var resp = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    // CSRF expired — refresh token and retry once
    if (resp.statusCode == 403) {
      final newCsrf = await _refreshCsrf(baseUrl, sid);
      if (newCsrf != null) {
        headers["X-Frappe-CSRF-Token"] = newCsrf;
        resp = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }

    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> put(String endpoint, Map body) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) throw Exception("Not authenticated");

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    var resp = await http
        .put(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 403) {
      final newCsrf = await _refreshCsrf(baseUrl, sid);
      if (newCsrf != null) {
        headers["X-Frappe-CSRF-Token"] = newCsrf;
        resp = await http
            .put(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }

    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> delete(String endpoint) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) throw Exception("Not authenticated");

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    final resp = await http
        .delete(url, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  /// Fetches a fresh CSRF token from Frappe and saves it to storage.
  static Future<String?> _refreshCsrf(String baseUrl, String sid) async {
    try {
      final url  = Uri.parse('$baseUrl/api/method/frappe.auth.get_logged_user');
      final resp = await http
          .get(url, headers: {"Cookie": "sid=$sid"})
          .timeout(const Duration(seconds: 10));
      final setCookie = resp.headers['set-cookie'] ?? '';
      final match = RegExp(r'csrf_token=([^;,\s]+)').firstMatch(setCookie);
      final token = match?.group(1);
      if (token != null && token.isNotEmpty) {
        await StorageService.saveCsrfToken(token);
        return token;
      }
    } catch (_) {}
    return null;
  }
}
