import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/ticket_service.dart';

void main() {
  group('SupportTicket Model & Reply Tests', () {
    test('SupportTicket parses fields and computes initials correctly', () {
      final multiWord = SupportTicket.fromJson({
        'name': 'HD-2026-00001',
        'subject': 'Billing issue with renewal invoice',
        'status': 'Open',
        'priority': 'High',
        'raised_by': 'customer@acme.com',
        'creation': '2026-11-03 10:00:00',
        'modified': '2026-11-03 10:30:00',
      });
      expect(multiWord.name, equals('HD-2026-00001'));
      expect(multiWord.subject, equals('Billing issue with renewal invoice'));
      expect(multiWord.status, equals('Open'));
      expect(multiWord.priority, equals('High'));
      expect(multiWord.initials, equals('BI'));

      final singleWord = SupportTicket.fromJson({
        'name': 'HD-2026-00002',
        'subject': 'Inquiry',
        'status': 'Closed',
        'priority': 'Low',
        'raised_by': 'user@example.com',
        'creation': '2026-11-02 12:00:00',
        'modified': '2026-11-02 12:00:00',
      });
      expect(singleWord.initials, equals('I'));

      final emptySubject = SupportTicket.fromJson({
        'name': 'HD-2026-00003',
      });
      expect(emptySubject.subject, equals('(no subject)'));
      expect(emptySubject.initials, equals('(S'));
    });

    test('TicketReply parses sender, message, and agent flag correctly', () {
      final agentReply = TicketReply.fromJson({
        'sender': 'agent@crm.com',
        'message': 'We have credited your account.',
        'creation': '2026-11-03 11:00:00',
        'is_agent': '1',
      });
      expect(agentReply.sender, equals('agent@crm.com'));
      expect(agentReply.message, equals('We have credited your account.'));
      expect(agentReply.isAgent, isTrue);
      expect(agentReply.senderLabel, equals('agent')); // Strips domain for clean display

      final customerReply = TicketReply.fromJson({
        'sender': '',
        'message': 'Thank you!',
        'creation': '2026-11-03 11:05:00',
        'is_agent': '0',
      });
      expect(customerReply.isAgent, isFalse);
      expect(customerReply.senderLabel, equals('Unknown'));
    });
  });
}
