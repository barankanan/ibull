import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

class ResolvedWeightGramSettings {
  const ResolvedWeightGramSettings({
    required this.minGrams,
    required this.defaultGrams,
    required this.stepGrams,
    required this.source,
    this.maxGrams,
  });

  final int minGrams;
  final int defaultGrams;
  final int stepGrams;
  final int? maxGrams;
  final String source;
}

enum ProductPricingType {
  portion,
  weight;

  static ProductPricingType fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'kg':
      case 'weight':
        return ProductPricingType.weight;
      case 'portion':
      default:
        return ProductPricingType.portion;
    }
  }

  String get storageValue => name;

  String get sellerLabelTr {
    switch (this) {
      case ProductPricingType.weight:
        return 'Kiloluk';
      case ProductPricingType.portion:
        return 'Porsiyonlu';
    }
  }
}

enum ProductServiceControlType {
  none,
  portionStepper,
  skewerStepper,
  weightStepper;

  static ProductServiceControlType fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'portion_stepper':
        return ProductServiceControlType.portionStepper;
      case 'skewer_stepper':
        return ProductServiceControlType.skewerStepper;
      case 'weight_stepper':
        return ProductServiceControlType.weightStepper;
      default:
        return ProductServiceControlType.none;
    }
  }

  String get storageValue {
    switch (this) {
      case ProductServiceControlType.portionStepper:
        return 'portion_stepper';
      case ProductServiceControlType.skewerStepper:
        return 'skewer_stepper';
      case ProductServiceControlType.weightStepper:
        return 'weight_stepper';
      case ProductServiceControlType.none:
        return 'none';
    }
  }

  String get sellerLabelTr {
    switch (this) {
      case ProductServiceControlType.portionStepper:
        return 'Porsiyon Stepper';
      case ProductServiceControlType.skewerStepper:
        return 'Sis Stepper';
      case ProductServiceControlType.weightStepper:
        return 'Kilo Stepper';
      case ProductServiceControlType.none:
        return 'Standart';
    }
  }

  String get shortLabelTr {
    switch (this) {
      case ProductServiceControlType.portionStepper:
        return 'Porsiyon';
      case ProductServiceControlType.skewerStepper:
        return 'Sis';
      case ProductServiceControlType.weightStepper:
        return 'Kilo';
      case ProductServiceControlType.none:
        return 'Standart';
    }
  }
}

enum ProductPricingMode {
  baseOnly,
  weightOnly,
  sizeOnly,
  hybrid;

  static ProductPricingMode fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'weight_only':
      case 'weight':
        return ProductPricingMode.weightOnly;
      case 'size_only':
      case 'size':
        return ProductPricingMode.sizeOnly;
      case 'hybrid':
        return ProductPricingMode.hybrid;
      case 'base_only':
      case 'base':
      default:
        return ProductPricingMode.baseOnly;
    }
  }

  String get storageValue {
    switch (this) {
      case ProductPricingMode.weightOnly:
        return 'weight_only';
      case ProductPricingMode.sizeOnly:
        return 'size_only';
      case ProductPricingMode.hybrid:
        return 'hybrid';
      case ProductPricingMode.baseOnly:
        return 'base_only';
    }
  }
}

