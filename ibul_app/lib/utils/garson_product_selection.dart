import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/product_pricing.dart';
import '../models/seller_product.dart';
import '../services/kitchen_print_trace_log.dart';
import '../services/kitchen_routing_service.dart';

/// Garson ürün seçimi: varsayılan boyut/gramaj, fiyat, satır anahtarı, fiş etiketi.
enum GarsonActivePricingMode {
  portion,
  weight,
  size,
}

void garsonProductSelectLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[GarsonProductSelect] $stage$suffix');
}

void garsonOrderItemLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[GarsonOrderItem] $stage$suffix');
}

void sellerNavigationLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[SellerNavigation] $stage$suffix');
}

void garsonDraftLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[GarsonDraft] $stage$suffix');
}

void garsonWeightVisibilityLog(SellerProduct product) {
  if (!kDebugMode) return;
  final visible = GarsonProductSelection.shouldShowWeightControls(product);
  final payload = <String, Object?>{
    'productName': product.name,
    'pricingType': product.pricingType,
    'pricingMode': product.pricingMode,
    'portionPrice': product.portionPrice ?? product.effectiveBaseUnitPrice,
    'kgPrice': product.effectivePricePerKg,
    'minWeightGrams': product.minWeightGrams ?? '',
    'defaultWeightGrams': product.defaultWeightGrams ?? '',
    'weightStepGrams': product.weightStepGrams ?? '',
    'supportsWeightSelection': product.supportsGarsonWeightSelection,
    'visible': visible,
    'reason': GarsonProductSelection.weightVisibilityReason(product),
  };
  debugPrint(
    '[GarsonProductSelect][WeightVisibility] ${jsonEncode(payload)}',
  );
}

/// Tek adet için boyut/gramaj/özellik seçimi.
class GarsonUnitSelection {
  GarsonUnitSelection({
    required this.pricingMode,
    this.selectedSizeName,
    this.selectedServiceAmount = 1,
    this.selectedWeightGrams = 0,
    this.selectedGrams = 0,
    Set<String>? selectedFeatures,
    this.note = '',
  }) : selectedFeatures = selectedFeatures ?? <String>{};

  GarsonActivePricingMode pricingMode;
  String? selectedSizeName;
  double selectedServiceAmount;
  int selectedWeightGrams;
  int selectedGrams;
  final Set<String> selectedFeatures;
  String note;

  factory GarsonUnitSelection.defaultsFor(SellerProduct product) {
    final defaults = GarsonProductSelection.resolveDefaults(product);
    final explicitDefault =
        ProductPriceCalculator.explicitDefaultSizeOption(product.sizeOptions);
    if (explicitDefault != null) {
      return GarsonUnitSelection(
        pricingMode: GarsonActivePricingMode.size,
        selectedSizeName: explicitDefault.name,
        selectedServiceAmount: defaults.serviceAmount,
        selectedWeightGrams: defaults.weightGrams,
        selectedGrams: defaults.gramsForWeightPrice,
      );
    }
    // Garson modal: gramaj UI görünse bile varsayılan Tam porsiyon (portion).
    final latentGrams = GarsonProductSelection.supportsWeightUi(product)
        ? product.resolvedDefaultWeightGrams
        : 0;
    return GarsonUnitSelection(
      pricingMode: GarsonActivePricingMode.portion,
      selectedSizeName: null,
      selectedServiceAmount: defaults.serviceAmount,
      selectedWeightGrams: latentGrams,
      selectedGrams: latentGrams,
    );
  }

  factory GarsonUnitSelection.fromDraftItem(
    SellerProduct product,
    Map<String, dynamic> item,
  ) {
    final sanitized = GarsonProductSelection.sanitizeOrderItemFields(item);
    final mode = GarsonProductSelection.activeModeFromStorage(
      sanitized['pricing_mode']?.toString(),
    );
    final attrs =
        (sanitized['attributes'] as List?)?.whereType<String>().toList() ??
        const <String>[];
    final defaults = GarsonProductSelection.resolveDefaults(product);
    final note =
        sanitized['notes']?.toString().trim() ??
        sanitized['note']?.toString().trim() ??
        '';
    return GarsonUnitSelection(
      pricingMode: mode,
      selectedSizeName: mode == GarsonActivePricingMode.size
          ? sanitized['selected_size_name']?.toString() ??
                sanitized['selectedSizeName']?.toString()
          : null,
      selectedServiceAmount:
          (sanitized['selected_service_amount'] as num?)?.toDouble() ??
          (sanitized['selectedServiceAmount'] as num?)?.toDouble() ??
          defaults.serviceAmount,
      selectedWeightGrams:
          GarsonProductSelection._gramsFromItem(sanitized) > 0
          ? GarsonProductSelection._gramsFromItem(sanitized)
          : defaults.weightGrams,
      selectedGrams: mode == GarsonActivePricingMode.weight
          ? GarsonProductSelection._gramsFromItem(sanitized)
          : defaults.gramsForWeightPrice,
      selectedFeatures: attrs.toSet(),
      note: note,
    );
  }

  GarsonUnitSelection copy() {
    return GarsonUnitSelection(
      pricingMode: pricingMode,
      selectedSizeName: selectedSizeName,
      selectedServiceAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
      selectedGrams: selectedGrams,
      selectedFeatures: Set<String>.from(selectedFeatures),
      note: note,
    );
  }
}

/// Garson modal açılış durumu — build sırasında yeniden hesaplanmaz.
class GarsonProductModalState {
  GarsonProductModalState._({
    required this.product,
    required this.quantity,
    required this.unitSelections,
    required this.activeUnitIndex,
    required this.showGramajUi,
    required this.isEditingExistingLine,
  });

  final SellerProduct product;
  int quantity;
  int activeUnitIndex;
  final List<GarsonUnitSelection> unitSelections;
  final bool showGramajUi;
  final bool isEditingExistingLine;

