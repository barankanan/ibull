class StoreSubCategory {
  const StoreSubCategory({
    required this.id,
    required this.sellerId,
    required this.mainCategory,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String sellerId;
  final String mainCategory;
  final String name;
  final bool isActive;
  final int sortOrder;

  String get normalizedName => name.trim().toLowerCase();

  factory StoreSubCategory.fromMap(Map<String, dynamic> map) {
    return StoreSubCategory(
      id: map['id']?.toString() ?? '',
      sellerId: map['seller_id']?.toString() ?? '',
      mainCategory: map['main_category']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isActive: map['is_active'] != false,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'seller_id': sellerId,
      'main_category': mainCategory,
      'name': name,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
