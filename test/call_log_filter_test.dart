import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/call_log_service.dart';

void main() {
  group('CallLog Filtering & Tab Logic Tests', () {
    final sampleLogs = [
      // 1. Incoming Answered
      CallLog(
        name: 'MCL-001', phoneNumber: '0722084691', callerName: 'Amila',
        direction: 'Received', callType: 'Regular', callDatetime: '2026-11-03 10:00:00',
        durationSeconds: 45, status: 'Answered', callOutcome: '', linkedDoctype: '',
        linkedDocname: '', agent: '', notes: '', creation: '2026-11-03 10:00:00',
      ),
      // 2. Incoming Missed
      CallLog(
        name: 'MCL-002', phoneNumber: '0711111111', callerName: 'Unknown',
        direction: 'Received', callType: 'Regular', callDatetime: '2026-11-03 10:15:00',
        durationSeconds: 0, status: 'Missed', callOutcome: '', linkedDoctype: '',
        linkedDocname: '', agent: '', notes: '', creation: '2026-11-03 10:15:00',
      ),
      // 3. Incoming Declined
      CallLog(
        name: 'MCL-003', phoneNumber: '0733333333', callerName: 'Spam',
        direction: 'Received', callType: 'Regular', callDatetime: '2026-11-03 10:30:00',
        durationSeconds: 0, status: 'Declined', callOutcome: '', linkedDoctype: '',
        linkedDocname: '', agent: '', notes: '', creation: '2026-11-03 10:30:00',
      ),
      // 4. Outgoing Answered
      CallLog(
        name: 'MCL-004', phoneNumber: '0744444444', callerName: 'Client A',
        direction: 'Sent', callType: 'Regular', callDatetime: '2026-11-03 11:00:00',
        durationSeconds: 120, status: 'Answered', callOutcome: '', linkedDoctype: '',
        linkedDocname: '', agent: '', notes: '', creation: '2026-11-03 11:00:00',
      ),
      // 5. Outgoing No Answer
      CallLog(
        name: 'MCL-005', phoneNumber: '0755555555', callerName: 'Client B',
        direction: 'Sent', callType: 'Regular', callDatetime: '2026-11-03 11:30:00',
        durationSeconds: 0, status: 'No Answer', callOutcome: '', linkedDoctype: '',
        linkedDocname: '', agent: '', notes: '', creation: '2026-11-03 11:30:00',
      ),
    ];

    test('counts and filters accurately for each CallLogTab', () {
      final allLogs = sampleLogs;
      expect(allLogs.length, equals(5));

      // Incoming: answered incoming only
      final incoming = allLogs.where((l) => l.isInbound && !l.isMissed && !l.isDeclined).toList();
      expect(incoming.length, equals(1));
      expect(incoming.first.name, equals('MCL-001'));

      // Outgoing: both answered and unanswered outbound
      final outgoing = allLogs.where((l) => l.isOutbound).toList();
      expect(outgoing.length, equals(2));
      expect(outgoing.map((l) => l.name), containsAll(['MCL-004', 'MCL-005']));

      // Missed & Declined: missed incoming + declined incoming
      final missedDeclined = allLogs.where((l) => l.isMissed || l.isDeclined).toList();
      expect(missedDeclined.length, equals(2));
      expect(missedDeclined.map((l) => l.name), containsAll(['MCL-002', 'MCL-003']));
    });
  });
}
