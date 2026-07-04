import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/category_pricing_helper.dart';

void main() {
  group('isFoodPricingCategory', () {
    test('yemek ana kategorisi true döner', () {
      expect(isFoodPricingCategory('Yemek'), isTrue);
      expect(isFoodPricingCategory('Yemek', 'Ana Yemek'), isTrue);
    });

    test('elektronik ana kategorisi false döner', () {
      expect(isFoodPricingCategory('Elektronik'), isFalse);
      expect(isFoodPricingCategory('Elektronik', 'Telefon'), isFalse);
    });

    test('kasap/manav alt kategorisi true döner', () {
      expect(isFoodPricingCategory('Market', 'Kasap'), isTrue);
      expect(isFoodPricingCategory('Süpermarket', 'Manav'), isTrue);
    });
  });

  group('isPhysicalProductCategory', () {
    test('elektronik fiziksel ürün', () {
      expect(isPhysicalProductCategory('Elektronik', 'Telefon'), isTrue);
    });

    test('yemek fiziksel değil', () {
      expect(isPhysicalProductCategory('Yemek', 'Ana Yemek'), isFalse);
    });
  });

  group('subCategoryAttributeTemplate', () {
    test('telefon şablonu dolu', () {
      final template = subCategoryAttributeTemplate('Elektronik', 'Telefon');
      expect(template, contains('Dahili Hafıza'));
      expect(template, contains('RAM Kapasitesi'));
    });

    test('ev aletleri şablonu', () {
      final template = subCategoryAttributeTemplate('Elektronik', 'Ev Aletleri');
      expect(template, contains('Güç'));
      expect(template, contains('Kapasite'));
    });
  });
}
