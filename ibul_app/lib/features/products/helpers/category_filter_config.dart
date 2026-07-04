import '../../../utils/text_normalizer.dart';
import '../models/product_filter_models.dart';
import 'product_quick_filter_chip_groups.dart';

/// Kategori bazlı filtre görünürlüğü ve chip etiketleri.
abstract final class CategoryFilterConfig {
  CategoryFilterConfig._();

  /// Ana tab shell — Harita sekmesi indeksi ([HomeScreen] bottom nav).
  static const int mapTabIndex = 2;

  static const Set<String> _foodHiddenChipKeys = {
    'size',
    'color',
    'storage',
    'ram',
    'gender',
    'numara',
  };

  static const List<String> _foodChipPriority = [
    'brand',
    'seller',
    'subcategory',
    'price',
    'foodtype',
    'portion',
    'delivery',
  ];

  static bool isFoodCategory(String? category) {
    final normalized = TextNormalizer.normalize(category ?? '');
    if (normalized.isEmpty) return false;
    return normalized == 'yemek' ||
        normalized.contains('yemek') ||
        normalized.contains('hizli yemek') ||
        normalized.contains('restoran');
  }

  static String brandGroupTitle(String mainCategory) {
    return isFoodCategory(mainCategory) ? 'Restoran' : 'Marka';
  }

  static String subCategoryGroupTitle(String mainCategory) {
    return isFoodCategory(mainCategory) ? 'Yemek Türü' : 'Alt Kategori';
  }

  static String sellerGroupTitle(String mainCategory) {
    return isFoodCategory(mainCategory) ? 'Mağaza' : 'Satıcı / Mağaza';
  }

  static bool shouldLoadDbAttributeGroups({
    required String mainCategory,
    required String subCategory,
  }) {
    if (isFoodCategory(mainCategory)) return false;
    if (TextNormalizer.normalize(subCategory) == 'yemek') return false;
    return true;
  }

  static List<ProductFilterGroup> filterQuickChipGroups({
    required List<ProductFilterGroup> candidates,
    required List<ProductFilterGroup> allGroups,
    required String mainCategory,
    int maxChips = 4,
  }) {
    if (!isFoodCategory(mainCategory)) {
      return candidates;
    }

    final filtered = candidates.where((group) {
      final key = ProductQuickFilterChipGroups.quickFilterCanonicalKey(group);
      if (_foodHiddenChipKeys.contains(key)) return false;
      final title = TextNormalizer.normalize(group.title);
      if (title.contains('beden') ||
          title.contains('numara') ||
          title.contains('renk') ||
          title.contains('cinsiyet') ||
          title.contains('malzeme')) {
        return false;
      }
      return true;
    }).toList(growable: true);

    if (!filtered.any((g) => g.id == 'price')) {
      final price = _findGroupById(allGroups, 'price');
      if (price != null) filtered.add(price);
    }

    if (!filtered.any((g) => g.type == ProductFilterGroupType.seller)) {
      final seller = _findGroupById(allGroups, 'seller');
      if (seller != null) filtered.insert(0, seller);
    }

    filtered.sort((a, b) {
      final aRank = _foodChipRank(_foodChipSortKey(a));
      final bRank = _foodChipRank(_foodChipSortKey(b));
      return aRank.compareTo(bRank);
    });

    return filtered.take(maxChips).toList(growable: false);
  }

  static String quickChipLabel({
    required String mainCategory,
    required ProductFilterGroup group,
    required String defaultLabel,
  }) {
    if (!isFoodCategory(mainCategory)) return defaultLabel;

    switch (ProductQuickFilterChipGroups.quickFilterCanonicalKey(group)) {
      case 'brand':
        return 'Restoran';
      case 'seller':
        return 'Mağaza';
      default:
        if (group.type == ProductFilterGroupType.subcategory ||
            group.id == 'subcategory') {
          return 'Yemek Türü';
        }
        if (group.type == ProductFilterGroupType.priceRange ||
            group.id == 'price') {
          return 'Fiyat';
        }
        final title = TextNormalizer.normalize(group.title);
        if (title.contains('porsiyon')) return 'Porsiyon';
        if (title.contains('teslimat') || title.contains('hazirlanma')) {
          return 'Teslimat';
        }
        return defaultLabel;
    }
  }

  static String _foodChipSortKey(ProductFilterGroup group) {
    if (group.id == 'brand') return 'brand';
    if (group.id == 'seller') return 'seller';
    if (group.id == 'subcategory') return 'subcategory';
    if (group.id == 'price') return 'price';
    final title = TextNormalizer.normalize(group.title);
    if (title.contains('porsiyon')) return 'portion';
    if (title.contains('teslimat') || title.contains('hazirlanma')) {
      return 'delivery';
    }
    if (title.contains('tur') || title.contains('yemek')) return 'foodtype';
    return ProductQuickFilterChipGroups.quickFilterCanonicalKey(group);
  }

  static int _foodChipRank(String key) {
    final index = _foodChipPriority.indexOf(key);
    return index >= 0 ? index : _foodChipPriority.length;
  }

  static ProductFilterGroup? _findGroupById(
    List<ProductFilterGroup> groups,
    String id,
  ) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }
}