  GarsonUnitSelection get activeUnit => unitSelections[activeUnitIndex];

  GarsonActivePricingMode get activeMode => activeUnit.pricingMode;

  String? get selectedSizeName => activeUnit.selectedSizeName;

  double get selectedServiceAmount => activeUnit.selectedServiceAmount;

  int get selectedWeightGrams => activeUnit.selectedWeightGrams;

  int get selectedGrams => activeUnit.selectedGrams;

  Set<String> get selectedFeatures => activeUnit.selectedFeatures;

  /// Yeni satır ekleme — her zaman quantity=1, varsayılan tam porsiyon.
  factory GarsonProductModalState.openNew(SellerProduct product) {
    final state = GarsonProductModalState._(
      product: product,
      quantity: 1,
      unitSelections: <GarsonUnitSelection>[
        GarsonUnitSelection.defaultsFor(product),
      ],
      activeUnitIndex: 0,
      showGramajUi: GarsonProductSelection.supportsWeightUi(product),
      isEditingExistingLine: false,
    );
    garsonWeightVisibilityLog(product);
    state._logInit();
    return state;
  }

  /// Mevcut taslak satırını düzenleme.
  factory GarsonProductModalState.fromDraftItem(
    SellerProduct product,
    Map<String, dynamic> item,
  ) {
    final sanitized = GarsonProductSelection.sanitizeOrderItemFields(item);
    final qty = (sanitized['quantity'] as num?)?.toInt() ?? 1;
    final unit = GarsonUnitSelection.fromDraftItem(product, sanitized);
    final state = GarsonProductModalState._(
      product: product,
      quantity: qty,
      unitSelections: List<GarsonUnitSelection>.generate(
        qty,
        (_) => unit.copy(),
        growable: true,
      ),
      activeUnitIndex: 0,
      showGramajUi: GarsonProductSelection.supportsWeightUi(product),
      isEditingExistingLine: true,
    );
    garsonWeightVisibilityLog(product);
    state._logInit();
    return state;
  }

  void _logInit() {
    final unit = activeUnit;
    final calculatedPrice = GarsonProductSelection.resolveUnitPrice(
      product: product,
      activeMode: unit.pricingMode,
      selectedSizeName: unit.selectedSizeName,
      selectedServiceAmount: unit.selectedServiceAmount,
      selectedWeightGrams: unit.selectedWeightGrams,
      selectedGramsForWeight:
          unit.pricingMode == GarsonActivePricingMode.weight
          ? unit.selectedGrams
          : null,
    );
    final explicitDefault =
        ProductPriceCalculator.explicitDefaultSizeOption(product.sizeOptions);
    final normalizedDefaults = product.normalizedSizeOptions
        .map((o) => '${o.name}:${o.isDefault}')
        .join(',');
    final defaultReason = explicitDefault != null
        ? 'explicit_size_default'
        : 'base_portion_default';
    garsonProductSelectLog(
      'init_state',
      extra: {
        'productId': product.id,
        'productName': product.name,
        'quantity': quantity,
        'unitCount': unitSelections.length,
        'activeUnit': activeUnitIndex + 1,
        'pricingMode': activeMode.name,
        'selectedSizeName': selectedSizeName ?? '',
        'explicitDefaultSizeName': explicitDefault?.name ?? '',
        'normalizedSizeDefaults': normalizedDefaults,
        'selectedGrams': activeMode == GarsonActivePricingMode.weight
            ? selectedGrams
            : 0,
        'selectedFeatures': selectedFeatures.join(','),
        'editing': isEditingExistingLine,
        'calculatedPrice': calculatedPrice,
        'defaultReason': defaultReason,
      },
    );
  }

  void ensureUnitSelectionCount(int target) {
    while (unitSelections.length < target) {
      unitSelections.add(GarsonUnitSelection.defaultsFor(product));
    }
    while (unitSelections.length > target) {
      unitSelections.removeLast();
    }
    if (activeUnitIndex >= unitSelections.length) {
      activeUnitIndex = unitSelections.length - 1;
    }
    if (activeUnitIndex < 0) activeUnitIndex = 0;
  }

  void setActiveUnitIndex(int index) {
    if (index < 0 || index >= quantity) return;
    activeUnitIndex = index;
    garsonProductSelectLog(
      'active_unit_changed',
      extra: {'activeUnit': activeUnitIndex + 1, 'quantity': quantity},
    );
  }

  void syncActiveUnitNote(String note) {
    activeUnit.note = note;
  }

  void setPortionMode() {
    final unit = activeUnit;
    final previous = unit.pricingMode;
    unit.pricingMode = GarsonActivePricingMode.portion;
    unit.selectedSizeName = null;
    if (previous != unit.pricingMode) {
      garsonProductSelectLog(
        'pricing_mode_changed',
        extra: {'mode': 'portion', 'from': previous.name, 'unit': activeUnitIndex + 1},
      );
    }
  }

  void setWeightMode({int? grams, bool snapToStep = true}) {
    if (grams != null) {
      setWeightModeForActiveUnit(grams, snapToStep: snapToStep);
      return;
    }
    final unit = activeUnit;
    final previous = unit.pricingMode;
    unit.pricingMode = GarsonActivePricingMode.weight;
    unit.selectedSizeName = null;
    if (previous != unit.pricingMode) {
      garsonProductSelectLog(
        'pricing_mode_changed',
        extra: {'mode': 'weight', 'from': previous.name, 'unit': activeUnitIndex + 1},
      );
    }
  }

