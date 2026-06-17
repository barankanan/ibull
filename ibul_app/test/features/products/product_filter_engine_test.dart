import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/products/helpers/product_filter_attribute_extractor.dart';
import 'package:ibul_app/features/products/helpers/product_filter_engine.dart';
import 'package:ibul_app/features/products/models/product_filter_models.dart';
import 'package:ibul_app/models/product_model.dart';

Product _product({
  required String name,
  String brand = 'Marka',
  String price = '1000 TL',
  String? oldPrice,
  double rating = 4.5,
  int reviewCount = 10,
  String? specifications,
  String? variantOptions,
  String? store,
  String? sellerId,
  String? category,
  String? subCategory,
  List<String> tags = const [],
  String? productId,
}) {
  return Product(
    productId: productId,
    name: name,
    brand: brand,
    price: price,
    oldPrice: oldPrice,
    rating: rating,
    reviewCount: reviewCount,
    tags: tags,
    images: const [],
    specifications: specifications,
    variantOptions: variantOptions,
    store: store,
    sellerId: sellerId,
    category: category,
    subCategory: subCategory,
  );
}

void main() {
  group('ProductFilterEngine', () {
    final sampleProducts = [
      _product(
        productId: '1',
        name: 'iPhone 15 128GB',
        brand: 'Apple',
        price: '45000 TL',
        oldPrice: '50000 TL',
        rating: 4.8,
        reviewCount: 120,
        specifications: '{"Depolama":"128GB","RAM":"8GB"}',
        store: 'TeknoShop',
        sellerId: 'seller-1',
      ),
      _product(
        productId: '2',
        name: 'Galaxy S24 256GB',
        brand: 'Samsung',
        price: '38000 TL',
        rating: 4.2,
        reviewCount: 80,
        specifications: '{"Depolama":"256GB","RAM":"12GB"}',
        store: 'MobilDunya',
        sellerId: 'seller-2',
      ),
      _product(
        productId: '3',
        name: 'Basic Telefon',
        brand: 'Xiaomi',
        price: '9000 TL',
        rating: 3.5,
        reviewCount: 12,
        tags: const ['İndirimde'],
      ),
    ];

    test('buildFilterGroups includes price, brand and dynamic attributes', () {
      final groups = ProductFilterEngine.buildFilterGroups(
        products: sampleProducts,
        mainCategory: 'Elektronik',
        subCategory: 'Telefonlar',
      );

      expect(groups.any((g) => g.id == 'price'), isTrue);
      expect(groups.any((g) => g.id == 'brand'), isTrue);
      expect(
        groups.any(
          (g) =>
              g.type == ProductFilterGroupType.dynamicAttribute &&
              g.title == 'Depolama',
        ),
        isTrue,
      );
    });

    test('applyFilters price min/max', () {
      final filtered = ProductFilterEngine.applyFilters(
        products: sampleProducts,
        state: const ProductFilterState(priceMin: 10000, priceMax: 40000),
      );

      expect(filtered.map((p) => p.name), ['Galaxy S24 256GB']);
    });

    test('applyFilters brand', () {
      final filtered = ProductFilterEngine.applyFilters(
        products: sampleProducts,
        state: const ProductFilterState(selectedBrands: {'Apple'}),
      );

      expect(filtered, hasLength(1));
      expect(filtered.first.brand, 'Apple');
    });

    test('applyFilters discounted', () {
      final filtered = ProductFilterEngine.applyFilters(
        products: sampleProducts,
        state: const ProductFilterState(onlyDiscounted: true),
      );

      expect(filtered.map((p) => p.name), contains('iPhone 15 128GB'));
      expect(filtered.map((p) => p.name), contains('Basic Telefon'));
    });

    test('applyFilters rating', () {
      final filtered = ProductFilterEngine.applyFilters(
        products: sampleProducts,
        state: const ProductFilterState(selectedRatings: {4}),
      );

      expect(filtered.every((product) => product.rating >= 4), isTrue);
    });

    test('applyFilters stock uses meta map', () {
      final filtered = ProductFilterEngine.applyFilters(
        products: sampleProducts,
        state: const ProductFilterState(onlyInStock: true),
        metaByProductId: {
          '1': const ProductFilterMeta(stock: 5),
          '2': const ProductFilterMeta(stock: 0),
          '3': const ProductFilterMeta(stock: 2),
        },
      );

      expect(filtered.map((p) => p.productId), ['1', '3']);
    });

    test('applySort price asc/desc', () {
      final asc = ProductFilterEngine.applySort(
        products: sampleProducts,
        sortOption: ProductSortOption.priceAsc,
      );
      final desc = ProductFilterEngine.applySort(
        products: sampleProducts,
        sortOption: ProductSortOption.priceDesc,
      );

      expect(asc.first.name, 'Basic Telefon');
      expect(desc.first.name, 'iPhone 15 128GB');
    });

    test('applySort rating and review count', () {
      final byRating = ProductFilterEngine.applySort(
        products: sampleProducts,
        sortOption: ProductSortOption.highestRating,
      );
      final byReviews = ProductFilterEngine.applySort(
        products: sampleProducts,
        sortOption: ProductSortOption.mostReviewed,
      );

      expect(byRating.first.name, 'iPhone 15 128GB');
      expect(byReviews.first.name, 'iPhone 15 128GB');
    });

    test('clear filters resets state', () {
      const dirty = ProductFilterState(
        selectedBrands: {'Apple'},
        onlyDiscounted: true,
        sortOption: ProductSortOption.priceDesc,
      );
      final cleared = ProductFilterState.cleared(sortOption: dirty.sortOption);

      expect(cleared.selectedBrands, isEmpty);
      expect(cleared.onlyDiscounted, isFalse);
      expect(cleared.sortOption, ProductSortOption.priceDesc);
    });
  });

  group('ProductFilterAttributeExtractor', () {
    test('extracts phone storage and RAM from specs', () {
      final products = [
        _product(
          name: 'Telefon',
          specifications: '{"Depolama":"256GB","RAM":"12GB"}',
        ),
      ];

      final extracted = ProductFilterAttributeExtractor.extractDynamicAttributes(
        products: products,
        mainCategory: 'Elektronik',
        subCategory: 'Telefonlar',
      );

      expect(extracted['Depolama'], contains('256GB'));
      expect(extracted['RAM'], contains('12GB'));
    });

    test('extracts clothing size and color from variant options', () {
      final products = [
        _product(
          name: 'Gömlek',
          variantOptions: 'Beden:L|Renk:Mavi',
        ),
      ];

      final extracted = ProductFilterAttributeExtractor.extractDynamicAttributes(
        products: products,
        mainCategory: 'Erkek',
        subCategory: 'Giyim',
      );

      expect(extracted['Beden'], contains('L'));
      expect(extracted['Renk'], contains('Mavi'));
    });
  });
}
