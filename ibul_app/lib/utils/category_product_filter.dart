import 'text_normalizer.dart';

/// UI kategori etiketleri ile ürün `main_category` / `sub_category` alanlarını
/// aynı kurallarla eşleştirir. Arama fuzzy/contains kullanır; kategori akışı
/// bu helper ile aynı veri gerçekliğine hizalanır.
class CategoryProductFilter {
  const CategoryProductFilter._();

  static bool isAllSubCategory(String? subCategory) {
    final trimmed = (subCategory ?? '').trim();
    if (trimmed.isEmpty) return true;
    final upper = trimmed.toUpperCase();
    return upper == 'HEPSI' || upper == 'HEPSİ';
  }

  /// Supabase `.or(...)` filtresi gerekiyorsa döner; exact `sub_category` eq
  /// yeterliyse `null` döner.
  static String? buildSubCategoryOrClause({
    required String mainCategory,
    required String subCategory,
  }) {
    final main = TextNormalizer.normalize(mainCategory);
    final sub = TextNormalizer.normalize(subCategory);

    if (main == TextNormalizer.normalize('Elektronik')) {
      if (sub.contains('telefonlar') || sub == 'telefon') {
        return 'sub_category.ilike.*telefon*,'
            'name.ilike.*telefon*,'
            'name.ilike.*iphone*,'
            'name.ilike.*galaxy*';
      }

      if (sub.contains('laptop') || sub.contains('tablet')) {
        return 'sub_category.ilike.*bilgisayar*,'
            'sub_category.ilike.*tablet*,'
            'name.ilike.*laptop*,'
            'name.ilike.*macbook*,'
            'name.ilike.*bilgisayar*';
      }

      if (sub.contains('televizyon')) {
        return 'sub_category.ilike.*tv*,'
            'sub_category.ilike.*televizyon*,'
            'name.ilike.*tv*,'
            'name.ilike.*televizyon*';
      }

      if (sub.contains('beyaz esya')) {
        return 'sub_category.ilike.*beyaz esya*';
      }

      if (sub.contains('isitma') || sub.contains('sogutma')) {
        return 'sub_category.ilike.*klima*,'
            'sub_category.ilike.*isitici*,'
            'name.ilike.*klima*,'
            'name.ilike.*isitici*';
      }

      if (sub.contains('sinema') || sub.contains('ses sistemleri')) {
        return 'sub_category.ilike.*tv & ses sistemleri*,'
            'sub_category.ilike.*ses*,'
            'name.ilike.*ses sistemi*';
      }

      if (sub.contains('telefon aksesuar')) {
        return 'sub_category.ilike.*telefon & aksesuar*,'
            'name.ilike.*kilif*,'
            'name.ilike.*kılıf*,'
            'name.ilike.*kulaklik*,'
            'name.ilike.*kulaklık*,'
            'name.ilike.*sarj*,'
            'name.ilike.*şarj*';
      }
    }

    return null;
  }

  static bool productMatchesSelection({
    required String mainCategory,
    required String? subCategory,
    required String? productMainCategory,
    required String? productSubCategory,
    required String productName,
  }) {
    final selectedMain = TextNormalizer.normalize(mainCategory);
    final productMain = TextNormalizer.normalize(productMainCategory ?? '');
    if (productMain != selectedMain) return false;

    if (isAllSubCategory(subCategory)) return true;

    final selectedSub = TextNormalizer.normalize(subCategory!);
    final productSub = TextNormalizer.normalize(productSubCategory ?? '');
    final productNameNorm = TextNormalizer.normalize(productName);

    if (selectedMain == TextNormalizer.normalize('Elektronik')) {
      if (selectedSub.contains('telefonlar') || selectedSub == 'telefon') {
        return productSub.contains('telefon') ||
            productNameNorm.contains('telefon') ||
            productNameNorm.contains('iphone') ||
            productNameNorm.contains('galaxy');
      }

      if (selectedSub.contains('laptop') || selectedSub.contains('tablet')) {
        return productSub.contains('bilgisayar') ||
            productSub.contains('tablet') ||
            productNameNorm.contains('laptop') ||
            productNameNorm.contains('macbook') ||
            productNameNorm.contains('bilgisayar');
      }

      if (selectedSub.contains('televizyon')) {
        return productSub.contains('tv') ||
            productSub.contains('televizyon') ||
            productNameNorm.contains('tv') ||
            productNameNorm.contains('televizyon');
      }

      if (selectedSub.contains('beyaz esya')) {
        return productSub.contains('beyaz esya');
      }

      if (selectedSub.contains('isitma') || selectedSub.contains('sogutma')) {
        return productSub.contains('klima') ||
            productSub.contains('isitici') ||
            productNameNorm.contains('klima') ||
            productNameNorm.contains('isitici');
      }

      if (selectedSub.contains('sinema') ||
          selectedSub.contains('ses sistemleri')) {
        return productSub.contains('tv & ses sistemleri') ||
            productSub.contains('ses') ||
            productNameNorm.contains('ses sistemi');
      }

      if (selectedSub.contains('telefon aksesuar')) {
        return productSub.contains('telefon & aksesuar') ||
            productNameNorm.contains('kilif') ||
            productNameNorm.contains('kılıf') ||
            productNameNorm.contains('kulaklik') ||
            productNameNorm.contains('kulaklık') ||
            productNameNorm.contains('sarj') ||
            productNameNorm.contains('şarj');
      }
    }

    return productSub.isNotEmpty && productSub == selectedSub;
  }
}