class ProductSizeOption {
  const ProductSizeOption({
    required this.id,
    required this.name,
    required this.price,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final double price;
  final bool isDefault;
  final int sortOrder;

  ProductSizeOption copyWith({
    String? id,
    String? name,
    double? price,
    bool? isDefault,
    int? sortOrder,
  }) {
    return ProductSizeOption(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'is_default': isDefault,
      'sort_order': sortOrder,
    };
  }

  factory ProductSizeOption.fromJson(Map<String, dynamic> json) {
    final rawName =
        json['name']?.toString() ?? json['size_name']?.toString() ?? '';
    final trimmedName = rawName.trim();
    final sortOrder =
        (json['sort_order'] as num?)?.toInt() ??
        (json['sortOrder'] as num?)?.toInt() ??
        0;
    final idCandidate =
        json['id']?.toString().trim() ?? json['size_id']?.toString().trim();
    return ProductSizeOption(
      id: (idCandidate ?? '').isNotEmpty
          ? idCandidate!
          : _fallbackId(trimmedName, sortOrder),
      name: trimmedName,
      price:
          (json['price'] as num?)?.toDouble() ??
          (json['size_price'] as num?)?.toDouble() ??
          0,
      isDefault:
          json['is_default'] == true ||
          json['isDefault'] == true ||
          json['default'] == true,
      sortOrder: sortOrder,
    );
  }

  static List<ProductSizeOption> listFromDynamic(dynamic raw) {
    if (raw == null) return const <ProductSizeOption>[];
    if (raw is List) {
      return raw
          .whereType<Object>()
          .map((entry) {
            if (entry is ProductSizeOption) return entry;
            if (entry is Map<String, dynamic>) {
              return ProductSizeOption.fromJson(entry);
            }
            if (entry is Map) {
              return ProductSizeOption.fromJson(
                Map<String, dynamic>.from(entry),
              );
            }
            return null;
          })
          .whereType<ProductSizeOption>()
          .toList(growable: false);
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <ProductSizeOption>[];
      try {
        final decoded = jsonDecode(trimmed);
        return listFromDynamic(decoded);
      } catch (_) {
        return const <ProductSizeOption>[];
      }
    }
    return const <ProductSizeOption>[];
  }

  static String _fallbackId(String name, int sortOrder) {
    final normalized = name.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final safeName = normalized.isEmpty ? 'size' : normalized;
    return '${safeName}_$sortOrder';
  }
}

class ProductPriceCalculator {
  const ProductPriceCalculator._();

  static const double defaultMinPortion = 0.5;
  static const double defaultMaxPortion = 2.0;
  static const double defaultPortionStep = 0.5;
  static const double defaultMinSkewer = 1.0;
  static const double defaultMaxSkewer = 3.0;
  static const double defaultSkewerStep = 1.0;
  static const int defaultMinWeightGrams = 500;
  static const int defaultWeightStepGrams = 250;
  static const int defaultWeightSelectionGrams = 500;

  /// Ürün kaydında en az bir gramaj alanı doluysa global fallback kullanılmaz.
  static bool hasConfiguredWeightGramSettings({
    int? minWeightGrams,
    int? defaultWeightGrams,
    int? weightStepGrams,
  }) {
    return (minWeightGrams ?? 0) > 0 ||
        (defaultWeightGrams ?? 0) > 0 ||
        (weightStepGrams ?? 0) > 0;
  }

  /// Tek kaynak: DB/spec alanları → clamp; yoksa global fallback.
  static ResolvedWeightGramSettings resolveWeightGramSettings({
    int? minWeightGrams,
    int? defaultWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
  }) {
    final configured = hasConfiguredWeightGramSettings(
      minWeightGrams: minWeightGrams,
      defaultWeightGrams: defaultWeightGrams,
      weightStepGrams: weightStepGrams,
    );
    if (!configured) {
      final min = defaultMinWeightGrams;
      final step = defaultWeightStepGrams;
      final max = resolveMaxWeightGrams(maxWeightGrams);
      final defaultGrams = clampWeightSelection(
        defaultWeightSelectionGrams,
        minWeightGrams: min,
        weightStepGrams: step,
        maxWeightGrams: max,
      );
      return ResolvedWeightGramSettings(
        minGrams: min,
        defaultGrams: defaultGrams,
        stepGrams: step,
        maxGrams: max,
        source: 'fallback',
      );
    }

    final step = (weightStepGrams ?? 0) > 0
        ? weightStepGrams!
        : defaultWeightStepGrams;
    final min = (minWeightGrams ?? 0) > 0
        ? minWeightGrams!
        : ((defaultWeightGrams ?? 0) > 0 ? defaultWeightGrams! : defaultMinWeightGrams);
    final max = resolveMaxWeightGrams(maxWeightGrams);
    final defaultTarget = (defaultWeightGrams ?? 0) > 0
        ? defaultWeightGrams!
        : min;
    final defaultGrams = clampWeightSelection(
      defaultTarget,
      minWeightGrams: min,
      weightStepGrams: step,
      maxWeightGrams: max,
    );
    return ResolvedWeightGramSettings(
      minGrams: min,
      defaultGrams: defaultGrams,
      stepGrams: step,
      maxGrams: max,
      source: 'product',
    );
  }

  static void productParseWeightLog({
    required String productId,
    required ResolvedWeightGramSettings settings,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ProductParse] weight_settings_resolved '
      'productId=$productId '
      'minGrams=${settings.minGrams} '
      'defaultGrams=${settings.defaultGrams} '
      'stepGrams=${settings.stepGrams} '
      'maxGrams=${settings.maxGrams ?? ''} '
      'source=${settings.source}',
    );
  }

  static void productSaveWeightLog({
    int? minGrams,
    int? defaultGrams,
    int? stepGrams,
    int? maxGrams,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[ProductSave] weight_settings_payload '
      'minGrams=${minGrams ?? ''} '
      'defaultGrams=${defaultGrams ?? ''} '
      'stepGrams=${stepGrams ?? ''} '
      'maxGrams=${maxGrams ?? ''}',
    );
  }

  static bool supportsWeightPricing({
    required ProductPricingType pricingType,
    required double? pricePerKg,
  }) {
    return pricingType == ProductPricingType.weight && (pricePerKg ?? 0) > 0;
  }

  /// Garson / hibrit ürünler: kilo fiyatı veya kayıtlı gramaj + kilo fiyatı.
  /// Yalnızca global fallback gramaj (500 g) tek başına yeterli değildir.
  static bool supportsWeightSelection({
    required double? pricePerKg,
    ProductPricingType? pricingType,
    ProductPricingMode? pricingMode,
    int? minWeightGrams,
    int? defaultWeightGrams,
    int? weightStepGrams,
  }) {
    final kg = sanitizePrice(pricePerKg);
    if (kg > 0) return true;

    final hasWeightConfig = hasConfiguredWeightGramSettings(
      minWeightGrams: minWeightGrams,
      defaultWeightGrams: defaultWeightGrams,
      weightStepGrams: weightStepGrams,
    );
    if (!hasWeightConfig) return false;

    final mode = pricingMode ?? ProductPricingMode.baseOnly;
    final type = pricingType ?? ProductPricingType.portion;
    return mode == ProductPricingMode.hybrid ||
        mode == ProductPricingMode.weightOnly ||
        type == ProductPricingType.weight;
  }

  static double? _readNumericField(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final raw = source[key];
      if (raw == null) continue;
      final parsed = raw is num
          ? raw.toDouble()
          : parsePriceValue(raw);
      if (sanitizePrice(parsed) > 0) return parsed;
    }
    return null;
  }

