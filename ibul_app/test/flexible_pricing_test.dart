import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/services/store/store_mapping_helpers.dart';
import 'package:ibul_app/services/store_service_mappers.dart';

void main() {
  group('Flexible pricing', () {
    test('selected size price overrides base and weight pricing', () {
      final unitPrice =
          ProductPriceCalculator.resolveServiceControlledUnitPrice(
            serviceControlType: ProductServiceControlType.none,
            pricingType: ProductPricingType.portion,
            pricingMode: ProductPricingMode.hybrid,
            basePrice: 120,
            portionPrice: 120,
            pricePerKg: 380,
            sizeOptions: const [
              ProductSizeOption(
                id: 'small',
                name: 'Kucuk',
                price: 90,
                isDefault: true,
              ),
              ProductSizeOption(id: 'large', name: 'Buyuk', price: 150),
            ],
            selectedSizeName: 'Buyuk',
            selectedWeightGrams: 500,
            fallbackPrice: 120,
          );

      expect(unitPrice, 150);
    });

    test('size only products fall back to default size', () {
      final unitPrice =
          ProductPriceCalculator.resolveServiceControlledUnitPrice(
            serviceControlType: ProductServiceControlType.none,
            pricingType: ProductPricingType.portion,
            pricingMode: ProductPricingMode.sizeOnly,
            sizeOptions: const [
              ProductSizeOption(
                id: '250g',
                name: '250 gr',
                price: 110,
                isDefault: true,
              ),
              ProductSizeOption(id: '500g', name: '500 gr', price: 210),
            ],
            fallbackPrice: 0,
          );

      expect(unitPrice, 110);
    });

    test('product mapper persists new pricing fields in snake_case', () {
      final payload = StoreServiceMappers.productToSnakeCase({
        'name': 'Adana',
        'price': 120,
        'pricingMode': 'hybrid',
        'basePrice': 120,
        'pricingType': 'portion',
        'pricePerKg': 360,
        'sizeOptions': [
          {
            'id': 'small',
            'name': 'Kucuk',
            'price': 90,
            'is_default': true,
            'sort_order': 0,
          },
        ],
        'selectedSizeName': 'Kucuk',
        'selectedSizePrice': 90,
      });

      expect(payload['pricing_mode'], 'hybrid');
      expect(payload['base_price'], 120);
      expect(payload['size_options'], isA<List<dynamic>>());
      expect(payload['selected_size_name'], 'Kucuk');
      expect(payload['selected_size_price'], 90);
    });

    test(
      'snake_case product mapper reads size pricing snapshot fields back',
      () {
        final product = mapSnakeCaseToProduct({
          'id': 'prd_1',
          'name': 'Çoban Salata',
          'brand': 'Mutfak',
          'main_category': 'Yemek',
          'sub_category': 'Salata',
          'price': 90,
          'pricing_mode': 'hybrid',
          'base_price': 90,
          'pricing_type': 'portion',
          'portion_price': 90,
          'price_per_kg': 240,
          'size_options': [
            {
              'id': 'small',
              'name': 'Küçük',
              'price': 75,
              'is_default': true,
              'sort_order': 0,
            },
            {'id': 'large', 'name': 'Büyük', 'price': 110, 'sort_order': 1},
          ],
          'selected_size_name': 'Küçük',
          'selected_size_price': 75,
        });

        expect(product.pricingMode, 'hybrid');
        expect(product.basePrice, 90);
        expect(product.selectedSizeName, 'Küçük');
        expect(product.selectedSizePrice, 75);
        expect(product.sizeOptions.length, 2);
        expect(product.defaultSizeOption?.name, 'Küçük');
      },
    );
  });
}