  /// Hazır butonlar: [snapToStep]=true. Özel gramaj: false (575 gibi serbest değer).
  void setWeightModeForActiveUnit(int grams, {bool snapToStep = false}) {
    final unit = activeUnit;
    final previous = unit.pricingMode;
    unit.pricingMode = GarsonActivePricingMode.weight;
    unit.selectedSizeName = null;
    final resolved = snapToStep
        ? GarsonProductSelection.clampGrams(product, grams)
        : GarsonProductSelection.clampCustomGrams(product, grams);
    unit.selectedGrams = resolved;
    unit.selectedWeightGrams = resolved;
    garsonProductSelectLog(
      snapToStep ? 'gram_selected' : 'custom_gram_selected',
      extra: {
        'grams': resolved,
        'pricingMode': unit.pricingMode.name,
        'unit': activeUnitIndex + 1,
        'snapToStep': snapToStep,
      },
    );
    if (previous != unit.pricingMode) {
      garsonProductSelectLog(
        'pricing_mode_changed',
        extra: {'mode': 'weight', 'from': previous.name, 'unit': activeUnitIndex + 1},
      );
    }
  }

  bool get isCustomGramSelection {
    if (activeMode != GarsonActivePricingMode.weight) return false;
    final presets = GarsonProductSelection.weightQuickGramOptions(product);
    return !presets.contains(selectedGrams);
  }

  void setSizeMode(String sizeName) {
    final unit = activeUnit;
    final previous = unit.pricingMode;
    unit.pricingMode = GarsonActivePricingMode.size;
    unit.selectedSizeName = sizeName;
    garsonProductSelectLog(
      'size_selected',
      extra: {
        'selectedSizeName': sizeName,
        'pricingMode': unit.pricingMode.name,
        'unit': activeUnitIndex + 1,
      },
    );
    if (previous != unit.pricingMode) {
      garsonProductSelectLog(
        'pricing_mode_changed',
        extra: {'mode': 'size', 'from': previous.name, 'unit': activeUnitIndex + 1},
      );
    }
  }

  void changeQuantity(int delta) {
    final oldQuantity = quantity;
    final next = quantity + delta;
    if (next < 1) return;
    quantity = next;
    ensureUnitSelectionCount(quantity);
    garsonProductSelectLog(
      'quantity_changed',
      extra: {
        'oldQuantity': oldQuantity,
        'newQuantity': quantity,
        'unitCount': unitSelections.length,
        'activeUnit': activeUnitIndex + 1,
      },
    );
  }

  void toggleFeature(String feature) {
    final unit = activeUnit;
    if (unit.selectedFeatures.contains(feature)) {
      unit.selectedFeatures.remove(feature);
    } else {
      unit.selectedFeatures.add(feature);
    }
    garsonProductSelectLog(
      'feature_changed',
      extra: {
        'selectedFeatures': unit.selectedFeatures.join(','),
        'pricingMode': unit.pricingMode.name,
        'selectedSizeName': unit.selectedSizeName ?? '',
        'selectedGrams': unit.pricingMode == GarsonActivePricingMode.weight
            ? unit.selectedGrams
            : 0,
        'unit': activeUnitIndex + 1,
      },
    );
  }

  set selectedServiceAmount(double value) {
    activeUnit.selectedServiceAmount = value;
  }

  String buildSelectionSummary() {
    return GarsonProductSelection.buildSelectionSummary(
      product: product,
      lines: buildGroupedOrderLines(),
    );
  }

  @Deprecated('Use buildSelectionSummary')
  String selectionSummaryLabel({String notes = ''}) {
    syncActiveUnitNote(notes);
    return buildSelectionSummary();
  }

  List<Map<String, dynamic>> buildGroupedOrderLines() {
    if (product.usesServiceControlStepper) {
      return [
        GarsonProductSelection.buildOrderItemFromUnit(
          product: product,
          quantity: 1,
          unit: activeUnit,
          showGramajUi: showGramajUi,
        ),
      ];
    }
    return GarsonProductSelection.groupUnitSelectionsByMergeKey(
      product: product,
      units: unitSelections,
      showGramajUi: showGramajUi,
    );
  }

  List<Map<String, dynamic>> buildConfirmedLines() {
    final lines = buildGroupedOrderLines();
    for (final line in lines) {
      if (kDebugMode) {
        final storageMode = GarsonProductSelection.strictPricingModeFromItem(line);
        debugPrint(
          '[GarsonProductSelect][confirm_lines] ${jsonEncode(<String, Object?>{
            'pricingMode': storageMode == 'kilo' ? 'weight' : storageMode,
            'selectedGrams': GarsonProductSelection._gramsFromItem(line),
            'displayLabel': line['display_label'] ?? '',
            'amountLabel': line['amount_label'] ?? line['gramaj'] ?? '',
            'quantity': line['quantity'] ?? 1,
          })}',
        );
      }
    }
    return lines;
  }

  Map<String, dynamic> buildConfirmedLine({required String notes}) {
    syncActiveUnitNote(notes);
    final lines = buildConfirmedLines();
    return lines.first;
  }
}

void garsonPrintPayloadLog(String stage, {Map<String, Object?>? extra}) {
  if (!kDebugMode) return;
  final suffix = extra == null || extra.isEmpty
      ? ''
      : ' ${extra.entries.map((e) => '${e.key}=${e.value}').join(' ')}';
  debugPrint('[GarsonPrintPayload] $stage$suffix');
}

class GarsonProductSelectionDefaults {
  const GarsonProductSelectionDefaults({
    required this.pricingMode,
    this.sizeName,
    this.serviceAmount = 1,
    this.weightGrams = 0,
    this.gramsForWeightPrice = 0,
  });

  final GarsonActivePricingMode pricingMode;
  final String? sizeName;
  final double serviceAmount;
  final int weightGrams;
  final int gramsForWeightPrice;
}

class GarsonProductSelection {
  GarsonProductSelection._();

