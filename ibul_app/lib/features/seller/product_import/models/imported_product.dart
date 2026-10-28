import 'dart:convert';

/// Veri kalitesi derecelendirmesi
enum ProductQualityLevel {
  high, // Eksiksiz ve güvenilir (>80%)
  medium, // Eksik alanlar var ama aktarılabilir (50-80%)
  low, // Temel alanlar eksik (<50%)
}

/// Veri kalitesi raporu
class ProductQualityReport {
  final int score; // 0 - 100
  final ProductQualityLevel level;
  final List<String> completeFields;
  final List<String> missingFields;
  final List<String> warningMessages;

  const ProductQualityReport({
    required this.score,
    required this.level,
    required this.completeFields,
    required this.missingFields,
    required this.warningMessages,
  });

  bool get isReadyForImport => score >= 50 && !missingFields.contains('Ürün Adı') && !missingFields.contains('Fiyat');

  Map<String, dynamic> toMap() => {
    'score': score,
    'level': level.name,
    'completeFields': completeFields,
    'missingFields': missingFields,
    'warningMessages': warningMessages,
  };

  factory ProductQualityReport.fromMap(Map<String, dynamic> map) {
    return ProductQualityReport(
      score: (map['score'] as num?)?.toInt() ?? 0,
      level: ProductQualityLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => ProductQualityLevel.low,
      ),
      completeFields: List<String>.from(map['completeFields'] ?? const []),
      missingFields: List<String>.from(map['missingFields'] ?? const []),
      warningMessages: List<String>.from(map['warningMessages'] ?? const []),
    );
  }
}

/// Kaynaktan tespit edilen gerçek bir varyasyon kombinasyonu
class ImportedProductVariant {
  String id;
  String combinationTitle; // Örn: "Siyah / M / 128 GB"
  String? color;
  String? colorHex;
  String? size;
  String? ram;
  String? storage;
  String? sku;
  String? barcode;
  double price;
  double? discountPrice;
  int? stock;
  bool? inStock;
  String? imageUrl;
  Map<String, String> specValues; // Diğer boyutlar veya özel alanlar

  ImportedProductVariant({
    required this.id,
    required this.combinationTitle,
    this.color,
    this.colorHex,
    this.size,
    this.ram,
    this.storage,
    this.sku,
    this.barcode,
    required this.price,
    this.discountPrice,
    this.stock,
    this.inStock,
    this.imageUrl,
    this.specValues = const {},
  });

  bool get isStockKnown => stock != null;
  int get safeStock => stock ?? 0;
  int? get stockQuantity => stock;

  String get inStockStatus {
    if (inStock != null) {
      return inStock! ? 'in_stock' : 'out_of_stock';
    }
    if (stock != null) {
      return stock! > 0 ? 'in_stock' : 'out_of_stock';
    }
    return 'unknown';
  }

