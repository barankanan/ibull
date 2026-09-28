import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/map_store_marker.dart';
import 'package:ibul_app/core/map_store_pipeline_helpers.dart';

void main() {
  group('buildSyntheticMapStoresFromProducts', () {
    test('produces unique sellers', () {
      final rows = buildSyntheticMapStoresFromProducts(
        sellers: const [
          (sellerId: 's1', storeName: 'destina'),
          (sellerId: 's1', storeName: 'destina'),
          (sellerId: 's2', storeName: 'sem usta'),
        ],
      );
      expect(rows.length, 2);
      expect(rows.first['business_name'], 'destina');
    });
  });

  group('MapStoreMarker.fromPipelineRow', () {
    test('synthetic Hatay marker when coordinates missing', () {
      final marker = MapStoreMarker.fromPipelineRow(
        const {
          'seller_id': 's1',
          'business_name': 'Teknosa',
          'city': 'Hatay',
          'district': 'Antakya',
        },
        disambiguationIndex: 0,
        source: 'home_ads',
      );
      expect(marker, isNotNull);
      expect(marker!.fromCityFallback, isTrue);
      expect(marker.location.latitude, closeTo(36.2, 0.2));
    });

    test('search-empty marker survives filter indices via business record', () {
      final marker = MapStoreMarker.fromPipelineRow(
        const {
          'seller_id': 's2',
          'business_name': 'sem usta',
          'store_lat': 36.21,
          'store_lng': 36.17,
        },
        disambiguationIndex: 1,
        source: 'stores_table',
      );
      final record = marker!.toBusinessRecord(index: 0);
      expect(record['name'], 'sem usta');
      expect(record['location'], isNotNull);
    });

    test('gallery pin keeps Galerici even when map category is other', () {
      final marker = MapStoreMarker.fromPipelineRow(
        const {
          'seller_id': 'dc3b13dc-6c64-47bf-9670-971dc01c728f',
          'business_name': 'seco',
          'category': 'Galerici',
          'store_lat': 36.21,
          'store_lng': 36.17,
        },
        disambiguationIndex: 0,
        source: 'stores_table',
        mapCategory: (_) => 'other',
      );
      final record = marker!.toBusinessRecord(index: 0);
      expect(record['category'], 'other');
      expect(record['store_category'], 'Galerici');
      expect(record['seller_id'], 'dc3b13dc-6c64-47bf-9670-971dc01c728f');
    });
  });
}
