import 'product_model.dart';

enum ProductListVisibility { private, public }

extension ProductListVisibilityX on ProductListVisibility {
  String get dbValue {
    switch (this) {
      case ProductListVisibility.private:
        return 'private';
      case ProductListVisibility.public:
        return 'public';
    }
  }

  String get label {
    switch (this) {
      case ProductListVisibility.private:
        return 'Sadece Ben';
      case ProductListVisibility.public:
        return 'Herkese Açık';
    }
  }

  static ProductListVisibility fromValue(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'public':
        return ProductListVisibility.public;
      default:
        return ProductListVisibility.private;
    }
  }
}

class ProductList {
  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? category;
  final String? subCategory;
  final ProductListVisibility visibility;
  final String shareCode;
  final String? sellerId;
  final String? storeName;
  final String? ownerUserId;
  final String? ownerDisplayName;
  final String? ownerPhotoUrl;
  final int followerCount;
  final bool isFollowing;
  final bool followNotificationsEnabled;
  final List<String> productIds; // Ürün ID'leri (isimleri)
  final List<Product> products; // Ürün nesneleri (UI için)
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductList({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.category,
    this.subCategory,
    this.visibility = ProductListVisibility.private,
    String? shareCode,
    this.sellerId,
    this.storeName,
    this.ownerUserId,
    this.ownerDisplayName,
    this.ownerPhotoUrl,
    this.followerCount = 0,
    this.isFollowing = false,
    this.followNotificationsEnabled = true,
    required this.productIds,
    this.products = const [],
    required this.createdAt,
    required this.updatedAt,
  }) : shareCode = (shareCode == null || shareCode.trim().isEmpty)
           ? _fallbackShareCode(id)
           : shareCode.trim();

  bool get isPublic => visibility == ProductListVisibility.public;
  int get productCount =>
      productIds.isNotEmpty ? productIds.length : products.length;

  ProductList copyWith({
    String? id,
    String? name,
    String? description,
    String? iconUrl,
    String? category,
    String? subCategory,
    ProductListVisibility? visibility,
    String? shareCode,
    String? sellerId,
    String? storeName,
    String? ownerUserId,
    String? ownerDisplayName,
    String? ownerPhotoUrl,
    int? followerCount,
    bool? isFollowing,
    bool? followNotificationsEnabled,
    List<String>? productIds,
    List<Product>? products,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconUrl: iconUrl ?? this.iconUrl,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      visibility: visibility ?? this.visibility,
      shareCode: shareCode ?? this.shareCode,
      sellerId: sellerId ?? this.sellerId,
      storeName: storeName ?? this.storeName,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      ownerPhotoUrl: ownerPhotoUrl ?? this.ownerPhotoUrl,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      followNotificationsEnabled:
          followNotificationsEnabled ?? this.followNotificationsEnabled,
      productIds: productIds ?? this.productIds,
      products: products ?? this.products,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'iconUrl': iconUrl,
      'category': category,
      'subCategory': subCategory,
      'visibility': visibility.dbValue,
      'shareCode': shareCode,
      'sellerId': sellerId,
      'storeName': storeName,
      'ownerUserId': ownerUserId,
      'ownerDisplayName': ownerDisplayName,
      'ownerPhotoUrl': ownerPhotoUrl,
      'followerCount': followerCount,
      'isFollowing': isFollowing,
      'followNotificationsEnabled': followNotificationsEnabled,
      'productIds': productIds,
      'products': products.map((product) => product.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductList.fromJson(Map<String, dynamic> json) {
    return ProductList(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      category: json['category']?.toString(),
      subCategory: json['subCategory']?.toString(),
      visibility: ProductListVisibilityX.fromValue(
        json['visibility']?.toString(),
      ),
      shareCode: json['shareCode']?.toString(),
      sellerId: json['sellerId']?.toString() ?? json['seller_id']?.toString(),
      storeName:
          json['storeName']?.toString() ?? json['store_name']?.toString(),
      ownerUserId: json['ownerUserId']?.toString(),
      ownerDisplayName: json['ownerDisplayName']?.toString(),
      ownerPhotoUrl: json['ownerPhotoUrl']?.toString(),
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      isFollowing: json['isFollowing'] == true,
      followNotificationsEnabled: json['followNotificationsEnabled'] != false,
      productIds: (json['productIds'] as List<dynamic>? ?? const [])
          .cast<String>(),
      products: (json['products'] as List<dynamic>? ?? const [])
          .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static String _fallbackShareCode(String seed) {
    final sanitized = seed
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '')
        .trim();
    if (sanitized.isEmpty) {
      return 'list';
    }
    return sanitized.length <= 24 ? sanitized : sanitized.substring(0, 24);
  }
}
