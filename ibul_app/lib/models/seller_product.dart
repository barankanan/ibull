class SellerProduct {
  final String id;
  final String name;
  final String brand;
  final String mainCategory;
  final String subCategory;
  final double price;
  final double? discountPrice;
  final int stock;
  final String sku;
  final String status;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? description;
  final String? specifications;
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
  final List<Map<String, String>>? faq; // New: Sıkça Sorulan Sorular
  final String? stationId;
  final bool printerRoutingEnabled;

  SellerProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.mainCategory,
    required this.subCategory,
    required this.price,
    this.discountPrice,
    required this.stock,
    required this.sku,
    required this.status,
    this.imageUrl,
    this.imageUrls = const [],
    this.description,
    this.specifications,
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
    this.faq,
    this.stationId,
    this.printerRoutingEnabled = true,
  });

  String get displayPrice {
    if (discountPrice != null && discountPrice! > 0) {
      return '₺${discountPrice!.toStringAsFixed(0)}';
    }
    return '₺${price.toStringAsFixed(0)}';
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
      'subCategory': subCategory,
      'price': price,
      'discountPrice': discountPrice,
      'stock': stock,
      'sku': sku,
      'status': status,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'description': description,
      'specifications': specifications,
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
      'faq': faq,
      'stationId': stationId,
      'printerRoutingEnabled': printerRoutingEnabled,
    };
  }

  factory SellerProduct.fromMap(Map<String, dynamic> map, String id) {
    print('DB Verisi (SellerProduct): $map'); // Debug Print

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

    return SellerProduct(
      id: id,
      name: map['name'] ?? '',
      brand: map['brand'] ?? '',
      mainCategory:
          map['main_category'] ?? map['mainCategory'] ?? map['category'] ?? '',
      subCategory: map['sub_category'] ?? map['subCategory'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      discountPrice: (map['discount_price'] ?? map['discountPrice'] as num?)
          ?.toDouble(),
      stock: map['stock'] ?? 0,
      sku: map['sku'] ?? '',
      status: map['status'] ?? 'Aktif',
      imageUrl: mainImg,
      imageUrls: imgUrls,
      description: map['description'],
      specifications: map['specifications']?.toString(),
      createdAt: created,
      attributes: map['attributes'] != null
          ? List<String>.from(map['attributes'])
          : [],
      storeName: map['store_name'],
      videoUrl:
          map['video_public_url'] ??
          map['video_url'], // DB column name usually snake_case
      videoPath: map['video_path'],
      videoPublicUrl: map['video_public_url'],
      thumbnailPath: map['thumbnail_path'],
      thumbnailPublicUrl: map['thumbnail_public_url'],
      videoDurationSeconds: (map['video_duration_seconds'] as num?)?.toInt(),
      videoSizeBytes: (map['video_size_bytes'] as num?)?.toInt(),
      thumbnailSizeBytes: (map['thumbnail_size_bytes'] as num?)?.toInt(),
      videoStatus: map['video_status'],
      variants: map['variants'], // DB column name usually snake_case
      accessories: map['accessories'] != null
          ? List<String>.from(map['accessories'])
          : null,
      additionalInfo: map['additional_info'],
      faq: map['faq'] != null
          ? (map['faq'] as List)
                .map((e) => Map<String, String>.from(e))
                .toList()
          : null,
      stationId: map['station_id']?.toString(),
      printerRoutingEnabled: map['printer_routing_enabled'] != false,
    );
  }
}