  static GarsonProductSelectionDefaults resolveDefaults(SellerProduct product) {
    GarsonActivePricingMode mode = GarsonActivePricingMode.portion;
    String? sizeName;
    var serviceAmount = product.resolvedDefaultServiceAmount;
    var weightGrams = product.resolvedDefaultWeightGrams;
    var gramsForWeight = 0;

    if (product.usesPortionLikeStepper) {
      serviceAmount = _defaultPortionAmount(product);
      mode = GarsonActivePricingMode.portion;
      garsonProductSelectLog(
        'default_selection',
        extra: {
          'productId': product.id,
          'mode': 'portion_stepper',
          'serviceAmount': serviceAmount,
        },
      );
      return GarsonProductSelectionDefaults(
        pricingMode: mode,
        serviceAmount: serviceAmount,
        weightGrams: weightGrams,
      );
    }

    final hasPortionPrice = ProductPriceCalculator.sanitizePrice(
          product.portionPrice ?? product.basePrice ?? 0,
        ) >
        0;
    if (product.resolvedServiceControlType ==
            ProductServiceControlType.weightStepper &&
        !product.hasSizeOptions &&
        !hasPortionPrice) {
      gramsForWeight = weightGrams;
      mode = GarsonActivePricingMode.weight;
      garsonProductSelectLog(
        'default_selection',
        extra: {
          'productId': product.id,
          'mode': 'weight_stepper',
          'weightGrams': weightGrams,
        },
      );
      return GarsonProductSelectionDefaults(
        pricingMode: mode,
        weightGrams: weightGrams,
        gramsForWeightPrice: gramsForWeight,
      );
    }

    final explicitDefault = ProductPriceCalculator.explicitDefaultSizeOption(
      product.sizeOptions,
    );
    if (explicitDefault != null) {
      sizeName = explicitDefault.name;
      mode = GarsonActivePricingMode.size;
    }

    if (supportsWeightUi(product)) {
      gramsForWeight = product.resolvedDefaultWeightGrams;
      if (explicitDefault == null &&
          !product.hasSizeOptions &&
          !hasPortionPrice) {
        mode = GarsonActivePricingMode.weight;
      }
    }

    garsonProductSelectLog(
      'default_selection',
      extra: {
        'productId': product.id,
        'mode': mode.name,
        'sizeName': sizeName ?? '',
        'grams': gramsForWeight,
      },
    );

    return GarsonProductSelectionDefaults(
      pricingMode: mode,
      sizeName: sizeName,
      serviceAmount: serviceAmount,
      weightGrams: weightGrams,
      gramsForWeightPrice: gramsForWeight,
    );
  }

  static double _defaultPortionAmount(SellerProduct product) {
    final min = ProductPriceCalculator.resolveMinPortionAmount(
      product.resolvedServiceControlType,
      product.minPortion,
    );
    final target = product.resolvedServiceControlType ==
            ProductServiceControlType.portionStepper
        ? (min < 1 ? 1.0 : min)
        : min;
    return ProductPriceCalculator.clampPortionSelection(
      target,
      type: product.resolvedServiceControlType,
      minPortion: product.minPortion,
      maxPortion: product.maxPortion,
      portionStep: product.portionStep,
    );
  }

  /// Gramaj bölümü görünürlüğü — kilo fiyatı veya hibrit kilo/gramaj desteği.
  static bool shouldShowWeightControls(SellerProduct product) {
    if (product.resolvedServiceControlType ==
            ProductServiceControlType.weightStepper &&
        product.effectivePricePerKg > 0 &&
        product.effectiveBaseUnitPrice <= 0 &&
        !product.hasSizeOptions) {
      return false;
    }
    return product.supportsGarsonWeightSelection;
  }

  static String weightVisibilityReason(SellerProduct product) {
    if (!shouldShowWeightControls(product)) {
      if (product.effectivePricePerKg <= 0 &&
          !product.hasConfiguredWeightGramFields) {
        return 'no_kg_price_or_weight_settings';
      }
      if (product.resolvedServiceControlType ==
          ProductServiceControlType.weightStepper) {
        return 'weight_stepper_dedicated_ui';
      }
      return 'weight_controls_hidden';
    }
    if (product.effectivePricePerKg > 0) {
      return 'kg_price_or_weight_settings';
    }
    return 'pricing_metadata_weight';
  }

  static bool supportsWeightUi(SellerProduct product) {
    return shouldShowWeightControls(product);
  }

  static List<int> weightQuickGramOptions(SellerProduct product) {
    if (!supportsWeightUi(product)) return const <int>[];
    final settings = product.resolvedWeightGramSettings;
    final options = ProductPriceCalculator.buildPresetWeightOptions(
      minWeightGrams: product.minWeightGrams,
      defaultWeightGrams: product.defaultWeightGrams,
      weightStepGrams: product.weightStepGrams,
      maxWeightGrams: product.maxWeightGrams,
    );
    garsonProductSelectLog(
      'weight_settings_applied',
      extra: {
        'productId': product.id,
        'minGrams': settings.minGrams,
        'defaultGrams': settings.defaultGrams,
        'stepGrams': settings.stepGrams,
        'maxGrams': settings.maxGrams ?? '',
        'source': settings.source,
        'quickOptions': options.join(','),
      },
    );
    return options;
  }

  static int clampGrams(SellerProduct product, int grams) {
    final settings = product.resolvedWeightGramSettings;
    return ProductPriceCalculator.clampWeightSelection(
      grams,
      minWeightGrams: settings.minGrams,
      weightStepGrams: settings.stepGrams,
      maxWeightGrams: settings.maxGrams,
    );
  }

  /// Özel gramaj: yalnızca min/max; step yuvarlaması yok (575 → 575 kalır).
  static int clampCustomGrams(SellerProduct product, int grams) {
    final settings = product.resolvedWeightGramSettings;
    var resolved = grams;
    if (resolved < settings.minGrams) {
      resolved = settings.minGrams;
    }
    final max = settings.maxGrams;
    if (max != null && resolved > max) {
      resolved = max;
    }
    return resolved;
  }

