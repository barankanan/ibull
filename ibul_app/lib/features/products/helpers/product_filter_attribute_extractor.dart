import '../../../models/product_model.dart';
import '../../../services/category_attribute_service.dart';
import '../../../utils/text_normalizer.dart';

class ProductFilterAttributeExtractor {
  const ProductFilterAttributeExtractor._();

  static const Map<String, List<String>> _categoryHints = {
    'elektronik::telefon': [
      'Marka',
      'Model',
      'Depolama',
      'RAM',
      'Ekran Boyutu',
      'Renk',
      'Garanti',
      'Durum',
      '5G',
      'Şarj Tipi',
    ],
    'elektronik::telefonlar': [
      'Marka',
      'Model',
      'Depolama',
      'RAM',
      'Ekran Boyutu',
      'Renk',
      'Garanti',
      'Durum',
      '5G',
      'Şarj Tipi',
    ],
    'elektronik::bilgisayar': [
      'Marka',
      'İşlemci',
      'RAM',
      'Depolama',
      'Ekran Boyutu',
      'Ekran Kartı',
      'İşletim Sistemi',
      'Kullanım Tipi',
    ],
    'elektronik::laptop': [
      'Marka',
      'İşlemci',
      'RAM',
      'Depolama',
      'Ekran Boyutu',
      'Ekran Kartı',
      'İşletim Sistemi',
    ],
    'elektronik::televizyon': [
      'Marka',
      'Model',
      'Ekran Boyutu',
      'Çözünürlük',
      'Panel Tipi',
      'Smart TV',
      'Garanti',
    ],
    'elektronik::tv': [
      'Marka',
      'Model',
      'Ekran Boyutu',
      'Çözünürlük',
      'Panel Tipi',
      'Smart TV',
      'Garanti',
    ],
    'erkek::giyim': ['Beden', 'Renk', 'Kumaş', 'Cinsiyet', 'Sezon', 'Kalıp', 'Marka'],
    'kadin::giyim': ['Beden', 'Renk', 'Kumaş', 'Cinsiyet', 'Sezon', 'Kalıp', 'Marka'],
    'erkek::ayakkabi': [
      'Numara',
      'Renk',
      'Marka',
      'Materyal',
      'Kullanım',
      'Cinsiyet',
    ],
    'kadin::ayakkabi': [
      'Numara',
      'Renk',
      'Marka',
      'Materyal',
      'Kullanım',
      'Cinsiyet',
    ],
    'aksesuar::saat': [
      'Marka',
      'Renk',
      'Kordon Tipi',
      'Materyal',
      'Su Geçirmezlik',
    ],
    'ev::yasam': ['Marka', 'Renk', 'Malzeme', 'Ölçü', 'Oda Tipi'],
    'kirtasiye::ofis': ['Marka', 'Ürün Tipi', 'Renk', 'Paket Adedi'],
    'supermarket::gida': ['Marka', 'Gramaj', 'Paket Adedi', 'Organik'],
    'yemek::restoran': [
      'Mutfak Türü',
      'Porsiyon',
      'Acılı',
      'Vejetaryen',
      'Hazırlanma Süresi',
    ],
  };

  static final Map<String, RegExp> _patternExtractors = {
    'Depolama': RegExp(r'\b(\d+(?:[.,]\d+)?\s*(?:GB|TB))\b', caseSensitive: false),
    'RAM': RegExp(r'\b(\d+(?:[.,]\d+)?\s*GB(?:\s*RAM)?)\b', caseSensitive: false),
    'Beden': RegExp(r'\b(XXS|XS|S|M|L|XL|XXL|XXXL)\b', caseSensitive: false),
    'Numara': RegExp(
      r'\b(\d{2}(?:[.,]\d)?(?:\s*(?:numara|no))?)\b',
      caseSensitive: false,
    ),
    'Ekran Boyutu': RegExp(
      r'\b(\d{1,2}(?:[.,]\d)?\s*(?:inç|inch|"))(?![a-zA-Z0-9])',
      caseSensitive: false,
    ),
  };

  static String _categoryKey(String mainCategory, String subCategory) {
    final main = TextNormalizer.normalize(mainCategory);
    final sub = TextNormalizer.normalize(subCategory);
    return '$main::$sub';
  }

