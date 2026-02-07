class DBProductVariant {
  final int? id;
  final int productId; // Ana ürün ID'si
  final String variantGroupId; // Varyant grubu ID'si (aynı grup ID'li ürünler birlikte gösterilir)
  final String? variantOptions; // JSON: {"Renk":"Siyah","Depolama":"512GB"}
  final double price;
  final double? oldPrice;
  final int stock;
  final String? imageUrl;
  final bool isActive;

  DBProductVariant({
    this.id,
    required this.productId,
    required this.variantGroupId,
    this.variantOptions,
    required this.price,
    this.oldPrice,
    required this.stock,
    this.imageUrl,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'variantGroupId': variantGroupId,
      'variantOptions': variantOptions,
      'price': price,
      'oldPrice': oldPrice,
      'stock': stock,
      'imageUrl': imageUrl,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory DBProductVariant.fromMap(Map<String, dynamic> map) {
    return DBProductVariant(
      id: map['id'] as int?,
      productId: map['productId'] as int,
      variantGroupId: map['variantGroupId'] as String,
      variantOptions: map['variantOptions'] as String?,
      price: map['price'] as double,
      oldPrice: map['oldPrice'] as double?,
      stock: map['stock'] as int,
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] == 1,
    );
  }

  DBProductVariant copyWith({
    int? id,
    int? productId,
    String? variantGroupId,
    String? variantOptions,
    double? price,
    double? oldPrice,
    int? stock,
    String? imageUrl,
    bool? isActive,
  }) {
    return DBProductVariant(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantGroupId: variantGroupId ?? this.variantGroupId,
      variantOptions: variantOptions ?? this.variantOptions,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
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

  // Varyant seçeneklerinden display text oluştur
  String getDisplayText() {
    final options = getVariantOptionsMap();
    if (options.isEmpty) return '';
    
    return options.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
  }
}
