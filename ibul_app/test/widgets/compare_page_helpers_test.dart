import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/widgets/compare_page_helpers.dart';

void main() {
  group('compare_page_helpers', () {
    test('compareProductAt returns product from selection map', () {
      final product = Product(
        name: 'Test Ürün',
        brand: 'Marka',
        price: '100 TL',
        rating: 4.5,
        reviewCount: 3,
        tags: const ['hızlı'],
        images: const ['https://example.com/a.jpg'],
        store: 'Mağaza A',
      );

      final maps = [
        {'product': product, 'name': product.name},
      ];

      expect(compareProductAt(maps, 0), same(product));
      expect(compareProductAt(maps, 1), isNull);
    });

    test('reviewImageUrls filters empty urls', () {
      expect(
        reviewImageUrls({
          'imageUrls': ['https://a.jpg', '', '  '],
        }),
        ['https://a.jpg'],
      );
    });

    test('compareDisplayProducts caps at four items', () {
      final maps = List.generate(
        6,
        (i) => {'name': 'P$i'},
      );
      expect(compareDisplayProducts(maps).length, 4);
    });

    test('maskReviewUserName masks trailing characters', () {
      expect(maskReviewUserName('Baran'), 'Bar**');
      expect(maskReviewUserName(null), 'Kullanı**');
    });

    test('compareProductImageUrl prefers product images and thumbnail', () {
      final product = Product(
        name: 'Telefon',
        brand: 'Marka',
        price: '100 TL',
        rating: 4,
        reviewCount: 1,
        tags: const [],
        images: const ['https://example.com/phone.jpg'],
        thumbnailPublicUrl: 'https://example.com/thumb.jpg',
      );

      expect(
        compareProductImageUrl({'product': product}),
        isNotEmpty,
      );
    });

    test('compareProductsShareMainCategory allows same main category', () {
      final phone = Product(
        name: 'Telefon',
        brand: 'A',
        price: '1',
        rating: 0,
        reviewCount: 0,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Telefon',
      );
      final laptop = Product(
        name: 'Laptop',
        brand: 'B',
        price: '2',
        rating: 0,
        reviewCount: 0,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Bilgisayar',
      );

      expect(compareProductsShareMainCategory([phone, laptop]), isTrue);
    });

    test('compareProductsShareMainCategory blocks different main categories', () {
      final food = Product(
        name: 'Kebap',
        brand: 'A',
        price: '1',
        rating: 0,
        reviewCount: 0,
        tags: const [],
        images: const [],
        category: 'Yemek',
      );
      final phone = Product(
        name: 'Telefon',
        brand: 'B',
        price: '2',
        rating: 0,
        reviewCount: 0,
        tags: const [],
        images: const [],
        category: 'Elektronik',
      );

      expect(compareProductsShareMainCategory([food, phone]), isFalse);
      expect(
        compareMainCategoryMismatchForProducts([food, phone]),
        kCompareMainCategoryMismatchMessage,
      );
    });

    test('buildCompareFeatureSections includes dynamic seller attributes', () {
      final first = Product(
        name: 'Ürün A',
        brand: 'Marka A',
        price: '100 TL',
        rating: 4.2,
        reviewCount: 2,
        tags: const ['etiket'],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Telefon',
        attributes: const ['Dahili Hafıza: 128 GB'],
        specifications: '{"Ekran Boyutu":"6.1 inç"}',
      );
      final second = Product(
        name: 'Ürün B',
        brand: 'Marka B',
        price: '120 TL',
        rating: 4.5,
        reviewCount: 5,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Bilgisayar',
        attributes: const ['RAM: 16 GB'],
      );

      final sections = buildCompareFeatureSections([first, second]);
      final labels = sections
          .expand((section) => section.rows.map((row) => row.label))
          .toList();

      expect(labels, contains('Dahili Hafıza'));
      expect(labels, contains('Ekran Boyutu'));
      expect(labels, contains('RAM'));
      expect(labels, contains('Marka'));
    });
  });
}
