import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';


class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

class ApiService {
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
    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url = Uri.parse('$baseUrl$endpoint');
    final sw   = Stopwatch()..start();
    final resp = await http
        .get(url, headers: {"Cookie": "sid=$sid", "Content-Type": "application/json"})
        .timeout(const Duration(seconds: 15));
    sw.stop();

    _logResponse('GET', endpoint, resp.statusCode, sw.elapsedMilliseconds, resp.body);
    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> post(String endpoint, Map body) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    final sw = Stopwatch()..start();
    var resp = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 403) {
      final newCsrf = await _refreshCsrf(baseUrl, sid);
      if (newCsrf != null) {
        headers["X-Frappe-CSRF-Token"] = newCsrf;
        resp = await http
            .post(url, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }

    // Follow redirects for POST if http->https
    if (resp.statusCode == 307 || resp.statusCode == 308 || resp.statusCode == 301 || resp.statusCode == 302) {
      final loc = resp.headers['location'];
      if (loc != null) {
        final newUrl = loc.startsWith('http') ? Uri.parse(loc) : Uri.parse('${url.scheme}://${url.host}$loc');
        resp = await http
            .post(newUrl, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }
    sw.stop();

    _logResponse('POST', endpoint, resp.statusCode, sw.elapsedMilliseconds, resp.body);
    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> put(String endpoint, Map body) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    final sw = Stopwatch()..start();
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

    // Follow redirects for PUT if http->https
    if (resp.statusCode == 307 || resp.statusCode == 308 || resp.statusCode == 301 || resp.statusCode == 302) {
      final loc = resp.headers['location'];
      if (loc != null) {
        final newUrl = loc.startsWith('http') ? Uri.parse(loc) : Uri.parse('${url.scheme}://${url.host}$loc');
        resp = await http
            .put(newUrl, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 20));
      }
    }
    sw.stop();

    _logResponse('PUT', endpoint, resp.statusCode, sw.elapsedMilliseconds, resp.body);
    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static Future<http.Response> delete(String endpoint) async {
    final baseUrl = await StorageService.getBaseUrl();
    final sid     = await StorageService.getSessionId();
    final csrf    = await StorageService.getCsrfToken();
    if (baseUrl == null || sid == null) {
      throw Exception("Not authenticated");
    }

    final url     = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      "Cookie":       "sid=$sid",
      "Content-Type": "application/json",
    };
    if (csrf != null && csrf.isNotEmpty) headers["X-Frappe-CSRF-Token"] = csrf;

    final sw   = Stopwatch()..start();
    final resp = await http
        .delete(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    sw.stop();

    _logResponse('DELETE', endpoint, resp.statusCode, sw.elapsedMilliseconds, resp.body);
    if (resp.statusCode == 401) await _handleUnauthorised();
    return resp;
  }

  static void _logResponse(
      String method, String endpoint, int status, int ms, String body) {}

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
