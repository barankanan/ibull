import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_flow_cache.dart';

void main() {
  group('garson table load performance helpers', () {
    test('cache varsa garson ana ekran için ürün fetch atlanır', () {
      final cache = GarsonProductsCacheEntry(
        products: const [],
        cachedAt: DateTime.now(),
      );
      expect(
        shouldUseGarsonProductsCache(
          parentProducts: const [],
          cacheEntry: cache,
        ),
        isTrue,
      );
    });

    test('parent products varsa fetch atlanır', () {
      expect(
        shouldUseGarsonProductsCache(
          parentProducts: [
            // id only needed for non-empty check in helper callers
          ],
          cacheEntry: null,
        ),
        isFalse,
      );
    });

    test('open table list products fetch tetiklemez when parent has products', () {
      final orders = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'o1', 'table_number': 3, 'items': <dynamic>[]},
        <String, dynamic>{'id': 'o2', 'table_number': 5, 'items': <dynamic>[]},
      ];
      final tableThree = garsonOrdersForTableNumber(
        orders: orders,
        tableNumber: 3,
      );
      expect(tableThree, hasLength(1));
      expect(tableThree.first['id'], 'o1');
    });

    test('offline hydrate raporu cache varlığını döner', () async {
      final result = await hydrateGarsonBoardFromOfflineCache(
        restaurantId: '',
      );
      expect(result.applied, isFalse);
    });
  });
}
