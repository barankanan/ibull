import '../models/product_filter_models.dart';
import '../../../utils/text_normalizer.dart';

/// Mobil kategori ürün listesi hızlı filtre chip'leri için aday grupları
/// tekilleştirir ve öncelik sırasına göre döner.
class ProductQuickFilterChipGroups {
  const ProductQuickFilterChipGroups._();

  static const List<String> _displayPriority = [
    'brand',
    'storage',
    'ram',
    'size',
    'color',
  ];

  static const Map<String, String> _canonicalAliases = {
    'marka': 'brand',
    'brand': 'brand',
    'manufacturer': 'brand',
    'uretici': 'brand',
    'attribute:brand': 'brand',
    'attribute_brand': 'brand',
    'attribute brand': 'brand',
    'depolama': 'storage',
    'storage': 'storage',
    'hafiza': 'storage',
    'ram': 'ram',
    'memory': 'ram',
    'beden': 'size',
    'size': 'size',
    'renk': 'color',
    'color': 'color',
  };

  static List<ProductFilterGroup> resolve(
    List<ProductFilterGroup> allGroups, {
    int maxChips = 4,
  }) {
    final candidates = _buildCandidates(allGroups);
    return dedupeAndSort(candidates).take(maxChips).toList(growable: false);
  }

  static List<ProductFilterGroup> dedupeAndSort(List<ProductFilterGroup> candidates) {
    return dedupeForRender(candidates);
  }

  /// Mobil chip satırına basılmadan önce aynı canonical key tekrarlarını
  /// kaldırır; ilk adayı korur ve öncelik sırasına göre döner.
  static List<ProductFilterGroup> dedupeForRender(
    List<ProductFilterGroup> candidates,
  ) {
    final deduped = <String, ProductFilterGroup>{};

    for (final group in candidates) {
      deduped.putIfAbsent(quickFilterCanonicalKey(group), () => group);
    }

    final sortedKeys = deduped.keys.toList()
      ..sort(
        (a, b) => _displayPriorityIndex(a).compareTo(_displayPriorityIndex(b)),
      );

    return sortedKeys
        .map((key) => deduped[key]!)
        .toList(growable: false);
  }

  static String canonicalQuickChipKey(ProductFilterGroup group) {
    return quickFilterCanonicalKey(group);
  }

  static String quickFilterCanonicalKey(ProductFilterGroup group) {
    if (group.type == ProductFilterGroupType.brand) {
      return 'brand';
    }

    final id = TextNormalizer.normalize(group.id);
    final title = TextNormalizer.normalize(group.title);
    final raw = '$id $title';

    if (raw.contains('brand') ||
        raw.contains('marka') ||
        raw.contains('manufacturer') ||
        raw.contains('uretici')) {
      return 'brand';
    }

    if (raw.contains('storage') ||
        raw.contains('depolama') ||
        raw.contains('hafiza')) {
      return 'storage';
    }

    if (raw.contains('ram') || raw.contains('memory')) {
      return 'ram';
    }

    if (raw.contains('beden') || raw.contains('size')) {
      return 'size';
    }

    if (raw.contains('renk') || raw.contains('color')) {
      return 'color';
    }

    final titleKey = _normalizeQuickChipLabel(group.title);
    final idKey = _normalizeQuickChipLabel(
      group.id.replaceFirst('attr::', ''),
    );

    return _canonicalAliases[titleKey] ??
        _canonicalAliases[idKey] ??
        (id.isNotEmpty ? id : titleKey);
  }

  static String quickChipDisplayLabel(ProductFilterGroup group) {
    switch (canonicalQuickChipKey(group)) {
      case 'brand':
        return 'Marka';
      case 'storage':
        return 'Depolama';
      case 'ram':
        return 'RAM';
      case 'size':
        return 'Beden';
      case 'color':
        return 'Renk';
      default:
        return group.title.trim();
    }
  }

  static List<ProductFilterGroup> _buildCandidates(
    List<ProductFilterGroup> allGroups,
  ) {
    final candidates = <ProductFilterGroup>[];

    final brand = _findGroup(allGroups, id: 'brand');
    if (brand != null && brand.options.isNotEmpty) {
      candidates.add(brand);
    }

    for (final group in allGroups) {
      if (group.type != ProductFilterGroupType.dynamicAttribute) continue;
      if (group.options.isEmpty) continue;
      candidates.add(group);
    }

    if (candidates.isEmpty) {
      final price = _findGroup(allGroups, id: 'price');
      if (price != null) candidates.add(price);
      final discount = _findGroup(allGroups, id: 'discount');
      if (discount != null) candidates.add(discount);
    }

    return candidates;
  }

  static ProductFilterGroup? _findGroup(
    List<ProductFilterGroup> groups, {
    required String id,
  }) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  static int _displayPriorityIndex(String canonicalKey) {
    final index = _displayPriority.indexOf(canonicalKey);
    if (index >= 0) return index;
    return _displayPriority.length + canonicalKey.hashCode.abs();
  }

  static String _normalizeQuickChipLabel(String raw) {
    return TextNormalizer.normalize(raw)
        .replaceAll('_', ' ')
        .replaceAll('&', ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
