import 'dart:convert';
import 'api_service.dart';

class AppSettings {
  final bool enableIncomingCallPopup;
  final bool enableOpportunityPopup;
  final bool enableTicketPopup;
  final int  popupAutoDismissSeconds;
  final String defaultCallDirection;
  final int  maxCallLogsFetch;
  final bool showMissedCallBadge;

  const AppSettings({
    this.enableIncomingCallPopup = true,
    this.enableOpportunityPopup  = true,
    this.enableTicketPopup       = true,
    this.popupAutoDismissSeconds = 0,
    this.defaultCallDirection    = 'Inbound',
    this.maxCallLogsFetch        = 200,
    this.showMissedCallBadge     = true,
  });

  static const AppSettings defaults = AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    enableIncomingCallPopup: _b(j['enable_incoming_call_popup'], def: true),
    enableOpportunityPopup:  _b(j['enable_opportunity_popup'],   def: true),
    enableTicketPopup:       _b(j['enable_ticket_popup'],        def: true),
    popupAutoDismissSeconds: _i(j['popup_auto_dismiss_seconds']),
    defaultCallDirection:    j['default_call_direction']?.toString() ?? 'Inbound',
    maxCallLogsFetch:        _i(j['max_call_logs_fetch'], def: 200),
    showMissedCallBadge:     _b(j['show_missed_call_badge'],     def: true),
  );

  static bool _b(dynamic v, {bool def = false}) {
    if (v == null) return def;
    if (v is bool) return v;
    return v.toString() == '1' || v.toString().toLowerCase() == 'true';
  }

  static int _i(dynamic v, {int def = 0}) {
    if (v == null) return def;
    return int.tryParse(v.toString()) ?? def;
  }
}

class AppSettingsService {
  static AppSettings _cache = AppSettings.defaults;

  static AppSettings get current => _cache;

  static Future<AppSettings> load() async {
    try {
      final resp = await ApiService.post(
          '/api/method/nxtgen_crm_mobile.api.get_app_settings', {});
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final msg  = body['message'];
        if (msg is Map<String, dynamic>) {
          _cache = AppSettings.fromJson(msg);
        }
      }
    } catch (_) {}
    return _cache;
  }
}
