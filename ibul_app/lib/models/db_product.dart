import 'dart:convert';

import 'product_pricing.dart';

class DBProduct {
  final String? id;
  final String? sellerId;
  final String name;
  final String brand;
  final String? store; // Mağaza adı
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
  final String? oldPrice;
  final double rating;
  final int reviewCount;
  final String imageUrl; // Ana resim
  final String? imageUrls; // JSON array - birden fazla resim
  final String category; // Ana kategori
  final String? subCategory; // Alt kategori
  final String tags; // JSON array - ["Ücretsiz Kargo", "İndirimde"]
  final String? keywords; // Anahtar kelimeler (arama için) - virgülle ayrılmış
  final String? description; // Ürün açıklaması
  final String?
  specifications; // JSON object - {"RAM": "8GB", "Depolama": "256GB", "Ekran": "6.7 inç"}
  final bool isPart; // Parça mı? (2.el ürünler için)
  final String?
  damagedParts; // Hasarlı parçalar (virgülle ayrılmış) - "ekran,batarya,kamera"
  final String?
  variantGroupId; // Varyant grup ID'si - aynı grup ID'li ürünler varyant olarak gösterilir
  final String?
  variantOptions; // Varyant seçenekleri (pipe ayrılmış) - "Renk:Siyah|Depolama:512GB"
  final int? stock; // Stok miktarı
  final bool isActive; // Ürün aktif mi?
  final String? attributes;
  final String? videoUrl; // Video URL (Supabase video_url)
  final String? videoPath;
  final String? videoPublicUrl;
  final String? thumbnailPath;
  final String? thumbnailPublicUrl;
  final int? videoDurationSeconds;
  final int? videoSizeBytes;
  final int? thumbnailSizeBytes;
  final String? videoStatus;
  final dynamic variants; // JSON List (Supabase variants)

  DBProduct({
    this.id,
    this.sellerId,
    required this.name,
    required this.brand,
    this.store,
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
    this.oldPrice,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
    this.imageUrls,
    required this.category,
    this.subCategory,
    required this.tags,
    this.keywords,
    this.description,
    this.specifications,
    this.isPart = false,
    this.damagedParts,
    this.variantGroupId,
    this.variantOptions,
    this.stock,
    this.isActive = true,
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
  });

