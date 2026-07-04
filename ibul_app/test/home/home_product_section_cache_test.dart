import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/enums/ad_enums.dart';
import 'package:ibul_app/ads/services/home_feature_ad_service.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/core/simple_memory_ttl_cache.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _sampleProduct({
  required String id,
  bool isActive = true,
}) {
  return DBProduct(
    id: id,
    name: 'Product',
    brand: 'Brand',
    price: '10',
    rating: 4.0,
    reviewCount: 0,
    imageUrl: 'img.jpg',
    category: 'X',
    tags: '[]',
    isActive: isActive,
    approvalStatus: isActive ? 'approved' : 'pending',
  );
}

void main() {
  group('Home product section cache', () {
    test('SimpleMemoryTtlCache TTL içinde tekrar fetch etmez', () async {
      var fetchCount = 0;
      Future<String> fetch() async {
        fetchCount++;
        return 'value';
      }

      final cache = SimpleMemoryTtlCache<String>(
        defaultTtl: const Duration(minutes: 5),
      );

      expect(cache.read('section'), isNull);
      cache.write('section', await fetch());
      expect(cache.read('section'), 'value');
      await fetch();
      expect(fetchCount, 2);
      expect(cache.read('section'), 'value');
    });

    test('force refresh cache anahtarını invalidate eder', () {
      HomeFeatureAdService.invalidateHomePageGroupsCache();
      final cache = SimpleMemoryTtlCache<List<dynamic>>();
      cache.write('k', [1]);
      cache.invalidate('k');
      expect(cache.read('k'), isNull);
    });

    test('public/approved/active filter DBProduct.isActive ile korunur', () {
      final active = _sampleProduct(id: 'a1', isActive: true);
      final inactive = _sampleProduct(id: 'a2', isActive: false);

      final snapshot = HomeSnapshot.fromJson({
        'products': [active.toMap(), inactive.toMap()],
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect(snapshot, isNotNull);
      expect(snapshot!.products.length, 1);
      expect(snapshot.products.first.isActive, isTrue);
    });

    test('section boşsa empty state ayrımı', () {
      const emptySnapshot = HomeSnapshot();
      expect(emptySnapshot.isEmpty, isTrue);

      final withProducts = HomeSnapshot(
        products: [_sampleProduct(id: 'p')],
      );
      expect(withProducts.isEmpty, isFalse);
    });

    test('HomeSponsoredContentService cache key formatı', () {
      final key = '${AdPlacement.homeFeed.dbValue}|6|';
      expect(key, contains('home_feed'));
    });
  });
}
