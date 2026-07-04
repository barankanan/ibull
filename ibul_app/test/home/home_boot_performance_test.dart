import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_perf_logger.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/core/section_load_state.dart';
import 'package:ibul_app/core/simple_memory_ttl_cache.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _sampleProduct({
  required String id,
  required String name,
  bool isActive = true,
}) {
  return DBProduct(
    id: id,
    name: name,
    brand: 'Brand',
    price: '10',
    rating: 4.5,
    reviewCount: 1,
    imageUrl: 'https://example.com/a.jpg',
    category: 'Elektronik',
    tags: '[]',
    isActive: isActive,
    approvalStatus: isActive ? 'approved' : 'pending',
  );
}

void main() {
  group('Home boot performance', () {
    test('cache varsa snapshot memoryden okunur', () {
      final cache = SimpleMemoryTtlCache<HomeSnapshot>();
      final snapshot = HomeSnapshot(
        products: [_sampleProduct(id: 'p1', name: 'Test')],
        createdAt: DateTime.now(),
      );
      cache.write('home', snapshot);

      final read = cache.read('home');
      expect(read, isNotNull);
      expect(read!.products.length, 1);
      expect(read.products.first.name, 'Test');
    });

    test('SectionLoadState loading sırasında error göstermez', () {
      final loading = SectionLoadState.beginLoading();
      expect(loading.isLoading, isTrue);
      expect(loading.shouldShowError, isFalse);

      final error = SectionLoadState(
        phase: SectionLoadPhase.error,
        startedAt: DateTime.now(),
        errorMessage: 'fail',
        gracePeriod: const Duration(seconds: 2),
      );
      expect(error.shouldShowError, isFalse);
    });

    test('SectionLoadState grace period sonrası error gösterir', () {
      final error = SectionLoadState(
        phase: SectionLoadPhase.error,
        startedAt: DateTime.now().subtract(const Duration(seconds: 3)),
        errorMessage: 'fail',
        gracePeriod: const Duration(seconds: 2),
      );
      expect(error.shouldShowError, isTrue);
    });

    test('HomeBootPerfTracker boot log API mevcut', () {
      final tracker = HomeBootPerfTracker(startMs: 1000);
      tracker.markFirstFrame();
      tracker.markRouteReady();
      tracker.cachedSnapshotUsed = true;
      expect(tracker.firstFrameMs, isNotNull);
      expect(() => tracker.logBoot(), returnsNormally);
    });

    test('HomeSnapshot round-trip json korur', () {
      final snapshot = HomeSnapshot(
        products: [_sampleProduct(id: 'p2', name: 'Phone')],
        heroAds: const [
          {'id': 'b1', 'image_path': 'banner.jpg'},
        ],
        categories: const [
          {'id': 'c1', 'title': 'Fırsatlar'},
        ],
        createdAt: DateTime.now(),
      );

      final decoded = HomeSnapshot.fromJson(snapshot.toJson());
      expect(decoded, isNotNull);
      expect(decoded!.products.length, 1);
      expect(decoded.heroAds.length, 1);
      expect(decoded.categories.length, 1);
    });

    test('network error sonrası last good snapshot memoryde kalır', () {
      HomeSnapshotCache.instance.writeMemory(
        HomeSnapshot(
          products: [_sampleProduct(id: 'cached', name: 'Cached')],
          createdAt: DateTime.now(),
        ),
      );

      final afterError = HomeSnapshotCache.instance.readMemory();
      expect(afterError, isNotNull);
      expect(afterError!.products.first.id, 'cached');
    });

    test('AppPerfLogger API çağrılabilir', () {
      expect(
        () => AppPerfLogger.logHomeFetch(
          categoriesMs: 10,
          heroAdsMs: 20,
          totalMs: 30,
          parallel: true,
        ),
        returnsNormally,
      );
    });
  });
}
