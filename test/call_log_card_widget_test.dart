import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/call_log_service.dart';
import 'package:crm_caller_nxtgen/src/screens/call_logs_screen.dart';

void main() {
  group('CallLogCard Widget Tests', () {
    testWidgets('renders Incoming call with correct label and icon', (tester) async {
      final log = CallLog(
        name: 'MCL-001',
        phoneNumber: '0722084691',
        callerName: 'Amila weerasekara',
        direction: 'Received',
        callType: 'Regular',
        callDatetime: '2026-11-03 10:00:00',
        durationSeconds: 45,
        status: 'Answered',
        callOutcome: '',
        linkedDoctype: '',
        linkedDocname: '',
        agent: '',
        notes: '',
        creation: '2026-11-03 10:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallLogCard(log: log, onRefresh: () async {}),
          ),
        ),
      );

      expect(find.text('Amila weerasekara'), findsOneWidget);
      expect(find.text('0722084691'), findsOneWidget);
      expect(find.text('Incoming'), findsOneWidget);
      expect(find.byIcon(Icons.call_received_rounded), findsNWidgets(2)); // avatar badge + direction row
    });

    testWidgets('renders Outgoing call with correct label and icon', (tester) async {
      final log = CallLog(
        name: 'MCL-002',
        phoneNumber: '0712345678',
        callerName: 'Kasun Silva',
        direction: 'Sent',
        callType: 'Regular',
        callDatetime: '2026-11-03 11:00:00',
        durationSeconds: 90,
        status: 'Answered',
        callOutcome: '',
        linkedDoctype: '',
        linkedDocname: '',
        agent: '',
        notes: '',
        creation: '2026-11-03 11:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallLogCard(log: log, onRefresh: () async {}),
          ),
        ),
      );

      expect(find.text('Kasun Silva'), findsOneWidget);
      expect(find.text('0712345678'), findsOneWidget);
      expect(find.text('Outgoing'), findsOneWidget);
      expect(find.byIcon(Icons.call_made_rounded), findsNWidgets(2)); // avatar badge + direction row
    });

    testWidgets('renders Missed call with correct label and icon', (tester) async {
      final log = CallLog(
        name: 'MCL-003',
        phoneNumber: '0779998888',
        callerName: 'Unknown',
        direction: 'Received',
        callType: 'Regular',
        callDatetime: '2026-11-03 12:00:00',
        durationSeconds: 0,
        status: 'Missed',
        callOutcome: '',
        linkedDoctype: '',
        linkedDocname: '',
        agent: '',
        notes: '',
        creation: '2026-11-03 12:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallLogCard(log: log, onRefresh: () async {}),
          ),
        ),
      );

      expect(find.text('Missed'), findsNWidgets(2)); // direction row + status chip
      expect(find.byIcon(Icons.call_missed_rounded), findsNWidgets(3)); // avatar badge + direction row + status chip
    });

    testWidgets('renders Declined call with correct label and end-call icon', (tester) async {
      final log = CallLog(
        name: 'MCL-004',
        phoneNumber: '0771112222',
        callerName: 'Unknown',
        direction: 'Received',
        callType: 'Regular',
        callDatetime: '2026-11-03 13:00:00',
        durationSeconds: 0,
        status: 'Declined',
        callOutcome: '',
        linkedDoctype: '',
        linkedDocname: '',
        agent: '',
        notes: '',
        creation: '2026-11-03 13:00:00',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CallLogCard(log: log, onRefresh: () async {}),
          ),
        ),
      );

      expect(find.text('Declined'), findsNWidgets(2)); // direction row + status chip
      expect(find.byIcon(Icons.call_end_rounded), findsNWidgets(3)); // avatar badge + direction row + status chip
    });
  });
}
