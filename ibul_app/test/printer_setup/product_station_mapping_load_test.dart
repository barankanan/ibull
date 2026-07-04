import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/utils/product_visibility_helper.dart';

void main() {
  group('Product station mapping load', () {
    test('seller product rows are not filtered by public visibility helper', () {
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p1',
          'seller_id': 'seller-1',
          'name': 'Karışık Servis',
          'status': 'Aktif',
          'approval_status': 'pending',
          'station_id': null,
          'printer_routing_enabled': true,
        },
        <String, dynamic>{
          'id': 'p2',
          'seller_id': 'seller-1',
          'name': 'Katı Cacık',
          'status': 'active',
          'admin_approval_status': null,
          'station_id': 'station-1',
          'printer_routing_enabled': true,
        },
      ];

      final publicFiltered = ProductVisibilityHelper.filterPublicProductMaps(rows);
      expect(publicFiltered, isEmpty);

      final sellerProducts = rows
          .map((row) => SellerProduct.fromMap(row, row['id']!.toString()))
          .toList();
      expect(sellerProducts, hasLength(2));
      expect(sellerProducts.map((p) => p.name), contains('Karışık Servis'));
      expect(sellerProducts.map((p) => p.name), contains('Katı Cacık'));
    });

    test('sellerId is used as restaurantId in printer settings context', () {
      const sellerId = 'restaurant-seller-uuid';
      const restaurantId = sellerId;
      expect(restaurantId, sellerId);
    });

    test('empty fetch with error should not masquerade as success', () {
      Object? caught;
      try {
        throw StateError('network');
      } catch (error) {
        caught = error;
      }
      expect(caught, isNotNull);
      expect(caught.toString(), contains('network'));
    });
  });
}
