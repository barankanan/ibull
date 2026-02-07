class DBBanner {
  final int? id;
  final String imageUrl; // Banner resmi
  final String? link; // Tıklanınca gidilecek link (ürün/kategori/mağaza)
  final int orderIndex; // Sıralama için
  final String type; // 'main', 'category', 'brand', 'campaign'
  final String? title; // Banner başlığı
  final String? description; // Banner açıklaması
  final bool isActive; // Aktif mi?
  
  DBBanner({
    this.id,
    required this.imageUrl,
    this.link,
    required this.orderIndex,
    required this.type,
    this.title,
    this.description,
    this.isActive = true,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'link': link,
      'orderIndex': orderIndex,
      'type': type,
      'title': title,
      'description': description,
      'isActive': isActive ? 1 : 0,
    };
  }
  
  factory DBBanner.fromMap(Map<String, dynamic> map) {
    return DBBanner(
      id: map['id'] as int?,
      imageUrl: map['imageUrl'] as String,
      link: map['link'] as String?,
      orderIndex: map['orderIndex'] as int,
      type: map['type'] as String,
      title: map['title'] as String?,
      description: map['description'] as String?,
      isActive: map['isActive'] == 1,
    );
  }
  
  DBBanner copyWith({
    int? id,
    String? imageUrl,
    String? link,
    int? orderIndex,
    String? type,
    String? title,
    String? description,
    bool? isActive,
  }) {
    return DBBanner(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      link: link ?? this.link,
      orderIndex: orderIndex ?? this.orderIndex,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }
  
  @override
  String toString() {
    return 'DBBanner(id: $id, type: $type, orderIndex: $orderIndex)';
  }
}
