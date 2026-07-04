import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/product_visibility_helper.dart';

void main() {
  group('ProductVisibilityHelper', () {
    test('active approved product is public visible', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'approval_status': 'approved',
        }),
        isTrue,
      );
    });

    test('active with english status and admin approval is public visible', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'active',
          'admin_approval_status': 'approved',
        }),
        isTrue,
      );
    });

    test('active with turkish approved token is public visible', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'approval_status': 'onaylandı',
        }),
        isTrue,
      );
    });

    test('active product without approval keys trusts RLS-filtered row', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'name': 'Phone',
        }),
        isTrue,
      );
    });

    test('active product with explicit null approval is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'approval_status': null,
          'admin_approval_status': null,
        }),
        isFalse,
      );
    });

    test('pending approval status product is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'pending_approval',
        }),
        isFalse,
      );
    });

    test('active with pending approval_status is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'approval_status': 'pending_approval',
        }),
        isFalse,
      );
    });

    test('active with pending admin_approval_status is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'admin_approval_status': 'pending_approval',
        }),
        isFalse,
      );
    });

    test('active with rejected approval_status is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Aktif',
          'approval_status': 'rejected',
        }),
        isFalse,
      );
    });

    test('passive product with approved approval is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Pasif',
          'approval_status': 'approved',
        }),
        isFalse,
      );
    });

    test('draft product with approved approval is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'Taslak',
          'approval_status': 'approved',
        }),
        isFalse,
      );
    });

    test('rejected status product is hidden from public', () {
      expect(
        ProductVisibilityHelper.isPublicVisibleProductMap({
          'status': 'rejected',
        }),
        isFalse,
      );
    });

    test('customer cart rejects non-public product', () {
      expect(
        ProductVisibilityHelper.isCustomerCartEligibleMap({
          'status': 'Aktif',
          'approval_status': 'pending_approval',
          'stock': 5,
        }),
        isFalse,
      );
    });

    test('customer cart rejects zero stock public product', () {
      expect(
        ProductVisibilityHelper.isCustomerCartEligibleMap({
          'status': 'Aktif',
          'approval_status': 'approved',
          'stock': 0,
        }),
        isFalse,
      );
    });

    test('customer cart accepts approved in-stock product', () {
      expect(
        ProductVisibilityHelper.isCustomerCartEligibleMap({
          'status': 'Aktif',
          'approval_status': 'approved',
          'stock': 3,
        }),
        isTrue,
      );
    });

    test('dedupeOtherSellerRows excludes same seller and product', () {
      final rows = ProductVisibilityHelper.dedupeOtherSellerRows(
        [
          {
            'id': 'p1',
            'seller_id': 's1',
            'status': 'Aktif',
            'approval_status': 'approved',
          },
          {
            'id': 'p2',
            'seller_id': 's1',
            'status': 'Aktif',
            'approval_status': 'approved',
          },
          {
            'id': 'p3',
            'seller_id': 's2',
            'status': 'Aktif',
            'approval_status': 'approved',
          },
        ],
        excludeSellerId: 's0',
        excludeProductId: 'p9',
        limit: 10,
      );

      expect(rows.length, 2);
      expect(rows.map((row) => row['seller_id']).toSet(), {'s1', 's2'});
    });

    test('ad-linked active product with empty approval is displayable', () {
      expect(
        ProductVisibilityHelper.isAdLinkedDisplayProductMap({
          'status': 'Aktif',
          'approval_status': '',
        }),
        isTrue,
      );
    });

    test('ad-linked rejected approval product stays hidden', () {
      expect(
        ProductVisibilityHelper.isAdLinkedDisplayProductMap({
          'status': 'Aktif',
          'approval_status': 'rejected',
        }),
        isFalse,
      );
      expect(
        ProductVisibilityHelper.adLinkedDisplayRejectReason({
          'status': 'Aktif',
          'approval_status': 'rejected',
        }),
        contains('approval_rejected'),
      );
    });

    test('ad-linked pending approval product is displayable', () {
      expect(
        ProductVisibilityHelper.isAdLinkedDisplayProductMap({
          'status': 'Aktif',
          'approval_status': 'pending_approval',
        }),
        isTrue,
      );
    });

    test('ad-linked reject reason null for active empty approval', () {
      expect(
        ProductVisibilityHelper.adLinkedDisplayRejectReason({
          'status': 'Aktif',
          'approval_status': null,
          'admin_approval_status': null,
        }),
        isNull,
      );
    });
  });
}
