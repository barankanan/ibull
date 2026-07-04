import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';

void main() {
  group('map store select fallback', () {
    test('detects missing is_brand_verified column errors', () {
      expect(
        isMissingDbColumnError(
          Exception(
            'PostgrestException: column stores.is_brand_verified does not exist',
          ),
          mapStoreBrandVerifiedColumn,
        ),
        isTrue,
      );
      expect(
        isMissingDbColumnError(
          Exception('permission denied for table stores'),
          mapStoreBrandVerifiedColumn,
        ),
        isFalse,
      );
    });

    test('mapStoreSelectMinimal uses only real stores columns', () {
      expect(mapStoreSelectMinimal, isNot(contains('latitude')));
      expect(mapStoreSelectMinimal, isNot(contains('location_lat')));
      expect(mapStoreSelectMinimal, contains('store_lat'));
      expect(mapStoreSelectMinimal, contains('business_name'));
    });

    test('fallback select omits is_brand_verified column', () {
      expect(
        mapStoreSelect(includeBrandVerified: false),
        isNot(contains(mapStoreBrandVerifiedColumn)),
      );
      expect(
        mapStoreSelect(includeBrandVerified: true),
        contains(mapStoreBrandVerifiedColumn),
      );
      expect(
        mapStoreSelect(includeBrandVerified: false, includeDescription: false),
        isNot(contains(mapStoreDescriptionColumn)),
      );
    });

    test('detects missing description column errors', () {
      expect(
        isMissingDbColumnError(
          Exception(
            'PostgrestException: column stores.description does not exist',
          ),
          mapStoreDescriptionColumn,
        ),
        isTrue,
      );
    });

    test('normalizeMapStoreRows defaults is_brand_verified to false', () {
      final rows = normalizeMapStoreRows(
        [
          {
            'seller_id': 'seller-1',
            'business_name': 'TeknoSA',
            'store_lat': 36.2,
            'store_lng': 36.16,
          },
        ],
        brandVerifiedAvailable: false,
      );

      expect(rows, hasLength(1));
      expect(rows.first['is_brand_verified'], isFalse);
      expect(rows.first['business_name'], 'TeknoSA');
    });

    test('normalizeMapStoreRows preserves verified flag when available', () {
      final rows = normalizeMapStoreRows(
        [
          {
            'seller_id': 'seller-1',
            'is_brand_verified': true,
          },
        ],
        brandVerifiedAvailable: true,
      );

      expect(rows.first['is_brand_verified'], isTrue);
    });
  });
}