  ImportedProductVariant copyWith({
    String? id,
    String? combinationTitle,
    String? color,
    String? colorHex,
    String? size,
    String? ram,
    String? storage,
    String? sku,
    String? barcode,
    double? price,
    double? discountPrice,
    int? stock,
    bool? inStock,
    String? imageUrl,
    Map<String, String>? specValues,
  }) {
    return ImportedProductVariant(
      id: id ?? this.id,
      combinationTitle: combinationTitle ?? this.combinationTitle,
      color: color ?? this.color,
      colorHex: colorHex ?? this.colorHex,
      size: size ?? this.size,
      ram: ram ?? this.ram,
      storage: storage ?? this.storage,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      stock: stock ?? this.stock,
      inStock: inStock ?? this.inStock,
      imageUrl: imageUrl ?? this.imageUrl,
      specValues: specValues ?? Map.from(this.specValues),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'combinationTitle': combinationTitle,
    'color': color,
    'colorHex': colorHex,
    'size': size,
    'ram': ram,
    'storage': storage,
    'sku': sku,
    'barcode': barcode,
    'price': price,
    'discountPrice': discountPrice,
    'stock': stock,
    'stock_quantity': stock,
    'in_stock': inStockStatus,
    'imageUrl': imageUrl,
    'specValues': specValues,
  };

  factory ImportedProductVariant.fromMap(Map<String, dynamic> map) {
    final rawInStock = map['in_stock'] ?? map['inStock'];
    bool? inStockParsed;
    if (rawInStock is bool) {
      inStockParsed = rawInStock;
    } else if (rawInStock is String) {
      if (rawInStock == 'in_stock' || rawInStock == 'true') {
        inStockParsed = true;
      } else if (rawInStock == 'out_of_stock' || rawInStock == 'false') {
        inStockParsed = false;
      }
    }

    return ImportedProductVariant(
      id: map['id']?.toString() ?? '',
      combinationTitle: map['combinationTitle']?.toString() ?? '',
      color: map['color']?.toString(),
      colorHex: map['colorHex']?.toString(),
      size: map['size']?.toString(),
      ram: map['ram']?.toString(),
      storage: map['storage']?.toString(),
      sku: map['sku']?.toString(),
      barcode: map['barcode']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (map['discountPrice'] as num?)?.toDouble(),
      stock: (map['stock_quantity'] ?? map['stock'] as num?)?.toInt(),
      inStock: inStockParsed,
      imageUrl: map['imageUrl']?.toString(),
      specValues: map['specValues'] is Map ? Map<String, String>.from(map['specValues']) : const {},
    );
  }
}

/// İçe aktarma işlem durumu
enum ProductImportStatus {
  pending,
  importing,
  success,
  duplicate,
  failed,
}

/// Standart ürün içe aktarma modeli
class ImportedProductData {
  final String id;
  String sourceUrl;
  String? sourceId;
  String adapterName;
  String name;
  String brand;
  String? modelCode;
  String sku;
  String? barcode;
  double price;
  double? discountPrice;
  String currency;
  String originalCurrency;
  int? stock;
  bool? inStock;
  String mainCategory;
  String subCategory;
  String description;
  List<String> imageUrls;
  Map<String, dynamic> specifications;
  Map<String, List<String>> variantOptions;
  List<ImportedProductVariant> realVariants;
  String? warranty;
  String? shippingInfo;
  DateTime capturedAt;
  bool isSelected;
  ProductQualityReport quality;
  ProductImportStatus importStatus;
  String? errorMessage;
  String? createdProductId;

  ImportedProductData({
    required this.id,
    required this.sourceUrl,
    this.sourceId,
    required this.adapterName,
    required this.name,
    required this.brand,
    this.modelCode,
    required this.sku,
    this.barcode,
    required this.price,
    this.discountPrice,
    this.currency = 'TRY',
    this.originalCurrency = 'TRY',
    this.stock,
    this.inStock,
    required this.mainCategory,
    required this.subCategory,
    this.description = '',
    this.imageUrls = const [],
    this.specifications = const {},
    this.variantOptions = const {},
    this.realVariants = const [],
    this.warranty,
    this.shippingInfo,
    required this.capturedAt,
    this.isSelected = true,
    required this.quality,
    this.importStatus = ProductImportStatus.pending,
    this.errorMessage,
    this.createdProductId,
  });

  String? get mainImageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  int get variantCount => realVariants.length;

  bool get hasVariants => realVariants.isNotEmpty;

  bool get isStockKnown => stock != null;

  int get safeStock => stock ?? 0;

  int? get stockQuantity => stock;

  String get inStockStatus {
    if (inStock != null) {
      return inStock! ? 'in_stock' : 'out_of_stock';
    }
    if (stock != null) {
      return stock! > 0 ? 'in_stock' : 'out_of_stock';
    }
    return 'unknown';
  }

