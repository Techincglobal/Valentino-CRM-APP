import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/sales_service.dart';

void main() {
  group('Sales Models & Parsing Tests', () {
    test('CrmLead parsing handles first_name and lead_name correctly', () {
      final leadWithFull = CrmLead.fromJson({
        'name': 'LEAD-001',
        'lead_name': 'Amila Weerasekara',
        'email_id': 'amila@example.com',
        'mobile_no': '0722084691',
        'status': 'Open',
        'modified': '2026-11-03 10:00:00',
      });
      expect(leadWithFull.name, equals('LEAD-001'));
      expect(leadWithFull.displayName, equals('Amila Weerasekara'));
      expect(leadWithFull.initials, equals('AW'));
      expect(leadWithFull.email, equals('amila@example.com'));
      expect(leadWithFull.mobile, equals('0722084691'));

      final leadWithFirst = CrmLead.fromJson({
        'name': 'LEAD-002',
        'first_name': 'Kasun',
        'email_id': '',
        'mobile_no': '',
      });
      expect(leadWithFirst.displayName, equals('Kasun'));
      expect(leadWithFirst.initials, equals('K'));

      final leadEmpty = CrmLead.fromJson({
        'name': 'LEAD-003',
      });
      expect(leadEmpty.displayName, equals('Unknown'));
      expect(leadEmpty.initials, equals('U'));
    });

    test('Opportunity parsing handles customer_name, title, and party_name hierarchy', () {
      final oppCustomer = Opportunity.fromJson({
        'name': 'CRM-OPP-2026-00001',
        'customer_name': 'Enterprise Corp',
        'title': 'Server upgrade',
        'party_name': 'LEAD-001',
        'opportunity_amount': 250000.0,
        'stage': 'Proposal/Price Quote',
        'status': 'Open',
        'expected_closing': '2026-12-01',
      });
      expect(oppCustomer.partyName, equals('Enterprise Corp'));
      expect(oppCustomer.partyDocname, equals('LEAD-001'));
      expect(oppCustomer.amount, equals(250000.0));
      expect(oppCustomer.stage, equals('Proposal/Price Quote'));

      final oppTitle = Opportunity.fromJson({
        'name': 'CRM-OPP-2026-00002',
        'customer_name': '',
        'title': 'Direct Equipment Sale',
        'party_name': 'LEAD-002',
        'expected_revenue': 12000.5,
      });
      expect(oppTitle.partyName, equals('Direct Equipment Sale'));
      expect(oppTitle.amount, equals(12000.5));

      final oppParty = Opportunity.fromJson({
        'name': 'CRM-OPP-2026-00003',
        'customer_name': '',
        'title': '',
        'party_name': 'Amila',
      });
      expect(oppParty.partyName, equals('Amila'));
    });

    test('Quotation model parses totals and default currency correctly', () {
      final quote = Quotation.fromJson({
        'name': 'SAL-QTN-2026-00010',
        'party_name': 'Acme Ltd',
        'grand_total': 1500000.0,
        'status': 'Submitted',
        'modified': '2026-11-02 08:30:00',
        'currency': 'LKR',
      });
      expect(quote.name, equals('SAL-QTN-2026-00010'));
      expect(quote.partyName, equals('Acme Ltd'));
      expect(quote.grandTotal, equals(1500000.0));
      expect(quote.status, equals('Submitted'));
      expect(quote.currency, equals('LKR'));
    });

    test('FrappeItem parses itemCode, itemName, and standardRate', () {
      final item = FrappeItem.fromJson({
        'name': 'CRM-PROD-01',
        'item_name': 'Enterprise Annual License',
        'description': 'Software subscription',
        'standard_rate': 75000.0,
      });
      expect(item.itemCode, equals('CRM-PROD-01'));
      expect(item.itemName, equals('Enterprise Annual License'));
      expect(item.description, equals('Software subscription'));
      expect(item.standardRate, equals(75000.0));
    });
  });
}
