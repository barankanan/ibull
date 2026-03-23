class DBCategory {
  final int? id;
  final String name;
  final String? iconName; // Icons.phone_android gibi icon adı (string olarak)
  final String? imageUrl; // Kategori görseli
  final int orderIndex; // Sıralama
  final int? parentId; // Alt kategori ise üst kategori ID'si
  final bool isActive;
  
  DBCategory({
    this.id,
    required this.name,
    this.iconName,
    this.imageUrl,
    required this.orderIndex,
    this.parentId,
    this.isActive = true,
  });
  
  // Ana kategori mi?
  bool get isMainCategory => parentId == null;
  
  // Alt kategori mi?
  bool get isSubCategory => parentId != null;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'orderIndex': orderIndex,
      'parentId': parentId,
      'isActive': isActive ? 1 : 0,
    };
  }
  
  factory DBCategory.fromMap(Map<String, dynamic> map) {
    final isActiveRaw = map['isActive'];
    return DBCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconName: map['iconName'] as String?,
      imageUrl: map['imageUrl'] as String?,
      orderIndex: (map['orderIndex'] as num).toInt(),
      parentId: (map['parentId'] as num?)?.toInt(),
      isActive: isActiveRaw is bool ? isActiveRaw : isActiveRaw == 1,
    );
  }
  
  DBCategory copyWith({
    int? id,
    String? name,
    String? iconName,
    String? imageUrl,
    int? orderIndex,
    int? parentId,
    bool? isActive,
  }) {
    return DBCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      imageUrl: imageUrl ?? this.imageUrl,
      orderIndex: orderIndex ?? this.orderIndex,
      parentId: parentId ?? this.parentId,
      isActive: isActive ?? this.isActive,
    );
  }
  
  @override
  String toString() {
    return 'DBCategory(id: $id, name: $name, parentId: $parentId)';
  }
}

/// Alt kategorileri ile birlikte kategori
class CategoryWithSubcategories {
  final DBCategory mainCategory;
  final List<DBCategory> subCategories;
  
  CategoryWithSubcategories({
    required this.mainCategory,
    required this.subCategories,
  });
}