  static List<String> hintsForCategory({
    required String mainCategory,
    required String subCategory,
  }) {
    final key = _categoryKey(mainCategory, subCategory);
    if (_categoryHints.containsKey(key)) {
      return _categoryHints[key]!;
    }

    for (final entry in _categoryHints.entries) {
      final parts = entry.key.split('::');
      if (parts.length != 2) continue;
      if (key.contains(parts[0]) && key.contains(parts[1])) {
        return entry.value;
      }
    }

    if (key.contains('telefon')) {
      return _categoryHints['elektronik::telefon']!;
    }
    if (key.contains('giyim')) {
      return _categoryHints['erkek::giyim']!;
    }
    if (key.contains('ayakkabi') || key.contains('ayakkab')) {
      return _categoryHints['erkek::ayakkabi']!;
    }
    if (key.contains('bilgisayar') || key.contains('laptop')) {
      return _categoryHints['elektronik::bilgisayar']!;
    }
    if (key.contains('televizyon') || key.contains('tv')) {
      return _categoryHints['elektronik::televizyon']!;
    }
    if (key.contains('yemek') || mainCategory.toLowerCase().contains('yemek')) {
      return const [
        'Yemek Türü',
        'Porsiyon',
        'Teslimat',
        'Marka',
      ];
    }

    return const ['Renk', 'Marka', 'Model', 'Beden', 'Depolama', 'RAM', 'Ekran Boyutu'];
  }

  static Map<String, Set<String>> extractDynamicAttributes({
    required List<Product> products,
    required String mainCategory,
    required String subCategory,
    List<String> dbAttributeNames = const [],
  }) {
    final hints = <String>{
      ...hintsForCategory(
        mainCategory: mainCategory,
        subCategory: subCategory,
      ),
      ...dbAttributeNames,
    };

    final grouped = <String, Set<String>>{
      for (final hint in hints) hint: <String>{},
    };

    for (final product in products) {
      final values = _collectProductAttributeMap(product);
      for (final hint in hints) {
        final direct = values[hint];
        if (direct != null && direct.isNotEmpty) {
          grouped[hint]!.add(direct);
          continue;
        }

        final normalizedHint = TextNormalizer.normalize(hint);
        for (final entry in values.entries) {
          if (TextNormalizer.normalize(entry.key) == normalizedHint &&
              entry.value.isNotEmpty) {
            grouped[hint]!.add(entry.value);
          }
        }

        final pattern = _patternExtractors[hint];
        if (pattern != null) {
          final haystack = '${product.name} ${product.description ?? ''}';
          for (final match in pattern.allMatches(haystack)) {
            final value = match.group(1)?.trim();
            if (value != null && value.isNotEmpty) {
              grouped[hint]!.add(_normalizeExtractedValue(hint, value, match.group(0)));
            }
          }
        }
      }
    }

    grouped.removeWhere((_, values) => values.isEmpty);
    return grouped;
  }

  static Map<String, String> _collectProductAttributeMap(Product product) {
    final values = <String, String>{};

    values.addAll(
      CategoryAttributeService.decodeProductSpecifications(product.specifications),
    );

    if (product.variantOptions != null && product.variantOptions!.isNotEmpty) {
      for (final part in product.variantOptions!.split('|')) {
        final segments = part.split(':');
        if (segments.length < 2) continue;
        final key = segments.first.trim();
        final value = segments.sublist(1).join(':').trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          values[key] = value;
        }
      }
    }

    if (product.attributes != null) {
      for (final item in product.attributes!) {
        final trimmed = item.trim();
        if (trimmed.isEmpty) continue;
        values.putIfAbsent(trimmed, () => trimmed);
      }
    }

    if (product.brand.trim().isNotEmpty) {
      values.putIfAbsent('Marka', () => product.brand.trim());
    }

    return values;
  }

  static String _normalizeExtractedValue(
    String hint,
    String captured,
    String? fullMatch,
  ) {
    switch (hint) {
      case 'Depolama':
        final upper = (fullMatch ?? captured).toUpperCase();
        final numPart = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(captured)?.group(0)?.replaceAll(',', '.') ?? captured;
        if (upper.contains('TB')) return '$numPart TB';
        if (upper.contains('GB')) return '$numPart GB';
        return captured;
      case 'RAM':
        final numPart = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(captured)?.group(0)?.replaceAll(',', '.') ?? captured;
        return '$numPart GB';
      case 'Ekran Boyutu':
        final numPart = RegExp(r'\d{1,2}(?:[.,]\d)?').firstMatch(captured)?.group(0)?.replaceAll(',', '.') ?? captured;
        return '$numPart inç';
      case 'Numara':
        final numPart = RegExp(r'\d{2}(?:[.,]\d)?').firstMatch(captured)?.group(0)?.replaceAll(',', '.') ?? captured;
        return numPart;
      case 'Beden':
        return captured.toUpperCase();
      default:
        return captured;
    }
  }

  static Map<String, String> attributeMapForProduct(Product product) {
    return _collectProductAttributeMap(product);
  }
}
