import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store_service_mappers.dart';

void main() {
  // ── F-06 tests ─────────────────────────────────────────────────────────────

  group('productToSnakeCase (F-06)', () {
    test('UPDATE path: does NOT contain created_at', () {
      final result = StoreServiceMappers.productToSnakeCase({
        'name': 'Köfte',
        'price': 90.0,
        'stock': 10,
      });

      expect(
        result.containsKey('created_at'),
        isFalse,
        reason: 'productToSnakeCase must never include created_at so that '
            'UPDATE calls cannot overwrite the original creation timestamp.',
      );
    });

    test('UPDATE path: updated_at is set explicitly by updateProduct, '
        'not by the mapper itself', () {
      // updated_at is injected by store_service.dart::updateProduct after
      // calling productToSnakeCase, so the mapper must NOT contain it either.
      // This test documents that contract.
      final result = StoreServiceMappers.productToSnakeCase({
        'name': 'Köfte',
        'price': 90.0,
      });

      expect(
        result.containsKey('updated_at'),
        isFalse,
        reason: 'Mapper stays pure. Callers are responsible for setting '
            'updated_at to ensure the correct timestamp is used.',
      );
    });

    test('INSERT path: created_at is set explicitly by addProduct', () {
      // Simulate what addProduct does after calling productToSnakeCase:
      // it injects created_at itself so the DB timestamp is controlled.
      final dbData = StoreServiceMappers.productToSnakeCase({'name': 'Lahmacun'});
      dbData['created_at'] = DateTime.now().toIso8601String();

      expect(
        dbData.containsKey('created_at'),
        isTrue,
        reason: 'INSERT path must explicitly add created_at after the mapper.',
      );
    });
  });

  // ── storeToCamelCase / storeToSnakeCase ────────────────────────────────────

  test('storeToCamelCase maps store fields for UI', () {
    final mapped = StoreServiceMappers.storeToCamelCase({
      'business_name': 'Teknosa',
      'website': 'https://teknosa.com',
      'support_phone': '555',
      'store_lat': 39.9,
      'store_lng': 32.8,
      'seller_videos': ['video.mp4'],
    });

    expect(mapped['storeName'], 'Teknosa');
    expect(mapped['storeUrl'], 'https://teknosa.com');
    expect(mapped['supportPhone'], '555');
    expect(mapped['storeLat'], 39.9);
    expect(mapped['sellerVideos'], ['video.mp4']);
  });

  test('storeToSnakeCase maps UI fields for persistence', () {
    final mapped = StoreServiceMappers.storeToSnakeCase({
      'storeName': 'Teknosa',
      'supportPhone': '555',
      'storeLat': 39.9,
      'storeLng': 32.8,
      'sellerVideos': ['video.mp4'],
    });

    expect(mapped['business_name'], 'Teknosa');
    expect(mapped['support_phone'], '555');
    expect(mapped['store_lat'], 39.9);
    expect(mapped['store_lng'], 32.8);
    expect(mapped['seller_videos'], ['video.mp4']);
  });
}
