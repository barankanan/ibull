import '../models/imported_product.dart';

/// Ürün veri kalitesini değerlendiren ve kategori haritalaması yapan servis
class ProductQualityService {
  const ProductQualityService();

  static const List<String> standardMainCategories = [
    'Giyim & Aksesuar',
    'Elektronik',
    'Ev & Yaşam',
    'Kozmetik & Kişisel Bakım',
    'Spor & Outdoor',
    'Anne & Bebek & Oyuncak',
    'Kitap & Hobi',
    'Süpermarket & Petshop',
    '2.el Ürünler',
    'Yemek',
  ];

  /// Ürünün kalite skorunu ve eksik alan raporunu hesaplar
  ProductQualityReport evaluateQuality(ImportedProductData product) {
    int score = 0;
    final List<String> complete = [];
    final List<String> missing = [];
    final List<String> warnings = [];

    // 1. Ürün Adı (20 puan - Zorunlu)
    if (product.name.trim().isNotEmpty && product.name.trim().length >= 3) {
      score += 20;
      complete.add('Ürün Adı');
    } else {
      missing.add('Ürün Adı');
    }

    // 2. Fiyat ve Para Birimi (25 puan - Zorunlu)
    if (product.price > 0) {
      score += 25;
      complete.add('Fiyat');
    } else {
      missing.add('Fiyat');
    }

    if (product.currency != 'TRY') {
      warnings.add('Para birimi ${product.currency}. Doğrulanmış kur olmadan otomatik TL dönüşümü yapılmaz.');
    }

    // 3. Görseller (20 puan - Zorunlu)
    if (product.imageUrls.isNotEmpty) {
      score += 20;
      complete.add('Görseller (${product.imageUrls.length})');
    } else {
      missing.add('Görseller');
      warnings.add('Ürünün hiçbir görseli tespit edilemedi. En az 1 görsel gereklidir.');
    }

    // 4. Kategori Eşleştirmesi (15 puan - Zorunlu)
    if (product.mainCategory.trim().isNotEmpty && standardMainCategories.contains(product.mainCategory.trim())) {
      score += 15;
      complete.add('Ana Kategori');
    } else {
      missing.add('Ana Kategori');
      warnings.add('Kategori İBUL standart kategorileriyle tam eşleşmedi. Satıcı seçimi önerilir.');
    }

    // 5. Marka veya SKU (10 puan - Önerilen)
    if (product.brand.trim().isNotEmpty) {
      score += 5;
      complete.add('Marka');
    } else {
      missing.add('Marka');
    }

    if (product.sku.trim().isNotEmpty) {
      score += 5;
      complete.add('SKU');
    } else {
      missing.add('SKU');
    }

    // 6. Açıklama veya Teknik Özellikler (10 puan - Önerilen)
    if (product.description.trim().isNotEmpty || product.specifications.isNotEmpty) {
      score += 10;
      complete.add('Açıklama/Özellikler');
    } else {
      missing.add('Açıklama/Özellikler');
    }

    // Barkod kontrolü (Opsiyonel)
    if (product.barcode != null && product.barcode!.trim().isNotEmpty) {
      complete.add('Barkod');
    } else {
      missing.add('Barkod');
    }

    // Stok kontrolü (Bilinmeyen veya tükenmiş stok)
    if (product.stock == null) {
      warnings.add('Kaynakta net stok miktarı belirtilmemiş (Bilinmiyor). Güvenli varsayılan olarak stok 0 kaydedilecek; satışa açmadan önce satıcı panelinden stoğu belirleyin.');
    } else if (product.stock! <= 0) {
      warnings.add('Ürün kaynakta stokta yok (0) olarak görünüyor.');
    }

    // Para birimi kontrolü
    if (product.currency.toUpperCase() != 'TRY' &&
        product.currency.toUpperCase() != 'TL' &&
        product.currency != '₺') {
      warnings.add('Ürün para birimi yabancı (${product.currency}). Lütfen mağazanızda satışa sunmadan önce fiyatı Türk Lirası (TRY) olarak güncelleyin.');
    }

    // İndirimli fiyat tutarlılık kontrolü
    if (product.discountPrice != null && product.discountPrice! > 0) {
      if (product.discountPrice! >= product.price) {
        warnings.add('İndirimli fiyat (${product.discountPrice} ₺), normal liste fiyatından (${product.price} ₺) düşük olmalıdır.');
      }
    }

    // Varyasyon kontrolü
    if (product.hasVariants) {
      complete.add('Varyasyonlar (${product.variantCount} Kombinasyon)');
      for (final v in product.realVariants) {
        if (v.price <= 0) {
          warnings.add('Varyasyon "${v.combinationTitle}" için fiyat eksik.');
          break;
        }
        if (v.stock == null) {
          warnings.add('Varyasyon "${v.combinationTitle}" için stok bilinmiyor.');
          break;
        }
      }
    }

    ProductQualityLevel level;
    if (score >= 80) {
      level = ProductQualityLevel.high;
    } else if (score >= 50) {
      level = ProductQualityLevel.medium;
    } else {
      level = ProductQualityLevel.low;
    }

    return ProductQualityReport(
      score: score,
      level: level,
      completeFields: complete,
      missingFields: missing,
      warningMessages: warnings,
    );
  }

