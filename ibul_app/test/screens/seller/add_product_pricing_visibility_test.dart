import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/category_pricing_helper.dart';

/// Fiyat ekranı görünürlük mantığını doğrular.
/// AddProductPage tam pump gerektirmez — aynı helper kullanılır.
void main() {
  group('Fiyat ekranı alan görünürlüğü', () {
    test('Elektronik > Telefon: yemek alanları kapalı', () {
      expect(isFoodPricingCategory('Elektronik', 'Telefon'), isFalse);
      expect(isPhysicalProductCategory('Elektronik', 'Telefon'), isTrue);
    });

    test('Yemek > Ana Yemek: yemek alanları açık', () {
      expect(isFoodPricingCategory('Yemek', 'Ana Yemek'), isTrue);
      expect(isPhysicalProductCategory('Yemek', 'Ana Yemek'), isFalse);
    });

    test('Kasap alt kategorisi yemek fiyatlandırması', () {
      expect(isFoodPricingCategory('Market', 'Kasap'), isTrue);
    });
  });

  group('Fiyat ekranı widget etiketleri (simülasyon)', () {
    testWidgets('fiziksel ürün etiketleri yemek etiketlerinden ayrı', (
      tester,
    ) async {
      const foodLabels = <String>[
        'Porsiyon fiyati',
        'Kiloluk fiyat',
        'Gramaj',
      ];
      const physicalLabels = <String>[
        'Satış Fiyatı',
        'İndirimli Fiyat',
        'Barkod',
        'Garanti Süresi',
        'Para Birimi',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                if (!isFoodPricingCategory('Elektronik', 'Telefon'))
                  ...physicalLabels.map(Text.new),
                if (isFoodPricingCategory('Elektronik', 'Telefon'))
                  ...foodLabels.map(Text.new),
              ],
            ),
          ),
        ),
      );

      for (final label in physicalLabels) {
        expect(find.text(label), findsOneWidget);
      }
      for (final label in foodLabels) {
        expect(find.text(label), findsNothing);
      }
    });

    testWidgets('yemek kategorisinde porsiyon alanları görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                if (isFoodPricingCategory('Yemek', 'Ana Yemek'))
                  const Text('Porsiyon fiyati'),
                if (isFoodPricingCategory('Yemek', 'Ana Yemek'))
                  const Text('Kiloluk fiyat'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Porsiyon fiyati'), findsOneWidget);
      expect(find.text('Kiloluk fiyat'), findsOneWidget);
    });
  });
}
