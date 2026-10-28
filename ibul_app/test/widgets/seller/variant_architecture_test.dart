import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/products/helpers/product_filter_attribute_extractor.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/seller/add_product_page.dart';
import 'package:ibul_app/widgets/seller/product_image_editor_dialog.dart';

void main() {
  group('Attribute Extraction & String Formatting Tests (Item 3)', () {
    test('ProductFilterAttributeExtractor preserves numbers and units verbatim', () {
      final product1 = Product(
        productId: 'ssd-1',
        name: 'Samsung 990 Pro 1 TB NVMe SSD',
        brand: 'Samsung',
        price: '3.499 TL',
        rating: 4.9,
        reviewCount: 50,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Bilgisayar',
        description: 'Yüksek performanslı 1 TB depolama ve 7450 MB/s hız',
      );

      final product2 = Product(
        productId: 'ssd-2',
        name: 'Kingston Fury Renegade 256 GB PCIe 4.0 SSD',
        brand: 'Kingston',
        price: '1.299 TL',
        rating: 4.7,
        reviewCount: 30,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Bilgisayar',
        description: '256 GB M.2 NVMe SSD',
      );

      final product3 = Product(
        productId: 'tv-1',
        name: 'LG 55 inç 4K Ultra HD OLED TV',
        brand: 'LG',
        price: '38.999 TL',
        rating: 4.8,
        reviewCount: 80,
        tags: const [],
        images: const [],
        category: 'Elektronik',
        subCategory: 'Televizyon',
        description: '55 inç sinematik ekran',
      );

      final product4 = Product(
        productId: 'shoe-1',
        name: 'Nike Air Max 42.5 Numara Koşu Ayakkabısı',
        brand: 'Nike',
        price: '2.999 TL',
        rating: 4.6,
        reviewCount: 15,
        tags: const [],
        images: const [],
        category: 'Erkek',
        subCategory: 'Ayakkabı',
        description: 'Rahat taban 42.5 Numara spor ayakkabı',
      );

      final extractedStorage = ProductFilterAttributeExtractor.extractDynamicAttributes(
        products: [product1, product2],
        mainCategory: 'Elektronik',
        subCategory: 'Bilgisayar',
      );

      // Verify '1 TB' and '256 GB' are preserved with numbers, not truncated to 'TB' or 'GB'
      expect(extractedStorage['Depolama'], contains('1 TB'));
      expect(extractedStorage['Depolama'], contains('256 GB'));
      expect(extractedStorage['Depolama']?.contains('TB'), isFalse); // Not just 'TB'

      final extractedTv = ProductFilterAttributeExtractor.extractDynamicAttributes(
        products: [product3],
        mainCategory: 'Elektronik',
        subCategory: 'Televizyon',
      );
      expect(extractedTv['Ekran Boyutu'], contains('55 inç'));

      final extractedShoe = ProductFilterAttributeExtractor.extractDynamicAttributes(
        products: [product4],
        mainCategory: 'Erkek',
        subCategory: 'Ayakkabı',
      );
      expect(extractedShoe['Numara'], contains('42.5'));
    });

    test('DBProduct with comma in decimal attributes is not split into separate items', () {
      final dbProduct = DBProduct.fromMap({
        'name': 'Spor Ayakkabı',
        'brand': 'Adidas',
        'price': '2.499 TL',
        'attributes': '42,5 Numara, Siyah, Koşu',
      });

      final product = Product.fromDBProduct(dbProduct);
      expect(product.attributes, isNotNull);
      // '42,5 Numara' should NOT be split into '42' and '5 Numara'
      expect(product.attributes!.any((a) => a.contains('42,5 Numara')), isTrue);
      expect(product.attributes!.length, 3);
    });
  });

  group('Seller Panel Variant Modal Option Rows & Architecture (Item 1)', () {
    test('VariantOptionRow initializes controllers and default values', () {
      final row = VariantOptionRow(
        type: 'Kapasite',
        value: '1 TB',
        priceDiff: '+500',
        stock: '25',
      );

      expect(row.typeController.text, 'Kapasite');
      expect(row.valueController.text, '1 TB');
      expect(row.priceDiffController.text, '+500');
      expect(row.stockController.text, '25');

      row.dispose();
    });

    test('ProductVariant serialization preserves options, colorHex, and priceDifference', () {
      final v1 = ProductVariant(
        color: '', // No color specified
        colorHex: null,
        size: '1 TB',
        optionType: 'Kapasite',
        options: {'Kapasite': '1 TB'},
        sku: 'SSD-1TB',
        stock: 15,
        priceDifference: 500.0,
      );

      final map1 = v1.toMap();
      expect(map1['color'], '');
      expect(map1.containsKey('colorHex'), isFalse);
      expect(map1['size'], '1 TB');
      expect(map1['priceDifference'], 500.0);
      expect(map1['stock'], 15);
      expect(map1['options']['Kapasite'], '1 TB');
    });

    test('ImageCropDialog can be constructed with raw imageBytes and wraps ProductImageEditorDialog', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final cropDialog = ImageCropDialog(imageBytes: sampleBytes);
      expect(cropDialog.imageBytes, sampleBytes);
    });

    test('ProductVariant stores and exposes Uint8List imageBytes for crop flow', () {
      final sampleBytes = Uint8List.fromList([10, 20, 30, 40]);
      final variant = ProductVariant(
        color: 'Siyah',
        size: '55 inç',
        sku: 'TV-55-BLK',
        stock: 5,
        priceDifference: 0.0,
        imageBytes: sampleBytes,
      );

      expect(variant.imageBytes, sampleBytes);
      expect(variant.imageBytes?.length, 4);
    });
  });
}
