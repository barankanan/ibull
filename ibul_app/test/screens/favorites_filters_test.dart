import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/favorites/favorites_filters.dart';

Product _product(String name, String category) {
  return Product(
    name: name,
    brand: 'Marka',
    price: '10 TL',
    rating: 4,
    reviewCount: 1,
    tags: const [],
    images: const [],
    category: category,
  );
}

void main() {
  test('favorite categories come from product data', () {
    final categories = favoriteCategoriesOf([
      _product('Telefon', 'Elektronik'),
      _product('Burger', 'Yemek'),
      _product('Kulaklık', 'Elektronik'),
    ]);
    expect(categories, ['Tümü', 'Elektronik', 'Yemek']);
    expect(favoriteCategoryCount([
      _product('Telefon', 'Elektronik'),
      _product('Burger', 'Yemek'),
    ]), 2);
  });

  test('category and search filter favorites', () {
    final products = [
      _product('iPhone', 'Elektronik'),
      _product('Hatay tava', 'Yemek'),
    ];
    final filtered = filterFavoriteProducts(
      products,
      const FavoriteBrowseQuery(query: 'tava', category: 'Yemek'),
    );
    expect(filtered, hasLength(1));
    expect(filtered.single.name, 'Hatay tava');
  });

  test('recommendations prefer favorite categories and skip liked products', () {
    final catalog = [
      Product(
        productId: 'liked',
        name: 'iPhone',
        brand: 'Apple',
        price: '10 TL',
        rating: 4,
        reviewCount: 1,
        tags: const [],
        images: const [],
        category: 'Elektronik',
      ),
      Product(
        productId: 'burger',
        name: 'Tava',
        brand: 'Mutfak',
        price: '20 TL',
        rating: 4,
        reviewCount: 1,
        tags: const [],
        images: const [],
        category: 'Yemek',
      ),
      Product(
        productId: 'phone',
        name: 'Kulaklık',
        brand: 'Sony',
        price: '30 TL',
        oldPrice: '40 TL',
        rating: 5,
        reviewCount: 30,
        tags: const [],
        images: const [],
        category: 'Elektronik',
      ),
    ];
    final ranked = rankRecommendedProducts(
      catalog: catalog,
      favorites: [
        Product(
          productId: 'liked',
          name: 'iPhone',
          brand: 'Apple',
          price: '10 TL',
          rating: 4,
          reviewCount: 1,
          tags: const [],
          images: const [],
          category: 'Elektronik',
        ),
      ],
      recentlyViewed: const [],
      chip: 'Sana Göre',
    );
    expect(ranked.map((product) => product.productId), ['phone', 'burger']);
  });

  test('yemek chip keeps only food products', () {
    final ranked = rankRecommendedProducts(
      catalog: [
        _product('Telefon', 'Elektronik'),
        _product('Tava', 'Yemek'),
      ],
      favorites: const [],
      recentlyViewed: const [],
      chip: 'Yemek',
    );
    expect(ranked, hasLength(1));
    expect(ranked.single.category, 'Yemek');
  });
}
