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
}
