import 'mobile_category_catalog.dart';

/// Kategori / alt kategori kartları için asset öncelikli görsel çözümleyici.
/// Eski `categories_page` `_subCategoryIcons` haritasının mobil kategori ağacına
/// taşınmış ve ana kategori bağlamı eklenmiş halidir.
class CategoryImageResolver {
  const CategoryImageResolver._();

  static const String _subDir = 'assets/subcategory_icons';
  static const String _mainDir = 'assets/category_icons';

  static const Map<String, String> _subCategoryAssets = {
    'yemek': '$_subDir/yemek.png',
    'market': '$_subDir/market.png',
    'isletme': '$_subDir/işletme.png',
    'meslekler': '$_subDir/meslekler.png',
    'telefon & aksesuar': '$_subDir/telefon & aksesuar.png',
    'telefonlar': '$_subDir/telefon & aksesuar.png',
    'bilgisayar & tablet': '$_subDir/bilgisayar & tablet.png',
    'tv & ses sistemleri': '$_subDir/tv & ses sistemleri.png',
    'kamera & fotograf': '$_subDir/kamera & fotoğraf.png',
    'spor ayakkabi': '$_subDir/spor ayakkabı.png',
    'spor giyim': '$_subDir/spor giyim.png',
    'spor giyim & ayakkabi': '$_subDir/spor giyim.png',
    'outdoor': '$_subDir/outdoor.png',
    'outdoor giyim & ayakkabi': '$_subDir/outdoor.png',
    'fitness & kondisyon': '$_subDir/fitness & kondisyon.png',
    'kadin giyim': '$_subDir/Kadın giyim.png',
    'erkek giyim': '$_subDir/Erkek Giyim.png',
    'cocuk giyim': '$_subDir/Çocuk Giyim.png',
    'aksesuar': '$_subDir/aksesuar.png',
    'giyim': '$_subDir/Erkek Giyim.png',
    'ayakkabi & canta': '$_subDir/spor ayakkabı.png',
    'spor & outdoor': '$_subDir/outdoor.png',
    'kisisel bakim': '$_mainDir/kozmetik & Kişisel Bakım.png',
    'buyuk beden': '$_subDir/Erkek Giyim.png',
    'saat': '$_subDir/aksesuar.png',
    'kozmetik': '$_mainDir/kozmetik & Kişisel Bakım.png',
    'ev & ic giyim': '$_subDir/Kadın giyim.png',
  };

  static const Map<String, String> _mainSubAssets = {
    'erkek::giyim': '$_subDir/Erkek Giyim.png',
    'kadin::giyim': '$_subDir/Kadın giyim.png',
    'kadin::kozmetik': '$_mainDir/kozmetik & Kişisel Bakım.png',
    'kadin::ev & ic giyim': '$_subDir/Kadın giyim.png',
    'kadin::buyuk beden': '$_subDir/Kadın giyim.png',
    'erkek::saat': '$_subDir/aksesuar.png',
    'erkek::aksesuar': '$_subDir/aksesuar.png',
    'erkek::ayakkabi & canta': '$_subDir/spor ayakkabı.png',
    'erkek::spor & outdoor': '$_subDir/outdoor.png',
    'erkek::kisisel bakim': '$_mainDir/kozmetik & Kişisel Bakım.png',
    'erkek::buyuk beden': '$_subDir/Erkek Giyim.png',
    'kadin::aksesuar': '$_subDir/aksesuar.png',
    'kadin::ayakkabi & canta': '$_subDir/spor ayakkabı.png',
    'kadin::spor & outdoor': '$_subDir/outdoor.png',
    'cocuk::giyim': '$_subDir/Çocuk Giyim.png',
    'cocuk::aksesuar': '$_subDir/aksesuar.png',
    'cocuk::ayakkabi': '$_subDir/spor ayakkabı.png',
    'spor & outdoor::spor giyim & ayakkabi': '$_subDir/spor giyim.png',
    'spor & outdoor::outdoor giyim & ayakkabi': '$_subDir/outdoor.png',
    'spor & outdoor::fitness & kondisyon': '$_subDir/fitness & kondisyon.png',
    'elektronik::telefon & aksesuar': '$_subDir/telefon & aksesuar.png',
    'elektronik::bilgisayar & tablet': '$_subDir/bilgisayar & tablet.png',
    'elektronik::tv & ses sistemleri': '$_subDir/tv & ses sistemleri.png',
    'elektronik::kamera & fotograf': '$_subDir/kamera & fotoğraf.png',
    'yakin lokasyon::yemek': '$_subDir/yemek.png',
    'yakin lokasyon::market': '$_subDir/market.png',
  };

  static const Map<String, String> _mainCategoryAssets = {
    'yakin lokasyon': '$_mainDir/Yakın lokasyon.png',
    'elektronik': '$_mainDir/elektronik.png',
    'spor & outdoor': '$_mainDir/spor & Outdoor.png',
    'giyim & aksesuar': '$_mainDir/Giyim & Aksesuar.png',
    'erkek': '$_mainDir/Giyim & Aksesuar.png',
    'kadin': '$_mainDir/Giyim & Aksesuar.png',
    'cocuk': '$_mainDir/Giyim & Aksesuar.png',
    'anne & bebek & oyuncak': '$_mainDir/Anne & Bebek & Oyuncak.png',
    'kozmetik & kisisel bakim': '$_mainDir/kozmetik & Kişisel Bakım.png',
    'ev & yasam': '$_mainDir/Ev & Yaşam.png',
    'kitap & hobi': '$_mainDir/Kitap & Hobi.png',
    'supermarket & petshop': '$_mainDir/Süpermakret & Petshop.png',
    'supermarket': '$_mainDir/Süpermakret & Petshop.png',
  };

  static String? resolveSubCategoryAsset({
    required String mainCategoryName,
    required String subCategoryName,
    String? explicitFallback,
  }) {
    if (explicitFallback != null && explicitFallback.trim().isNotEmpty) {
      return explicitFallback;
    }

    final mainKey = normalizeCategoryNameForLookup(mainCategoryName);
    final subKey = normalizeCategoryNameForLookup(subCategoryName);
    final composite = '$mainKey::$subKey';

    final compositeAsset = _mainSubAssets[composite];
    if (compositeAsset != null) return compositeAsset;

    final directAsset = _subCategoryAssets[subKey];
    if (directAsset != null) return directAsset;

    for (final entry in _subCategoryAssets.entries) {
      if (subKey.contains(entry.key) || entry.key.contains(subKey)) {
        return entry.value;
      }
    }

    return null;
  }

  static String? resolveMainCategoryAsset({
    required String mainCategoryName,
    String? explicitFallback,
  }) {
    if (explicitFallback != null && explicitFallback.trim().isNotEmpty) {
      return explicitFallback;
    }
    return _mainCategoryAssets[normalizeCategoryNameForLookup(mainCategoryName)];
  }

  static String? resolveForNode(
    MobileCategoryNode node, {
    String? parentMainCategoryName,
  }) {
    if (node.isMainCategory) {
      return resolveMainCategoryAsset(
        mainCategoryName: node.name,
        explicitFallback: node.fallbackAssetPath,
      );
    }
    return resolveSubCategoryAsset(
      mainCategoryName: parentMainCategoryName ?? '',
      subCategoryName: node.name,
      explicitFallback: node.fallbackAssetPath,
    );
  }
}
