/// Kategori bazlı fiyatlandırma ve ürün tipi yardımcıları.
library;

/// Yemek/restoran ile fiziksel (elektronik, moda vb.) ürün alanlarını ayırır.

String normalizeCategoryKey(String? raw) {
  return (raw ?? '')
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ş', 's')
      .replaceAll('Ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('Ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('Ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll('Ç', 'c');
}

const Set<String> _foodMainCategoryKeys = <String>{
  'yemek',
  'restoran',
  'gida',
  'kasap',
  'manav',
  'balik',
};

const Set<String> _foodKeywordTokens = <String>{
  'yemek',
  'restoran',
  'restaurant',
  'gida',
  'kasap',
  'manav',
  'balik',
  'kafe',
  'cafe',
  'lokanta',
  'kebap',
  'doner',
  'döner',
  'catering',
  'mutfak',
};

/// Porsiyon, kiloluk ve gramaj alanlarının gösterileceği kategoriler.
bool isFoodPricingCategory(String? categoryKey, [String? subCategoryKey]) {
  final main = normalizeCategoryKey(categoryKey);
  final sub = normalizeCategoryKey(subCategoryKey);
  if (main.isEmpty && sub.isEmpty) return false;

  if (_foodMainCategoryKeys.contains(main)) return true;
  for (final token in _foodKeywordTokens) {
    if (main.contains(token) || sub.contains(token)) return true;
  }
  return false;
}

/// Fiziksel ürün: satış fiyatı, stok, SKU, kargo vb. alanlar gösterilir.
bool isPhysicalProductCategory(String? categoryKey, [String? subCategoryKey]) {
  if (isFoodPricingCategory(categoryKey, subCategoryKey)) return false;
  final main = normalizeCategoryKey(categoryKey);
  if (main.isEmpty) return true;
  const nonPhysical = <String>{'hizmet', 'dijital urun', 'dijital ürün'};
  for (final token in nonPhysical) {
    if (main.contains(normalizeCategoryKey(token))) return false;
  }
  return true;
}

/// Alt kategori için hazır teknik özellik şablonu.
/// DB'de tanım yoksa manuel giriş için önerilen alanlar.
List<String> subCategoryAttributeTemplate(
  String? mainCategory,
  String? subCategory,
) {
  final main = normalizeCategoryKey(mainCategory);
  final sub = normalizeCategoryKey(subCategory);
  if (main.isEmpty) return const <String>[];

  if (main.contains('elektronik')) {
    if (sub.contains('telefon')) {
      return const <String>[
        'Dahili Hafıza',
        'RAM Kapasitesi',
        'Ekran Boyutu',
        'Kamera Çözünürlüğü',
        'Batarya Kapasitesi',
        'İşlemci',
        'İşletim Sistemi',
        'Garanti Süresi',
        'Renk',
        'Menşei',
        'Kozmetik Durum',
      ];
    }
    if (sub.contains('ev alet') ||
        sub.contains('kucuk ev') ||
        sub.contains('beyaz esya')) {
      return const <String>[
        'Güç',
        'Kapasite',
        'Enerji Sınıfı',
        'Garanti Süresi',
        'Ölçüler',
        'Renk',
        'Kullanım Tipi',
      ];
    }
    if (sub.contains('bilgisayar') ||
        sub.contains('laptop') ||
        sub.contains('tablet')) {
      return const <String>[
        'İşlemci',
        'RAM Kapasitesi',
        'Dahili Hafıza',
        'Ekran Boyutu',
        'İşletim Sistemi',
        'Garanti Süresi',
        'Renk',
      ];
    }
    if (sub.contains('gaming') || sub.contains('oyuncu')) {
      return const <String>[
        'İşlemci',
        'RAM Kapasitesi',
        'Ekran Boyutu',
        'Garanti Süresi',
        'Renk',
      ];
    }
  }

  if (main.contains('kisisel') ||
      main.contains('kozmetik') ||
      sub.contains('kisisel bakim cihaz')) {
    if (sub.contains('sac') ||
        sub.contains('cilt') ||
        sub.contains('cihaz') ||
        sub.contains('tiras')) {
      return const <String>[
        'Güç',
        'Başlık Sayısı',
        'Kablosuz Kullanım',
        'Şarj Süresi',
        'Kullanım Süresi',
        'Garanti Süresi',
      ];
    }
  }

  return const <String>[];
}