  ImportedProductData copyWith({
    String? id,
    String? sourceUrl,
    String? sourceId,
    String? adapterName,
    String? name,
    String? brand,
    String? modelCode,
    String? sku,
    String? barcode,
    double? price,
    double? discountPrice,
    String? currency,
    String? originalCurrency,
    int? stock,
    bool? inStock,
    String? mainCategory,
    String? subCategory,
    String? description,
    List<String>? imageUrls,
    Map<String, dynamic>? specifications,
    Map<String, List<String>>? variantOptions,
    List<ImportedProductVariant>? realVariants,
    String? warranty,
    String? shippingInfo,
    DateTime? capturedAt,
    bool? isSelected,
    ProductQualityReport? quality,
    ProductImportStatus? importStatus,
    String? errorMessage,
    String? createdProductId,
  }) {
    return ImportedProductData(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceId: sourceId ?? this.sourceId,
      adapterName: adapterName ?? this.adapterName,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      modelCode: modelCode ?? this.modelCode,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      price: price ?? this.price,
      discountPrice: discountPrice ?? this.discountPrice,
      currency: currency ?? this.currency,
      originalCurrency: originalCurrency ?? this.originalCurrency,
      stock: stock ?? this.stock,
      inStock: inStock ?? this.inStock,
      mainCategory: mainCategory ?? this.mainCategory,
      subCategory: subCategory ?? this.subCategory,
      description: description ?? this.description,
      imageUrls: imageUrls ?? List.from(this.imageUrls),
      specifications: specifications ?? Map.from(this.specifications),
      variantOptions: variantOptions ?? Map.from(this.variantOptions),
      realVariants: realVariants ?? List.from(this.realVariants),
      warranty: warranty ?? this.warranty,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      capturedAt: capturedAt ?? this.capturedAt,
      isSelected: isSelected ?? this.isSelected,
      quality: quality ?? this.quality,
      importStatus: importStatus ?? this.importStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      createdProductId: createdProductId ?? this.createdProductId,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'sourceUrl': sourceUrl,
    'sourceId': sourceId,
    'adapterName': adapterName,
    'name': name,
    'brand': brand,
    'modelCode': modelCode,
    'sku': sku,
    'barcode': barcode,
    'price': price,
    'discountPrice': discountPrice,
    'currency': currency,
    'originalCurrency': originalCurrency,
    'stock': stock,
    'stock_quantity': stock,
    'in_stock': inStockStatus,
    'mainCategory': mainCategory,
    'subCategory': subCategory,
    'description': description,
    'imageUrls': imageUrls,
    'specifications': specifications,
    'variantOptions': variantOptions,
    'realVariants': realVariants.map((v) => v.toMap()).toList(),
    'warranty': warranty,
    'shippingInfo': shippingInfo,
    'capturedAt': capturedAt.toIso8601String(),
    'isSelected': isSelected,
    'quality': quality.toMap(),
    'importStatus': importStatus.name,
    'errorMessage': errorMessage,
    'createdProductId': createdProductId,
  };

  factory ImportedProductData.fromMap(Map<String, dynamic> map) {
    final rawInStock = map['in_stock'] ?? map['inStock'];
    bool? inStockParsed;
    if (rawInStock is bool) {
      inStockParsed = rawInStock;
    } else if (rawInStock is String) {
      if (rawInStock == 'in_stock' || rawInStock == 'true') {
        inStockParsed = true;
      } else if (rawInStock == 'out_of_stock' || rawInStock == 'false') {
        inStockParsed = false;
      }
    }

    return ImportedProductData(
      id: map['id']?.toString() ?? '',
      sourceUrl: map['sourceUrl']?.toString() ?? '',
      sourceId: map['sourceId']?.toString(),
      adapterName: map['adapterName']?.toString() ?? 'Generic',
      name: map['name']?.toString() ?? '',
      brand: map['brand']?.toString() ?? '',
      modelCode: map['modelCode']?.toString(),
      sku: map['sku']?.toString() ?? '',
      barcode: map['barcode']?.toString(),
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      discountPrice: (map['discountPrice'] as num?)?.toDouble(),
      currency: map['currency']?.toString() ?? 'TRY',
      originalCurrency: map['originalCurrency']?.toString() ?? 'TRY',
      stock: (map['stock_quantity'] ?? map['stock'] as num?)?.toInt(),
      inStock: inStockParsed,
      mainCategory: map['mainCategory']?.toString() ?? '',
      subCategory: map['subCategory']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      imageUrls: List<String>.from(map['imageUrls'] ?? const []),
      specifications: map['specifications'] is Map ? Map<String, dynamic>.from(map['specifications']) : const {},
      variantOptions: (map['variantOptions'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v ?? const [])),
          ) ??
          const {},
      realVariants: (map['realVariants'] as List?)
              ?.map((v) => ImportedProductVariant.fromMap(Map<String, dynamic>.from(v)))
              .toList() ??
          const [],
      warranty: map['warranty']?.toString(),
      shippingInfo: map['shippingInfo']?.toString(),
      capturedAt: map['capturedAt'] != null
          ? DateTime.tryParse(map['capturedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isSelected: map['isSelected'] == true,
      quality: map['quality'] is Map
          ? ProductQualityReport.fromMap(Map<String, dynamic>.from(map['quality']))
          : const ProductQualityReport(
              score: 0,
              level: ProductQualityLevel.low,
              completeFields: [],
              missingFields: [],
              warningMessages: [],
            ),
      importStatus: ProductImportStatus.values.firstWhere(
        (e) => e.name == map['importStatus'],
        orElse: () => ProductImportStatus.pending,
      ),
      errorMessage: map['errorMessage']?.toString(),
      createdProductId: map['createdProductId']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ImportedProductData.fromJson(String source) =>
      ImportedProductData.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