  /// Kaynak kategori metnini İBUL'un 10 ana kategorisine akıllıca haritalar
  String mapToMainCategory(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) return '';
    final s = rawCategory.toLowerCase();

    // 1. Ev & Yaşam (Mutfak, Banyo, Mobilya vb.)
    if (s.contains('ev') ||
        s.contains('yaşam') ||
        s.contains('mobilya') ||
        s.contains('dekorasyon') ||
        s.contains('aydınlatma') ||
        s.contains('mutfak') ||
        s.contains('banyo') ||
        s.contains('bahçe') ||
        s.contains('yapı')) {
      return 'Ev & Yaşam';
    }

    // 2. Elektronik (Telefon, Bilgisayar vb.)
    if (s.contains('elektronik') ||
        s.contains('telefon') ||
        s.contains('bilgisayar') ||
        s.contains('kulaklık') ||
        s.contains('tablet') ||
        s.contains('tv') ||
        s.contains('laptop') ||
        s.contains('electronic')) {
      return 'Elektronik';
    }

    // 3. Giyim & Aksesuar
    if (s.contains('giyim') ||
        s.contains('elbise') ||
        s.contains('ayakkabı') ||
        s.contains('çanta') ||
        s.contains('t-shirt') ||
        s.contains('pantolon') ||
        s.contains('moda') ||
        s.contains('takı') ||
        s.contains('saat') ||
        s.contains('aksesuar') ||
        s.contains('clothing')) {
      return 'Giyim & Aksesuar';
    }

    if (s.contains('kozmetik') ||
        s.contains('bakım') ||
        s.contains('parfüm') ||
        s.contains('makyaj') ||
        s.contains('cilt') ||
        s.contains('şampuan') ||
        s.contains('beauty')) {
      return 'Kozmetik & Kişisel Bakım';
    }

    if (s.contains('spor') ||
        s.contains('outdoor') ||
        s.contains('fitness') ||
        s.contains('kamp') ||
        s.contains('bisiklet') ||
        s.contains('sport')) {
      return 'Spor & Outdoor';
    }

    if (s.contains('bebek') ||
        s.contains('oyuncak') ||
        s.contains('anne') ||
        s.contains('çocuk') ||
        s.contains('baby') ||
        s.contains('toy')) {
      return 'Anne & Bebek & Oyuncak';
    }

    if (s.contains('kitap') ||
        s.contains('hobi') ||
        s.contains('müzik') ||
        s.contains('film') ||
        s.contains('enstrüman') ||
        s.contains('book')) {
      return 'Kitap & Hobi';
    }

    if (s.contains('süpermarket') ||
        s.contains('market') ||
        s.contains('petshop') ||
        s.contains('evcil') ||
        s.contains('gıda') ||
        s.contains('temizlik') ||
        s.contains('grocery')) {
      return 'Süpermarket & Petshop';
    }

    if (s.contains('ikinci') || s.contains('2.el') || s.contains('araç') || s.contains('otomotiv')) {
      return '2.el Ürünler';
    }

    if (s.contains('yemek') || s.contains('restoran') || s.contains('fast food') || s.contains('tatlı')) {
      return 'Yemek';
    }

    return '';
  }
}