  // Database'e kaydetmek için Map'e çevir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'brand': brand,
      'store': store,
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
      'oldPrice': oldPrice,
      'rating': rating,
      'reviewCount': reviewCount,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'category': category,
      'subCategory': subCategory,
      'tags': tags,
      'keywords': keywords,
      'description': description,
      'specifications': specifications,
      'isPart': isPart ? 1 : 0,
      'damagedParts': damagedParts,
      'variantGroupId': variantGroupId,
      'variantOptions': variantOptions,
      'stock': stock,
      'isActive': isActive ? 1 : 0,
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
    };
  }

  // Database'den okumak için Map'ten oluştur
  factory DBProduct.fromMap(Map<String, dynamic> map) {
    final isPartRaw = map['isPart'];
    final isActiveRaw = map['isActive'];
    return DBProduct(
      id: map['id']?.toString(),
      sellerId: map['sellerId']?.toString() ?? map['seller_id']?.toString(),
      name: map['name'] as String,
      brand: map['brand'] as String,
      store: map['store'] as String?,
      price: map['price'] as String,
        pricingMode:
          map['pricing_mode']?.toString() ??
          map['pricingMode']?.toString() ??
          ProductPriceCalculator.resolvePricingMode(
          basePrice:
            (map['base_price'] as num?)?.toDouble() ??
            (map['basePrice'] as num?)?.toDouble() ??
            (map['portion_price'] as num?)?.toDouble() ??
            (map['portionPrice'] as num?)?.toDouble(),
          pricePerKg:
            (map['price_per_kg'] as num?)?.toDouble() ??
            (map['pricePerKg'] as num?)?.toDouble(),
          sizeOptions: ProductSizeOption.listFromDynamic(
            map['size_options'] ?? map['sizeOptions'],
          ),
          ).storageValue,
        basePrice:
          (map['base_price'] as num?)?.toDouble() ??
          (map['basePrice'] as num?)?.toDouble() ??
          (map['portion_price'] as num?)?.toDouble() ??
          (map['portionPrice'] as num?)?.toDouble(),
      pricingType:
          map['pricing_type']?.toString() ??
          map['pricingType']?.toString() ??
          'portion',
      portionPrice:
          (map['portion_price'] as num?)?.toDouble() ??
          (map['portionPrice'] as num?)?.toDouble(),
      pricePerKg:
          (map['price_per_kg'] as num?)?.toDouble() ??
          (map['pricePerKg'] as num?)?.toDouble(),
        sizeOptions: ProductSizeOption.listFromDynamic(
        map['size_options'] ?? map['sizeOptions'],
        ),
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
      oldPrice: map['oldPrice'] as String?,
      rating: (map['rating'] as num).toDouble(),
      reviewCount: (map['reviewCount'] as num).toInt(),
      imageUrl: map['imageUrl'] as String,
      imageUrls: map['imageUrls'] as String?,
      category: map['category'] as String,
      subCategory: map['subCategory'] as String?,
      tags: map['tags'] as String,
      keywords: map['keywords'] as String?,
      description: map['description'] as String?,
      specifications: _normalizeSpecifications(map['specifications']),
      isPart: isPartRaw is bool ? isPartRaw : isPartRaw == 1,
      damagedParts: map['damagedParts'] as String?,
      variantGroupId: map['variantGroupId'] as String?,
      variantOptions: map['variantOptions'] as String?,
      stock: (map['stock'] as num?)?.toInt(),
      isActive: isActiveRaw is bool ? isActiveRaw : isActiveRaw == 1,
      attributes: map['attributes'] as String?,
      videoUrl:
          map['video_public_url'] as String? ??
          map['video_url'] as String? ??
          map['videoUrl'] as String?,
      videoPath: map['video_path'] as String?,
      videoPublicUrl: map['video_public_url'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      thumbnailPublicUrl: map['thumbnail_public_url'] as String?,
      videoDurationSeconds: (map['video_duration_seconds'] as num?)?.toInt(),
      videoSizeBytes: (map['video_size_bytes'] as num?)?.toInt(),
      thumbnailSizeBytes: (map['thumbnail_size_bytes'] as num?)?.toInt(),
      videoStatus: map['video_status'] as String?,
      variants: map['variants'],
    );
  }

  // Kopyalama fonksiyonu (güncelleme için)
  DBProduct copyWith({
    String? id,
    String? sellerId,
    String? name,
    String? brand,
    String? store,
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
    String? oldPrice,
    double? rating,
    int? reviewCount,
    String? imageUrl,
    String? imageUrls,
    String? category,
    String? subCategory,
    String? tags,
    String? keywords,
    String? description,
    String? specifications,
    bool? isPart,
    String? damagedParts,
    String? variantGroupId,
    String? variantOptions,
    int? stock,
    bool? isActive,
    String? attributes,
    String? videoUrl,
    String? videoPath,
    String? videoPublicUrl,
    String? thumbnailPath,
    String? thumbnailPublicUrl,
    int? videoDurationSeconds,
    int? videoSizeBytes,
    int? thumbnailSizeBytes,
    String? videoStatus,
    dynamic variants,
  }) {
    return DBProduct(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      store: store ?? this.store,
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
      oldPrice: oldPrice ?? this.oldPrice,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      tags: tags ?? this.tags,
      keywords: keywords ?? this.keywords,
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
      isPart: isPart ?? this.isPart,
      damagedParts: damagedParts ?? this.damagedParts,
      variantGroupId: variantGroupId ?? this.variantGroupId,
      variantOptions: variantOptions ?? this.variantOptions,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
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
    );
  }

  // Varyant seçeneklerini Map olarak parse et
  Map<String, String> getVariantOptionsMap() {
    if (variantOptions == null || variantOptions!.isEmpty) {
      return {};
    }

    try {
      final options = <String, String>{};
      final pairs = variantOptions!.split('|');
      for (var pair in pairs) {
        final keyValue = pair.split(':');
        if (keyValue.length == 2) {
          options[keyValue[0].trim()] = keyValue[1].trim();
        }
      }
      return options;
    } catch (e) {
      return {};
    }
  }

  @override
  String toString() {
    return 'DBProduct(id: $id, sellerId: $sellerId, name: $name, brand: $brand, price: $price)';
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
}
