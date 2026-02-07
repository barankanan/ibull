class Product {
  final String name;
  final String brand;
  final String price;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final List<String> images;
  final bool isDigital;
  final List<String>? accessories;
  final String? store;
  final String? category;
  final String? subCategory;
  final String? description;
  final String? specifications;
  final String? oldPrice;
  final String? variantOptions;
  final String? variantGroupId;
  final List<String> selectedServices;

  Product({
    required this.name,
    required this.brand,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.tags,
    required this.images,
    this.isDigital = false,
    this.accessories,
    this.store,
    this.category,
    this.subCategory,
    this.description,
    this.specifications,
    this.oldPrice,
    this.variantOptions,
    this.variantGroupId,
    this.selectedServices = const [],
  });

  Product copyWith({
    String? name,
    String? brand,
    String? price,
    double? rating,
    int? reviewCount,
    List<String>? tags,
    List<String>? images,
    bool? isDigital,
    List<String>? accessories,
    String? store,
    String? category,
    String? subCategory,
    String? description,
    String? specifications,
    String? oldPrice,
    String? variantOptions,
    String? variantGroupId,
    List<String>? selectedServices,
  }) {
    return Product(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      isDigital: isDigital ?? this.isDigital,
      accessories: accessories ?? this.accessories,
      store: store ?? this.store,
      category: category ?? this.category,
      subCategory: subCategory ?? this.subCategory,
      description: description ?? this.description,
      specifications: specifications ?? this.specifications,
      oldPrice: oldPrice ?? this.oldPrice,
      variantOptions: variantOptions ?? this.variantOptions,
      variantGroupId: variantGroupId ?? this.variantGroupId,
      selectedServices: selectedServices ?? this.selectedServices,
    );
  }
  
  // DBProduct'tan Product'a dönüştür
  factory Product.fromDBProduct(dynamic dbProduct) {
    // Görselleri hazırla
    List<String> images = [];
    if (dbProduct.imageUrl != null && dbProduct.imageUrl.isNotEmpty) {
      // imageUrl zaten assets/products/ içeriyor (normalize edilmiş)
      images.add(dbProduct.imageUrl);
    }
    if (dbProduct.imageUrls != null && dbProduct.imageUrls.isNotEmpty) {
      final additionalImages = dbProduct.imageUrls.split(',');
      for (var img in additionalImages) {
        if (img.trim().isNotEmpty) {
          // imageUrls da normalize edilmiş olmalı
          images.add(img.trim());
        }
      }
    }
    
    // Etiketleri hazırla
    List<String> tags = [];
    if (dbProduct.tags != null && dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }
    
    return Product(
      name: dbProduct.name ?? 'Ürün',
      brand: dbProduct.brand ?? '',
      price: dbProduct.price ?? '0',
      rating: dbProduct.rating ?? 0.0,
      reviewCount: dbProduct.reviewCount ?? 0,
      tags: tags,
      images: images,
      store: dbProduct.store,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
      variantOptions: dbProduct.variantOptions,
      variantGroupId: dbProduct.variantGroupId,
    );
  }

  // UI Helper methods to ensure consistency across pages
  String getDisplayDescription() {
    // Ürün adına göre farklı açıklamalar (Hardcoded logic from ProductDetailPage)
    if (brand.contains('Uf') || name.contains('CT-23')) {
      return 'UFO City CT-23 2300W İnfrared tipi ayaklı ısıtıcı, modern tasarımı ve güçlü ısıtma kapasitesi ile yaşam alanlarınızda konfor sağlar. Enerji tasarruflu teknolojisi sayesinde ekonomik kullanım sunar.';
    } else if (brand.contains('Haylou') || name.contains('Solar')) {
      return 'Haylou Solar Plus RT3 akıllı saati, 1.43 inç AMOLED ekranı, 105+ spor modu ve 14 güne kadar pil ömrü ile sağlıklı yaşamınızı takip edin. Bluetooth arama, müzik kontrolü ve sağlık izleme özellikleri sunar.';
    } else if (brand.contains('Apple') || name.contains('iPhone')) {
      return 'Apple iPhone 12, 5G desteği, A14 Bionic çip, 12MP çift kamera sistemi ve Super Retina XDR ekran ile güçlü performans sunar. 128GB depolama alanı ile tüm dosyalarınızı rahatça saklayabilirsiniz.';
    } else {
      return description ?? 'Ürün hakkında detaylı bilgi için mağazamızı ziyaret edebilir veya müşteri hizmetlerimizle iletişime geçebilirsiniz.';
    }
  }

  String getDisplaySpecs() {
    // Ürün adına göre farklı özellikler (Hardcoded logic from ProductDetailPage)
    if (brand.contains('Uf') || name.contains('CT-23')) {
      return 'Güç: 2300W\nRenk: Siyah\nTip: İnfrared Ayaklı Isıtıcı\nBoyutlar: 180cm Yükseklik\nGaranti: 2 Yıl';
    } else if (brand.contains('Haylou') || name.contains('Solar')) {
      return 'Ekran: 1.43" AMOLED\nPil Ömrü: 14 gün\nSu Geçirmezlik: 5ATM\nSpor Modu: 105+\nBluetooth: 5.0\nGaranti: 2 Yıl';
    } else if (brand.contains('Apple') || name.contains('iPhone')) {
      return 'Ekran: 6.1" Super Retina XDR\nDepolama: 128GB\nKamera: 12MP Çift\nÇip: A14 Bionic\n5G: Evet\nGaranti: 1 Yıl';
    } else {
      return specifications ?? 'Detaylı özellikler için mağazamızı ziyaret edin.';
    }
  }
}
