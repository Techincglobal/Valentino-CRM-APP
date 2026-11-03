import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/call_log_service.dart';

void main() {
  group('CallLog Model Tests', () {
    test('parses ERPNext standard "Received" direction as Inbound', () {
      final json = {
        'name': 'MCL-2026-11-00001',
        'phone_number': '0722084691',
        'caller_name': 'Amila weerasekara',
        'direction': 'Received',
        'call_type': 'Regular',
        'duration': '45',
        'status': 'Answered',
      };

      final log = CallLog.fromJson(json);

      expect(log.phoneNumber, equals('0722084691'));
      expect(log.callerName, equals('Amila weerasekara'));
      expect(log.isInbound, isTrue);
      expect(log.isOutbound, isFalse);
      expect(log.isMissed, isFalse);
      expect(log.directionLabel, equals('Incoming'));
      expect(log.initials, equals('AW'));
      expect(log.durationLabel, equals('45s'));
    });

    test('parses ERPNext standard "Sent" direction as Outbound', () {
      final json = {
        'name': 'MCL-2026-11-00002',
        'phone_number': '+94712345678',
        'caller_name': 'Nimal Perera',
        'direction': 'Sent',
        'call_type': 'Regular',
        'duration': '135',
        'status': 'Answered',
      };

      final log = CallLog.fromJson(json);

      expect(log.isInbound, isFalse);
      expect(log.isOutbound, isTrue);
      expect(log.isMissed, isFalse);
      expect(log.directionLabel, equals('Outgoing'));
      expect(log.durationLabel, equals('2m 15s'));
    });

    test('parses "Inbound" and "Outbound" directions correctly', () {
      final inLog = CallLog.fromJson({
        'name': '1', 'phone_number': '111', 'caller_name': 'A', 'direction': 'Inbound',
      });
      expect(inLog.isInbound, isTrue);
      expect(inLog.isOutbound, isFalse);
      expect(inLog.directionLabel, equals('Incoming'));

      final outLog = CallLog.fromJson({
        'name': '2', 'phone_number': '222', 'caller_name': 'B', 'direction': 'Outbound',
      });
      expect(outLog.isInbound, isFalse);
      expect(outLog.isOutbound, isTrue);
      expect(outLog.directionLabel, equals('Outgoing'));
    });

    test('parses "Missed" direction or status as Missed', () {
      final missedDir = CallLog.fromJson({
        'name': '3', 'phone_number': '333', 'caller_name': 'Unknown', 'direction': 'Missed',
      });
      expect(missedDir.isMissed, isTrue);
      expect(missedDir.directionLabel, equals('Missed'));

      final missedStatus = CallLog.fromJson({
        'name': '4', 'phone_number': '444', 'caller_name': 'Unknown', 'direction': 'Received', 'status': 'Missed',
      });
      expect(missedStatus.isMissed, isTrue);
      expect(missedStatus.directionLabel, equals('Missed'));
    });

    test('parses WhatsApp call type case-insensitively', () {
      final waLog = CallLog.fromJson({
        'name': '5', 'phone_number': '555', 'call_type': 'WhatsApp',
      });
      expect(waLog.isWhatsApp, isTrue);

      final waLower = CallLog.fromJson({
        'name': '6', 'phone_number': '666', 'call_type': 'whatsapp',
      });
      expect(waLower.isWhatsApp, isTrue);

      final regular = CallLog.fromJson({
        'name': '7', 'phone_number': '777', 'call_type': 'Regular',
      });
      expect(regular.isWhatsApp, isFalse);
    });

    test('handles Unknown caller and empty names', () {
      final unknownLog = CallLog.fromJson({
        'name': '8', 'phone_number': '0722084691', 'caller_name': 'Unknown',
      });
      expect(unknownLog.callerLabel, equals('Unknown'));
      expect(unknownLog.initials, equals('U'));

      final phoneOnlyLog = CallLog.fromJson({
        'name': '9', 'phone_number': '0722084691', 'caller_name': '',
      });
      expect(phoneOnlyLog.callerLabel, equals('0722084691'));
      expect(phoneOnlyLog.initials, equals('0'));
    });
  });
}