  /// Tek kaynak: DB / map / specifications içinden kilo fiyatı.
  static double resolvePricePerKgFromMap(
    Map<String, dynamic> map, {
    String? pricingType,
  }) {
    final direct = _readNumericField(map, <String>[
      'price_per_kg',
      'pricePerKg',
      'kg_price',
      'kgPrice',
      'weight_price',
      'weightPrice',
    ]);
    if (direct != null) return sanitizePrice(direct);

    final specsRaw = map['specifications'] ?? map['pricing_metadata'];
    if (specsRaw != null) {
      Map<String, dynamic>? specsMap;
      if (specsRaw is Map) {
        specsMap = Map<String, dynamic>.from(specsRaw);
      } else if (specsRaw is String && specsRaw.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(specsRaw.trim());
          if (decoded is Map) {
            specsMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }
      if (specsMap != null) {
        final nestedPricing = specsMap['pricing'];
        if (nestedPricing is Map) {
          specsMap = Map<String, dynamic>.from(nestedPricing);
        }
        final fromSpecs = _readNumericField(specsMap, <String>[
          'price_per_kg',
          'pricePerKg',
          'kg_price',
          'kgPrice',
          'weight_price',
          'weightPrice',
        ]);
        if (fromSpecs != null) return sanitizePrice(fromSpecs);
      }
    }

    final resolvedType = ProductPricingType.fromValue(
      pricingType ??
          map['pricing_type']?.toString() ??
          map['pricingType']?.toString(),
    );
    if (resolvedType == ProductPricingType.weight) {
      return sanitizePrice(parsePriceValue(map['price']));
    }
    return 0;
  }

  static double sanitizePrice(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0) {
      return 0;
    }
    return value;
  }

