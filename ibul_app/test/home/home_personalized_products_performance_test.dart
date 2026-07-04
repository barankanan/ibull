import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_for_you_helper.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/core/section_load_state.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _sampleProduct({
  required String id,
  bool isActive = true,
  String imageUrl = 'img.jpg',
}) {
  return DBProduct(
    id: id,
    name: 'Product $id',
    brand: 'Brand',
    price: '99',
    rating: 4.5,
    reviewCount: 3,
    imageUrl: imageUrl,
    category: 'Elektronik',
    tags: '[]',
    isActive: isActive,
    approvalStatus: 'approved',
  );
}

void main() {
  group('Sana Özel Ürünler performans', () {
    setUp(() {
      HomeSnapshotCache.instance.invalidate();
    });

    test('cache varsa skeleton gösterilmez', () {
      expect(
        shouldShowPersonalizedProductsSkeleton(
          isLoading: true,
          productCount: 4,
        ),
        isFalse,
      );
      expect(
        shouldShowPersonalizedProductsSkeleton(
          isLoading: true,
          productCount: 0,
        ),
        isTrue,
      );
    });

    test('HomeSnapshotCache personalized read/write', () {
      final products = List.generate(
        3,
        (index) => _sampleProduct(id: 'p$index'),
      );
      HomeSnapshotCache.instance.writePersonalizedProducts(products);
      final read = HomeSnapshotCache.instance.readPersonalizedProducts();

      expect(read, isNotNull);
      expect(read!.length, 3);
    });

    test('network refresh personalized cache günceller', () {
      HomeSnapshotCache.instance.writePersonalizedProducts([
        _sampleProduct(id: 'old'),
      ]);
      HomeSnapshotCache.instance.writePersonalizedProducts([
        _sampleProduct(id: 'new1'),
        _sampleProduct(id: 'new2'),
      ]);

      final read = HomeSnapshotCache.instance.readPersonalizedProducts();
      expect(read!.first.id, 'new1');
      expect(read.length, 2);
    });

    test('inactive ürünler cache\'e yazılmaz', () {
      HomeSnapshotCache.instance.writePersonalizedProducts([
        _sampleProduct(id: 'active', isActive: true),
        _sampleProduct(id: 'inactive', isActive: false),
      ]);
      final read = HomeSnapshotCache.instance.readPersonalizedProducts();
      expect(read!.length, 1);
      expect(read.first.id, 'active');
    });

    test('limit 10', () {
      final many = List.generate(
        15,
        (index) => _sampleProduct(id: 'p$index'),
      );
      HomeSnapshotCache.instance.writePersonalizedProducts(many);
      final read = HomeSnapshotCache.instance.readPersonalizedProducts();
      expect(read!.length, lessThanOrEqualTo(homePersonalizedProductsLimit));
    });

    test('cache yok + boş liste skeleton kalkar', () {
      expect(
        shouldShowPersonalizedProductsSkeleton(
          isLoading: false,
          productCount: 0,
        ),
        isFalse,
      );
    });

    test('featured fallback uses active products without images', () {
      final products = [
        _sampleProduct(id: 'a', imageUrl: ''),
        _sampleProduct(id: 'b', imageUrl: ''),
      ];
      final slice = computeForYouFeaturedSliceWithFallback(products, limit: 2);
      expect(slice.length, 2);
      expect(slice.map((p) => p.id), ['a', 'b']);
    });
  });
}
