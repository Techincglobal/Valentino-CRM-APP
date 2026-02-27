import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: 'base_url', value: url);
    // Also write to SharedPreferences so native Kotlin can read it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_base_url', url);
  }

  static Future<String?> getBaseUrl() async {
    return await _storage.read(key: 'base_url');
  }

  static Future<void> saveSessionId(String sid) async {
    await _storage.write(key: 'sid', value: sid);
    // Also write to SharedPreferences so native Kotlin can read it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_sid', sid);
  }

  static Future<String?> getSessionId() async {
    return await _storage.read(key: 'sid');
  }

  static Future<void> saveFullName(String name) async {
    await _storage.write(key: 'full_name', value: name);
  }

  static Future<String?> getFullName() async {
    return await _storage.read(key: 'full_name');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crm_base_url');
    await prefs.remove('crm_sid');
  }
}