  static double sanitizeAmount(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return 0;
    }
    return value;
  }

  static ProductPricingMode resolvePricingMode({
    Object? explicitMode,
    double? basePrice,
    double? pricePerKg,
    List<ProductSizeOption> sizeOptions = const <ProductSizeOption>[],
  }) {
    final normalizedExplicit = explicitMode?.toString().trim();
    if ((normalizedExplicit ?? '').isNotEmpty) {
      return ProductPricingMode.fromValue(normalizedExplicit);
    }
    final hasBase = sanitizePrice(basePrice) > 0;
    final hasWeight = sanitizePrice(pricePerKg) > 0;
    final hasSizes = normalizeSizeOptions(sizeOptions).isNotEmpty;
    final enabledCount = [hasBase, hasWeight, hasSizes]
        .where((value) => value)
        .length;
    if (enabledCount > 1) return ProductPricingMode.hybrid;
    if (hasSizes) return ProductPricingMode.sizeOnly;
    if (hasWeight) return ProductPricingMode.weightOnly;
    return ProductPricingMode.baseOnly;
  }

  static List<ProductSizeOption> _sanitizeSizeOptionList(
    Iterable<ProductSizeOption> raw,
  ) {
    return raw
        .map(
          (entry) => entry.copyWith(
            name: entry.name.trim(),
            price: sanitizePrice(entry.price),
          ),
        )
        .where((entry) => entry.name.isNotEmpty && entry.price > 0)
        .toList(growable: false)
      ..sort((left, right) {
        final sortCompare = left.sortOrder.compareTo(right.sortOrder);
        if (sortCompare != 0) return sortCompare;
        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });
  }

  static List<ProductSizeOption> normalizeSizeOptions(
    Iterable<ProductSizeOption> raw,
  ) {
    // Sıralama/filtreleme yapılır; is_default otomatik atanmaz (yalnızca ürün datası).
    return _sanitizeSizeOptionList(raw);
  }

  static final RegExp _nonStandardSizePattern = RegExp(
    r'yarım|yarim|half|duble|double|xl|xxl|büyük|buyuk|large|küçük|kucuk|small|mini',
    caseSensitive: false,
  );

  /// Yarım/duble vb. — standart boyut tercihinde kullanılmaz.
  static bool isNonStandardSizeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    return _nonStandardSizePattern.hasMatch(trimmed);
  }

  static final RegExp _garsonRejectedDefaultSizePattern = RegExp(
    r'yarım|yarim|\bhalf\b',
    caseSensitive: false,
  );

  /// Garson modal: is_default olsa bile otomatik seçilmeyecek boyutlar (yarım porsiyon).
  static bool isGarsonRejectedDefaultSizeName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    return _garsonRejectedDefaultSizePattern.hasMatch(trimmed);
  }

  static final List<String> _standardSizeNameHints = <String>[
    'standart',
    'standard',
    'normal',
    '1 porsiyon',
    'tek porsiyon',
    'tam',
    'full',
    'regular',
    'tek',
  ];

  /// Boyut listesinde "standart" isimli seçeneği döndürür (yarım/duble değil).
  static ProductSizeOption? preferredStandardSizeOption(
    List<ProductSizeOption> sizeOptions,
  ) {
    final normalized = _sanitizeSizeOptionList(sizeOptions);
    if (normalized.isEmpty) return null;
    for (final hint in _standardSizeNameHints) {
      for (final option in normalized) {
        final name = option.name.trim().toLowerCase();
        if (name.contains(hint) && !_nonStandardSizePattern.hasMatch(name)) {
          return option;
        }
      }
    }
    for (final option in normalized) {
      if (!_nonStandardSizePattern.hasMatch(option.name)) {
        return option;
      }
    }
    return null;
  }

  /// Yalnızca ürün oluştururken işaretlenmiş varsayılan boyut.
  static ProductSizeOption? explicitDefaultSizeOption(
    List<ProductSizeOption> sizeOptions,
  ) {
    final normalized = sizeOptions
        .map(
          (entry) => entry.copyWith(
            name: entry.name.trim(),
            price: sanitizePrice(entry.price),
          ),
        )
        .where((entry) => entry.name.isNotEmpty && entry.price > 0)
        .toList(growable: false);
    final flagged = normalized
        .where(
          (entry) =>
              entry.isDefault && !isGarsonRejectedDefaultSizeName(entry.name),
        )
        .toList();
    if (flagged.length == 1) return flagged.first;
    if (flagged.length > 1) {
      return preferredStandardSizeOption(flagged);
    }
    return null;
  }

  static ProductSizeOption? defaultSizeOption(
    List<ProductSizeOption> sizeOptions,
  ) {
    return explicitDefaultSizeOption(sizeOptions);
  }

  static ProductSizeOption? findSizeOption({
    required List<ProductSizeOption> sizeOptions,
    String? selectedSizeName,
    double? selectedSizePrice,
    bool preferDefault = false,
  }) {
    final normalized = normalizeSizeOptions(sizeOptions);
    if (normalized.isEmpty) return null;
    final safeName = selectedSizeName?.trim().toLowerCase() ?? '';
    if (safeName.isNotEmpty) {
      for (final option in normalized) {
        if (option.name.trim().toLowerCase() == safeName) {
          return option;
        }
      }
    }
    final safePrice = sanitizePrice(selectedSizePrice);
    if (safePrice > 0) {
      for (final option in normalized) {
        if ((option.price - safePrice).abs() < 0.001) {
          return option;
        }
      }
    }
    if (!preferDefault) return null;
    return defaultSizeOption(normalized);
  }

  static List<String> validateSizeOptions(List<ProductSizeOption> sizeOptions) {
    final normalized = normalizeSizeOptions(sizeOptions);
    if (normalized.isEmpty) return const <String>[];
    final errors = <String>[];
    final seenNames = <String>{};
    var defaultCount = 0;
    for (final option in normalized) {
      final normalizedName = option.name.trim().toLowerCase();
      if (!seenNames.add(normalizedName)) {
        errors.add('Ayni boyut adi birden fazla kez kullanilamaz.');
        break;
      }
      if (option.isDefault) defaultCount++;
      if (option.sortOrder < 0) {
        errors.add('Boyut sirasi negatif olamaz.');
        break;
      }
    }
    if (defaultCount > 1) {
      errors.add('Sadece bir varsayilan boyut secilebilir.');
    }
    return errors;
  }

  static bool usesServiceControlStepper(ProductServiceControlType type) {
    return type != ProductServiceControlType.none;
  }

  static bool usesPortionLikeStepper(ProductServiceControlType type) {
    return type == ProductServiceControlType.portionStepper ||
        type == ProductServiceControlType.skewerStepper;
  }

  static double resolveMinPortionAmount(
    ProductServiceControlType type,
    double? value,
  ) {
    final safeValue = sanitizeAmount(value);
    switch (type) {
      case ProductServiceControlType.skewerStepper:
        if (safeValue > 0) {
          return safeValue.roundToDouble().clamp(1, double.infinity);
        }
        return defaultMinSkewer;
      case ProductServiceControlType.portionStepper:
        return safeValue > 0 ? safeValue : defaultMinPortion;
      case ProductServiceControlType.weightStepper:
      case ProductServiceControlType.none:
        return safeValue;
    }
  }

  static double resolveMaxPortionAmount(
    ProductServiceControlType type,
    double? value, {
    double? minPortion,
  }) {
    final safeValue = sanitizeAmount(value);
    switch (type) {
      case ProductServiceControlType.skewerStepper:
        if (safeValue > 0) {
          final min = resolveMinPortionAmount(type, minPortion);
          return safeValue.roundToDouble() < min
              ? min
              : safeValue.roundToDouble();
        }
        return defaultMaxSkewer;
      case ProductServiceControlType.portionStepper:
        if (safeValue > 0) {
          final min = resolveMinPortionAmount(type, minPortion);
          return safeValue < min ? min : safeValue;
        }
        return defaultMaxPortion;
      case ProductServiceControlType.weightStepper:
      case ProductServiceControlType.none:
        return safeValue;
    }
  }

  static double resolvePortionStepAmount(
    ProductServiceControlType type,
    double? value,
  ) {
    final safeValue = sanitizeAmount(value);
    switch (type) {
      case ProductServiceControlType.skewerStepper:
        if (safeValue > 0) {
          return safeValue.roundToDouble().clamp(1, double.infinity);
        }
        return defaultSkewerStep;
      case ProductServiceControlType.portionStepper:
        return safeValue > 0 ? safeValue : defaultPortionStep;
      case ProductServiceControlType.weightStepper:
      case ProductServiceControlType.none:
        return safeValue;
    }
  }

  static double resolveDefaultServiceAmount({
    required ProductServiceControlType type,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
  }) {
    if (!usesPortionLikeStepper(type)) return 0;
    final min = resolveMinPortionAmount(type, minPortion);
    final target = type == ProductServiceControlType.portionStepper
        ? (min < 1 ? 1.0 : min)
        : min;
    return clampPortionSelection(
      target,
      type: type,
      minPortion: minPortion,
      maxPortion: maxPortion,
      portionStep: portionStep,
    );
  }

  static double clampPortionSelection(
    double amount, {
    required ProductServiceControlType type,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
  }) {
    if (!usesPortionLikeStepper(type)) return sanitizeAmount(amount);
    final min = resolveMinPortionAmount(type, minPortion);
    final step = resolvePortionStepAmount(type, portionStep);
    final max = resolveMaxPortionAmount(type, maxPortion, minPortion: min);
    var sanitized = sanitizeAmount(amount);
    if (sanitized <= 0) sanitized = min;
    if (sanitized < min) sanitized = min;
    if (sanitized > max) sanitized = max;

    final offset = sanitized - min;
    final snapped = min + ((offset / step).round() * step);
    var resolved = snapped < min ? min : snapped;
    if (resolved > max) {
      final diff = max - min;
      resolved = min + ((diff / step).floor() * step);
      if (resolved < min) {
        resolved = max;
      }
    }

    if (type == ProductServiceControlType.skewerStepper) {
      return resolved.roundToDouble();
    }
    return double.parse(resolved.toStringAsFixed(2));
  }

  static List<double> buildPresetPortionOptions({
    required ProductServiceControlType type,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
  }) {
    if (!usesPortionLikeStepper(type)) return const <double>[];
    final min = resolveMinPortionAmount(type, minPortion);
    final step = resolvePortionStepAmount(type, portionStep);
    final max = resolveMaxPortionAmount(type, maxPortion, minPortion: min);
    final options = <double>{min, max};
    for (var value = min; value <= max + 0.0001; value += step) {
      options.add(
        clampPortionSelection(
          value,
          type: type,
          minPortion: min,
          maxPortion: max,
          portionStep: step,
        ),
      );
      if (options.length >= 8) break;
    }
    final sorted = options.toList(growable: false)..sort();
    return sorted;
  }

  static List<String> validatePortionConfiguration({
    required ProductServiceControlType type,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
  }) {
    if (!usesPortionLikeStepper(type)) return const <String>[];
    final errors = <String>[];
    final min = resolveMinPortionAmount(type, minPortion);
    final step = resolvePortionStepAmount(type, portionStep);
    final max = resolveMaxPortionAmount(type, maxPortion, minPortion: min);

    if (min <= 0) {
      errors.add('Minimum secim 0\'dan buyuk olmali.');
    }
    if (step <= 0) {
      errors.add('Artis adimi 0 olamaz.');
      return errors;
    }
    if (max < min) {
      errors.add('Maksimum secim minimumdan kucuk olamaz.');
    }

    final diff = (max - min) / step;
    if ((diff - diff.round()).abs() > 0.0001) {
      errors.add('Maksimum deger artis adimina uygun olmali.');
    }

    if (type == ProductServiceControlType.skewerStepper) {
      final values = <double>[min, max, step];
      final allWhole = values.every(
        (value) => (value - value.roundToDouble()).abs() < 0.0001,
      );
      if (!allWhole) {
        errors.add('Sis seciminde min, max ve artis tam sayi olmali.');
      }
    }

    return errors;
  }

  static int resolveMinWeightGrams(int? value) {
    return value != null && value > 0 ? value : defaultMinWeightGrams;
  }

  static int resolveWeightStepGrams(int? value) {
    return value != null && value > 0 ? value : defaultWeightStepGrams;
  }

  static int? resolveMaxWeightGrams(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static int resolveDefaultWeightGrams({
    int? defaultWeightGrams,
    int? minWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
  }) {
    final min = resolveMinWeightGrams(minWeightGrams);
    final step = resolveWeightStepGrams(weightStepGrams);
    final max = resolveMaxWeightGrams(maxWeightGrams);
    final target = defaultWeightGrams != null && defaultWeightGrams > 0
        ? defaultWeightGrams
        : defaultWeightSelectionGrams;
    return clampWeightSelection(
      target,
      minWeightGrams: min,
      weightStepGrams: step,
      maxWeightGrams: max,
    );
  }

  static int clampWeightSelection(
    int grams, {
    int? minWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
  }) {
    final min = resolveMinWeightGrams(minWeightGrams);
    final step = resolveWeightStepGrams(weightStepGrams);
    final max = resolveMaxWeightGrams(maxWeightGrams);
    var sanitized = grams <= 0 ? min : grams;
    if (sanitized < min) sanitized = min;
    if (max != null && sanitized > max) sanitized = max;

    final offset = sanitized - min;
    final snapped = min + ((offset / step).round() * step);
    var resolved = snapped < min ? min : snapped;
    if (max != null && resolved > max) {
      final diff = max - min;
      resolved = min + ((diff / step).floor() * step);
      if (resolved < min) {
        resolved = max;
      }
    }
    return resolved;
  }

  static List<int> buildPresetWeightOptions({
    int? minWeightGrams,
    int? defaultWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
  }) {
    final min = resolveMinWeightGrams(minWeightGrams);
    final step = resolveWeightStepGrams(weightStepGrams);
    final max =
        resolveMaxWeightGrams(maxWeightGrams) ??
        _autoMaxWeightGrams(
          defaultWeightGrams: defaultWeightGrams,
          minWeightGrams: min,
          weightStepGrams: step,
        );
    final defaultWeight = resolveDefaultWeightGrams(
      defaultWeightGrams: defaultWeightGrams,
      minWeightGrams: min,
      weightStepGrams: step,
      maxWeightGrams: max,
    );

    final options = <int>{min, defaultWeight, max};

    if (!hasConfiguredWeightGramSettings(
      minWeightGrams: minWeightGrams,
      defaultWeightGrams: defaultWeightGrams,
      weightStepGrams: weightStepGrams,
    )) {
      for (final common in const [250, 500, 750, 1000]) {
        if (common < min || common > max) continue;
        if ((common - min) % step == 0) {
          options.add(common);
        }
      }
    }

    for (var value = min; value <= max && options.length < 7; value += step) {
      options.add(value);
    }

    final sorted = options.where((value) => value > 0).toList()..sort();
    return sorted;
  }

  static List<String> validateWeightConfiguration({
    int? minWeightGrams,
    int? defaultWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
  }) {
    final errors = <String>[];
    final min = minWeightGrams ?? defaultMinWeightGrams;
    final step = weightStepGrams ?? defaultWeightStepGrams;
    final defaultWeight = defaultWeightGrams ?? defaultWeightSelectionGrams;
    final max = maxWeightGrams;

    if (min <= 0) {
      errors.add('Minimum gramaj 0\'dan büyük olmalı.');
    }
    if (step <= 0) {
      errors.add('Gramaj artış adımı 0 olamaz.');
      return errors;
    }
    final safeMin = min > 0 ? min : defaultMinWeightGrams;
    if (defaultWeight < safeMin) {
      errors.add('Varsayılan gramaj minimum gramajdan küçük olamaz.');
    }
    if ((defaultWeight - safeMin) % step != 0) {
      errors.add('Varsayılan gramaj artış adımına uygun olmalı.');
    }
    if (max != null && max > 0) {
      if (max < safeMin) {
        errors.add('Maksimum gramaj minimum gramajdan küçük olamaz.');
      }
      if ((max - safeMin) % step != 0) {
        errors.add('Maksimum gramaj artış adımına uygun olmalı.');
      }
      if (defaultWeight > max) {
        errors.add('Varsayılan gramaj maksimum gramajı aşamaz.');
      }
    }
    return errors;
  }

  static double calculateWeightPrice({
    required int selectedGrams,
    required double pricePerKg,
  }) {
    final safePricePerKg = sanitizePrice(pricePerKg);
    if (selectedGrams <= 0 || safePricePerKg <= 0) return 0;
    return (selectedGrams / 1000) * safePricePerKg;
  }

  static double resolveUnitPrice({
    required ProductPricingType pricingType,
    double? portionPrice,
    double? pricePerKg,
    int? selectedWeightGrams,
    double? fallbackPrice,
  }) {
    if (pricingType == ProductPricingType.weight &&
        supportsWeightPricing(
          pricingType: pricingType,
          pricePerKg: pricePerKg,
        )) {
      final grams = selectedWeightGrams != null && selectedWeightGrams > 0
          ? selectedWeightGrams
          : resolveDefaultWeightGrams();
      return calculateWeightPrice(
        selectedGrams: grams,
        pricePerKg: pricePerKg!,
      );
    }

    final directPortion = sanitizePrice(portionPrice);
    if (directPortion > 0) return directPortion;
    return sanitizePrice(fallbackPrice);
  }

  static double resolveServiceControlledUnitPrice({
    required ProductServiceControlType serviceControlType,
    required ProductPricingType pricingType,
    ProductPricingMode? pricingMode,
    double? basePrice,
    double? portionPrice,
    double? pricePerKg,
    List<ProductSizeOption> sizeOptions = const <ProductSizeOption>[],
    String? selectedSizeName,
    double? selectedSizePrice,
    double? fallbackPrice,
    double? selectedAmount,
    int? selectedWeightGrams,
  }) {
    final selectedSize = findSizeOption(
      sizeOptions: sizeOptions,
      selectedSizeName: selectedSizeName,
      selectedSizePrice: selectedSizePrice,
    );
    if (selectedSize != null) {
      return sanitizePrice(selectedSize.price);
    }

    if (serviceControlType == ProductServiceControlType.weightStepper) {
      final grams = selectedWeightGrams ?? selectedAmount?.round();
      return resolveUnitPrice(
        pricingType: ProductPricingType.weight,
        portionPrice: portionPrice,
        pricePerKg: pricePerKg,
        selectedWeightGrams: grams,
        fallbackPrice: fallbackPrice,
      );
    }

    if (usesPortionLikeStepper(serviceControlType)) {
      final baseUnitPrice = sanitizePrice(basePrice ?? portionPrice);
      final fallbackUnitPrice = sanitizePrice(fallbackPrice);
      final selected = sanitizeAmount(selectedAmount);
      final amount = selected > 0
          ? selected
          : resolveDefaultServiceAmount(type: serviceControlType);
      final unit = baseUnitPrice > 0 ? baseUnitPrice : fallbackUnitPrice;
      return unit * amount;
    }

    if (selectedWeightGrams != null &&
        selectedWeightGrams > 0 &&
        sanitizePrice(pricePerKg) > 0) {
      return calculateWeightPrice(
        selectedGrams: selectedWeightGrams,
        pricePerKg: pricePerKg!,
      );
    }

    final resolvedMode = resolvePricingMode(
      explicitMode: pricingMode?.storageValue,
      basePrice: basePrice ?? portionPrice,
      pricePerKg: pricePerKg,
      sizeOptions: sizeOptions,
    );
    if (resolvedMode == ProductPricingMode.sizeOnly) {
      final defaultSize = defaultSizeOption(sizeOptions);
      if (defaultSize != null) return sanitizePrice(defaultSize.price);
    }

    return resolveUnitPrice(
      pricingType: pricingType,
      portionPrice: basePrice ?? portionPrice,
      pricePerKg: pricePerKg,
      selectedWeightGrams: selectedWeightGrams,
      fallbackPrice: fallbackPrice,
    );
  }

  static String formatNumericAmount(double value) {
    final safeValue = sanitizeAmount(value);
    final rounded = safeValue.roundToDouble();
    if ((safeValue - rounded).abs() < 0.0001) {
      return rounded.toStringAsFixed(0);
    }
    return safeValue.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  static String formatPortionLabel(double amount) {
    final normalized = sanitizeAmount(amount);
    if ((normalized - 0.5).abs() < 0.0001) {
      return 'Yarım Porsiyon';
    }
    return '${formatNumericAmount(normalized)} Porsiyon';
  }

  static String formatSkewerLabel(double amount) {
    final normalized = sanitizeAmount(amount).round();
    if (normalized <= 1) return 'Tek Sis';
    if (normalized == 2) return 'Cift Sis';
    return '$normalized Sis';
  }

  static String formatServiceAmountLabel({
    required ProductServiceControlType type,
    double? amount,
    int? grams,
  }) {
    switch (type) {
      case ProductServiceControlType.portionStepper:
        return formatPortionLabel(amount ?? 0);
      case ProductServiceControlType.skewerStepper:
        return formatSkewerLabel(amount ?? 0);
      case ProductServiceControlType.weightStepper:
        return formatWeight(grams ?? amount?.round() ?? 0);
      case ProductServiceControlType.none:
        return '';
    }
  }

  static String buildServiceControlSummary({
    required ProductServiceControlType type,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
    int? minWeightGrams,
    int? defaultWeightGrams,
  }) {
    if (type == ProductServiceControlType.weightStepper) {
      return buildWeightRangeLabel(
        minWeightGrams: minWeightGrams,
        defaultWeightGrams: defaultWeightGrams,
      );
    }
    if (!usesPortionLikeStepper(type)) return '';
    final min = resolveMinPortionAmount(type, minPortion);
    final max = resolveMaxPortionAmount(type, maxPortion, minPortion: min);
    final step = resolvePortionStepAmount(type, portionStep);
    return '${formatServiceAmountLabel(type: type, amount: min)} - ${formatServiceAmountLabel(type: type, amount: max)} · ${formatNumericAmount(step)} artis';
  }

  static String formatWeight(int grams) {
    if (grams <= 0) return '';
    if (grams % 1000 == 0) {
      return '${grams ~/ 1000} kg';
    }
    return '$grams g';
  }

  static String formatWeightShort(int grams) {
    if (grams <= 0) return '';
    if (grams % 1000 == 0) {
      return '${grams ~/ 1000}kg';
    }
    return '${grams}g';
  }

  static String selectedPricingTypeStorageValue({
    required ProductServiceControlType serviceControlType,
    required ProductPricingType pricingType,
  }) {
    if (serviceControlType == ProductServiceControlType.weightStepper ||
        pricingType == ProductPricingType.weight) {
      return 'kg';
    }
    return 'portion';
  }

  static String formatCurrency(double amount) {
    final sanitized = amount.isNaN || amount.isInfinite ? 0.0 : amount;
    final hasFraction = (sanitized - sanitized.roundToDouble()).abs() >= 0.01;
    return hasFraction
        ? '₺${sanitized.toStringAsFixed(2)}'
        : '₺${sanitized.toStringAsFixed(0)}';
  }

  static String formatPerKgLabel(double? pricePerKg) {
    final safePrice = sanitizePrice(pricePerKg);
    if (safePrice <= 0) return '';
    return '${formatCurrency(safePrice)} / kg';
  }

  static String buildWeightRangeLabel({
    int? minWeightGrams,
    int? defaultWeightGrams,
  }) {
    final min = resolveMinWeightGrams(minWeightGrams);
    final defaultWeight = resolveDefaultWeightGrams(
      defaultWeightGrams: defaultWeightGrams,
      minWeightGrams: min,
    );
    if (defaultWeight > min) {
      return 'Başlangıç: ${formatWeight(defaultWeight)}';
    }
    return 'Min: ${formatWeight(min)}';
  }

  static double parsePriceValue(Object? rawPrice) {
    if (rawPrice == null) return 0;
    if (rawPrice is num) return rawPrice.toDouble();
    var sanitized = rawPrice
        .toString()
        .replaceAll('₺', '')
        .replaceAll('TL', '')
        .replaceAll(RegExp(r'\s+'), '');
    if (sanitized.contains(',') && sanitized.contains('.')) {
      sanitized = sanitized.replaceAll('.', '').replaceAll(',', '.');
    } else if (sanitized.contains(',')) {
      sanitized = sanitized.replaceAll(',', '.');
    } else if ('.'.allMatches(sanitized).length > 1) {
      final parts = sanitized.split('.');
      sanitized = '${parts.sublist(0, parts.length - 1).join()}.${parts.last}';
    }
    return double.tryParse(sanitized) ?? 0;
  }

  static int _autoMaxWeightGrams({
    int? defaultWeightGrams,
    required int minWeightGrams,
    required int weightStepGrams,
  }) {
    final desiredUpper = [
      defaultWeightSelectionGrams,
      defaultWeightGrams ?? 0,
      minWeightGrams + (weightStepGrams * 6),
      1000,
    ].reduce((a, b) => a > b ? a : b);
    return clampWeightSelection(
      desiredUpper,
      minWeightGrams: minWeightGrams,
      weightStepGrams: weightStepGrams,
    );
  }
}
