class DBProduct {
  final int? id;
  final String name;
  final String brand;
  final String? store; // Mağaza adı
  final String price;
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
  final String? specifications; // JSON object - {"RAM": "8GB", "Depolama": "256GB", "Ekran": "6.7 inç"}
  final bool isPart; // Parça mı? (2.el ürünler için)
  final String? damagedParts; // Hasarlı parçalar (virgülle ayrılmış) - "ekran,batarya,kamera"
  final String? variantGroupId; // Varyant grup ID'si - aynı grup ID'li ürünler varyant olarak gösterilir
  final String? variantOptions; // Varyant seçenekleri (pipe ayrılmış) - "Renk:Siyah|Depolama:512GB"
  final int? stock; // Stok miktarı
  final bool isActive; // Ürün aktif mi?
  
  DBProduct({
    this.id,
    required this.name,
    required this.brand,
    this.store,
    required this.price,
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
  });
  
  // Database'e kaydetmek için Map'e çevir
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'store': store,
      'price': price,
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
    };
  }
  
  // Database'den okumak için Map'ten oluştur
  factory DBProduct.fromMap(Map<String, dynamic> map) {
    return DBProduct(
      id: map['id'] as int?,
      name: map['name'] as String,
      brand: map['brand'] as String,
      store: map['store'] as String?,
      price: map['price'] as String,
      oldPrice: map['oldPrice'] as String?,
      rating: map['rating'] as double,
      reviewCount: map['reviewCount'] as int,
      imageUrl: map['imageUrl'] as String,
      imageUrls: map['imageUrls'] as String?,
      category: map['category'] as String,
      subCategory: map['subCategory'] as String?,
      tags: map['tags'] as String,
      keywords: map['keywords'] as String?,
      description: map['description'] as String?,
      specifications: map['specifications'] as String?,
      isPart: map['isPart'] == 1,
      damagedParts: map['damagedParts'] as String?,
      variantGroupId: map['variantGroupId'] as String?,
      variantOptions: map['variantOptions'] as String?,
      stock: map['stock'] as int?,
      isActive: map['isActive'] == 1,
    );
  }
  
  // Kopyalama fonksiyonu (güncelleme için)
  DBProduct copyWith({
    int? id,
    String? name,
    String? brand,
    String? store,
    String? price,
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
  }) {
    return DBProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      store: store ?? this.store,
      price: price ?? this.price,
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
    return 'DBProduct(id: $id, name: $name, brand: $brand, price: $price)';
  }
}
