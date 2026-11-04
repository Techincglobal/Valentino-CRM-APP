import 'package:flutter_test/flutter_test.dart';
import 'package:crm_caller_nxtgen/src/services/caller_service.dart';

void main() {
  group('CallerService Models Tests', () {
    test('CallerNote handles note vs content and ownerLabel correctly', () {
      final note1 = CallerNote.fromJson({
        'note': 'Customer requested a quote for 5 licenses.',
        'owner': 'sales.agent@valentinocrm.com',
        'creation': '2026-11-03 14:00:00',
      });
      expect(note1.note, equals('Customer requested a quote for 5 licenses.'));
      expect(note1.owner, equals('sales.agent@valentinocrm.com'));
      expect(note1.ownerLabel, equals('sales.agent'));

      final note2 = CallerNote.fromJson({
        'content': 'Meeting completed.',
        'modified_by': 'admin',
        'creation': '',
      });
      expect(note2.note, equals('Meeting completed.'));
      expect(note2.owner, equals('admin'));
      expect(note2.ownerLabel, equals('admin'));
      expect(note2.timeLabel, equals(''));
    });

    test('CallerContext empty instance has consistent defaults', () {
      const empty = CallerContext.empty;
      expect(empty.found, isFalse);
      expect(empty.docname, isEmpty);
      expect(empty.displayName, isEmpty);
      expect(empty.doctype, isEmpty);
      expect(empty.email, isEmpty);
      expect(empty.notes, isEmpty);
    });
  });
}
