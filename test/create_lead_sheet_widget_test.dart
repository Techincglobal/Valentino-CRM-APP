import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/call_log_service.dart';
import 'package:crm_caller_nxtgen/src/screens/call_logs_screen.dart';

void main() {
  group('CreateLeadSheet Widget Tests', () {
    testWidgets('renders properly and does NOT overflow when keyboard is open', (tester) async {
      final log = CallLog(
        name: 'MCL-001',
        phoneNumber: '0722084691',
        callerName: 'Unknown',
        direction: 'Received',
        callType: 'Regular',
        callDatetime: '2026-11-03 10:00:00',
        durationSeconds: 30,
        status: 'Answered',
        callOutcome: '',
        linkedDoctype: '',
        linkedDocname: '',
        agent: '',
        notes: '',
        creation: '2026-11-03 10:00:00',
      );

      // Set physical size to a standard phone height: 400x800
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Simulate on-screen keyboard by setting bottom viewInsets to 300px
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CreateLeadSheet(log: log),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and fields exist
      expect(find.text('Create Lead'), findsNWidgets(2)); // Title + button
      expect(find.text('From call with Unknown'), findsOneWidget);
      expect(find.text('0722084691'), findsOneWidget);

      // Verify no RenderFlex overflow exception was thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows validation snackbar if invalid email is submitted', (tester) async {
      final log = CallLog(
        name: 'MCL-002',
        phoneNumber: '0722084691',
        callerName: 'Unknown',
        direction: 'Received',
        callType: 'Regular',
        callDatetime: '2026-11-03 10:00:00',
        durationSeconds: 30,
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
            body: CreateLeadSheet(log: log),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter name
      await tester.enterText(find.widgetWithText(TextField, 'e.g. John Smith'), 'Amila weerasekara');

      // Enter incomplete email 'amila' (from user screenshot)
      await tester.enterText(find.widgetWithText(TextField, 'lead@example.com'), 'amila');

      // Tap 'Create Lead' button
      await tester.tap(find.widgetWithText(GestureDetector, 'Create Lead'));
      await tester.pump();

      // Verify error snackbar is displayed
      expect(find.text('Please enter a valid email address or leave it blank.'), findsOneWidget);
    });
  });
}
