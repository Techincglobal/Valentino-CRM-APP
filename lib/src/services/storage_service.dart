import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_call_service.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveBaseUrl(String url) async {
    await _storage.write(key: 'base_url', value: url);
    // Also write to SharedPreferences so native Kotlin can read it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_base_url', url);
  }

  static Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('crm_base_url') ??
        await _storage.read(key: 'base_url');
  }

  static Future<void> saveSessionId(String sid) async {
    await _storage.write(key: 'sid', value: sid);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_sid', sid);
  }

  static Future<String?> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('crm_sid') ?? await _storage.read(key: 'sid');
  }

  static Future<void> saveCsrfToken(String token) async {
    await _storage.write(key: 'csrf_token', value: token);
    // Also write to SharedPreferences so native Kotlin overlay can read it
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_csrf_token', token);
  }

  static Future<String?> getCsrfToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('crm_csrf_token') ??
        await _storage.read(key: 'csrf_token');
  }

  static Future<void> saveFullName(String name) async {
    await _storage.write(key: 'full_name', value: name);
  }

  static Future<String?> getFullName() async {
    return await _storage.read(key: 'full_name');
  }

  // Clears session credentials only — base URL is intentionally preserved so
  // the user lands on the login screen (not site setup) after signing out.
  //
  // Also tears down the native overlay: dropping the sid is what makes the whole
  // call-detection chain go inert, so a popup already on screen must not outlive
  // it. Done here rather than at each sign-out button so the session-expiry path
  // (ApiService._handleUnauthorised) is covered too.
  static Future<void> clearSession() async {
    await _storage.delete(key: 'sid');
    await _storage.delete(key: 'csrf_token');
    await _storage.delete(key: 'full_name');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crm_sid');
    await prefs.remove('crm_csrf_token');
    await NativeCallService.hideOverlay();
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('crm_base_url');
    await prefs.remove('crm_sid');
    await prefs.remove('crm_csrf_token');
    await NativeCallService.hideOverlay();
  }

  // ── Overlay schedule settings (SharedPreferences — readable by Kotlin) ─────

  static Future<void> saveOverlayEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('crm_overlay_enabled', enabled);
  }

  static Future<bool> getOverlayEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('crm_overlay_enabled') ?? true;
  }

  static Future<void> saveOfficeHoursEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('crm_office_hours_enabled', enabled);
  }

  static Future<bool> getOfficeHoursEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('crm_office_hours_enabled') ?? false;
  }

  // Time stored as "HH:mm" string.
  static Future<void> saveOfficeHoursStart(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_office_hours_start', time);
  }

  static Future<String> getOfficeHoursStart() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('crm_office_hours_start') ?? '09:00';
  }

  static Future<void> saveOfficeHoursEnd(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_office_hours_end', time);
  }

  static Future<String> getOfficeHoursEnd() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('crm_office_hours_end') ?? '17:00';
  }

  // Days stored as comma-separated ints: Mon=1 … Sun=7.
  static Future<void> saveOfficeHoursDays(List<int> days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('crm_office_hours_days', days.join(','));
  }

  static Future<List<int>> getOfficeHoursDays() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('crm_office_hours_days') ?? '1,2,3,4,5';
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
  }
}
