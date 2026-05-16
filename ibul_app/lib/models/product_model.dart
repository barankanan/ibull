import 'dart:convert';

import '../core/app_image_cdn.dart';
import 'product_pricing.dart';
import '../utils/preparation_time_formatter.dart';

class Product {
  final String? productId;
  final String name;
  final String brand;
  final String price;
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
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final List<String> images;
  final bool isDigital;
  final List<String>? accessories;
  final List<String>? threeSixtyImages;
  final String? store;
  final String? sellerId;
  final String? category;
  final String? subCategory;
  final String? shortDescription;
  final String? description;
  final String? specifications;
  final String? preparationTime;
  final String? cookingTime;
  final List<String>? ingredients;
  final List<String>? features;
  final String? oldPrice;
  final String? variantOptions;
  final String? variantGroupId;
  final List<String> selectedServices;
  final List<Product>? selectedParts; // Seçili yedek parçalar
  final List<String>?
  attributes; // Satıcı tanımlı ürün özellikleri (Domatessiz, Az Tuzlu vb.)
  final String? videoUrl; // Ürün tanıtım videosu URL'i
  final String? videoPath;
  final String? videoPublicUrl;
  final String? thumbnailPath;
  final String? thumbnailPublicUrl;
  final int? videoDurationSeconds;
  final int? videoSizeBytes;
  final int? thumbnailSizeBytes;
  final String? videoStatus;
  final List<dynamic>?
  variants; // Varyantlar (SellerProduct.variants ile eşleşmeli)
  final String? additionalInfo; // Ek Bilgiler
  final List<Map<String, String>>? faq; // Sıkça Sorulan Sorular

  Product({
    this.productId,
    required this.name,
    required this.brand,
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
    required this.rating,
    required this.reviewCount,
    required this.tags,
    required this.images,
    this.isDigital = false,
    this.accessories,
    this.threeSixtyImages,
    this.store,
    this.sellerId,
    this.category,
    this.subCategory,
    this.shortDescription,
    this.description,
    this.specifications,
    this.preparationTime,
    this.cookingTime,
    this.ingredients,
    this.features,
    this.oldPrice,
    this.variantOptions,
    this.variantGroupId,
    this.selectedServices = const [],
    this.selectedParts,
    this.attributes,
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
    this.additionalInfo,
    this.faq,
  });

  Product copyWith({
    String? productId,
    String? name,
    String? brand,
    String? price,
    String? pricingMode,
    double? basePrice,
    String? pricingType,
    double? portionPrice,
    double? pricePerKg,
    List<ProductSizeOption>? sizeOptions,
    String? selectedSizeName,
    double? selectedSizePrice,
    String? serviceControlType,
    double? minPortion,
    double? maxPortion,
    double? portionStep,
    int? defaultWeightGrams,
    int? minWeightGrams,
    int? weightStepGrams,
    int? maxWeightGrams,
    double? rating,
    int? reviewCount,
    List<String>? tags,
    List<String>? images,
    bool? isDigital,
    List<String>? accessories,
    List<String>? threeSixtyImages,
    String? store,
    String? sellerId,
    String? category,
    String? subCategory,
    String? shortDescription,
    String? description,
    String? specifications,
    String? preparationTime,
    String? cookingTime,
    List<String>? ingredients,
    List<String>? features,
    String? oldPrice,
    String? variantOptions,
    String? variantGroupId,
    List<String>? selectedServices,
    List<Product>? selectedParts,
    List<String>? attributes,
    String? videoUrl,
    String? videoPath,
    String? videoPublicUrl,
    String? thumbnailPath,
    String? thumbnailPublicUrl,
    int? videoDurationSeconds,
    int? videoSizeBytes,
    int? thumbnailSizeBytes,
    String? videoStatus,
    List<dynamic>? variants,
    String? additionalInfo,
    List<Map<String, String>>? faq,
  }) {
    return Product(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      pricingMode: pricingMode ?? this.pricingMode,
      basePrice: basePrice ?? this.basePrice,
      pricingType: pricingType ?? this.pricingType,
      portionPrice: portionPrice ?? this.portionPrice,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      sizeOptions: sizeOptions ?? this.sizeOptions,
      selectedSizeName: selectedSizeName ?? this.selectedSizeName,
      selectedSizePrice: selectedSizePrice ?? this.selectedSizePrice,
      serviceControlType: serviceControlType ?? this.serviceControlType,
      minPortion: minPortion ?? this.minPortion,
      maxPortion: maxPortion ?? this.maxPortion,
      portionStep: portionStep ?? this.portionStep,
      defaultWeightGrams: defaultWeightGrams ?? this.defaultWeightGrams,
      minWeightGrams: minWeightGrams ?? this.minWeightGrams,
      weightStepGrams: weightStepGrams ?? this.weightStepGrams,
      maxWeightGrams: maxWeightGrams ?? this.maxWeightGrams,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      isDigital: isDigital ?? this.isDigital,
      accessories: accessories ?? this.accessories,
      threeSixtyImages: threeSixtyImages ?? this.threeSixtyImages,
      store: store ?? this.store,
      sellerId: sellerId ?? this.sellerId,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      shortDescription: shortDescription ?? this.shortDescription,
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
      preparationTime: preparationTime ?? this.preparationTime,
      cookingTime: cookingTime ?? this.cookingTime,
      ingredients: ingredients ?? this.ingredients,
      features: features ?? this.features,
      oldPrice: oldPrice ?? this.oldPrice,
      variantOptions: variantOptions ?? this.variantOptions,
      variantGroupId: variantGroupId ?? this.variantGroupId,
      selectedServices: selectedServices ?? this.selectedServices,
      selectedParts: selectedParts ?? this.selectedParts,
      attributes: attributes ?? this.attributes,
      videoUrl: videoUrl ?? this.videoUrl,
      videoPath: videoPath ?? this.videoPath,
      videoPublicUrl: videoPublicUrl ?? this.videoPublicUrl,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailPublicUrl: thumbnailPublicUrl ?? this.thumbnailPublicUrl,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      videoSizeBytes: videoSizeBytes ?? this.videoSizeBytes,
      thumbnailSizeBytes: thumbnailSizeBytes ?? this.thumbnailSizeBytes,
      videoStatus: videoStatus ?? this.videoStatus,
      variants: variants ?? this.variants,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      faq: faq ?? this.faq,
    );
  }

  // Helper method for Video Button - moved to top
  // bool get hasVideo => videoUrl != null && videoUrl!.trim().isNotEmpty;

