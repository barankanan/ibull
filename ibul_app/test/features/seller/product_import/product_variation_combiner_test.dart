import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/product_import/models/imported_product.dart';
import 'package:ibul_app/features/seller/product_import/services/product_variation_combiner.dart';

void main() {
  group('ProductVariationCombiner - Real Combinations', () {
    const combiner = ProductVariationCombiner();

    test('Kaynakta tespit edilen gerçek kombinasyonları kayıpsız DB formatına dönüştürmeli', () {
      final variants = [
        ImportedProductVariant(
          id: 'v1',
          combinationTitle: 'Siyah / M / 128 GB',
          color: 'Siyah',
          size: 'M',
          storage: '128 GB',
          sku: 'PHONE-BLK-M-128',
          barcode: '868000000001',
          price: 15000.0,
          stock: 5,
          imageUrl: 'https://example.com/black.jpg',
        ),
        ImportedProductVariant(
          id: 'v2',
          combinationTitle: 'Siyah / L / 128 GB',
          color: 'Siyah',
          size: 'L',
          storage: '128 GB',
          sku: 'PHONE-BLK-L-128',
          barcode: '868000000002',
          price: 15000.0,
          stock: 3,
          imageUrl: 'https://example.com/black.jpg',
        ),
        ImportedProductVariant(
          id: 'v3',
          combinationTitle: 'Beyaz / M / 256 GB',
          color: 'Beyaz',
          size: 'M',
          storage: '256 GB',
          sku: 'PHONE-WHT-M-256',
          barcode: '868000000003',
          price: 18000.0,
          stock: 2,
          imageUrl: 'https://example.com/white.jpg',
        ),
      ];

      final dbList = combiner.toDbVariants(variants, basePrice: 15000.0);

      expect(dbList.length, 3);

      // v1 kontrolü
      expect(dbList[0]['title'], 'Siyah / M / 128 GB');
      expect(dbList[0]['color'], 'Siyah');
      expect(dbList[0]['size'], 'M');
      expect(dbList[0]['storage'], '128 GB');
      expect(dbList[0]['sku'], 'PHONE-BLK-M-128');
      expect(dbList[0]['barcode'], '868000000001');
      expect(dbList[0]['price'], 15000.0);
      expect(dbList[0]['priceDifference'], 0.0);
      expect(dbList[0]['stock'], 5);
      expect(dbList[0]['imageUrl'], 'https://example.com/black.jpg');

      // v3 fiyat farkı kontrolü (18000 - 15000 = +3000)
      expect(dbList[2]['title'], 'Beyaz / M / 256 GB');
      expect(dbList[2]['priceDifference'], 3000.0);
    });

    test('DB formatından ImportedProductVariant listesine geri çözümleme (Roundtrip)', () {
      final rawDbVariants = [
        {
          'id': 'v_db_1',
          'title': 'Kırmızı / XL',
          'color': 'Kırmızı',
          'size': 'XL',
          'sku': 'TSHIRT-RED-XL',
          'price': 450.0,
          'priceDifference': 50.0,
          'stock': 10,
          'imageUrl': 'https://example.com/red.jpg',
        }
      ];

      final restored = combiner.fromDbVariants(rawDbVariants, basePrice: 400.0);

      expect(restored.length, 1);
      final r = restored.first;
      expect(r.combinationTitle, 'Kırmızı / XL');
      expect(r.color, 'Kırmızı');
      expect(r.size, 'XL');
      expect(r.sku, 'TSHIRT-RED-XL');
      expect(r.price, 450.0);
      expect(r.stock, 10);
      expect(r.imageUrl, 'https://example.com/red.jpg');
    });

    test('Olmayan kombinasyonları otomatik üretmemeli ve tekilleştirmeli', () {
      final duplicates = [
        ImportedProductVariant(
          id: '1',
          combinationTitle: 'Siyah / S',
          color: 'Siyah',
          size: 'S',
          price: 100,
        ),
        ImportedProductVariant(
          id: '2',
          combinationTitle: 'Siyah / S', // Aynı kombinasyon
          color: 'Siyah',
          size: 'S',
          price: 100,
        ),
        ImportedProductVariant(
          id: '3',
          combinationTitle: 'Beyaz / M',
          color: 'Beyaz',
          size: 'M',
          price: 110,
        ),
      ];

      final validated = combiner.validateExistingCombinations(
        detectedVariants: duplicates,
        declaredOptions: {'Renk': ['Siyah', 'Beyaz'], 'Beden': ['S', 'M']},
        basePrice: 100,
      );

      // Yalnızca 2 benzersiz gerçek kombinasyon kalmalı
      expect(validated.length, 2);
      expect(validated[0].combinationTitle, 'Siyah / S');
      expect(validated[1].combinationTitle, 'Beyaz / M');
    });
  });
}
