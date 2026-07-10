import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _channel = MethodChannel('crm_caller_nxtgen/native_overlay');

class NativeCallService {
  /// Initiates an outgoing phone call from within the app.
  ///
  /// Uses ACTION_CALL on Android (no dialer UI) so the CRM overlay appears
  /// immediately. Falls back to launchUrl('tel:') if CALL_PHONE is not yet
  /// granted or the channel call fails for any reason.
  static Future<void> makeOutgoingCall(String phone) async {
    if (phone.isEmpty) return;
    try {
      final ok = await _channel.invokeMethod<bool>('makeOutgoingCall', phone) ?? false;
      if (ok) return;
    } catch (_) {}
    // Fallback: open system dialer
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  /// Manually shows the CRM overlay popup for a specific contact — used to
  /// open the same identity card from within the app (e.g. from a Lead in
  /// the pipeline) without an actual phone call happening.
  static Future<void> showOverlayFor({
    required String phone,
    required String name,
    String type = 'Lead',
    String docname = '',
    bool found = true,
    String email = '',
    String status = '',
  }) async {
    if (phone.isEmpty) return;
    try {
      await _channel.invokeMethod('showNativeOverlay', {
        'phone': phone,
        'name': name,
        'type': type,
        'docname': docname,
        'found': found,
        'email': email,
        'status': status,
      });
    } catch (_) {}
  }

  /// Closes the CRM overlay popup if it is currently showing.
  static Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideNativeOverlay');
    } catch (_) {}
  }

  /// Whether this app currently holds the system "Caller ID & spam blocking"
  /// role — required on Android 10+ to learn the real incoming number without
  /// READ_CALL_LOG (which Play Protect flags as a stalkerware indicator).
  static Future<bool> isCallScreeningRoleHeld() async {
    try {
      return await _channel.invokeMethod<bool>('isCallScreeningRoleHeld') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system prompt letting the user grant this app the call
  /// screening role.
  static Future<void> requestCallScreeningRole() async {
    try {
      await _channel.invokeMethod('requestCallScreeningRole');
    } catch (_) {}
  }
}
