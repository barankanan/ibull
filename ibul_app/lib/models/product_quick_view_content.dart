import 'dart:convert';

import 'product_model.dart';

/// Quick view popup'ında gösterilen tek bir normalize özellik satırı.
class ProductQuickSpec {
  const ProductQuickSpec({
    required this.label,
    required this.value,
    this.priority = 100,
  });

  final String label;
  final String value;

  /// Küçük değer önce gösterilir (öncelikli alanlar < 100).
  final int priority;

  @override
  String toString() => '$label: $value';
}

/// Farklı kaynaklardan (specifications JSON/metin, attributes, features)
/// gelen ürün özelliklerini tek [ProductQuickSpec] listesine çevirir ve
/// açıklamayı önceliklendirir. SAF fonksiyonlar — fake/demo veri ÜRETMEZ;
/// yalnız üründe gerçekten bulunan alanları döndürür.
class ProductQuickViewContent {
  ProductQuickViewContent._();

  /// Öncelikli özellik etiketleri (küçük indeks = önce gösterilir).
  static const List<String> _priorityLabelKeywords = <String>[
    'hafıza',
    'depolama',
    'ram',
    'ekran',
    'işlemci',
    'kapasite',
    'renk',
    'bağlantı',
    'model',
    'beden',
    'materyal',
    'marka',
    'garanti',
  ];

  static String _clean(String? raw) => (raw ?? '').trim();

  static bool _isEmptyish(String value) {
    final lower = value.toLowerCase();
    return value.isEmpty ||
        lower == 'null' ||
        lower == 'undefined' ||
        lower == '-';
  }

  static int _priorityFor(String label) {
    final lower = label.toLowerCase();
    for (var i = 0; i < _priorityLabelKeywords.length; i++) {
      if (lower.contains(_priorityLabelKeywords[i])) return i;
    }
    return 100;
  }

  /// "Anahtar: Değer" metnini spec'e çevirir; ':' yoksa null.
  static ProductQuickSpec? _specFromLine(String line) {
    final text = line.trim();
    final idx = text.indexOf(':');
    if (idx <= 0) return null;
    final label = _clean(text.substring(0, idx));
    final value = _clean(text.substring(idx + 1));
    if (_isEmptyish(label) || _isEmptyish(value)) return null;
    return ProductQuickSpec(
      label: label,
      value: value,
      priority: _priorityFor(label),
    );
  }

  /// `specifications` alanını parse eder. Desteklenen biçimler:
  /// - JSON object: {"RAM": "8GB", "Ekran": "6.7 inç"}
  /// - JSON array:  ["Renk: Mavi", "Hafıza: 64 GB"]
  /// - Düz metin:   "Ekran: 10.9 inç\nHafıza: 64 GB"
  static List<ProductQuickSpec> parseSpecificationsField(String? raw) {
    final text = _clean(raw);
    if (_isEmptyish(text)) return const <ProductQuickSpec>[];

    // JSON dene
    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) {
          return <ProductQuickSpec>[
            for (final entry in decoded.entries)
              if (!_isEmptyish(_clean(entry.key.toString())) &&
                  entry.value != null &&
                  entry.value is! Map &&
                  entry.value is! List &&
                  !_isEmptyish(_clean(entry.value.toString())))
                ProductQuickSpec(
                  label: _clean(entry.key.toString()),
                  value: _clean(entry.value.toString()),
                  priority: _priorityFor(entry.key.toString()),
                ),
          ];
        }
        if (decoded is List) {
          final specs = <ProductQuickSpec>[];
          for (final item in decoded) {
            if (item == null) continue;
            final spec = _specFromLine(item.toString());
            if (spec != null) specs.add(spec);
          }
          return specs;
        }
      } catch (_) {
        // JSON değilse satır bazlı parse'a düş.
      }
    }

    // "Key: Value" satırları
    return <ProductQuickSpec>[
      for (final line in text.split(RegExp(r'[\n;]')))
        if (_specFromLine(line) != null) _specFromLine(line)!,
    ];
  }

  /// attributes / features gibi string listelerini spec'e çevirir.
  /// "Key: Value" biçimli olanlar key/value olur; düz metinler
  /// değer-only chip olarak (label boş) korunmaz — atlanır, çünkü popup
  /// key/value satırları gösterir; düz metin özellikler [plainFeatures]
  /// ile ayrıca alınabilir.
  static List<ProductQuickSpec> parseKeyValueList(List<String>? items) {
    if (items == null || items.isEmpty) return const <ProductQuickSpec>[];
    return <ProductQuickSpec>[
      for (final item in items)
        if (_specFromLine(item) != null) _specFromLine(item)!,
    ];
  }

  /// "Key: Value" biçiminde OLMAYAN düz metin özellikler (chip olarak
  /// gösterilir): ör. "Su geçirmez", "Bluetooth 5.0".
  static List<String> plainFeatures(Product product) {
    final out = <String>[];
    final seen = <String>{};
    for (final source in <List<String>?>[
      product.features,
      product.attributes,
    ]) {
      if (source == null) continue;
      for (final item in source) {
        final text = _clean(item);
        if (_isEmptyish(text)) continue;
        if (text.indexOf(':') > 0) continue; // key/value — specs'e gider
        final key = text.toLowerCase();
        if (seen.add(key)) out.add(text);
      }
    }
    return out;
  }

  /// Tüm kaynaklardan birleşik, tekilleştirilmiş, öncelik sıralı spec listesi.
  static List<ProductQuickSpec> buildQuickSpecs(Product product) {
    final merged = <ProductQuickSpec>[
      ...parseSpecificationsField(product.specifications),
      ...parseKeyValueList(product.attributes),
      ...parseKeyValueList(product.features),
    ];
    final seenLabels = <String>{};
    final deduped = <ProductQuickSpec>[
      for (final spec in merged)
        if (seenLabels.add(spec.label.toLowerCase())) spec,
    ];
    // Stabil sıralama: öncelik, sonra orijinal sıra.
    final indexed = deduped.asMap().entries.toList()
      ..sort((a, b) {
        final byPriority = a.value.priority.compareTo(b.value.priority);
        return byPriority != 0 ? byPriority : a.key.compareTo(b.key);
      });
    return <ProductQuickSpec>[for (final e in indexed) e.value];
  }

  /// Açıklama önceliği: description → shortDescription → specifications
  /// içindeki açıklama anahtarları. Hiçbiri yoksa null (fallback metni UI'da).
  static String? resolveDescription(Product product) {
    final direct = _clean(product.description);
    if (!_isEmptyish(direct)) return direct;
    final short = _clean(product.shortDescription);
    if (!_isEmptyish(short)) return short;
    // specifications JSON map ise açıklama anahtarlarına bak.
    final raw = _clean(product.specifications);
    if (raw.startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final key in const <String>[
            'long_description',
            'description',
            'product_description',
            'short_description',
            'details',
            'aciklama',
            'açıklama',
          ]) {
            final value = _clean(decoded[key]?.toString());
            if (!_isEmptyish(value)) return value;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