  static int? parseGramsFromText(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;
    final kgMatch = RegExp(r'(\d+(?:[.,]\d+)?)\s*kg').firstMatch(text);
    if (kgMatch != null) {
      final value =
          double.tryParse(kgMatch.group(1)!.replaceAll(',', '.')) ?? 0;
      return value > 0 ? (value * 1000).round() : null;
    }
    final gMatch = RegExp(r'(\d+)\s*g').firstMatch(text);
    if (gMatch != null) {
      return int.tryParse(gMatch.group(1)!);
    }
    final plain = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
    return plain;
  }

  /// Özel gramaj alanı: pozitif tam sayı; min/max sınırı, step yuvarlaması yok.
  static int? parseCustomGramInput(String raw, {required SellerProduct product}) {
    final parsed = parseGramsFromText(raw);
    if (parsed == null || parsed <= 0) return null;
    return clampCustomGrams(product, parsed);
  }

  static double resolveUnitPrice({
    required SellerProduct product,
    required GarsonActivePricingMode activeMode,
    String? selectedSizeName,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? selectedGramsForWeight,
  }) {
    final sizeName = activeMode == GarsonActivePricingMode.size
        ? selectedSizeName
        : null;
    final grams = activeMode == GarsonActivePricingMode.weight
        ? (selectedGramsForWeight ??
            selectedWeightGrams ??
            product.resolvedDefaultWeightGrams)
        : null;

    final effectivePricingType =
        activeMode == GarsonActivePricingMode.weight &&
            product.effectivePricePerKg > 0
        ? ProductPricingType.weight
        : product.resolvedPricingType;

    final price = ProductPriceCalculator.resolveServiceControlledUnitPrice(
      serviceControlType: product.resolvedServiceControlType,
      pricingType: effectivePricingType,
      pricingMode: product.resolvedPricingMode,
      basePrice: product.basePrice ?? product.portionPrice,
      portionPrice: product.portionPrice,
      pricePerKg: product.effectivePricePerKg > 0
          ? product.effectivePricePerKg
          : product.pricePerKg,
      sizeOptions: activeMode == GarsonActivePricingMode.size
          ? product.normalizedSizeOptions
          : const <ProductSizeOption>[],
      selectedSizeName: sizeName,
      fallbackPrice: product.price,
      selectedAmount: product.usesPortionLikeStepper
          ? selectedServiceAmount
          : null,
      selectedWeightGrams: grams,
    );

    garsonProductSelectLog(
      'calculated_price',
      extra: {
        'productId': product.id,
        'mode': activeMode.name,
        'unitPrice': price,
        'grams': grams ?? 0,
        'size': sizeName ?? '',
      },
    );
    return price;
  }

  static String resolveAmountLabel({
    required SellerProduct product,
    required GarsonActivePricingMode activeMode,
    String? selectedSizeName,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? selectedGramsForWeight,
  }) {
    switch (activeMode) {
      case GarsonActivePricingMode.size:
        return selectedSizeName?.trim() ?? '';
      case GarsonActivePricingMode.weight:
        final grams = selectedGramsForWeight ?? selectedWeightGrams ?? 0;
        if (grams <= 0) return '';
        return ProductPriceCalculator.formatWeight(grams);
      case GarsonActivePricingMode.portion:
        if (product.usesPortionLikeStepper) {
          return ProductPriceCalculator.formatServiceAmountLabel(
            type: product.resolvedServiceControlType,
            amount: selectedServiceAmount,
          );
        }
        return '';
    }
  }

  static String pricingModeStorage(GarsonActivePricingMode mode) {
    switch (mode) {
      case GarsonActivePricingMode.portion:
        return 'portion';
      case GarsonActivePricingMode.weight:
        return 'kilo';
      case GarsonActivePricingMode.size:
        return 'size';
    }
  }

  /// Yalnızca kayıtlı pricing_mode alanına güvenir; sızıntı alanlarından mod çıkarmaz.
  static String strictPricingModeFromItem(Map<String, dynamic> item) {
    switch (activeModeFromStorage(item['pricing_mode']?.toString())) {
      case GarsonActivePricingMode.weight:
        return 'kilo';
      case GarsonActivePricingMode.size:
        return 'size';
      case GarsonActivePricingMode.portion:
        return 'portion';
    }
  }

