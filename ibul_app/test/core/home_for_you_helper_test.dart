import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_for_you_helper.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/models/db_product.dart';

DBProduct _product(String id, {String? imageUrl}) {
  return DBProduct(
    id: id,
    sellerId: 'seller-$id',
    name: 'Product $id',
    brand: 'Brand',
    price: '100',
    rating: 4.5,
    reviewCount: 1,
    imageUrl: imageUrl ?? 'https://img.test/$id.jpg',
    category: 'Elektronik',
    subCategory: 'Telefon',
    tags: '[]',
    stock: 1,
  );
}

void main() {
  group('ForYou rail selection', () {
    test('not logged in path uses popular generic fallback', () {
      final selected = selectForYouProducts(
        personalizedCache: const [],
        popularCache: [_product('1'), _product('2')],
        mainProducts: const [],
      );
      expect(selected, hasLength(2));
    });

    test('cache hit returns personalized cache first', () {
      final cached = [_product('c1'), _product('c2')];
      final selected = selectForYouProducts(
        personalizedCache: cached,
        popularCache: [_product('p1')],
        mainProducts: [_product('m1')],
      );
      expect(selected.first.id, 'c1');
    });

    test('timeout/generic uses main products when personalized empty', () {
      final selected = selectForYouProducts(
        personalizedCache: const [],
        popularCache: const [],
        mainProducts: [_product('m1'), _product('m2')],
      );
      expect(selected, hasLength(2));
    });

    test('limits to homePersonalizedProductsLimit (8)', () {
      final many = List.generate(12, (i) => _product('$i'));
      final selected = selectForYouProducts(
        personalizedCache: many,
        popularCache: const [],
        mainProducts: const [],
      );
      expect(selected, hasLength(homePersonalizedProductsLimit));
    });

    test('skips products without images', () {
      final selected = computeForYouFeaturedSlice([
        _product('1'),
        _product('2', imageUrl: ''),
      ]);
      expect(selected, hasLength(1));
      expect(selected.first.id, '1');
    });
  });
}
