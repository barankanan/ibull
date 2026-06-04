import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'product_pricing.dart';

class SellerProduct {
  final String id;
  final String name;
  final String brand;
  final String mainCategory;
  final String? subCategoryId;
  final String subCategory;
  final double price;
  final String pricingMode;
  final double? basePrice;
  final String pricingType;
  final double? portionPrice;
  final double? pricePerKg;
  final List<ProductSizeOption> sizeOptions;
  final String? selectedSizeName;
  final double? selectedSizePrice;
  final String? serviceControlType;
  final double? minPortion;
  final double? maxPortion;
  final double? portionStep;
  final int? defaultWeightGrams;
  final int? minWeightGrams;
  final int? weightStepGrams;
  final int? maxWeightGrams;
  final double? discountPrice;
  final int stock;
  final String sku;
  final String status;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? description;
  final String? specifications;
  final String? preparationTime;
  final DateTime createdAt;
  final List<String> attributes;
  final String? storeName;
  final String? videoUrl; // New field for video URL
  final String? videoPath;
  final String? videoPublicUrl;
  final String? thumbnailPath;
  final String? thumbnailPublicUrl;
  final int? videoDurationSeconds;
  final int? videoSizeBytes;
  final int? thumbnailSizeBytes;
  final String? videoStatus;
  final List<dynamic>? variants; // Add variants field
  final List<String>? accessories;
  final String? additionalInfo; // New: Ek Bilgiler (HTML/Text)
  final List<String>? additionalInfoItems;
  final List<Map<String, String>>? faq; // New: Sıkça Sorulan Sorular
  final String? stationId;
  final String? stationName;
  final String? stationCode;
  final bool printerRoutingEnabled;

  SellerProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.mainCategory,
    this.subCategoryId,
    required this.subCategory,
    required this.price,
    this.pricingMode = 'base_only',
    this.basePrice,
    this.pricingType = 'portion',
    this.portionPrice,
    this.pricePerKg,
    this.sizeOptions = const <ProductSizeOption>[],
    this.selectedSizeName,
    this.selectedSizePrice,
    this.serviceControlType,
    this.minPortion,
    this.maxPortion,
    this.portionStep,
    this.defaultWeightGrams,
    this.minWeightGrams,
    this.weightStepGrams,
    this.maxWeightGrams,
    this.discountPrice,
    required this.stock,
    required this.sku,
    required this.status,
    this.imageUrl,
    this.imageUrls = const [],
    this.description,
    this.specifications,
    this.preparationTime,
    required this.createdAt,
    this.attributes = const [],
    this.storeName,
    this.videoUrl,
    this.videoPath,
    this.videoPublicUrl,
    this.thumbnailPath,
    this.thumbnailPublicUrl,
    this.videoDurationSeconds,
    this.videoSizeBytes,
    this.thumbnailSizeBytes,
    this.videoStatus,
    this.variants,
    this.accessories,
    this.additionalInfo,
    this.additionalInfoItems,
    this.faq,
    this.stationId,
    this.stationName,
    this.stationCode,
    this.printerRoutingEnabled = true,
  });

  String get displayPrice {
    final defaultSize = defaultSizeOption;
    if (defaultSize != null && effectiveBaseUnitPrice <= 0 && !isWeightPriced) {
      return ProductPriceCalculator.formatCurrency(defaultSize.price);
    }
    if (isWeightPriced && !hasSizeOptions) {
      return ProductPriceCalculator.formatPerKgLabel(pricePerKg);
    }
    if (discountPrice != null && discountPrice! > 0) {
      return '₺${discountPrice!.toStringAsFixed(0)}';
    }
    return '₺${price.toStringAsFixed(0)}';
  }

  ProductPricingMode get resolvedPricingMode =>
      ProductPriceCalculator.resolvePricingMode(
        explicitMode: pricingMode,
        basePrice: effectiveBaseUnitPrice,
        pricePerKg: pricePerKg,
        sizeOptions: sizeOptions,
      );

  ProductPricingType get resolvedPricingType =>
      ProductPricingType.fromValue(pricingType);

  ProductServiceControlType get resolvedServiceControlType {
    final explicit = ProductServiceControlType.fromValue(serviceControlType);
    if (explicit != ProductServiceControlType.none) {
      return explicit;
    }
    if (resolvedPricingType == ProductPricingType.weight) {
      return ProductServiceControlType.weightStepper;
    }
    return ProductServiceControlType.none;
  }

  bool get usesServiceControlStepper =>
      ProductPriceCalculator.usesServiceControlStepper(
        resolvedServiceControlType,
      );

  bool get usesPortionLikeStepper =>
      ProductPriceCalculator.usesPortionLikeStepper(resolvedServiceControlType);

  double get effectivePricePerKg =>
      ProductPriceCalculator.sanitizePrice(pricePerKg);

  bool get hasConfiguredWeightGramFields =>
      ProductPriceCalculator.hasConfiguredWeightGramSettings(
        minWeightGrams: minWeightGrams,
        defaultWeightGrams: defaultWeightGrams,
        weightStepGrams: weightStepGrams,
      );

  bool get hasWeightPricing => effectivePricePerKg > 0;

  bool get supportsGarsonWeightSelection =>
      ProductPriceCalculator.supportsWeightSelection(
        pricePerKg: pricePerKg,
        pricingType: resolvedPricingType,
        pricingMode: resolvedPricingMode,
        minWeightGrams: minWeightGrams,
        defaultWeightGrams: defaultWeightGrams,
        weightStepGrams: weightStepGrams,
      );

  bool get hasSizeOptions => normalizedSizeOptions.isNotEmpty;

  List<ProductSizeOption> get normalizedSizeOptions =>
      ProductPriceCalculator.normalizeSizeOptions(sizeOptions);

  ProductSizeOption? get defaultSizeOption =>
      ProductPriceCalculator.defaultSizeOption(normalizedSizeOptions);

  bool get isWeightPriced => hasWeightPricing;

  double get effectiveBaseUnitPrice {
    final direct = ProductPriceCalculator.sanitizePrice(basePrice);
    if (direct > 0) return direct;
    final portionDirect = ProductPriceCalculator.sanitizePrice(portionPrice);
    if (portionDirect > 0) return portionDirect;
    if (hasSizeOptions && !hasWeightPricing) {
      return ProductPriceCalculator.sanitizePrice(defaultSizeOption?.price);
    }
    return ProductPriceCalculator.sanitizePrice(price);
  }

  double get resolvedMinPortionAmount =>
      ProductPriceCalculator.resolveMinPortionAmount(
        resolvedServiceControlType,
        minPortion,
      );

  double get resolvedMaxPortionAmount =>
      ProductPriceCalculator.resolveMaxPortionAmount(
        resolvedServiceControlType,
        maxPortion,
        minPortion: minPortion,
      );

  double get resolvedPortionStepAmount =>
      ProductPriceCalculator.resolvePortionStepAmount(
        resolvedServiceControlType,
        portionStep,
      );

  double get resolvedDefaultServiceAmount =>
      ProductPriceCalculator.resolveDefaultServiceAmount(
        type: resolvedServiceControlType,
        minPortion: minPortion,
        maxPortion: maxPortion,
        portionStep: portionStep,
      );

  ResolvedWeightGramSettings get resolvedWeightGramSettings =>
      ProductPriceCalculator.resolveWeightGramSettings(
        minWeightGrams: minWeightGrams,
        defaultWeightGrams: defaultWeightGrams,
        weightStepGrams: weightStepGrams,
        maxWeightGrams: maxWeightGrams,
      );

  int get resolvedMinWeightGrams => resolvedWeightGramSettings.minGrams;

  int get resolvedWeightStepGrams => resolvedWeightGramSettings.stepGrams;

  int get resolvedDefaultWeightGrams => resolvedWeightGramSettings.defaultGrams;

  int? get resolvedMaxWeightGrams => resolvedWeightGramSettings.maxGrams;

  String? get displayServiceControlInfo {
    final type = resolvedServiceControlType;
    if (type == ProductServiceControlType.none) return null;
    final info = ProductPriceCalculator.buildServiceControlSummary(
      type: type,
      minPortion: minPortion,
      maxPortion: maxPortion,
      portionStep: portionStep,
      minWeightGrams: minWeightGrams,
      defaultWeightGrams: defaultWeightGrams,
    );
    return info.trim().isEmpty ? null : info;
  }

  String get originalPrice {
    return '₺${price.toStringAsFixed(0)}';
  }

  bool get hasDiscount {
    return discountPrice != null &&
        discountPrice! > 0 &&
        discountPrice! < price;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'mainCategory': mainCategory,
      'subCategoryId': subCategoryId,
      'subCategory': subCategory,
      'price': price,
      'pricingMode': pricingMode,
      'basePrice': basePrice,
      'pricingType': pricingType,
      'portionPrice': portionPrice,
      'pricePerKg': pricePerKg,
      'sizeOptions': sizeOptions.map((option) => option.toJson()).toList(),
      'selectedSizeName': selectedSizeName,
      'selectedSizePrice': selectedSizePrice,
      'serviceControlType': serviceControlType,
      'minPortion': minPortion,
      'maxPortion': maxPortion,
      'portionStep': portionStep,
      'defaultWeightGrams': defaultWeightGrams,
      'minWeightGrams': minWeightGrams,
      'weightStepGrams': weightStepGrams,
      'maxWeightGrams': maxWeightGrams,
      'discountPrice': discountPrice,
      'stock': stock,
      'sku': sku,
      'status': status,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'description': description,
      'specifications': specifications,
      'preparationTime': preparationTime,
      'createdAt': createdAt.toIso8601String(),
      'attributes': attributes,
      'videoUrl': videoUrl,
      'videoPath': videoPath,
      'videoPublicUrl': videoPublicUrl,
      'thumbnailPath': thumbnailPath,
      'thumbnailPublicUrl': thumbnailPublicUrl,
      'videoDurationSeconds': videoDurationSeconds,
      'videoSizeBytes': videoSizeBytes,
      'thumbnailSizeBytes': thumbnailSizeBytes,
      'videoStatus': videoStatus,
      'variants': variants,
      'accessories': accessories,
      'additional_info': additionalInfo,
      'additionalInfoItems': additionalInfoItems,
      'faq': faq,
      'stationId': stationId,
      'stationCode': stationCode,
      'printerRoutingEnabled': printerRoutingEnabled,
    };
  }

  factory SellerProduct.fromMap(Map<String, dynamic> map, String id) {
    if (kDebugMode) debugPrint('DB Verisi (SellerProduct): $map');

    DateTime created;
    if (map['created_at'] != null) {
      if (map['created_at'] is int) {
        created = DateTime.fromMillisecondsSinceEpoch(map['created_at']);
      } else {
        created =
            DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
      }
    } else {
      created = DateTime.now();
    }

    // Image URL Logic:
    // 1. Try 'image_url' (DB column)
    // 2. Try 'mainImage' (possible alias)
    // 3. If null/empty, check 'image_urls' list and take the first one
    List<String> imgUrls = [];
    if (map['image_urls'] != null && map['image_urls'] is List) {
      imgUrls = List<String>.from(map['image_urls']);
    }

    String? mainImg = map['image_url'] ?? map['mainImage'];
    if ((mainImg == null || mainImg.isEmpty) && imgUrls.isNotEmpty) {
      mainImg = imgUrls.first;
    }

    final resolvedPricingType =
        map['pricing_type']?.toString() ??
        map['pricingType']?.toString() ??
        ProductPricingType.portion.storageValue;
    final resolvedPortionPrice =
        (map['portion_price'] as num?)?.toDouble() ??
        (map['portionPrice'] as num?)?.toDouble() ??
        (map['base_price'] as num?)?.toDouble() ??
        (map['basePrice'] as num?)?.toDouble();
    final resolvedPricePerKg = ProductPriceCalculator.resolvePricePerKgFromMap(
      map,
      pricingType: resolvedPricingType,
    );
    final resolvedSizeOptions = ProductSizeOption.listFromDynamic(
      map['size_options'] ?? map['sizeOptions'],
    );

    final product = SellerProduct(
      id: id,
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      mainCategory:
          map['main_category'] ?? map['mainCategory'] ?? map['category'] ?? '',
      subCategoryId:
          map['sub_category_id']?.toString() ??
          map['subCategoryId']?.toString(),
      subCategory: map['sub_category'] ?? map['subCategory'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      pricingMode:
          map['pricing_mode']?.toString() ??
          map['pricingMode']?.toString() ??
          ProductPriceCalculator.resolvePricingMode(
            basePrice: resolvedPortionPrice,
            pricePerKg: resolvedPricePerKg > 0 ? resolvedPricePerKg : null,
            sizeOptions: resolvedSizeOptions,
          ).storageValue,
      basePrice: resolvedPortionPrice,
      pricingType: resolvedPricingType,
      portionPrice:
          resolvedPortionPrice ??
          ProductPriceCalculator.parsePriceValue(map['price']),
      pricePerKg: resolvedPricePerKg > 0 ? resolvedPricePerKg : null,
      sizeOptions: resolvedSizeOptions,
      selectedSizeName:
          map['selected_size_name']?.toString() ??
          map['selectedSizeName']?.toString(),
      selectedSizePrice:
          (map['selected_size_price'] as num?)?.toDouble() ??
          (map['selectedSizePrice'] as num?)?.toDouble(),
      serviceControlType:
          map['service_control_type']?.toString() ??
          map['serviceControlType']?.toString(),
      minPortion:
          (map['min_portion'] as num?)?.toDouble() ??
          (map['minPortion'] as num?)?.toDouble(),
      maxPortion:
          (map['max_portion'] as num?)?.toDouble() ??
          (map['maxPortion'] as num?)?.toDouble(),
      portionStep:
          (map['portion_step'] as num?)?.toDouble() ??
          (map['portionStep'] as num?)?.toDouble(),
      defaultWeightGrams:
          (map['default_weight_grams'] as num?)?.toInt() ??
          (map['defaultWeightGrams'] as num?)?.toInt(),
      minWeightGrams:
          (map['min_weight_grams'] as num?)?.toInt() ??
          (map['minWeightGrams'] as num?)?.toInt(),
      weightStepGrams:
          (map['weight_step_grams'] as num?)?.toInt() ??
          (map['weightStepGrams'] as num?)?.toInt(),
      maxWeightGrams:
          (map['max_weight_grams'] as num?)?.toInt() ??
          (map['maxWeightGrams'] as num?)?.toInt(),
      discountPrice: (map['discount_price'] ?? map['discountPrice'] as num?)
          ?.toDouble(),
      stock: map['stock'] ?? 0,
      sku: map['sku'] ?? '',
      status: map['status'] ?? 'Aktif',
      imageUrl: mainImg,
      imageUrls: imgUrls,
      description: map['description'],
      specifications: _normalizeSpecificationsWithType(
        map['specifications'],
        map['product_type'],
      ),
      preparationTime:
          map['preparation_time']?.toString() ??
          map['preparationTime']?.toString(),
      createdAt: created,
      attributes: map['attributes'] != null
          ? List<String>.from(map['attributes'])
          : [],
      storeName: map['store_name'],
      videoUrl: map['video_public_url'] ?? map['video_url'],
      videoPath: map['video_path'],
      videoPublicUrl: map['video_public_url'],
      thumbnailPath: map['thumbnail_path'],
      thumbnailPublicUrl: map['thumbnail_public_url'],
      videoDurationSeconds: (map['video_duration_seconds'] as num?)?.toInt(),
      videoSizeBytes: (map['video_size_bytes'] as num?)?.toInt(),
      thumbnailSizeBytes: (map['thumbnail_size_bytes'] as num?)?.toInt(),
      videoStatus: map['video_status'],
      variants: map['variants'],
      accessories: map['accessories'] != null
          ? List<String>.from(map['accessories'])
          : null,
      additionalInfo: map['additional_info'],
      additionalInfoItems: _parseAdditionalInfoItems(map['additional_info']),
      faq: map['faq'] != null
          ? (map['faq'] as List)
                .map((e) => Map<String, String>.from(e))
                .toList()
          : null,
      stationId: map['station_id']?.toString(),
      stationName: _parseProductionStationName(map),
      stationCode: _parseProductionStationCode(map),
      printerRoutingEnabled: map['printer_routing_enabled'] != false,
    );
    ProductPriceCalculator.productParseWeightLog(
      productId: product.id,
      settings: product.resolvedWeightGramSettings,
    );
    return product;
  }

  static String? _parseProductionStationName(Map<String, dynamic> map) {
    final nested = map['stations'];
    if (nested is Map) {
      final name = nested['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name;
    }
    final direct = map['station_name']?.toString().trim() ?? '';
    return direct.isEmpty ? null : direct;
  }

  static String? _parseProductionStationCode(Map<String, dynamic> map) {
    final nested = map['stations'];
    if (nested is Map) {
      final code = nested['code']?.toString().trim() ?? '';
      if (code.isNotEmpty) return code;
    }
    final direct = map['station_code']?.toString().trim() ?? '';
    return direct.isEmpty ? null : direct;
  }

  static String? _normalizeSpecifications(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  /// Normalizes [specifications] and injects [rawProductType] into the JSON as
  /// `_ibul_product_type` when the specs key is absent but the column value
  /// identifies a known template type (e.g. products created via SQL migration).
  static String? _normalizeSpecificationsWithType(
    Object? specifications,
    Object? rawProductType,
  ) {
    final normalized = _normalizeSpecifications(specifications);
    if (rawProductType == null) return normalized;
    final typeStr = rawProductType.toString().trim().toLowerCase();
    if (typeStr.isEmpty) return normalized;
    if (typeStr != 'service_template' &&
        typeStr != 'menu_template' &&
        typeStr != 'mixed_service_template') {
      return normalized;
    }
    Map<String, dynamic> specsMap = {};
    if (normalized != null) {
      try {
        final dynamic decoded = jsonDecode(normalized);
        if (decoded is Map) specsMap = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    if (specsMap.containsKey('_ibul_product_type')) return normalized;
    specsMap['_ibul_product_type'] = typeStr;
    return jsonEncode(specsMap);
  }

  static List<String>? _parseAdditionalInfoItems(Object? value) {
    if (value == null) return null;
    if (value is List) {
      final List<String> items = value
          .map((Object? item) => item?.toString().trim() ?? '')
          .where((String item) => item.isNotEmpty)
          .toList(growable: false);
      return items;
    }
    final String text = value.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('[')) {
      try {
        final dynamic decoded = jsonDecode(text);
        if (decoded is List) {
          final List<String> items = decoded
              .map((Object? item) => item?.toString().trim() ?? '')
              .where((String item) => item.isNotEmpty)
              .toList(growable: false);
          return items;
        }
      } catch (_) {}
    }
    return text
        .split(RegExp(r'[\n,|•]'))
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