  static GarsonActivePricingMode activeModeFromStorage(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value == 'kilo' || value == 'weight') {
      return GarsonActivePricingMode.weight;
    }
    if (value == 'size') {
      return GarsonActivePricingMode.size;
    }
    return GarsonActivePricingMode.portion;
  }

  static bool isGarsonPricingMode(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'portion':
      case 'size':
      case 'kilo':
      case 'weight':
        return true;
      default:
        return false;
    }
  }

  static Map<String, dynamic> sanitizeOrderItemFields(Map<String, dynamic> item) {
    final copy = Map<String, dynamic>.from(item);
    if (!isGarsonPricingMode(copy['pricing_mode']?.toString())) {
      return copy;
    }
    final mode = activeModeFromStorage(copy['pricing_mode']?.toString());
    copy['pricing_mode'] = pricingModeStorage(mode);

    if (mode == GarsonActivePricingMode.portion) {
      copy['selected_size_name'] = null;
      copy['selectedSizeName'] = null;
      copy['selected_grams'] = null;
      copy['selectedGrams'] = null;
      copy['selected_weight_grams'] = null;
      copy['selectedWeightGrams'] = null;
      if (!ProductPriceCalculator.usesPortionLikeStepper(
        ProductServiceControlType.fromValue(
          copy['service_control_type'] ?? copy['serviceControlType'],
        ),
      )) {
        copy['gramaj'] = '';
        copy['amount_label'] = '';
        copy['amountLabel'] = '';
      }
    } else if (mode == GarsonActivePricingMode.size) {
      copy['selected_grams'] = null;
      copy['selectedGrams'] = null;
      copy['selected_weight_grams'] = null;
      copy['selectedWeightGrams'] = null;
      copy['selected_service_amount'] = null;
      copy['selectedServiceAmount'] = null;
    } else {
      copy['selected_size_name'] = null;
      copy['selectedSizeName'] = null;
      copy['selected_service_amount'] = null;
      copy['selectedServiceAmount'] = null;
    }
    return copy;
  }

  static String previewSelectionSummary({
    required SellerProduct product,
    required int quantity,
    required GarsonActivePricingMode activeMode,
    String? selectedSizeName,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? selectedGramsForWeight,
    String notes = '',
    List<String> attributes = const <String>[],
  }) {
    final probe = buildOrderItem(
      product: product,
      quantity: quantity,
      activeMode: activeMode,
      selectedSizeName: selectedSizeName,
      selectedServiceAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
      selectedGramsForWeight: selectedGramsForWeight,
      notes: notes,
      attributes: attributes,
    );
    return _formatSummaryLine(probe);
  }

  static String buildSelectionSummary({
    required SellerProduct product,
    required List<Map<String, dynamic>> lines,
  }) {
    if (lines.isEmpty) return '';
    return lines.map(_formatSummaryLine).join('\n');
  }

  static String _formatSummaryLine(Map<String, dynamic> line) {
    final label = orderItemDisplayLabel(line);
    final noteLine = orderItemFeatureNoteLine(line);
    if (noteLine.isEmpty) return '- $label';
    return '- $label — $noteLine';
  }

  static Map<String, dynamic> buildOrderItemFromUnit({
    required SellerProduct product,
    required int quantity,
    required GarsonUnitSelection unit,
    required bool showGramajUi,
  }) {
    return buildOrderItem(
      product: product,
      quantity: quantity,
      activeMode: unit.pricingMode,
      selectedSizeName: unit.selectedSizeName,
      selectedServiceAmount: unit.selectedServiceAmount,
      selectedWeightGrams: unit.selectedWeightGrams,
      selectedGramsForWeight: unit.pricingMode == GarsonActivePricingMode.weight
          ? unit.selectedGrams
          : null,
      notes: unit.note,
      attributes: unit.selectedFeatures.toList(growable: false),
    );
  }

  static String unitSelectionMergeKey({
    required SellerProduct product,
    required GarsonUnitSelection unit,
    required bool showGramajUi,
  }) {
    final probe = buildOrderItemFromUnit(
      product: product,
      quantity: 1,
      unit: unit,
      showGramajUi: showGramajUi,
    );
    return orderLineMergeKey(probe);
  }

  static List<Map<String, dynamic>> groupUnitSelectionsByMergeKey({
    required SellerProduct product,
    required List<GarsonUnitSelection> units,
    required bool showGramajUi,
  }) {
    final grouped = <String, List<GarsonUnitSelection>>{};
    for (final unit in units) {
      final key = unitSelectionMergeKey(
        product: product,
        unit: unit,
        showGramajUi: showGramajUi,
      );
      grouped.putIfAbsent(key, () => <GarsonUnitSelection>[]).add(unit);
    }
    return grouped.entries
        .map(
          (entry) => buildOrderItemFromUnit(
            product: product,
            quantity: entry.value.length,
            unit: entry.value.first,
            showGramajUi: showGramajUi,
          ),
        )
        .toList(growable: false);
  }

  static String storagePricingModeFromItem(Map<String, dynamic> item) {
    return strictPricingModeFromItem(item);
  }

  static int _gramsFromItem(Map<String, dynamic> item) {
    return (item['selected_weight_grams'] as num?)?.toInt() ??
        (item['selectedWeightGrams'] as num?)?.toInt() ??
        (item['selected_grams'] as num?)?.toInt() ??
        (item['selectedGrams'] as num?)?.toInt() ??
        0;
  }

  static Map<String, dynamic> buildOrderItem({
    required SellerProduct product,
    required int quantity,
    required GarsonActivePricingMode activeMode,
    String? selectedSizeName,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int? selectedGramsForWeight,
    String notes = '',
    List<String> attributes = const <String>[],
  }) {
    final unitPrice = resolveUnitPrice(
      product: product,
      activeMode: activeMode,
      selectedSizeName: selectedSizeName,
      selectedServiceAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
      selectedGramsForWeight: selectedGramsForWeight,
    );
    final amountLabel = resolveAmountLabel(
      product: product,
      activeMode: activeMode,
      selectedSizeName: selectedSizeName,
      selectedServiceAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
      selectedGramsForWeight: selectedGramsForWeight,
    );
    final normalizedSize = activeMode == GarsonActivePricingMode.size
        ? selectedSizeName?.trim() ?? ''
        : '';
    final weightGrams = activeMode == GarsonActivePricingMode.weight
        ? (product.resolvedServiceControlType ==
                  ProductServiceControlType.weightStepper
              ? (selectedWeightGrams ??
                    selectedGramsForWeight ??
                    product.resolvedDefaultWeightGrams)
              : (selectedGramsForWeight ?? selectedWeightGrams))
        : null;
    final portionAmount = activeMode == GarsonActivePricingMode.portion &&
            product.usesPortionLikeStepper
        ? selectedServiceAmount
        : null;
    final productionHeader = KitchenTicketHeaderResolver.productionHeaderLabel(
      stationName: product.stationName ?? '',
      stationCode: product.stationCode ?? '',
    );
    final stationId = product.stationId?.trim() ?? '';
    final hasProductionStation = stationId.isNotEmpty &&
        productionHeader != kKitchenGeneralStationLabel;
    final item = <String, dynamic>{
      'product_id': product.id,
      'name': product.name,
      'price': unitPrice,
      'quantity': quantity,
      'gramaj': amountLabel,
      'amount_label': amountLabel,
      'amountLabel': amountLabel,
      'pricing_mode': pricingModeStorage(activeMode),
      'selected_size_name':
          normalizedSize.isEmpty ? null : normalizedSize,
      'selectedSizeName': normalizedSize.isEmpty ? null : normalizedSize,
      'selected_size_price':
          normalizedSize.isEmpty ? null : unitPrice,
      'selectedSizePrice': normalizedSize.isEmpty ? null : unitPrice,
      'selected_grams': weightGrams,
      'selectedGrams': weightGrams,
      'service_control_type': product.resolvedServiceControlType.storageValue,
      'serviceControlType': product.resolvedServiceControlType.storageValue,
      'selected_service_amount': portionAmount,
      'selectedServiceAmount': portionAmount,
      'selected_weight_grams': weightGrams,
      'selectedWeightGrams': weightGrams,
      'line_total': unitPrice * quantity,
      'notes': notes.trim(),
      'note': notes.trim(),
      if (stationId.isNotEmpty) 'station_id': stationId,
      if (hasProductionStation) ...<String, dynamic>{
        'station_name': productionHeader,
        'kitchen_station_name': productionHeader,
      },
      if (product.stationCode != null && product.stationCode!.trim().isNotEmpty)
        'station_code': product.stationCode!.trim().toUpperCase(),
      'printer_routing_enabled': product.printerRoutingEnabled,
      'attributes': attributes,
      'unit_price_snapshot': unitPrice,
      'unitPriceSnapshot': unitPrice,
    };
    final sanitized = sanitizeOrderItemFields(item);
    if (stationId.isNotEmpty) {
      logGarsonOrderItemStationAttached(sanitized);
      garsonOrderItemLog(
        'station_attached',
        extra: {
          'productId': product.id,
          'productName': product.name,
          'stationId': stationId,
          'stationName': hasProductionStation ? productionHeader : '',
          'stationCode': product.stationCode ?? '',
          'kitchen_station_name': sanitized['kitchen_station_name'] ?? '',
          'table_area_name': sanitized['table_area_name'] ?? '',
        },
      );
    }
    final enriched = enrichOrderItem(sanitized);
    garsonProductSelectLog(
      'line_key',
      extra: {'key': orderLineMergeKey(enriched)},
    );
    garsonPrintPayloadLog(
      'item_label',
      extra: {
        'name': enriched['name'],
        'display_label': enriched['display_label'],
        'amount_label': enriched['amount_label'] ?? enriched['gramaj'],
        'pricing_mode': enriched['pricing_mode'],
      },
    );
    return enriched;
  }

  /// İş mantığına göre birleştirilebilir satırlar için anahtar.
  static String orderLineMergeKey(Map<String, dynamic> item) {
    final productId = item['product_id']?.toString().trim() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    final identity = productId.isNotEmpty ? 'id:$productId' : 'name:$name';
    final pricingMode = storagePricingModeFromItem(item);
    final size = pricingMode == 'size'
        ? item['selected_size_name']?.toString().trim().toLowerCase() ??
              item['selectedSizeName']?.toString().trim().toLowerCase() ??
              ''
        : '';
    final grams = pricingMode == 'kilo' ? _gramsFromItem(item) : 0;
    final portion = pricingMode == 'portion'
        ? (item['selected_service_amount'] as num?)?.toDouble() ??
              (item['selectedServiceAmount'] as num?)?.toDouble()
        : null;
    final portionKey = portion == null ? '' : portion.toStringAsFixed(3);
    final note = item['notes']?.toString().trim() ?? item['note']?.toString().trim() ?? '';
    final attrs =
        ((item['attributes'] as List?)?.whereType<String>().toList() ??
              <String>[])
          ..sort();
    final childFingerprint = _childItemsFingerprint(item['child_items']);
    return [
      identity,
      pricingMode,
      size,
      'g$grams',
      'p$portionKey',
      attrs.join('|'),
      note,
      childFingerprint,
    ].join('\u0000');
  }

  static String _childItemsFingerprint(dynamic raw) {
    if (raw is! List || raw.isEmpty) return '';
    final parts = <String>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      parts.add(
        '${entry['product_id']}|${entry['selected_option_label']}|${entry['quantity']}',
      );
    }
    parts.sort();
    return parts.join(';');
  }

  /// Fiş/mutfak satırı için taban ürün adı (gramaj/boyut hariç).
  static String printItemBaseName(Map<String, dynamic> item) {
    for (final key in <String>['product_name', 'productName']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return _itemBaseName(item);
  }

  /// Gramaj/boyut etiketi: `300 g`, `Tek`, `Duble`.
  static String resolvePrintItemAmountLabel(Map<String, dynamic> item) {
    for (final key in <String>[
      'amount_label',
      'amountLabel',
      'gramaj',
    ]) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return _variantLabelForItem(item);
  }

  /// Mutfak/adisyon fişi satır etiketi (öncelik: display_label → label → print_label → ad+gramaj/boyut).
  static String resolvePrintItemLabel(Map<String, dynamic> item) {
    for (final key in <String>['display_label', 'label', 'print_label']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }

    final baseName = printItemBaseName(item);
    if (baseName.isEmpty) {
      final fallback = item['product_name']?.toString().trim() ??
          item['productName']?.toString().trim() ??
          '';
      return fallback.isEmpty ? 'Urun' : fallback;
    }

    final amountLabel = resolvePrintItemAmountLabel(item);
    if (amountLabel.isNotEmpty) {
      if (_nameAlreadyIncludesVariant(baseName, amountLabel)) {
        return baseName;
      }
      return '$baseName $amountLabel';
    }

    return baseName;
  }

  /// Log için pricing_mode: depoda `kilo` → `weight`.
  static String pricingModeForPrintLog(Map<String, dynamic> item) {
    final mode = strictPricingModeFromItem(item);
    if (mode == 'kilo') return 'weight';
    return mode;
  }

  static void logGarsonPrintItemLabel({
    required String path,
    required Map<String, dynamic> item,
    String? finalPrintName,
  }) {
    if (!kDebugMode) return;
    final resolved = finalPrintName ?? resolvePrintItemLabel(item);
    final payload = <String, Object?>{
      'path': path,
      'rawName': printItemBaseName(item),
      'displayLabel': item['display_label'] ?? '',
      'amountLabel': resolvePrintItemAmountLabel(item),
      'selectedGrams': _gramsFromItem(item),
      'selectedWeightGrams':
          item['selected_weight_grams'] ?? item['selectedWeightGrams'] ?? 0,
      'selectedSizeName':
          item['selected_size_name'] ?? item['selectedSizeName'] ?? '',
      'pricingMode': pricingModeForPrintLog(item),
      'finalPrintName': resolved,
    };
    debugPrint('[GarsonPrintPayload][item_label] ${jsonEncode(payload)}');
  }

  static bool _nameAlreadyIncludesVariant(String baseName, String variant) {
    if (variant.isEmpty) return true;
    final lower = baseName.toLowerCase().trim();
    final vLower = variant.toLowerCase().trim();
    return lower == vLower ||
        lower.endsWith(' $vLower') ||
        lower.endsWith(vLower);
  }

  /// Ürün adı + boyut/gramaj (adet yok): `Ciğer Servis 200 g`
  static String orderItemTitleLabel(Map<String, dynamic> item) {
    final name = _itemBaseName(item);
    if (name.isEmpty) return '';
    final variant = _variantLabelForItem(item);
    if (variant.isEmpty) return name;
    return '$name $variant';
  }

  /// Mutfak/adisyon satır etiketi: `2x Ciğer Şiş Duble`, `1x Ciğer Şiş 500 g`
  static String orderItemDisplayLabel(Map<String, dynamic> item) {
    final name = _itemBaseName(item);
    if (name.isEmpty) return '';
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    final variant = _variantLabelForItem(item);
    final buffer = StringBuffer('$qty x $name');
    if (variant.isNotEmpty) {
      buffer.write(' $variant');
    }
    return buffer.toString().trim();
  }

  static String _itemBaseName(Map<String, dynamic> item) {
    return item['name']?.toString().trim() ??
        item['item_name']?.toString().trim() ??
        '';
  }

  static String _variantLabelForItem(Map<String, dynamic> item) {
    final pricingMode = strictPricingModeFromItem(item);
    if (pricingMode == 'size') {
      final size =
          item['selected_size_name']?.toString().trim() ??
          item['selectedSizeName']?.toString().trim() ??
          '';
      if (size.isNotEmpty) return size;
    }

    if (pricingMode == 'kilo') {
      final grams = _gramsFromItem(item);
      if (grams > 0) {
        return ProductPriceCalculator.formatWeight(grams);
      }
      for (final candidate in <String?>[
        item['amount_label']?.toString(),
        item['amountLabel']?.toString(),
        item['gramaj']?.toString(),
      ]) {
        final normalized = candidate?.trim() ?? '';
        if (normalized.isNotEmpty && _looksLikeGramajOnly(normalized)) {
          return normalized;
        }
      }
    }

    if (pricingMode == 'portion') {
      final serviceType = ProductServiceControlType.fromValue(
        item['service_control_type'] ?? item['serviceControlType'],
      );
      final portion = (item['selected_service_amount'] as num?)?.toDouble() ??
          (item['selectedServiceAmount'] as num?)?.toDouble();
      if (serviceType != ProductServiceControlType.none) {
        return ProductPriceCalculator.formatServiceAmountLabel(
          type: serviceType,
          amount: portion,
        );
      }
      if ((portion ?? 0) > 0) {
        return ProductPriceCalculator.formatPortionLabel(portion!);
      }
    }
    return '';
  }

  /// Özellik/not satırı — fiş alt satırı (display_label'a eklenmez).
  static String orderItemFeatureNoteLine(Map<String, dynamic> item) {
    final notes = item['notes']?.toString().trim() ?? item['note']?.toString().trim() ?? '';
    final attrs =
        ((item['attributes'] as List?)?.whereType<String>().toList() ??
              <String>[])
          ..sort();
    final parts = <String>[
      if (notes.isNotEmpty) notes,
      ...attrs,
    ];
    if (parts.isEmpty) return '';
    return 'Not: ${parts.join(', ')}';
  }

  static bool _looksLikeGramajOnly(String value) {
    final lower = value.toLowerCase();
    return lower.contains('g') || lower.contains('kg');
  }

  static Map<String, dynamic> enrichOrderItem(Map<String, dynamic> item) {
    if (!isGarsonPricingMode(item['pricing_mode']?.toString())) {
      return Map<String, dynamic>.from(item);
    }
    final enriched = Map<String, dynamic>.from(sanitizeOrderItemFields(item));
    _syncGramFields(enriched);
    final mode = strictPricingModeFromItem(enriched);
    if (mode == 'kilo') {
      final grams = _gramsFromItem(enriched);
      if (grams > 0) {
        enriched['selected_grams'] = grams;
        enriched['selectedGrams'] = grams;
        enriched['selected_weight_grams'] = grams;
        enriched['selectedWeightGrams'] = grams;
      }
    }
    final title = orderItemTitleLabel(enriched);
    if (title.isNotEmpty) {
      enriched['display_label'] = title;
    }
    final amount = _variantLabelForItem(enriched);
    if (amount.isNotEmpty) {
      enriched['amount_label'] = amount;
      enriched['amountLabel'] = amount;
      enriched['gramaj'] = amount;
    } else if (mode == 'portion') {
      enriched['gramaj'] = '';
      enriched['amount_label'] = '';
      enriched['amountLabel'] = '';
    }
    return enriched;
  }

  static void _syncGramFields(Map<String, dynamic> item) {
    final grams = _gramsFromItem(item);
    if (grams <= 0) return;
    item['selected_grams'] ??= grams;
    item['selectedGrams'] ??= grams;
    item['selected_weight_grams'] ??= grams;
    item['selectedWeightGrams'] ??= grams;
  }
}
