import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    final url = Uri.parse("$baseUrl/api/method/login");

    final response = await http.post(
      url,
      body: {
        "usr": username,
        "pwd": password,
      },
    );

    if (response.statusCode == 200) {
      final cookies = response.headers['set-cookie'];

      if (cookies == null) {
        throw Exception("No session cookie received");
      }

      final sid = _extractSid(cookies);

      if (sid == null) {
        throw Exception("SID not found in cookies");
      }

      await StorageService.saveBaseUrl(baseUrl);
      await StorageService.saveSessionId(sid);

      final data = jsonDecode(response.body);

      final fullName = data['full_name'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        await StorageService.saveFullName(fullName);
      }

      return data;
    } else {
      throw Exception("Login failed: ${response.body}");
    }
  }

  static String? _extractSid(String cookieHeader) {
    final parts = cookieHeader.split(';');
    for (var part in parts) {
      if (part.trim().startsWith("sid=")) {
        return part.trim().substring(4);
      }
    }
    return null;
  }
}