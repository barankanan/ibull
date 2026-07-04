import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';

void main() {
  group('parseStoreCoordinate', () {
    test('parses numeric coordinates', () {
      expect(parseStoreCoordinate(36.2025), 36.2025);
      expect(parseStoreCoordinate(36), 36.0);
    });

    test('parses string coordinates with dot', () {
      expect(parseStoreCoordinate('36.1605'), 36.1605);
    });

    test('parses string coordinates with comma decimal', () {
      expect(parseStoreCoordinate('36,1605'), 36.1605);
    });

    test('returns null for null/empty/garbage', () {
      expect(parseStoreCoordinate(null), isNull);
      expect(parseStoreCoordinate(''), isNull);
      expect(parseStoreCoordinate('   '), isNull);
      expect(parseStoreCoordinate('not-a-number'), isNull);
      expect(parseStoreCoordinate(double.nan), isNull);
      expect(parseStoreCoordinate(double.infinity), isNull);
    });
  });

  group('resolveStoreLatLng', () {
    test('reads canonical store_lat/store_lng', () {
      final coords = resolveStoreLatLng({
        'store_lat': 36.2025,
        'store_lng': 36.1605,
      });
      expect(coords, isNotNull);
      expect(coords!.lat, 36.2025);
      expect(coords.lng, 36.1605);
    });

    test('falls back to latitude/longitude aliases', () {
      final coords = resolveStoreLatLng({
        'latitude': 36.2,
        'longitude': 36.16,
      });
      expect(coords, isNotNull);
      expect(coords!.lat, 36.2);
      expect(coords.lng, 36.16);
    });

    test('falls back to location_lat/location_lng aliases', () {
      final coords = resolveStoreLatLng({
        'location_lat': '36.2',
        'location_lng': '36.16',
      });
      expect(coords, isNotNull);
      expect(coords!.lat, 36.2);
    });

    test('falls back to store_latitude/store_longitude aliases', () {
      final coords = resolveStoreLatLng({
        'store_latitude': 36.2,
        'store_longitude': 36.16,
      });
      expect(coords, isNotNull);
    });

    test('parses string coordinates (does not crash, does not drop)', () {
      final coords = resolveStoreLatLng({
        'store_lat': '36,2025',
        'store_lng': '36,1605',
      });
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(36.2025, 0.0001));
    });

    test('address_lat/address_lng aliases', () {
      final coords = resolveStoreLatLng({
        'address_lat': 36.2,
        'address_lng': 36.16,
      });
      expect(coords, isNotNull);
      expect(coords!.lat, 36.2);
    });

    test('returns null when a coordinate is missing (skip, no crash)', () {
      expect(
        resolveStoreLatLng({'store_lat': 36.2, 'store_lng': null}),
        isNull,
      );
      expect(resolveStoreLatLng({'business_name': 'X'}), isNull);
    });

    test('rejects 0,0 and out-of-range coordinates', () {
      expect(resolveStoreLatLng({'store_lat': 0, 'store_lng': 0}), isNull);
      expect(
        resolveStoreLatLng({'store_lat': 999, 'store_lng': 36.16}),
        isNull,
      );
      expect(
        resolveStoreLatLng({'store_lat': 36.2, 'store_lng': 999}),
        isNull,
      );
    });
  });

  group('resolveStoreLatLngWithFallback', () {
    test('uses Hatay city when pin coordinates missing', () {
      final coords = resolveStoreLatLngWithFallback({
        'seller_id': 'seller-1',
        'city': 'Hatay',
        'district': 'Antakya',
      });
      expect(coords, isNotNull);
      expect(coords!.fromCityFallback, isTrue);
      expect(coords.lat, closeTo(36.2025, 0.05));
      expect(coords.lng, closeTo(36.1605, 0.05));
    });

    test('prefers exact pin over city fallback', () {
      final coords = resolveStoreLatLngWithFallback({
        'store_lat': 36.3,
        'store_lng': 36.2,
        'city': 'Hatay',
      });
      expect(coords, isNotNull);
      expect(coords!.fromCityFallback, isFalse);
      expect(coords.lat, 36.3);
    });
  });
}
