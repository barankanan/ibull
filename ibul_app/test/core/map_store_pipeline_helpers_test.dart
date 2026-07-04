import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/map_store_pipeline_helpers.dart';
import 'package:ibul_app/core/product_list_schema_helpers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('product list schema helpers', () {
    test('detects PGRST204 missing column', () {
      const error = PostgrestException(
        message:
            "Could not find the 'category' column of 'product_lists' in the schema cache",
        code: 'PGRST204',
      );
      expect(isProductListMissingColumnError(error), isTrue);
      expect(extractMissingProductListColumn(error), 'category');
    });

    test('stripProductListHeaderColumn removes column', () {
      final stripped = stripProductListHeaderColumn({
        'id': 'list-1',
        'category': 'Yemek',
        'name': 'Liste',
      }, 'category');
      expect(stripped.containsKey('category'), isFalse);
      expect(stripped['name'], 'Liste');
    });
  });

  group('map store pipeline helpers', () {
    test('buildSyntheticMapStoresFromProducts dedupes sellers', () {
      final rows = buildSyntheticMapStoresFromProducts(
        sellers: [
          (sellerId: 's1', storeName: 'Mağaza A'),
          (sellerId: 's1', storeName: 'Mağaza A'),
          (sellerId: 's2', storeName: 'Mağaza B'),
        ],
      );
      expect(rows, hasLength(2));
      expect(rows.first['business_name'], 'Mağaza A');
    });

    test('diagnoseMapStoresEmpty explains RLS when sellers exist but stores=0', () {
      final msg = diagnoseMapStoresEmpty(
        storesTableCount: 0,
        productSellerFallbackCount: 0,
        syntheticFromProductsCount: 0,
        activeProductsWithSeller: 12,
        uniqueSellers: 4,
        markerCount: 0,
      );
      expect(msg, contains('RLS'));
    });
  });
}
