import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/utils/garson_product_selection.dart';

SellerProduct _hybridWeightProduct({
  int? minWeightGrams,
  int? defaultWeightGrams,
  int? weightStepGrams,
  int? maxWeightGrams,
  double pricePerKg = 1900,
  double portionPrice = 380,
}) {
  return SellerProduct(
    id: 'ciger',
    name: 'Ciğer Servis',
    brand: 'Test',
    mainCategory: 'Yemek',
    subCategory: 'Izgara',
    price: portionPrice,
    portionPrice: portionPrice,
    pricePerKg: pricePerKg,
    pricingType: ProductPricingType.portion.storageValue,
    pricingMode: ProductPricingMode.hybrid.storageValue,
    minWeightGrams: minWeightGrams,
    defaultWeightGrams: defaultWeightGrams,
    weightStepGrams: weightStepGrams,
    maxWeightGrams: maxWeightGrams,
    stock: 10,
    sku: 'SKU',
    status: 'Aktif',
    createdAt: DateTime(2026),
  );
}

void main() {
  group('ProductPriceCalculator weight settings', () {
    test('resolveWeightGramSettings uses product values not 500 fallback', () {
      final settings = ProductPriceCalculator.resolveWeightGramSettings(
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(settings.source, 'product');
      expect(settings.minGrams, 200);
      expect(settings.defaultGrams, 200);
      expect(settings.stepGrams, 100);
      expect(settings.maxGrams, isNull);
    });

    test('buildPresetWeightOptions follows min/step without 750 stray', () {
      final options = ProductPriceCalculator.buildPresetWeightOptions(
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(options.first, 200);
      expect(options, contains(300));
      expect(options, contains(500));
      expect(options, contains(1000));
      expect(options, isNot(contains(750)));
    });

    test('clampWeightSelection respects step and min', () {
      expect(
        ProductPriceCalculator.clampWeightSelection(
          300,
          minWeightGrams: 200,
          weightStepGrams: 100,
        ),
        300,
      );
      expect(
        ProductPriceCalculator.clampWeightSelection(
          100,
          minWeightGrams: 200,
          weightStepGrams: 100,
        ),
        200,
      );
      expect(
        ProductPriceCalculator.clampWeightSelection(
          200,
          minWeightGrams: 200,
          weightStepGrams: 100,
        ),
        200,
      );
    });

    test('weight price from kg', () {
      expect(
        ProductPriceCalculator.calculateWeightPrice(
          selectedGrams: 200,
          pricePerKg: 1900,
        ),
        380,
      );
      expect(
        ProductPriceCalculator.calculateWeightPrice(
          selectedGrams: 500,
          pricePerKg: 1900,
        ),
        950,
      );
      expect(
        ProductPriceCalculator.calculateWeightPrice(
          selectedGrams: 1000,
          pricePerKg: 1900,
        ),
        1900,
      );
    });
  });

  group('SellerProduct parse', () {
    test('fromMap reads snake_case weight columns', () {
      final product = SellerProduct.fromMap(
        <String, dynamic>{
          'name': 'Ciğer',
          'min_weight_grams': 200,
          'default_weight_grams': 200,
          'weight_step_grams': 100,
          'price_per_kg': 1900,
          'portion_price': 380,
        },
        'p1',
      );
      expect(product.resolvedWeightGramSettings.source, 'product');
      expect(product.resolvedMinWeightGrams, 200);
      expect(product.resolvedDefaultWeightGrams, 200);
      expect(product.resolvedWeightStepGrams, 100);
      expect(product.effectivePricePerKg, 1900);
      expect(product.supportsGarsonWeightSelection, isTrue);
    });

    test('fromMap resolves kg_price alias and shows garson gramaj', () {
      final product = SellerProduct.fromMap(
        <String, dynamic>{
          'name': 'Kemiksiz Tavuk Servis',
          'kg_price': 1200,
          'portion_price': 300,
          'pricing_type': 'portion',
          'min_weight_grams': 200,
          'weight_step_grams': 100,
        },
        'p2',
      );
      expect(product.effectivePricePerKg, 1200);
      expect(GarsonProductSelection.shouldShowWeightControls(product), isTrue);
    });

    test('fallback min grams alone does not enable weight selection', () {
      final product = SellerProduct.fromMap(
        <String, dynamic>{
          'name': 'Sade Porsiyon',
          'portion_price': 100,
          'pricing_type': 'portion',
        },
        'p3',
      );
      expect(product.hasConfiguredWeightGramFields, isFalse);
      expect(product.supportsGarsonWeightSelection, isFalse);
      expect(GarsonProductSelection.shouldShowWeightControls(product), isFalse);
    });
  });

  group('Garson weight UI', () {
    test('quick options from product settings', () {
      final product = _hybridWeightProduct(
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      final options = GarsonProductSelection.weightQuickGramOptions(product);
      expect(options.first, 200);
      expect(options, contains(300));
      expect(options, contains(1000));
      expect(options, isNot(contains(750)));
    });

    test('openNew keeps portion default with latent 200g not 500', () {
      final product = _hybridWeightProduct(
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      expect(state.showGramajUi, isTrue);
      expect(state.activeMode, GarsonActivePricingMode.portion);
      expect(state.activeUnit.selectedGrams, 200);
      expect(
        GarsonProductSelection.resolveUnitPrice(
          product: product,
          activeMode: GarsonActivePricingMode.portion,
        ),
        380,
      );
    });

    test('clampGrams plus minus', () {
      final product = _hybridWeightProduct(
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(GarsonProductSelection.clampGrams(product, 200 + 100), 300);
      expect(GarsonProductSelection.clampGrams(product, 300 - 100), 200);
      expect(GarsonProductSelection.clampGrams(product, 200 - 100), 200);
    });
  });
}