  // JSON Serialization for Firestore
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'productId': productId,
      'brand': brand,
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
      'rating': rating,
      'reviewCount': reviewCount,
      'tags': tags,
      'images': images,
      'isDigital': isDigital,
      'accessories': accessories,
      'threeSixtyImages': threeSixtyImages,
      'store': store,
      'sellerId': sellerId,
      'category': category,
      'subCategory': subCategory,
      'shortDescription': shortDescription,
      'description': description,
      'specifications': specifications,
      'preparationTime': preparationTime,
      'cookingTime': cookingTime,
      'ingredients': ingredients,
      'features': features,
      'oldPrice': oldPrice,
      'variantOptions': variantOptions,
      'variantGroupId': variantGroupId,
      'selectedServices': selectedServices,
      'attributes': attributes,
      'videoUrl': videoUrl,
      'video_path': videoPath,
      'video_public_url': videoPublicUrl,
      'thumbnail_path': thumbnailPath,
      'thumbnail_public_url': thumbnailPublicUrl,
      'video_duration_seconds': videoDurationSeconds,
      'video_size_bytes': videoSizeBytes,
      'thumbnail_size_bytes': thumbnailSizeBytes,
      'video_status': videoStatus,
      'variants': variants,
      'additional_info': additionalInfo,
      'faq': faq,
      // selectedParts complex object, skipping for basic persistence or need recursive toJson
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      name: json['name'] ?? '',
      productId:
          json['productId']?.toString() ?? json['product_id']?.toString(),
      brand: json['brand'] ?? '',
      price: json['price'] ?? '0',
        pricingMode:
          json['pricingMode']?.toString() ??
          json['pricing_mode']?.toString() ??
          ProductPriceCalculator.resolvePricingMode(
          basePrice:
            (json['basePrice'] as num?)?.toDouble() ??
            (json['base_price'] as num?)?.toDouble() ??
            (json['portionPrice'] as num?)?.toDouble() ??
            (json['portion_price'] as num?)?.toDouble(),
          pricePerKg:
            (json['pricePerKg'] as num?)?.toDouble() ??
            (json['price_per_kg'] as num?)?.toDouble(),
          sizeOptions: ProductSizeOption.listFromDynamic(
            json['sizeOptions'] ?? json['size_options'],
          ),
          ).storageValue,
        basePrice:
          (json['basePrice'] as num?)?.toDouble() ??
          (json['base_price'] as num?)?.toDouble() ??
          (json['portionPrice'] as num?)?.toDouble() ??
          (json['portion_price'] as num?)?.toDouble(),
      pricingType:
          json['pricingType']?.toString() ??
          json['pricing_type']?.toString() ??
          'portion',
      portionPrice:
          (json['portionPrice'] as num?)?.toDouble() ??
          (json['portion_price'] as num?)?.toDouble() ??
          ProductPriceCalculator.parsePriceValue(json['price']),
      pricePerKg:
          (json['pricePerKg'] as num?)?.toDouble() ??
          (json['price_per_kg'] as num?)?.toDouble(),
        sizeOptions: ProductSizeOption.listFromDynamic(
        json['sizeOptions'] ?? json['size_options'],
        ),
        selectedSizeName:
          json['selectedSizeName']?.toString() ??
          json['selected_size_name']?.toString(),
        selectedSizePrice:
          (json['selectedSizePrice'] as num?)?.toDouble() ??
          (json['selected_size_price'] as num?)?.toDouble(),
      serviceControlType:
          json['serviceControlType']?.toString() ??
          json['service_control_type']?.toString(),
      minPortion:
          (json['minPortion'] as num?)?.toDouble() ??
          (json['min_portion'] as num?)?.toDouble(),
      maxPortion:
          (json['maxPortion'] as num?)?.toDouble() ??
          (json['max_portion'] as num?)?.toDouble(),
      portionStep:
          (json['portionStep'] as num?)?.toDouble() ??
          (json['portion_step'] as num?)?.toDouble(),
      defaultWeightGrams:
          (json['defaultWeightGrams'] as num?)?.toInt() ??
          (json['default_weight_grams'] as num?)?.toInt(),
      minWeightGrams:
          (json['minWeightGrams'] as num?)?.toInt() ??
          (json['min_weight_grams'] as num?)?.toInt(),
      weightStepGrams:
          (json['weightStepGrams'] as num?)?.toInt() ??
          (json['weight_step_grams'] as num?)?.toInt(),
      maxWeightGrams:
          (json['maxWeightGrams'] as num?)?.toInt() ??
          (json['max_weight_grams'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      tags: List<String>.from(json['tags'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      isDigital: json['isDigital'] ?? false,
      accessories: json['accessories'] != null
          ? List<String>.from(json['accessories'])
          : null,
      threeSixtyImages: json['threeSixtyImages'] != null
          ? List<String>.from(json['threeSixtyImages'])
          : null,
      store: json['store'],
      sellerId: json['sellerId']?.toString() ?? json['seller_id']?.toString(),
      category: json['category'],
      subCategory: json['subCategory'],
      shortDescription:
          json['shortDescription']?.toString() ??
          json['short_description']?.toString(),
      description: json['description'],
      specifications: _normalizeJsonText(json['specifications']),
      preparationTime:
          json['preparationTime']?.toString() ??
          json['preparation_time']?.toString(),
      cookingTime:
          json['cookingTime']?.toString() ?? json['cooking_time']?.toString(),
      ingredients: _parseStringList(
        json['ingredients'] ?? json['ingredient_list'],
      ),
      features: _parseStringList(json['features']),
      oldPrice: json['oldPrice'],
      variantOptions: json['variantOptions'],
      variantGroupId: json['variantGroupId'],
      selectedServices: List<String>.from(json['selectedServices'] ?? []),
      attributes: json['attributes'] != null
          ? List<String>.from(json['attributes'])
          : null,
      videoUrl:
          json['video_public_url'] ?? json['videoUrl'] ?? json['video_url'],
      videoPath: json['video_path'],
      videoPublicUrl: json['video_public_url'],
      thumbnailPath: json['thumbnail_path'],
      thumbnailPublicUrl: json['thumbnail_public_url'],
      videoDurationSeconds: (json['video_duration_seconds'] as num?)?.toInt(),
      videoSizeBytes: (json['video_size_bytes'] as num?)?.toInt(),
      thumbnailSizeBytes: (json['thumbnail_size_bytes'] as num?)?.toInt(),
      videoStatus: json['video_status'],
      variants: json['variants'],
      additionalInfo: json['additional_info'],
      faq: json['faq'] != null
          ? (json['faq'] as List)
                .map((e) => Map<String, String>.from(e))
                .toList()
          : null,
    );
  }

  // DBProduct'tan Product'a dönüştür
  factory Product.fromDBProduct(dynamic dbProduct) {
    // Görselleri hazırla
    List<String> images = [];
    try {
      final mainImage = (dbProduct as dynamic).imageUrl;
      if (mainImage != null && mainImage.toString().trim().isNotEmpty) {
        images.add(mainImage.toString().trim());
      }
    } catch (_) {}
    try {
      final extraImages = (dbProduct as dynamic).imageUrls;
      if (extraImages != null) {
        if (extraImages is List) {
          images.addAll(
            extraImages
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty),
          );
        } else if (extraImages is String && extraImages.trim().isNotEmpty) {
          final trimmed = extraImages.trim();
          if (trimmed.startsWith('[')) {
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is List) {
                images.addAll(
                  decoded
                      .map((e) => e.toString().trim())
                      .where((e) => e.isNotEmpty),
                );
              }
            } catch (_) {}
          } else {
            images.addAll(
              trimmed
                  .split(',')
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty),
            );
          }
        }
      }
    } catch (_) {}

    // Etiketleri hazırla
    List<String> tags = [];
    try {
      final rawTags = (dbProduct as dynamic).tags;
      if (rawTags != null) {
        if (rawTags is List) {
          tags = rawTags
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else if (rawTags is String && rawTags.trim().isNotEmpty) {
          final trimmed = rawTags.trim();
          if (trimmed.startsWith('[')) {
            try {
              final decoded = jsonDecode(trimmed);
              if (decoded is List) {
                tags = decoded
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }
            } catch (_) {}
          }
          if (tags.isEmpty) {
            tags = trimmed
                .split(RegExp(r'[|,]'))
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (_) {}

    // Satıcı panelinden gelen ürün özellikleri (JSON string veya List)
    List<String>? attributes;
    try {
      dynamic rawAttributes;
      if (dbProduct is Map) {
        rawAttributes = dbProduct['attributes'];
      } else {
        rawAttributes = (dbProduct as dynamic).attributes;
      }
      if (rawAttributes is List) {
        attributes = rawAttributes.map((e) => e.toString()).toList();
      } else if (rawAttributes is String && rawAttributes.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawAttributes);
          if (decoded is List) {
            attributes = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    } catch (_) {}

    // Varyantlar (SellerProduct -> Product)
    List<Map<String, dynamic>>? variants;
    try {
      // Dynamic parsing: List<dynamic> -> List<Map<String, dynamic>>
      List<dynamic>? rawVariants;

      // Check if dbProduct is a Map (direct DB row)
      if (dbProduct is Map) {
        // JSON String ise decode et (DIAGNOSTIC STEP 4)
        if (dbProduct['variants'] is String) {
          try {
            rawVariants = jsonDecode(dbProduct['variants']);
          } catch (_) {
            rawVariants = [];
          }
        } else {
          rawVariants = dbProduct['variants'];
        }
      } else {
        // Check if dbProduct is an object (SellerProduct)
        try {
          rawVariants = (dbProduct as dynamic).variants;
        } catch (_) {}
      }

      if (rawVariants != null) {
        variants = rawVariants
            .map((v) {
              if (v is Map) {
                return Map<String, dynamic>.from(v);
              }
              // If it's an object (ProductVariant), try to convert to Map
              try {
                return (v as dynamic).toMap();
              } catch (_) {
                return <String, dynamic>{};
              }
            })
            .where((m) => m.isNotEmpty)
            .toList()
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // Ignore malformed service option payloads and keep parsing the product.
    }

    List<String>? accessories;
    try {
      dynamic rawAccessories;
      if (dbProduct is Map) {
        rawAccessories = dbProduct['accessories'];
      } else {
        rawAccessories = (dbProduct as dynamic).accessories;
      }
      if (rawAccessories is List) {
        accessories = rawAccessories
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (rawAccessories is String && rawAccessories.trim().isNotEmpty) {
        final trimmed = rawAccessories.trim();
        if (trimmed.startsWith('[')) {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            accessories = decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }
    } catch (_) {}

    // Video URL'i parse et (Map veya Object)
    String? parsedVideoUrl;
    String? parsedVideoPath;
    String? parsedVideoPublicUrl;
    String? parsedThumbnailPath;
    String? parsedThumbnailPublicUrl;
    int? parsedVideoDurationSeconds;
    int? parsedVideoSizeBytes;
    int? parsedThumbnailSizeBytes;
    String? parsedVideoStatus;
    if (dbProduct is Map) {
      // Map ise snake_case veya camelCase kontrol et
      parsedVideoPath = dbProduct['video_path']?.toString();
      parsedVideoPublicUrl = dbProduct['video_public_url']?.toString();
      parsedThumbnailPath = dbProduct['thumbnail_path']?.toString();
      parsedThumbnailPublicUrl = dbProduct['thumbnail_public_url']?.toString();
      parsedVideoDurationSeconds = (dbProduct['video_duration_seconds'] as num?)
          ?.toInt();
      parsedVideoSizeBytes = (dbProduct['video_size_bytes'] as num?)?.toInt();
      parsedThumbnailSizeBytes = (dbProduct['thumbnail_size_bytes'] as num?)
          ?.toInt();
      parsedVideoStatus = dbProduct['video_status']?.toString();
      parsedVideoUrl =
          parsedVideoPublicUrl ??
          dbProduct['video_url']?.toString() ??
          dbProduct['videoUrl']?.toString();
    } else {
      // Obje ise videoUrl getter'ını dene
      try {
        parsedVideoPublicUrl = (dbProduct as dynamic).videoPublicUrl
            ?.toString();
      } catch (_) {}
      try {
        parsedVideoPath = (dbProduct as dynamic).videoPath?.toString();
      } catch (_) {}
      try {
        parsedThumbnailPath = (dbProduct as dynamic).thumbnailPath?.toString();
      } catch (_) {}
      try {
        parsedThumbnailPublicUrl = (dbProduct as dynamic).thumbnailPublicUrl
            ?.toString();
      } catch (_) {}
      try {
        parsedVideoDurationSeconds =
            ((dbProduct as dynamic).videoDurationSeconds as num?)?.toInt();
      } catch (_) {}
      try {
        parsedVideoSizeBytes = ((dbProduct as dynamic).videoSizeBytes as num?)
            ?.toInt();
      } catch (_) {}
      try {
        parsedThumbnailSizeBytes =
            ((dbProduct as dynamic).thumbnailSizeBytes as num?)?.toInt();
      } catch (_) {}
      try {
        parsedVideoStatus = (dbProduct as dynamic).videoStatus?.toString();
      } catch (_) {}
      try {
        parsedVideoUrl =
            parsedVideoPublicUrl ?? (dbProduct as dynamic).videoUrl?.toString();
      } catch (_) {}
    }

    // Debug log for ProductModel creation
    // print('ProductModel.fromDBProduct: parsedVideoUrl=$parsedVideoUrl');

    String? additionalInfo;
    List<Map<String, String>>? faq;
    if (dbProduct is Map) {
      additionalInfo = dbProduct['additional_info'];
      if (dbProduct['faq'] != null) {
        faq = (dbProduct['faq'] as List)
            .map((e) => Map<String, String>.from(e))
            .toList();
      }
    } else {
      try {
        additionalInfo = (dbProduct as dynamic).additionalInfo;
        faq = (dbProduct as dynamic).faq;
      } catch (_) {}
    }

    String name = 'Ürün';
    String? productId;
    String brand = '';
    String price = '0';
    String pricingMode = ProductPricingMode.baseOnly.storageValue;
    double? basePrice;
    String pricingType = ProductPricingType.portion.storageValue;
    double? portionPrice;
    double? pricePerKg;
    List<ProductSizeOption> sizeOptions = const <ProductSizeOption>[];
    String? selectedSizeName;
    double? selectedSizePrice;
    String? serviceControlType;
    double? minPortion;
    double? maxPortion;
    double? portionStep;
    int? defaultWeightGrams;
    int? minWeightGrams;
    int? weightStepGrams;
    int? maxWeightGrams;
    double rating = 0.0;
    int reviewCount = 0;
    String? store;
    String? sellerId;
    String? category;
    String? subCategory;
    String? shortDescription;
    String? description;
    String? specifications;
    String? preparationTime;
    String? cookingTime;
    String? oldPrice;
    String? variantOptions;
    String? variantGroupId;

    try {
      productId = (dbProduct as dynamic).id?.toString();
    } catch (_) {}
    try {
      name = (dbProduct as dynamic).name?.toString() ?? name;
    } catch (_) {}
    try {
      brand = (dbProduct as dynamic).brand?.toString() ?? brand;
    } catch (_) {}
    try {
      price = (dbProduct as dynamic).price?.toString() ?? price;
    } catch (_) {}
    try {
      pricingMode =
          (dbProduct as dynamic).pricingMode?.toString() ?? pricingMode;
    } catch (_) {}
    try {
      basePrice = ((dbProduct as dynamic).basePrice as num?)?.toDouble();
    } catch (_) {}
    try {
      pricingType =
          (dbProduct as dynamic).pricingType?.toString() ??
          ProductPricingType.portion.storageValue;
    } catch (_) {}
    try {
      portionPrice = ((dbProduct as dynamic).portionPrice as num?)?.toDouble();
    } catch (_) {}
    try {
      pricePerKg = ((dbProduct as dynamic).pricePerKg as num?)?.toDouble();
    } catch (_) {}
    try {
      sizeOptions = ProductSizeOption.listFromDynamic(
        (dbProduct as dynamic).sizeOptions,
      );
    } catch (_) {}
    try {
      selectedSizeName = (dbProduct as dynamic).selectedSizeName?.toString();
    } catch (_) {}
    try {
      selectedSizePrice =
          ((dbProduct as dynamic).selectedSizePrice as num?)?.toDouble();
    } catch (_) {}
    try {
      serviceControlType = (dbProduct as dynamic).serviceControlType
          ?.toString();
    } catch (_) {}
    try {
      minPortion = ((dbProduct as dynamic).minPortion as num?)?.toDouble();
    } catch (_) {}
    try {
      maxPortion = ((dbProduct as dynamic).maxPortion as num?)?.toDouble();
    } catch (_) {}
    try {
      portionStep = ((dbProduct as dynamic).portionStep as num?)?.toDouble();
    } catch (_) {}
    try {
      defaultWeightGrams = ((dbProduct as dynamic).defaultWeightGrams as num?)
          ?.toInt();
    } catch (_) {}
    try {
      minWeightGrams = ((dbProduct as dynamic).minWeightGrams as num?)?.toInt();
    } catch (_) {}
    try {
      weightStepGrams = ((dbProduct as dynamic).weightStepGrams as num?)
          ?.toInt();
    } catch (_) {}
    try {
      maxWeightGrams = ((dbProduct as dynamic).maxWeightGrams as num?)?.toInt();
    } catch (_) {}
    try {
      rating = ((dbProduct as dynamic).rating as num?)?.toDouble() ?? rating;
    } catch (_) {}
    try {
      reviewCount =
          ((dbProduct as dynamic).reviewCount as num?)?.toInt() ?? reviewCount;
    } catch (_) {}

    try {
      store = (dbProduct as dynamic).store?.toString();
    } catch (_) {}
    try {
      store ??= (dbProduct as dynamic).storeName?.toString();
    } catch (_) {}
    try {
      store ??= (dbProduct as dynamic).businessName?.toString();
    } catch (_) {}
    try {
      sellerId = (dbProduct as dynamic).sellerId?.toString();
    } catch (_) {}
    try {
      sellerId ??= (dbProduct as dynamic).seller_id?.toString();
    } catch (_) {}
    if (dbProduct is Map) {
      productId ??= dbProduct['id']?.toString();
      sellerId ??= dbProduct['seller_id']?.toString();
      sellerId ??= dbProduct['sellerId']?.toString();
      name = dbProduct['name']?.toString() ?? name;
      brand = dbProduct['brand']?.toString() ?? brand;
      price = dbProduct['price']?.toString() ?? price;
      pricingMode =
          dbProduct['pricing_mode']?.toString() ??
          dbProduct['pricingMode']?.toString() ??
          pricingMode;
      basePrice =
          (dbProduct['base_price'] as num?)?.toDouble() ??
          (dbProduct['basePrice'] as num?)?.toDouble() ??
          basePrice;
      pricingType =
          dbProduct['pricing_type']?.toString() ??
          dbProduct['pricingType']?.toString() ??
          pricingType;
      portionPrice =
          (dbProduct['portion_price'] as num?)?.toDouble() ??
          (dbProduct['portionPrice'] as num?)?.toDouble() ??
          portionPrice;
      pricePerKg =
          (dbProduct['price_per_kg'] as num?)?.toDouble() ??
          (dbProduct['pricePerKg'] as num?)?.toDouble() ??
          pricePerKg;
      sizeOptions = ProductSizeOption.listFromDynamic(
        dbProduct['size_options'] ?? dbProduct['sizeOptions'],
      );
      selectedSizeName =
          dbProduct['selected_size_name']?.toString() ??
          dbProduct['selectedSizeName']?.toString() ??
          selectedSizeName;
      selectedSizePrice =
          (dbProduct['selected_size_price'] as num?)?.toDouble() ??
          (dbProduct['selectedSizePrice'] as num?)?.toDouble() ??
          selectedSizePrice;
      serviceControlType =
          dbProduct['service_control_type']?.toString() ??
          dbProduct['serviceControlType']?.toString() ??
          serviceControlType;
      minPortion =
          (dbProduct['min_portion'] as num?)?.toDouble() ??
          (dbProduct['minPortion'] as num?)?.toDouble() ??
          minPortion;
      maxPortion =
          (dbProduct['max_portion'] as num?)?.toDouble() ??
          (dbProduct['maxPortion'] as num?)?.toDouble() ??
          maxPortion;
      portionStep =
          (dbProduct['portion_step'] as num?)?.toDouble() ??
          (dbProduct['portionStep'] as num?)?.toDouble() ??
          portionStep;
      defaultWeightGrams =
          (dbProduct['default_weight_grams'] as num?)?.toInt() ??
          (dbProduct['defaultWeightGrams'] as num?)?.toInt() ??
          defaultWeightGrams;
      minWeightGrams =
          (dbProduct['min_weight_grams'] as num?)?.toInt() ??
          (dbProduct['minWeightGrams'] as num?)?.toInt() ??
          minWeightGrams;
      weightStepGrams =
          (dbProduct['weight_step_grams'] as num?)?.toInt() ??
          (dbProduct['weightStepGrams'] as num?)?.toInt() ??
          weightStepGrams;
      maxWeightGrams =
          (dbProduct['max_weight_grams'] as num?)?.toInt() ??
          (dbProduct['maxWeightGrams'] as num?)?.toInt() ??
          maxWeightGrams;
      category ??= dbProduct['category']?.toString();
      category ??= dbProduct['main_category']?.toString();
      subCategory ??= dbProduct['sub_category']?.toString();
      subCategory ??= dbProduct['subCategory']?.toString();
      shortDescription ??=
          dbProduct['short_description']?.toString() ??
          dbProduct['shortDescription']?.toString();
      description ??= dbProduct['description']?.toString();
      specifications ??= _normalizeJsonText(dbProduct['specifications']);
      preparationTime ??=
          dbProduct['preparation_time']?.toString() ??
          dbProduct['preparationTime']?.toString();
      cookingTime ??=
          dbProduct['cooking_time']?.toString() ??
          dbProduct['cookingTime']?.toString();
      final rawStores = dbProduct['stores'];
      if (rawStores is Map) {
        store ??= rawStores['business_name']?.toString();
      } else if (rawStores is List && rawStores.isNotEmpty) {
        final firstStore = rawStores.first;
        if (firstStore is Map) {
          store ??= firstStore['business_name']?.toString();
        }
      }
      store ??= dbProduct['store']?.toString();
      store ??= dbProduct['store_name']?.toString();
      // Images — the object-style try/catch above silently fails for Map input
      // (Map has no .imageUrl property), so we read snake_case keys here.
      if (images.isEmpty) {
        final rawUrl = dbProduct['image_url']?.toString().trim();
        if (rawUrl != null && rawUrl.isNotEmpty) images.add(rawUrl);
      }
      if (images.isEmpty) {
        final rawUrls = dbProduct['image_urls'];
        if (rawUrls is List) {
          images.addAll(
            rawUrls
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty),
          );
        } else if (rawUrls is String && rawUrls.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawUrls.trim());
            if (decoded is List) {
              images.addAll(
                decoded
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty),
              );
            }
          } catch (_) {}
        }
      }
    }

    try {
      category = (dbProduct as dynamic).category?.toString();
    } catch (_) {}
    try {
      category ??= (dbProduct as dynamic).mainCategory?.toString();
    } catch (_) {}
    if (dbProduct is Map) {
      category ??= dbProduct['main_category']?.toString();
    }
    try {
      subCategory = (dbProduct as dynamic).subCategory?.toString();
    } catch (_) {}
    try {
      shortDescription = (dbProduct as dynamic).shortDescription?.toString();
    } catch (_) {}
    try {
      description = (dbProduct as dynamic).description?.toString();
    } catch (_) {}
    try {
      specifications = _normalizeJsonText(
        (dbProduct as dynamic).specifications,
      );
    } catch (_) {}
    try {
      preparationTime = (dbProduct as dynamic).preparationTime?.toString();
    } catch (_) {}
    try {
      cookingTime = (dbProduct as dynamic).cookingTime?.toString();
    } catch (_) {}
    try {
      oldPrice = (dbProduct as dynamic).oldPrice?.toString();
    } catch (_) {}
    try {
      variantOptions = (dbProduct as dynamic).variantOptions?.toString();
    } catch (_) {}
    try {
      variantGroupId = (dbProduct as dynamic).variantGroupId?.toString();
    } catch (_) {}

    final resolvedPricingType = ProductPricingType.fromValue(pricingType);
    final fallbackPrice = ProductPriceCalculator.parsePriceValue(price);
    if (resolvedPricingType == ProductPricingType.weight) {
      pricePerKg = ProductPriceCalculator.sanitizePrice(
        pricePerKg ?? fallbackPrice,
      );
    } else {
      portionPrice = ProductPriceCalculator.sanitizePrice(
        portionPrice ?? fallbackPrice,
      );
    }

    return Product(
      productId: productId,
      name: name,
      brand: brand,
      price: price,
      pricingMode: pricingMode,
      basePrice: basePrice,
      pricingType: resolvedPricingType.storageValue,
      portionPrice: portionPrice,
      pricePerKg: pricePerKg,
      sizeOptions: sizeOptions,
      selectedSizeName: selectedSizeName,
      selectedSizePrice: selectedSizePrice,
      serviceControlType: serviceControlType,
      minPortion: minPortion,
      maxPortion: maxPortion,
      portionStep: portionStep,
      defaultWeightGrams: defaultWeightGrams,
      minWeightGrams: minWeightGrams,
      weightStepGrams: weightStepGrams,
      maxWeightGrams: maxWeightGrams,
      rating: rating,
      reviewCount: reviewCount,
      tags: tags,
      images: images,
      isDigital: false,
      store: store,
      sellerId: sellerId,
      category: category,
      subCategory: subCategory,
      shortDescription: shortDescription,
      description: description,
      specifications: specifications,
      preparationTime: preparationTime,
      cookingTime: cookingTime,
      ingredients: _parseStringList(
        dbProduct is Map ? dbProduct['ingredients'] : null,
      ),
      features: _parseStringList(
        dbProduct is Map ? dbProduct['features'] : null,
      ),
      oldPrice: oldPrice,
      variantOptions: variantOptions,
      variantGroupId: variantGroupId,
      accessories: accessories,
      attributes: attributes,
      videoUrl: parsedVideoUrl,
      videoPath: parsedVideoPath,
      videoPublicUrl: parsedVideoPublicUrl,
      thumbnailPath: parsedThumbnailPath,
      thumbnailPublicUrl: parsedThumbnailPublicUrl,
      videoDurationSeconds: parsedVideoDurationSeconds,
      videoSizeBytes: parsedVideoSizeBytes,
      thumbnailSizeBytes: parsedThumbnailSizeBytes,
      videoStatus: parsedVideoStatus,
      variants: variants,
      additionalInfo: additionalInfo,
      faq: faq,
    );
  }

  // Helper method for Video Button
  bool get hasVideo {
    // Debug print
    // print('Product hasVideo check: videoUrl=$videoUrl'); // DIAGNOSTIC STEP 3
    return videoUrl != null && videoUrl!.trim().isNotEmpty;
  }

  ProductPricingType get resolvedPricingType =>
      ProductPricingType.fromValue(pricingType);

  ProductPricingMode get resolvedPricingMode =>
      ProductPriceCalculator.resolvePricingMode(
        explicitMode: pricingMode,
        basePrice: effectiveBaseUnitPrice,
        pricePerKg: pricePerKg,
        sizeOptions: sizeOptions,
      );

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

  bool get usesWeightSelector =>
      resolvedServiceControlType == ProductServiceControlType.weightStepper;

  bool get hasWeightPricing =>
      ProductPriceCalculator.sanitizePrice(pricePerKg) > 0;

  List<ProductSizeOption> get normalizedSizeOptions =>
      ProductPriceCalculator.normalizeSizeOptions(sizeOptions);

  bool get hasSizeOptions => normalizedSizeOptions.isNotEmpty;

  ProductSizeOption? get defaultSizeOption =>
      ProductPriceCalculator.defaultSizeOption(normalizedSizeOptions);

  double get effectivePricePerKg {
    final direct = ProductPriceCalculator.sanitizePrice(pricePerKg);
    if (direct > 0) return direct;
    if (usesWeightSelector) {
      return ProductPriceCalculator.parsePriceValue(price);
    }
    return 0;
  }

  bool get isWeightPriced => hasWeightPricing;

  double get effectivePortionPrice {
    final direct = ProductPriceCalculator.sanitizePrice(portionPrice);
    if (direct > 0) return direct;
    return ProductPriceCalculator.parsePriceValue(price);
  }

  double get effectiveBaseUnitPrice {
    final direct = ProductPriceCalculator.sanitizePrice(basePrice);
    if (direct > 0) return direct;
    final portionDirect = ProductPriceCalculator.sanitizePrice(portionPrice);
    if (portionDirect > 0) return portionDirect;
    final selectedDefaultSize = defaultSizeOption;
    if (selectedDefaultSize != null && !hasWeightPricing) {
      return ProductPriceCalculator.sanitizePrice(selectedDefaultSize.price);
    }
    return effectivePortionPrice;
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

  int get resolvedMinWeightGrams =>
      ProductPriceCalculator.resolveMinWeightGrams(minWeightGrams);

  int get resolvedWeightStepGrams =>
      ProductPriceCalculator.resolveWeightStepGrams(weightStepGrams);

  int get resolvedDefaultWeightGrams =>
      ProductPriceCalculator.resolveDefaultWeightGrams(
        defaultWeightGrams: defaultWeightGrams,
        minWeightGrams: minWeightGrams,
        weightStepGrams: weightStepGrams,
        maxWeightGrams: maxWeightGrams,
      );

  String get displayPricingText {
    final defaultSize = defaultSizeOption;
    if (defaultSize != null && effectiveBaseUnitPrice <= 0 && !hasWeightPricing) {
      return ProductPriceCalculator.formatCurrency(defaultSize.price);
    }
    if (hasWeightPricing && !hasSizeOptions) {
      return ProductPriceCalculator.formatPerKgLabel(effectivePricePerKg);
    }
    return ProductPriceCalculator.formatCurrency(effectiveBaseUnitPrice);
  }

  String? get displayWeightInfo {
    if (!usesWeightSelector) return null;
    return ProductPriceCalculator.buildWeightRangeLabel(
      minWeightGrams: minWeightGrams,
      defaultWeightGrams: defaultWeightGrams,
    );
  }

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

  String? get displayCategory {
    final sub = subCategory?.trim() ?? '';
    if (sub.isNotEmpty) return sub;
    final main = category?.trim() ?? '';
    return main.isEmpty ? null : main;
  }

  String? get displayPreparationTime {
    final directCooking = _formatPreparationDuration(cookingTime);
    if (directCooking != null) return directCooking;
    final directPreparation = _formatPreparationDuration(preparationTime);
    if (directPreparation != null) return directPreparation;
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'preparation_time',
      'preparationTime',
      'cooking_time',
      'cookingTime',
      'estimated_ready_time',
      'estimatedReadyTime',
      'ready_time',
      'readyTime',
      'delivery_time',
      'deliveryTime',
      'hazirlanma_suresi',
      'hazirlanma',
      'pişme_suresi',
      'pisme_suresi',
      'pişme',
      'pisme',
      'teslim_suresi',
      'teslim',
    ]) {
      final value = _formatPreparationDuration(specMap[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? get displayPreparationTimeLabel {
    final specMap = _decodedSpecificationsMap();
    if (_normalizedText(cookingTime) != null ||
        _firstMatchingSpecValue(specMap, const [
              'cooking_time',
              'cookingTime',
              'pişme_suresi',
              'pisme_suresi',
              'pişme',
              'pisme',
            ]) !=
            null) {
      return 'Pişme süresi';
    }
    if (_normalizedText(preparationTime) != null ||
        _firstMatchingSpecValue(specMap, const [
              'preparation_time',
              'preparationTime',
              'hazirlanma_suresi',
              'hazirlanma',
            ]) !=
            null) {
      return 'Hazırlanma';
    }
    if (_firstMatchingSpecValue(specMap, const [
          'estimated_ready_time',
          'estimatedReadyTime',
          'ready_time',
          'readyTime',
          'delivery_time',
          'deliveryTime',
          'teslim_suresi',
          'teslim',
        ]) !=
        null) {
      return 'Teslim süresi';
    }
    return null;
  }

  String? get displayPreparationInfoText {
    final duration = displayPreparationTime;
    if (duration == null) return null;
    final label = displayPreparationTimeLabel ?? 'Hazırlanma';
    return '$label: $duration';
  }

  String? get displayShortDescription {
    final directShort = _normalizedText(shortDescription);
    if (directShort != null) return directShort;
    final directDescription = _normalizedText(description);
    if (directDescription != null) return directDescription;
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'short_description',
      'shortDescription',
      'description',
      'aciklama',
    ]) {
      final value = _normalizedText(specMap[key]);
      if (value != null) return value;
    }
    return null;
  }

  List<String> get displayFeatures {
    final directFeatures = _cleanStringList(features);
    if (directFeatures.isNotEmpty) return directFeatures;
    final directAttributes = _cleanStringList(attributes);
    if (directAttributes.isNotEmpty) return directAttributes;
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'features',
      'feature',
      'ozellikler',
      'özellikler',
    ]) {
      final value = _cleanStringList(_parseStringList(specMap[key]));
      if (value.isNotEmpty) return value;
    }
    return const [];
  }

  List<String> get displayIngredients {
    final directIngredients = _cleanStringList(ingredients);
    if (directIngredients.isNotEmpty) return directIngredients;
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'ingredients',
      'ingredient_list',
      'icerik',
      'içerik',
      'malzeme',
      'malzemeler',
    ]) {
      final value = _cleanStringList(_parseStringList(specMap[key]));
      if (value.isNotEmpty) return value;
    }
    return const [];
  }

  String? get displayFullDescription {
    final directDescription = _normalizedText(description);
    if (directDescription != null) return directDescription;
    final directShort = _normalizedText(shortDescription);
    if (directShort != null) return directShort;
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'description',
      'short_description',
      'shortDescription',
      'aciklama',
    ]) {
      final value = _normalizedText(specMap[key]);
      if (value != null) return value;
    }
    return null;
  }

  List<String> get displayAdditionalInfoItems {
    final directAdditional = _parseStringList(additionalInfo);
    if (directAdditional != null && directAdditional.isNotEmpty) {
      return directAdditional;
    }
    final specMap = _decodedSpecificationsMap();
    for (final key in const [
      'additional_info',
      'additionalInfo',
      'notes',
      'notlar',
      'sunum',
    ]) {
      final value = _cleanStringList(_parseStringList(specMap[key]));
      if (value.isNotEmpty) return value;
    }
    return const [];
  }

  List<String> get displayServiceInfo {
    final specMap = _decodedSpecificationsMap();
    final items = <String>[];
    final selectionInfo = displayServiceControlInfo;

    if (selectionInfo != null) {
      items.add('Secim: $selectionInfo');
    }

    final serviceType = _firstMatchingSpecValue(specMap, const [
      'service_type',
      'serviceType',
      'servis_tipi',
      'servisTipi',
    ]);
    final serviceTime = _firstMatchingSpecValue(specMap, const [
      'service_time',
      'serviceTime',
      'servis_zamani',
      'servisZamani',
    ]);
    final serviceInfo = _firstMatchingSpecValue(specMap, const [
      'service_info',
      'serviceInfo',
      'servis_bilgisi',
      'servisBilgisi',
    ]);

    if (serviceType != null) {
      items.add('Servis: $serviceType');
    }
    if (serviceTime != null) {
      items.add('Zaman: $serviceTime');
    }
    if (serviceInfo != null) {
      items.add(serviceInfo);
    }

    return items;
  }

  Map<String, dynamic> _decodedSpecificationsMap() {
    final raw = specifications?.trim() ?? '';
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  String? _firstMatchingSpecValue(
    Map<String, dynamic> specMap,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _normalizedText(specMap[key]);
      if (value != null) return value;
    }
    return null;
  }

  static String? _normalizeJsonText(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is Map || raw is List) {
      return jsonEncode(raw);
    }
    final text = raw.toString().trim();
    return text.isEmpty ? null : text;
  }

  static List<String>? _parseStringList(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return _cleanStringList(raw.map((e) => e?.toString()).toList());
    }
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return _cleanStringList(decoded.map((e) => e?.toString()).toList());
        }
      } catch (_) {}
    }
    return _cleanStringList(text.split(RegExp(r'[\n,|•]')));
  }

  static List<String> _cleanStringList(List<String?>? values) {
    if (values == null) return const [];
    return values
        .map((e) => e?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  static String? _normalizedText(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _formatPreparationDuration(dynamic raw) {
    if (raw is num) {
      final minutes = raw.toInt();
      return minutes > 0 ? formatPreparationTime(minutes) : null;
    }

    final text = _normalizedText(raw);
    if (text == null) return null;
    if (RegExp(r'^\d+$').hasMatch(text)) {
      final minutes = int.parse(text);
      return minutes > 0 ? formatPreparationTime(minutes) : null;
    }
    return text;
  }

  // UI Helper methods to ensure consistency across pages
  String getDisplayDescription() {
    final lowerName = name.toLowerCase();
    final lowerBrand = brand.toLowerCase();
    final lowerCategory = (category ?? '').toLowerCase();
    final lowerSubCategory = (subCategory ?? '').toLowerCase();
    final isLaptop =
        lowerName.contains('macbook') ||
        lowerName.contains('laptop') ||
        lowerName.contains('notebook') ||
        lowerSubCategory.contains('bilgisayar') ||
        lowerCategory.contains('bilgisayar');
    final isPhone =
        lowerName.contains('iphone') ||
        lowerName.contains('telefon') ||
        lowerSubCategory.contains('telefon') ||
        lowerCategory.contains('telefon') ||
        lowerSubCategory.contains('cep telefonu');

    // Ürün adına göre farklı açıklamalar (Hardcoded logic from ProductDetailPage)
    if (brand.contains('Uf') || name.contains('CT-23')) {
      return 'UFO City CT-23 2300W İnfrared tipi ayaklı ısıtıcı, modern tasarımı ve güçlü ısıtma kapasitesi ile yaşam alanlarınızda konfor sağlar. Enerji tasarruflu teknolojisi sayesinde ekonomik kullanım sunar.';
    } else if (brand.contains('Haylou') || name.contains('Solar')) {
      return 'Haylou Solar Plus RT3 akıllı saati, 1.43 inç AMOLED ekranı, 105+ spor modu ve 14 güne kadar pil ömrü ile sağlıklı yaşamınızı takip edin. Bluetooth arama, müzik kontrolü ve sağlık izleme özellikleri sunar.';
    } else if (isLaptop) {
      return displayShortDescription ??
          '$brand $name, günlük kullanım ve profesyonel işler için güçlü performans sunar. Yüksek ekran kalitesi, hızlı depolama ve uzun pil ömrüyle taşınabilir verimli bir deneyim sağlar.';
    } else if (name.toLowerCase().contains('iphone 15 pro max')) {
      return 'Apple iPhone 15 Pro Max, A17 Pro çip, 5G desteği, 48MP üçlü kamera sistemi ve Super Retina XDR OLED ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayabilirsiniz.\n\n• 3500 mAh aralığında güçlü batarya kapasitesi ile uzun süreli kullanım imkanı sunar\n\n• 6,1 inç geniş ekranı sayesinde geniş ve net görüntüler elde edilir\n\n• Parmak izi okuyucu özelliği ile cihaz güvenliğini artırır ve hızlı erişim sağlar\n\n• 2 yıl Apple Türkiye garantisi ile güvenilir servis ve destek hizmetlerinden faydalanabilirsiniz\n\n• NFC desteği ile temasız işlemleri kolayca gerçekleştirebilirsiniz\n\n• iOS işletim sistemi, stabil ve kullanıcı dostu bir deneyim sunar\n\n• Çift hat özelliğiyle iki farklı numarayı aynı anda kullanma olanağı sağlar\n\n• Ultra HD 8K video kaydı yapabilme kapasitesine sahip kamera ile yüksek kaliteli görüntüler yakalayabilirsiniz\n\n• Dokunmatik ekran teknolojisi, akıcı ve hassas bir dokunma deneyimi sunar\n\n• 20 MP ve üstü kamera çözünürlüğüyle profesyonel kalitede fotoğraflar çekebilirsiniz\n\n• Yüz tanıma sistemi sayesinde cihaz kilidini hızlıca açabilirsiniz\n\n• Suya ve toza karşı dayanıklılık özellikleri';
    } else if ((lowerBrand.contains('apple') && isPhone) ||
        lowerName.contains('iphone')) {
      return 'Apple iPhone 13, 5G desteği, A15 Bionic çip, 12MP çift kamera sistemi ve Super Retina XDR ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayabilirsiniz.\n\n• 3500 mAh aralığında güçlü batarya kapasitesi ile uzun süreli kullanım imkanı sunar\n\n• 6,1 inç geniş ekranı sayesinde geniş ve net görüntüler elde edilir\n\n• Parmak izi okuyucu özelliği ile cihaz güvenliğini artırır ve hızlı erişim sağlar\n\n• 2 yıl Apple Türkiye garantisi ile güvenilir servis ve destek hizmetlerinden faydalanabilirsiniz\n\n• NFC desteği ile temasız işlemleri kolayca gerçekleştirebilirsiniz\n\n• iOS işletim sistemi, stabil ve kullanıcı dostu bir deneyim sunar\n\n• Çift hat özelliğiyle iki farklı numarayı aynı anda kullanma olanağı sağlar\n\n• Ultra HD 8K video kaydı yapabilme kapasitesine sahip kamera ile yüksek kaliteli görüntüler yakalayabilirsiniz\n\n• Dokunmatik ekran teknolojisi, akıcı ve hassas bir dokunma deneyimi sunar\n\n• 20 MP ve üstü kamera çözünürlüğüyle profesyonel kalitede fotoğraflar çekebilirsiniz\n\n• Yüz tanıma sistemi sayesinde cihaz kilidini hızlıca açabilirsiniz\n\n• Suya ve toza karşı dayanıklılık özellikleri';
    } else {
      return displayShortDescription ??
          'Ürün hakkında detaylı bilgi için mağazamızı ziyaret edebilir veya müşteri hizmetlerimizle iletişime geçebilirsiniz.';
    }
  }

  String getDisplaySpecs() {
    final lowerName = name.toLowerCase();
    final lowerBrand = brand.toLowerCase();
    final lowerCategory = (category ?? '').toLowerCase();
    final lowerSubCategory = (subCategory ?? '').toLowerCase();
    final isLaptop =
        lowerName.contains('macbook') ||
        lowerName.contains('laptop') ||
        lowerName.contains('notebook') ||
        lowerSubCategory.contains('bilgisayar') ||
        lowerCategory.contains('bilgisayar');
    final isPhone =
        lowerName.contains('iphone') ||
        lowerName.contains('telefon') ||
        lowerSubCategory.contains('telefon') ||
        lowerCategory.contains('telefon') ||
        lowerSubCategory.contains('cep telefonu');

    // Ürün adına göre farklı özellikler (Hardcoded logic from ProductDetailPage)
    if (brand.contains('Uf') || name.contains('CT-23')) {
      return 'Güç: 2300W\nRenk: Siyah\nTip: İnfrared Ayaklı Isıtıcı\nBoyutlar: 180cm Yükseklik\nGaranti: 2 Yıl';
    } else if (brand.contains('Haylou') || name.contains('Solar')) {
      return 'Ekran: 1.43" AMOLED\nPil Ömrü: 14 gün\nSu Geçirmezlik: 5ATM\nSpor Modu: 105+\nBluetooth: 5.0\nGaranti: 2 Yıl';
    } else if (isLaptop) {
      return specifications ??
          'Ekran: 13.6" Liquid Retina\n'
              'Çip: Apple M2\n'
              'Bellek: 8 GB\n'
              'Depolama: 256 GB SSD\n'
              'Bağlantı: Wi-Fi 6, Bluetooth 5.0\n'
              'Pil Ömrü: 18 saate kadar\n'
              'İşletim Sistemi: macOS\n'
              'Garanti: 2 Yıl';
    } else if ((lowerBrand.contains('apple') && isPhone) ||
        lowerName.contains('iphone')) {
      return 'Ekran: 6.1" Super Retina XDR\n'
          'Çözünürlük: 2532 x 1170 piksel, 460 ppi\n'
          'Çip: A15 Bionic, 6 çekirdekli CPU\n'
          'Depolama: 128GB\n'
          'Arka Kamera: 12MP Çift (Geniş + Ultra Geniş)\n'
          'Ön Kamera: 12MP TrueDepth\n'
          'Video: 4K Dolby Vision HDR, 60fps\n'
          'Biyometrik: Face ID yüz tanıma\n'
          'Bağlantı: 5G, Wi-Fi 6, Bluetooth 5.0, NFC\n'
          'SIM: Nano-SIM + eSIM (Çift SIM desteği)\n'
          'Su/Toz Dayanıklılık: IP68 (6m, 30dk)\n'
          'Batarya: 3240 mAh, 20W hızlı şarj\n'
          'Kablosuz Şarj: MagSafe 15W, Qi 7.5W\n'
          'İşletim Sistemi: iOS 17\n'
          'Boyutlar: 146.7 x 71.5 x 7.65 mm\n'
          'Ağırlık: 174 g\n'
          'Renk Seçenekleri: Siyah, Beyaz, Mavi, Kırmızı\n'
          'Garanti: 2 Yıl Apple Türkiye Garantisi';
    } else if (lowerBrand.contains('samsung') && isPhone) {
      return specifications ??
          'Ekran: 6.8" Dynamic AMOLED\n'
              'Çözünürlük: 3120 x 1440 piksel\n'
              'İşlemci: Snapdragon 8 Gen 3\n'
              'Depolama: 256 GB\n'
              'RAM: 12 GB\n'
              'Kamera: 200 MP + 12 MP + 10 MP\n'
              'Bağlantı: 5G, Wi-Fi 6E, Bluetooth 5.3\n'
              'Pil: 5000 mAh\n'
              'Garanti: 2 Yıl Samsung Türkiye Garantili';
    } else {
      return specifications ??
          'Detaylı özellikler için mağazamızı ziyaret edin.';
    }
  }
}

/// Convenience extension for CDN-transformed image URLs on [Product].
extension ProductImageX on Product {
  /// Returns a CDN-transformed URL for this product's primary image.
  ///
  /// Falls back to [thumbnailPublicUrl] when [images] is empty, then returns
  /// an empty string. The variant controls the size/quality applied by the CDN.
  String imageFor(AppImageVariant variant) {
    final raw = images.isNotEmpty
        ? images.first.trim()
        : (thumbnailPublicUrl?.trim() ?? '');
    if (raw.isEmpty) return '';
    return AppImageCdn.buildUrl(raw, variant);
  }
}
