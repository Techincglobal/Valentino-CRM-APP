import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage_service.dart';


class AuthService {
  static Future<Map<String, dynamic>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final Uri url;
    try {
      url = Uri.parse(baseUrl.endsWith('/')
          ? '${baseUrl}api/method/login'
          : '$baseUrl/api/method/login');
    } catch (_) {
      throw Exception('Invalid server URL. Please check your site address.');
    }

    try {
      final response = await http
          .post(url, body: {'usr': username, 'pwd': password})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final cookies = response.headers['set-cookie'];
        if (cookies == null) {
          throw Exception('No session received from server.');
        }

        final sid = _extractCookieValue(cookies, 'sid');
        if (sid == null) {
          throw Exception('Could not read session from server response.');
        }

        await StorageService.saveBaseUrl(baseUrl);
        await StorageService.saveSessionId(sid);

        final csrf = _extractCookieValue(cookies, 'csrf_token');
        if (csrf != null && csrf.isNotEmpty) {
          await StorageService.saveCsrfToken(csrf);
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final fullName = data['full_name'] as String?;
        if (fullName != null && fullName.isNotEmpty) {
          await StorageService.saveFullName(fullName);
        }
        return data;
      } else {
        final msg = _parseErrorBody(response.body, response.statusCode);
        throw Exception(msg);
      }
    } on SocketException {
      throw Exception('Cannot reach the server. Check your site URL and internet connection.');
    } on TimeoutException {
      throw Exception('Request timed out. The server took too long to respond.');
    } on FormatException {
      throw Exception('Unexpected response from server. Please try again.');
    }
  }

  /// Parses Frappe JSON error body → clean user-facing string.
  static String _parseErrorBody(String body, int statusCode) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Frappe v14/v15 login returns {"message": "...", "exc": "..."}
      final msg = data['message'] as String?;
      if (msg != null && msg.isNotEmpty && msg != 'null') {
        // Common Frappe messages
        if (msg.toLowerCase().contains('incorrect') ||
            msg.toLowerCase().contains('invalid') ||
            msg.toLowerCase().contains('not found')) {
          return 'Incorrect username or password.';
        }
        if (msg.toLowerCase().contains('disabled') ||
            msg.toLowerCase().contains('blocked')) {
          return 'Your account has been disabled. Contact your administrator.';
        }
        // Return as-is if reasonably short
        if (msg.length < 120) return msg;
      }

      // Frappe sometimes returns exc_type
      final excType = data['exc_type'] as String?;
      if (excType != null) {
        if (excType == 'AuthenticationError') {
          return 'Incorrect username or password.';
        }
        return 'Login failed ($excType).';
      }
    } catch (_) {
      // body wasn't JSON
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'Incorrect username or password.';
    }
    if (statusCode >= 500) {
      return 'Server error ($statusCode). Please try again later.';
    }
    return 'Login failed (HTTP $statusCode). Please try again.';
  }

  /// Extracts a named cookie value from a combined Set-Cookie header string.
  /// Handles Dart http library joining multiple Set-Cookie headers with ', '.
  static String? _extractCookieValue(String cookieHeader, String name) {
    for (final segment in cookieHeader.split(RegExp(r'[;,]'))) {
      final trimmed = segment.trim();
      if (trimmed.startsWith('$name=')) {
        final value = trimmed.substring(name.length + 1).trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }
}
