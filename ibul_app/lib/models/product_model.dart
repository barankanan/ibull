import 'dart:convert';

class Product {
  final String? productId;
  final String name;
  final String brand;
  final String price;
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
  final String? description;
  final String? specifications;
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
    this.description,
    this.specifications,
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
    String? description,
    String? specifications,
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
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
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
      'description': description,
      'specifications': specifications,
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
      description: json['description'],
      specifications: json['specifications'],
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
    } catch (e) {}

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
    double rating = 0.0;
    int reviewCount = 0;
    String? store;
    String? sellerId;
    String? category;
    String? subCategory;
    String? description;
    String? specifications;
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
      category ??= dbProduct['category']?.toString();
      category ??= dbProduct['main_category']?.toString();
      subCategory ??= dbProduct['sub_category']?.toString();
      subCategory ??= dbProduct['subCategory']?.toString();
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
      description = (dbProduct as dynamic).description?.toString();
    } catch (_) {}
    try {
      specifications = (dbProduct as dynamic).specifications?.toString();
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

    return Product(
      productId: productId,
      name: name,
      brand: brand,
      price: price,
      rating: rating,
      reviewCount: reviewCount,
      tags: tags,
      images: images,
      isDigital: false,
      store: store,
      sellerId: sellerId,
      category: category,
      subCategory: subCategory,
      description: description,
      specifications: specifications,
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
      return description ??
          '$brand $name, günlük kullanım ve profesyonel işler için güçlü performans sunar. Yüksek ekran kalitesi, hızlı depolama ve uzun pil ömrüyle taşınabilir verimli bir deneyim sağlar.';
    } else if (name.toLowerCase().contains('iphone 15 pro max')) {
      return 'Apple iPhone 15 Pro Max, A17 Pro çip, 5G desteği, 48MP üçlü kamera sistemi ve Super Retina XDR OLED ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayabilirsiniz.\n\n• 3500 mAh aralığında güçlü batarya kapasitesi ile uzun süreli kullanım imkanı sunar\n\n• 6,1 inç geniş ekranı sayesinde geniş ve net görüntüler elde edilir\n\n• Parmak izi okuyucu özelliği ile cihaz güvenliğini artırır ve hızlı erişim sağlar\n\n• 2 yıl Apple Türkiye garantisi ile güvenilir servis ve destek hizmetlerinden faydalanabilirsiniz\n\n• NFC desteği ile temasız işlemleri kolayca gerçekleştirebilirsiniz\n\n• iOS işletim sistemi, stabil ve kullanıcı dostu bir deneyim sunar\n\n• Çift hat özelliğiyle iki farklı numarayı aynı anda kullanma olanağı sağlar\n\n• Ultra HD 8K video kaydı yapabilme kapasitesine sahip kamera ile yüksek kaliteli görüntüler yakalayabilirsiniz\n\n• Dokunmatik ekran teknolojisi, akıcı ve hassas bir dokunma deneyimi sunar\n\n• 20 MP ve üstü kamera çözünürlüğüyle profesyonel kalitede fotoğraflar çekebilirsiniz\n\n• Yüz tanıma sistemi sayesinde cihaz kilidini hızlıca açabilirsiniz\n\n• Suya ve toza karşı dayanıklılık özellikleri';
    } else if ((lowerBrand.contains('apple') && isPhone) ||
        lowerName.contains('iphone')) {
      return 'Apple iPhone 13, 5G desteği, A15 Bionic çip, 12MP çift kamera sistemi ve Super Retina XDR ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayabilirsiniz.\n\n• 3500 mAh aralığında güçlü batarya kapasitesi ile uzun süreli kullanım imkanı sunar\n\n• 6,1 inç geniş ekranı sayesinde geniş ve net görüntüler elde edilir\n\n• Parmak izi okuyucu özelliği ile cihaz güvenliğini artırır ve hızlı erişim sağlar\n\n• 2 yıl Apple Türkiye garantisi ile güvenilir servis ve destek hizmetlerinden faydalanabilirsiniz\n\n• NFC desteği ile temasız işlemleri kolayca gerçekleştirebilirsiniz\n\n• iOS işletim sistemi, stabil ve kullanıcı dostu bir deneyim sunar\n\n• Çift hat özelliğiyle iki farklı numarayı aynı anda kullanma olanağı sağlar\n\n• Ultra HD 8K video kaydı yapabilme kapasitesine sahip kamera ile yüksek kaliteli görüntüler yakalayabilirsiniz\n\n• Dokunmatik ekran teknolojisi, akıcı ve hassas bir dokunma deneyimi sunar\n\n• 20 MP ve üstü kamera çözünürlüğüyle profesyonel kalitede fotoğraflar çekebilirsiniz\n\n• Yüz tanıma sistemi sayesinde cihaz kilidini hızlıca açabilirsiniz\n\n• Suya ve toza karşı dayanıklılık özellikleri';
    } else {
      return description ??
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
