import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/mixed_service_order.dart';
import 'package:ibul_app/models/product_pricing.dart';
import 'package:ibul_app/models/seller_product.dart';
import 'package:ibul_app/utils/garson_product_selection.dart';

SellerProduct _portionProduct({
  String id = 'p1',
  String name = 'Ciğer Servis',
  List<ProductSizeOption> sizes = const [],
  double portionPrice = 120,
  double? pricePerKg,
  int? minWeightGrams,
  int? defaultWeightGrams,
  int? weightStepGrams,
  String? stationId,
  String? stationName,
  String? stationCode,
}) {
  return SellerProduct(
    id: id,
    name: name,
    brand: 'Test',
    mainCategory: 'Yemek',
    subCategory: 'Izgara',
    price: portionPrice,
    portionPrice: portionPrice,
    pricePerKg: pricePerKg,
    pricingType: ProductPricingType.portion.storageValue,
    minWeightGrams: minWeightGrams,
    defaultWeightGrams: defaultWeightGrams,
    weightStepGrams: weightStepGrams,
    sizeOptions: sizes,
    stock: 10,
    sku: 'SKU1',
    status: 'Aktif',
    createdAt: DateTime(2026),
    stationId: stationId,
    stationName: stationName,
    stationCode: stationCode,
  );
}

