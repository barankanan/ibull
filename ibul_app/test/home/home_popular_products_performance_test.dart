import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/core/section_load_state.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _sampleProduct({
  required String id,
  bool isActive = true,
}) {
  return DBProduct(
    id: id,
    name: 'Product $id',
    brand: 'Brand',
    price: '99',
    rating: 4.5,
    reviewCount: 3,
    imageUrl: 'https://example.com/$id.jpg',
    category: 'Elektronik',
    tags: '[]',
    isActive: isActive,
    approvalStatus: isActive ? 'approved' : 'pending',
  );
}

void main() {
  group('Popüler Ürünler performans', () {
    setUp(() {
      HomeSnapshotCache.instance.invalidate();
    });

    test('cache varsa skeleton gösterilmez', () {
      expect(
        shouldShowPopularProductsSkeleton(isLoading: true, productCount: 5),
        isFalse,
      );
      expect(
        shouldShowPopularProductsSkeleton(isLoading: true, productCount: 0),
        isTrue,
      );
      expect(
        shouldShowPopularProductsSkeleton(isLoading: false, productCount: 0),
        isFalse,
      );
    });

    test('network refresh popular cache günceller', () {
      HomeSnapshotCache.instance.writePopularProducts([
        _sampleProduct(id: 'old'),
      ]);
      HomeSnapshotCache.instance.writePopularProducts([
        _sampleProduct(id: 'new1'),
        _sampleProduct(id: 'new2'),
      ]);

      final read = HomeSnapshotCache.instance.readPopularProducts();
      expect(read, isNotNull);
      expect(read!.length, 2);
      expect(read.first.id, 'new1');
    });

    test('heroAds/categoryCards yüklemesi skeleton kararını etkilemez', () {
      // Popüler Ürünler skeleton yalnızca ürün sayısına bağlı.
      expect(
        shouldShowPopularProductsSkeleton(
          isLoading: true,
          productCount: 3,
        ),
        isFalse,
      );
    });

    test('LazySectionLoader below-fold kuralı Popüler Ürünler için geçerli değil', () {
      // Popüler Ürünler shouldShowPopularProductsSkeleton ile doğrudan render edilir.
      expect(
        shouldShowPopularProductsSkeleton(isLoading: false, productCount: 2),
        isFalse,
      );
    });

    test('görseller yüklenmese bile ürün kartları render edilebilir', () {
      final product = _sampleProduct(id: 'no-image');
      HomeSnapshotCache.instance.writePopularProducts([product]);
      final read = HomeSnapshotCache.instance.readPopularProducts();
      expect(read, isNotNull);
      expect(read!.length, 1);
    });

    test('network error durumunda cache korunur', () {
      final cached = [
        _sampleProduct(id: 'cached1'),
        _sampleProduct(id: 'cached2'),
      ];
      HomeSnapshotCache.instance.writePopularProducts(cached);
      // Simüle: network başarısız, cache hâlâ okunabilir.
      final afterFailure = HomeSnapshotCache.instance.readPopularProducts();
      expect(afterFailure, isNotNull);
      expect(afterFailure!.length, 2);
      expect(afterFailure.first.id, 'cached1');
    });

    test('cache yok + boş liste skeleton kalkar', () {
      expect(
        shouldShowPopularProductsSkeleton(isLoading: false, productCount: 0),
        isFalse,
      );
    });

    test('visibility filter inactive ürünleri cache\'e yazmaz', () {
      HomeSnapshotCache.instance.writePopularProducts([
        _sampleProduct(id: 'active', isActive: true),
        _sampleProduct(id: 'inactive', isActive: false),
      ]);
      final read = HomeSnapshotCache.instance.readPopularProducts();
      expect(read, isNotNull);
      expect(read!.length, 1);
      expect(read.first.id, 'active');
      expect(read.every((product) => product.isActive), isTrue);
    });

    test('popular products limit 12', () {
      final many = List.generate(
        20,
        (index) => _sampleProduct(id: 'p$index'),
      );
      HomeSnapshotCache.instance.writePopularProducts(many);
      final read = HomeSnapshotCache.instance.readPopularProducts();
      expect(read, isNotNull);
      expect(read!.length, lessThanOrEqualTo(homePopularProductsLimit));
    });
  });
}
