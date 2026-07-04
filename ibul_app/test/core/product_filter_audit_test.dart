import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/product_filter_audit.dart';

void main() {
  group('ProductFilterAudit', () {
    test('counts active and approval filter drops', () {
      final audit = ProductFilterAudit.fromRows([
        {
          'id': '1',
          'status': 'Aktif',
          'approval_status': 'approved',
        },
        {
          'id': '2',
          'status': 'Aktif',
          'approval_status': null,
        },
        {
          'id': '3',
          'status': 'Pasif',
          'approval_status': 'approved',
        },
      ]);

      expect(audit.rawCount, 3);
      expect(audit.afterActiveStatusCount, 2);
      expect(audit.afterApprovalStatusCount, 1);
      expect(audit.afterVisibilityFilterCount, 1);
      expect(
        ProductFilterAudit.fromRows([
          {
            'id': '2',
            'status': 'Aktif',
            'approval_status': null,
          },
        ]).likelyApprovalFilterDrop,
        isTrue,
      );
    });

    test('empty raw rows', () {
      final audit = ProductFilterAudit.fromRows(const []);
      expect(audit.rawCount, 0);
      expect(audit.isEmptyAfterFilter, isFalse);
    });
  });
}