void main() {
  group('GarsonProductSelection defaults', () {
    test('does not preselect yarım size when standard size exists', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
          ProductSizeOption(id: 'std', name: 'Standart', price: 120),
          ProductSizeOption(id: 'dbl', name: 'Duble', price: 200),
        ],
      );

      final defaults = GarsonProductSelection.resolveDefaults(product);
      expect(defaults.sizeName, isNull);
      expect(defaults.pricingMode, GarsonActivePricingMode.portion);
      expect(
        GarsonProductSelection.resolveUnitPrice(
          product: product,
          activeMode: defaults.pricingMode,
        ),
        120,
      );
    });

    test('ignores is_default on yarım; garson uses tam porsiyon', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(
            id: 'half',
            name: 'Yarım Porsiyon',
            price: 60,
            isDefault: true,
          ),
          ProductSizeOption(id: 'std', name: 'Standart', price: 120),
        ],
      );

      final defaults = GarsonProductSelection.resolveDefaults(product);
      expect(defaults.sizeName, isNull);
      expect(defaults.pricingMode, GarsonActivePricingMode.portion);
    });
  });

  group('GarsonProductSelection weight visibility', () {
    test('hybrid portion+kg shows gramaj even when pricing_type is portion', () {
      final product = _portionProduct(
        portionPrice: 380,
        pricePerKg: 1900,
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(GarsonProductSelection.shouldShowWeightControls(product), isTrue);
      final state = GarsonProductModalState.openNew(product);
      expect(state.showGramajUi, isTrue);
      expect(state.activeMode, GarsonActivePricingMode.portion);
    });

    test('portion only without kg hides gramaj', () {
      final product = _portionProduct(portionPrice: 120);
      expect(GarsonProductSelection.shouldShowWeightControls(product), isFalse);
      final state = GarsonProductModalState.openNew(product);
      expect(state.showGramajUi, isFalse);
    });

    test('feature and quantity do not hide gramaj', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      expect(state.showGramajUi, isTrue);
      state.toggleFeature('Acısız');
      expect(state.showGramajUi, isTrue);
      state.changeQuantity(2);
      expect(state.showGramajUi, isTrue);
    });

    test('selecting 500g switches to weight mode and label', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      state.setWeightMode(grams: 500);
      expect(state.activeMode, GarsonActivePricingMode.weight);
      final line = state.buildConfirmedLines().first;
      expect(
        GarsonProductSelection.orderItemDisplayLabel(line),
        '1 x Ciğer Servis 500 g',
      );
      expect(
        GarsonProductSelection.resolveUnitPrice(
          product: product,
          activeMode: GarsonActivePricingMode.weight,
          selectedGramsForWeight: 500,
        ),
        950,
      );
    });
  });

  group('GarsonProductModalState openNew', () {
    test('opens with portion mode without yarım when no explicit default', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
          ProductSizeOption(id: 'std', name: 'Standart', price: 120),
        ],
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      expect(state.activeMode, GarsonActivePricingMode.portion);
      expect(state.showGramajUi, isTrue);
      expect(state.selectedSizeName, isNull);
      expect(state.quantity, 1);
      expect(state.unitSelections.length, 1);
      expect(state.isEditingExistingLine, isFalse);
    });

    test('opens with explicit standart default when is_default set', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(
            id: 'half',
            name: 'Yarım Porsiyon',
            price: 60,
            isDefault: true,
          ),
          ProductSizeOption(
            id: 'std',
            name: 'Standart',
            price: 120,
            isDefault: true,
          ),
        ],
      );
      final state = GarsonProductModalState.openNew(product);
      expect(state.activeMode, GarsonActivePricingMode.size);
      expect(state.selectedSizeName, 'Standart');
    });

    test('never opens with yarım even when sole is_default flag', () {
      final product = _portionProduct(
        portionPrice: 380,
        sizes: const [
          ProductSizeOption(
            id: 'half',
            name: 'Yarım Porsiyon',
            price: 190,
            isDefault: true,
          ),
        ],
      );
      final state = GarsonProductModalState.openNew(product);
      expect(state.activeMode, GarsonActivePricingMode.portion);
      expect(state.selectedSizeName, isNull);
      expect(
        GarsonProductSelection.resolveUnitPrice(
          product: product,
          activeMode: state.activeMode,
        ),
        380,
      );
    });
  });

  group('GarsonProductSelection pricing', () {
    test('calculates gram price from kg price', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        defaultWeightGrams: 200,
        weightStepGrams: 100,
      );

      expect(
        GarsonProductSelection.resolveUnitPrice(
          product: product,
          activeMode: GarsonActivePricingMode.weight,
          selectedGramsForWeight: 500,
        ),
        950,
      );
    });

    test('clamps below minimum grams', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(
        GarsonProductSelection.clampGrams(product, 50),
        200,
      );
    });
  });

  group('GarsonProductModalState unit selections', () {
    test('quantity=3 creates three default tam portion units', () {
      final product = _portionProduct(portionPrice: 120);
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(1);
      state.changeQuantity(1);
      expect(state.quantity, 3);
      expect(state.unitSelections.length, 3);
      for (final unit in state.unitSelections) {
        expect(unit.pricingMode, GarsonActivePricingMode.portion);
        expect(unit.selectedSizeName, isNull);
      }
      final lines = state.buildConfirmedLines();
      expect(lines.length, 1);
      expect(lines.first['quantity'], 3);
      expect(
        GarsonProductSelection.orderItemDisplayLabel(lines.first),
        '3 x Ciğer Servis',
      );
    });

    test('quantity=3 with unit 2 yarım → 2x tam + 1x yarım', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
        ],
      );
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(1);
      state.changeQuantity(1);
      state.setActiveUnitIndex(1);
      state.setSizeMode('Yarım Porsiyon');
      final lines = state.buildConfirmedLines();
      expect(lines.length, 2);
      final labels = lines
          .map(GarsonProductSelection.orderItemDisplayLabel)
          .toList()
        ..sort();
      expect(labels, contains('2 x Ciğer Servis'));
      expect(labels, contains('1 x Ciğer Servis Yarım Porsiyon'));
    });

    test('quantity=2 with unit 1 at 500g and unit 2 tam', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(1);
      state.setWeightMode(grams: 500);
      state.setActiveUnitIndex(1);
      state.setPortionMode();
      final lines = state.buildConfirmedLines();
      expect(lines.length, 2);
      final labels = lines
          .map(GarsonProductSelection.orderItemDisplayLabel)
          .toList()
        ..sort();
      expect(labels, contains('1 x Ciğer Servis 500 g'));
      expect(labels, contains('1 x Ciğer Servis'));
    });

    test('feature applies only to active unit', () {
      final product = _portionProduct();
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(1);
      state.toggleFeature('Acısız');
      final lines = state.buildConfirmedLines();
      expect(lines.length, 2);
      final withNote = lines.firstWhere(
        (line) =>
            GarsonProductSelection.orderItemFeatureNoteLine(line).isNotEmpty,
      );
      final plain = lines.firstWhere(
        (line) =>
            GarsonProductSelection.orderItemFeatureNoteLine(line).isEmpty,
      );
      expect(withNote['quantity'], 1);
      expect(plain['quantity'], 1);
      expect(
        GarsonProductSelection.orderItemFeatureNoteLine(withNote),
        'Not: Acısız',
      );
    });

    test('decreasing quantity trims unit selections', () {
      final product = _portionProduct();
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(2);
      state.setActiveUnitIndex(2);
      state.setSizeMode('Yarım Porsiyon');
      state.changeQuantity(-1);
      expect(state.quantity, 2);
      expect(state.unitSelections.length, 2);
      expect(state.activeUnitIndex, 1);
    });
  });

  group('GarsonProductModalState edit', () {
    test('edit 2x tam then split one to yarım', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
        ],
      );
      final existing = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 2,
        activeMode: GarsonActivePricingMode.portion,
      );
      final state = GarsonProductModalState.fromDraftItem(product, existing);
      state.setActiveUnitIndex(1);
      state.setSizeMode('Yarım Porsiyon');
      final lines = state.buildConfirmedLines();
      expect(lines.length, 2);
      final labels = lines
          .map(GarsonProductSelection.orderItemDisplayLabel)
          .toList()
        ..sort();
      expect(labels, contains('1 x Ciğer Servis'));
      expect(labels, contains('1 x Ciğer Servis Yarım Porsiyon'));
    });
  });

  group('GarsonProductModalState interactions', () {
    test('feature selection does not change size or pricing mode', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
        ],
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      state.toggleFeature('Acısız');
      expect(state.activeMode, GarsonActivePricingMode.portion);
      expect(state.selectedSizeName, isNull);
      expect(state.selectedFeatures, {'Acısız'});
    });

    test('quantity change on one unit does not copy to new units', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
        ],
      );
      final state = GarsonProductModalState.openNew(product);
      state.setSizeMode('Yarım Porsiyon');
      state.changeQuantity(1);
      expect(state.unitSelections[0].pricingMode, GarsonActivePricingMode.size);
      expect(state.unitSelections[1].pricingMode, GarsonActivePricingMode.portion);
      expect(state.unitSelections[1].selectedSizeName, isNull);
    });
  });

  group('GarsonProductSelection merge key', () {
    test('different sizes stay separate lines', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
          ProductSizeOption(id: 'dbl', name: 'Duble', price: 200),
        ],
      );

      final half = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.size,
        selectedSizeName: 'Yarım Porsiyon',
      );
      final duble = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.size,
        selectedSizeName: 'Duble',
      );

      expect(
        GarsonProductSelection.orderLineMergeKey(half),
        isNot(GarsonProductSelection.orderLineMergeKey(duble)),
      );
    });

    test('same variant merges, different gramaj does not', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );

      final g500 = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 500,
      );
      final g200 = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 200,
      );
      final g500b = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 500,
      );

      expect(
        GarsonProductSelection.orderLineMergeKey(g500),
        GarsonProductSelection.orderLineMergeKey(g500b),
      );
      expect(
        GarsonProductSelection.orderLineMergeKey(g500),
        isNot(GarsonProductSelection.orderLineMergeKey(g200)),
      );
    });

    test('same product different feature does not merge', () {
      final product = _portionProduct();
      final acisiz = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.portion,
        attributes: const ['Acısız'],
      );
      final acili = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.portion,
        attributes: const ['Acılı'],
      );
      expect(
        GarsonProductSelection.orderLineMergeKey(acisiz),
        isNot(GarsonProductSelection.orderLineMergeKey(acili)),
      );
    });
  });

  group('GarsonProductSelection station propagation', () {
    test('buildOrderItem attaches production station header from product', () {
      final product = _portionProduct(
        name: 'Ciğer Servis',
        stationId: 'ocak-id',
        stationName: 'Ocak',
        stationCode: 'OCAK',
      );
      final item = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.portion,
      );
      expect(item['station_id'], 'ocak-id');
      expect(item['station_name'], 'OCAK');
      expect(item['kitchen_station_name'], 'OCAK');
      expect(item['station_code'], 'OCAK');
    });
  });

  group('GarsonProductSelection display label', () {
    test('display_label is title without quantity', () {
      final product = _portionProduct(name: 'Ciğer Servis');
      final grams = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 2,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 500,
      );
      expect(grams['display_label'], 'Ciğer Servis 500 g');
      expect(grams['amount_label'], '500 g');
      expect(grams['selected_grams'], 500);
      expect(
        GarsonProductSelection.orderItemDisplayLabel(grams),
        '2 x Ciğer Servis 500 g',
      );
    });

    test('custom gram 575 keeps exact value despite step 100', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      expect(
        GarsonProductSelection.parseCustomGramInput('575', product: product),
        575,
      );
      expect(GarsonProductSelection.clampGrams(product, 575), 600);
      expect(GarsonProductSelection.clampCustomGrams(product, 575), 575);
      final item = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 575,
      );
      expect(item['selected_grams'], 575);
      expect(item['display_label'], 'Ciğer Servis 575 g');
      expect(item['amount_label'], '575 g');
      expect(item['price'], closeTo(1092.5, 0.01));
    });

    test('modal setWeightModeForActiveUnit applies custom grams to active unit', () {
      final product = _portionProduct(
        pricePerKg: 1900,
        minWeightGrams: 200,
        weightStepGrams: 100,
      );
      final state = GarsonProductModalState.openNew(product);
      state.setWeightModeForActiveUnit(575, snapToStep: false);
      expect(state.activeMode, GarsonActivePricingMode.weight);
      expect(state.selectedGrams, 575);
      expect(state.selectedWeightGrams, 575);
      expect(state.isCustomGramSelection, isTrue);
      final lines = state.buildConfirmedLines();
      expect(
        GarsonProductSelection.orderItemDisplayLabel(lines.first),
        '1 x Ciğer Servis 575 g',
      );
    });

    test('enrich restores amount_label after normalizeOrderItem', () {
      final raw = GarsonProductSelection.buildOrderItem(
        product: _portionProduct(pricePerKg: 1900, minWeightGrams: 200),
        quantity: 1,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 200,
      );
      final normalized = MixedServiceOrder.normalizeOrderItem(raw);
      expect(normalized['amount_label'], '200 g');
      expect(normalized['display_label'], 'Ciğer Servis 200 g');
      expect(
        GarsonProductSelection.orderItemDisplayLabel(normalized),
        '1 x Ciğer Servis 200 g',
      );
    });

    test('formats receipt labels with qty size and grams', () {
      final product = _portionProduct(name: 'Ciğer Servis');
      final portion1 = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.portion,
      );
      final portion3 = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 3,
        activeMode: GarsonActivePricingMode.portion,
      );
      final half = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 1,
        activeMode: GarsonActivePricingMode.size,
        selectedSizeName: 'Yarım Porsiyon',
      );
      final half2 = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 2,
        activeMode: GarsonActivePricingMode.size,
        selectedSizeName: 'Yarım Porsiyon',
      );
      final grams = GarsonProductSelection.buildOrderItem(
        product: product,
        quantity: 2,
        activeMode: GarsonActivePricingMode.weight,
        selectedGramsForWeight: 500,
      );

      expect(
        GarsonProductSelection.orderItemDisplayLabel(portion1),
        '1 x Ciğer Servis',
      );
      expect(
        GarsonProductSelection.orderItemDisplayLabel(portion3),
        '3 x Ciğer Servis',
      );
      expect(
        GarsonProductSelection.orderItemDisplayLabel(half),
        '1 x Ciğer Servis Yarım Porsiyon',
      );
      expect(
        GarsonProductSelection.orderItemDisplayLabel(half2),
        '2 x Ciğer Servis Yarım Porsiyon',
      );
      expect(
        GarsonProductSelection.orderItemDisplayLabel(grams),
        '2 x Ciğer Servis 500 g',
      );
    });

    test('portion line with leaked size fields still shows tam label', () {
      final dirty = <String, dynamic>{
        'name': 'Ciğer Servis',
        'quantity': 2,
        'pricing_mode': 'portion',
        'selected_size_name': 'Yarım Porsiyon',
      };
      expect(
        GarsonProductSelection.orderItemDisplayLabel(
          GarsonProductSelection.sanitizeOrderItemFields(dirty),
        ),
        '2 x Ciğer Servis',
      );
    });
  });

  group('GarsonProductSelection selection summary', () {
    test('buildSelectionSummary lists grouped lines', () {
      final product = _portionProduct(
        sizes: const [
          ProductSizeOption(id: 'half', name: 'Yarım Porsiyon', price: 60),
        ],
      );
      final state = GarsonProductModalState.openNew(product);
      state.changeQuantity(1);
      state.changeQuantity(1);
      state.setActiveUnitIndex(1);
      state.setSizeMode('Yarım Porsiyon');
      final summary = state.buildSelectionSummary();
      expect(summary, contains('- 2 x Ciğer Servis'));
      expect(summary, contains('- 1 x Ciğer Servis Yarım Porsiyon'));
    });
  });
}
