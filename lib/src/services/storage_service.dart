import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: "base_url", value: url);
  }

  static Future<String?> getBaseUrl() async {
    return await _storage.read(key: "base_url");
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  static Future<void> saveSessionId(String sid) async {
    await _storage.write(key: "sid", value: sid);
  }

  static Future<String?> getSessionId() async {
    return await _storage.read(key: "sid");
  }
}