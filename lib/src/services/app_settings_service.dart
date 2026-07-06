import 'dart:convert';
import 'api_service.dart';
import 'storage_service.dart';

class AppSettings {
  final bool enableIncomingCallPopup;
  final bool enableOpportunityPopup;
  final bool enableTicketPopup;
  final int  popupAutoDismissSeconds;
  final String defaultCallDirection;
  final int  maxCallLogsFetch;
  final bool showMissedCallBadge;
  final bool enableOfficeHours;
  final String officeHoursStart;
  final String officeHoursEnd;
  final String officeHoursDays;

  const AppSettings({
    this.enableIncomingCallPopup = true,
    this.enableOpportunityPopup  = true,
    this.enableTicketPopup       = true,
    this.popupAutoDismissSeconds = 0,
    this.defaultCallDirection    = 'Inbound',
    this.maxCallLogsFetch        = 200,
    this.showMissedCallBadge     = true,
    this.enableOfficeHours       = false,
    this.officeHoursStart        = '09:00:00',
    this.officeHoursEnd          = '17:00:00',
    this.officeHoursDays         = '1,2,3,4,5',
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
    enableOfficeHours:       _b(j['enable_office_hours'],        def: false),
    officeHoursStart:        j['office_hours_start']?.toString() ?? '09:00:00',
    officeHoursEnd:          j['office_hours_end']?.toString()   ?? '17:00:00',
    officeHoursDays:         j['office_hours_days']?.toString()  ?? '1,2,3,4,5',
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
          // Whether the native overlay shows at all is now controlled from
          // the Frappe app (Mobile App Settings), not a local toggle — mirror
          // it into the pref the native overlay service reads.
          await StorageService.saveOverlayEnabled(_cache.enableIncomingCallPopup);
          await StorageService.saveOfficeHoursEnabled(_cache.enableOfficeHours);
          
          // Note: Frappe Time fields include seconds (09:00:00), but Flutter's 
          // time strings are expected to be HH:mm (or HH:mm:ss is fine too, 
          // NativeCallOverlayService parses "HH:mm"). We can just save it, 
          // the native side handles the prefix.
          await StorageService.saveOfficeHoursStart(_cache.officeHoursStart);
          await StorageService.saveOfficeHoursEnd(_cache.officeHoursEnd);
          
          // Frappe days vs Android days mapping might need care if Frappe sends "1,2,3,4,5",
          // The native code in Android reads `val daysStr = prefs.getString("flutter.crm_office_hours_days", "1,2,3,4,5")`
          // and parses it by splitting on comma.
          // Wait, `StorageService.saveOfficeHoursDays` takes `List<int> days`.
          // We can parse the comma separated string to List<int> here.
          final daysList = _cache.officeHoursDays
              .split(',')
              .map((e) => int.tryParse(e.trim()) ?? -1)
              .where((e) => e != -1)
              .toList();
          if (daysList.isNotEmpty) {
            await StorageService.saveOfficeHoursDays(daysList);
          }
        }
      }
    } catch (_) {}
    return _cache;
  }
}
