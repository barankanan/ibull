import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/app_image_cdn.dart';
import '../core/constants.dart';
import '../core/review_state.dart';
import '../models/product_model.dart';
import '../services/review_repository.dart';
import 'product_detail/product_detail_content_helper.dart';

const kCompareMainCategoryMismatchMessage =
    'Farklı kategorilerdeki ürünler karşılaştırılamaz. Lütfen aynı kategoriden ürünler seçin.';

Product? compareProductAt(List<Map<String, dynamic>> maps, int index) {
  if (index >= maps.length) return null;
  return maps[index]['product'] as Product?;
}

List<Map<String, dynamic>> compareDisplayProducts(
  List<Map<String, dynamic>> products, {
  int maxCount = 4,
}) {
  return products.take(maxCount).toList(growable: false);
}

String compareCategoryLabel(List<Map<String, dynamic>> products) {
  final first = compareProductAt(products, 0);
  return first?.category ?? 'ürün';
}

String maskReviewUserName(String? name) {
  final value = (name ?? 'Kullanıcı').trim();
  if (value.length <= 2) return '$value**';
  return '${value.substring(0, value.length - 2)}**';
}

Future<List<Map<String, dynamic>>> loadReviewsForProduct(Product product) async {
  final reviewState = ReviewState();
  final local = reviewState.getProductReviewsFor(
    productName: product.name,
    storeName: product.store,
  );
  final summary = await ReviewRepository.instance.getProductReviewSummary(
    productName: product.name,
    storeName: product.store,
    localReviews: local,
  );
  return summary.reviews;
}

List<String> reviewImageUrls(Map<String, dynamic> review) {
  return ((review['imageUrls'] as List?) ?? const [])
      .map((item) => item.toString().trim())
      .where((url) => url.isNotEmpty)
      .toList(growable: false);
}

String? compareProductImageUrl(Map<String, dynamic> productMap) {
  final product = productMap['product'] as Product?;
  if (product != null) {
    final cdnUrl = product.imageFor(AppImageVariant.card);
    if (cdnUrl.isNotEmpty) return cdnUrl;
    for (final url in product.images) {
      final trimmed = url.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final thumb = product.thumbnailPublicUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) return thumb;
  }
  final fallback = productMap['image']?.toString().trim();
  return (fallback != null && fallback.isNotEmpty) ? fallback : null;
}

String compareNormalizeLabel(String label) => label.trim().toLowerCase();

String? compareNormalizeValue(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

String compareFormatSpecValue(dynamic raw) {
  if (raw == null) return '-';
  if (raw is List) {
    final items = raw
        .map((item) => compareNormalizeValue(item))
        .whereType<String>()
        .toList(growable: false);
    return items.isEmpty ? '-' : items.join(', ');
  }
  if (raw is Map) {
    final encoded = jsonEncode(raw);
    return encoded == '{}' ? '-' : encoded;
  }
  return compareNormalizeValue(raw) ?? '-';
}

Map<String, String> parseProductSpecificationsMap(Product product) {
  final raw = product.specifications?.trim() ?? '';
  if (raw.isEmpty) return const {};

  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final map = <String, String>{};
      decoded.forEach((key, value) {
        final label = compareNormalizeValue(key);
        final formatted = compareFormatSpecValue(value);
        if (label != null && formatted != '-') {
          map[label] = formatted;
        }
      });
      if (map.isNotEmpty) return map;
    }
  } catch (_) {}

  final map = <String, String>{};
  for (final line in raw.split('\n')) {
    final parts = line.split(':');
    if (parts.length < 2) continue;
    final key = parts[0].trim();
    final value = parts.sublist(1).join(':').trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      map[key] = value;
    }
  }
  return map;
}

Map<String, String> collectProductCompareFieldMap(Product product) {
  final normalizedToLabel = <String, String>{};
  final valuesByNormalized = <String, String>{};

  void put(String label, dynamic raw) {
    final displayLabel = label.trim();
    final value = compareFormatSpecValue(raw);
    if (displayLabel.isEmpty || value == '-') return;
    final normalized = compareNormalizeLabel(displayLabel);
    normalizedToLabel.putIfAbsent(normalized, () => displayLabel);
    valuesByNormalized[normalized] = value;
  }

  for (final spec in ProductDetailContentHelper.buildSpecs(product)) {
    put(spec['key'] ?? '', spec['value']);
  }

  for (final entry in parseProductSpecificationsMap(product).entries) {
    put(entry.key, entry.value);
  }

  for (final item in product.attributes ?? const <String>[]) {
    final text = item.trim();
    if (text.isEmpty) continue;
    final idx = text.indexOf(':');
    if (idx > 0) {
      put(text.substring(0, idx), text.substring(idx + 1));
    }
  }

  final simpleAttributes = (product.attributes ?? const <String>[])
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty && !item.contains(':'))
      .toList(growable: false);
  if (simpleAttributes.isNotEmpty) {
    put('Nitelikler', simpleAttributes.join(', '));
  }

  put('Marka', product.brand);
  put('Kategori', product.category);
  put('Alt Kategori', product.subCategory);
  put('Mağaza', product.store);
  put('Fiyat', product.price);
  put('Açıklama', product.displayFullDescription);
  put('Kısa Açıklama', product.shortDescription);
  put('Öne Çıkanlar', product.displayFeatures.join(', '));
  put('İçerik', product.displayIngredients.join(', '));
  put('Etiketler', product.tags.join(', '));
  put(
    'Puan',
    product.rating > 0 ? product.rating.toStringAsFixed(1) : null,
  );
  put(
    'Yorum Sayısı',
    product.reviewCount > 0 ? '${product.reviewCount} yorum' : null,
  );
  put('Hazırlanma', product.displayPreparationInfoText);

  final additional = product.displayAdditionalInfoItems;
  if (additional.isNotEmpty) {
    put('Ek Bilgiler', additional.join(' • '));
  }

  final serviceInfo = product.displayServiceInfo;
  if (serviceInfo.isNotEmpty) {
    put('Servis Bilgisi', serviceInfo.join(' • '));
  }

  return valuesByNormalized.map(
    (normalized, value) => MapEntry(
      normalizedToLabel[normalized] ?? normalized,
      value,
    ),
  );
}

List<CompareSpecRow> buildDynamicProductSpecRows(List<Product> products) {
  final productSpecMaps = products
      .map((product) => collectProductCompareFieldMap(product))
      .toList();

  final normalizedToDisplay = <String, String>{};
  final orderedKeys = <String>[];

  for (final specMap in productSpecMaps) {
    for (final label in specMap.keys) {
      final normalized = compareNormalizeLabel(label);
      if (!normalizedToDisplay.containsKey(normalized)) {
        normalizedToDisplay[normalized] = label;
        orderedKeys.add(normalized);
      }
    }
  }

  return orderedKeys.map((normalized) {
    final displayLabel = normalizedToDisplay[normalized]!;
    final values = productSpecMaps.map((specMap) {
      final direct = specMap[displayLabel];
      if (direct != null && direct != '-') return direct;
      for (final entry in specMap.entries) {
        if (compareNormalizeLabel(entry.key) == normalized) {
          return entry.value;
        }
      }
      return '-';
    }).toList(growable: false);
    return CompareSpecRow(displayLabel, values);
  }).toList(growable: false);
}

List<CompareSpecSection> buildCompareFeatureSections(List<Product> products) {
  if (products.isEmpty) return const [];

  final dynamicRows = buildDynamicProductSpecRows(products);
  final reserved = {
    'marka',
    'kategori',
    'alt kategori',
    'mağaza',
    'fiyat',
    'satıcı',
    'değerlendirmeler',
    'puan',
    'yorum sayısı',
    'etiketler',
  };

  final generalRows = <CompareSpecRow>[
    CompareSpecRow('Marka', products.map((p) => p.brand).toList()),
    CompareSpecRow(
      'Kategori',
      products.map((p) => p.category ?? '-').toList(),
    ),
    CompareSpecRow(
      'Alt Kategori',
      products.map((p) => p.subCategory ?? '-').toList(),
    ),
    CompareSpecRow('Mağaza', products.map((p) => p.store ?? '-').toList()),
    CompareSpecRow('Fiyat', products.map((p) => p.price).toList()),
  ];

  final specRows = dynamicRows
      .where((row) => !reserved.contains(compareNormalizeLabel(row.label)))
      .toList(growable: false);

  final evalRows = <CompareSpecRow>[
    CompareSpecRow(
      'Puan',
      products
          .map(
            (p) => p.rating > 0
                ? '⭐ ${p.rating.toStringAsFixed(1)}'
                : '-',
          )
          .toList(),
    ),
    CompareSpecRow(
      'Yorum Sayısı',
      products
          .map(
            (p) => p.reviewCount > 0 ? '${p.reviewCount} yorum' : '-',
          )
          .toList(),
    ),
    CompareSpecRow(
      'Etiketler',
      products
          .map((p) => p.tags.isNotEmpty ? p.tags.join(', ') : '-')
          .toList(),
    ),
  ];

  return [
    CompareSpecSection('GENEL BİLGİLER', generalRows),
    if (specRows.isNotEmpty)
      CompareSpecSection('ÜRÜN ÖZELLİKLERİ', specRows),
    CompareSpecSection('DEĞERLENDİRME', evalRows),
  ];
}

List<Product> compareProductsFromMaps(List<Map<String, dynamic>> maps) {
  return [
    for (var i = 0; i < maps.length; i++) compareProductAt(maps, i),
  ].whereType<Product>().toList(growable: false);
}

bool compareProductsShareMainCategory(List<Product> products) {
  if (products.length < 2) return true;
  final categories = products
      .map((product) => (product.category ?? '').trim().toLowerCase())
      .where((category) => category.isNotEmpty)
      .toSet();
  if (categories.isEmpty) return true;
  return categories.length == 1;
}

String? compareMainCategoryMismatchForProducts(List<Product> products) {
  if (compareProductsShareMainCategory(products)) return null;
  return kCompareMainCategoryMismatchMessage;
}

void showCompareCategoryMismatchSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(kCompareMainCategoryMismatchMessage)),
  );
}

Widget buildCompareCategoryBlockedState({String? message}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message ?? kCompareMainCategoryMismatchMessage,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.red,
        ),
      ),
    ),
  );
}

Widget buildCompareProductHeaderImage({
  required String? imagePath,
  double height = 140,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Container(
      height: height,
      width: double.infinity,
      color: Colors.grey.shade100,
      child: imagePath != null
          ? (imagePath.startsWith('http')
              ? OptimizedImage(
                  imageUrlOrPath: imagePath,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: height,
                )
              : Image.asset(imagePath, fit: BoxFit.contain))
          : const Center(
              child: Icon(Icons.image, size: 40, color: Colors.grey),
            ),
    ),
  );
}

void openCompareRoute(BuildContext context, Widget page) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

/// Full-width compare surface for web (no card/modal constraint).
class CompareWebShell extends StatelessWidget {
  const CompareWebShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComparePageHeader(title: title, subtitle: subtitle),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class ComparePageHeader extends StatelessWidget {
  const ComparePageHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              tooltip: 'Geri',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: Icon(Icons.close, color: Colors.grey.shade700),
              tooltip: 'Kapat',
            ),
          ],
        ),
      ),
    );
  }
}

class CompareInfoBanner extends StatelessWidget {
  const CompareInfoBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
      ),
    );
  }
}

/// N-column layout with vertical dividers (center divider emphasized for 2 cols).
class CompareColumnLayout extends StatelessWidget {
  const CompareColumnLayout({
    super.key,
    required this.columns,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 24),
  });

  final List<Widget> columns;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (columns.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const minColumnWidth = 220.0;
          final count = columns.length;
          final minWidth = minColumnWidth * count + (count - 1) * 17;
          final useHorizontalScroll = constraints.maxWidth < minWidth;

          Widget row = IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) CompareColumnDivider(twoColumn: count == 2),
                  Expanded(child: columns[i]),
                ],
              ],
            ),
          );

          if (useHorizontalScroll) {
            row = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minWidth),
                child: row,
              ),
            );
          }

          return row;
        },
      ),
    );
  }
}

class CompareColumnDivider extends StatelessWidget {
  const CompareColumnDivider({
    super.key,
    this.twoColumn = false,
    this.compact = false,
  });

  final bool twoColumn;
  /// Grid içinde tam hizalı divider için margin kullanma.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        width: twoColumn ? 2 : 1,
        color: twoColumn ? Colors.grey.shade400 : Colors.grey.shade200,
      );
    }

    return Container(
      width: twoColumn ? 2 : 1,
      margin: EdgeInsets.symmetric(horizontal: twoColumn ? 20 : 12),
      color: twoColumn ? Colors.grey.shade300 : Colors.grey.shade200,
    );
  }
}

class CompareProductColumnsHeader extends StatelessWidget {
  const CompareProductColumnsHeader({super.key, required this.products});

  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    return CompareColumnLayout(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      columns: products
          .map((productMap) => _CompareProductHeaderCard(productMap))
          .toList(growable: false),
    );
  }
}

class _CompareProductHeaderCard extends StatelessWidget {
  const _CompareProductHeaderCard(this.productMap);

  final Map<String, dynamic> productMap;

  @override
  Widget build(BuildContext context) {
    final product = productMap['product'] as Product?;
    final imagePath = compareProductImageUrl(productMap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          productMap['name']?.toString() ?? '-',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        if (product != null) ...[
          const SizedBox(height: 4),
          Text(
            product.store ?? product.brand,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            product.price,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (product.rating > 0) ...[
            const SizedBox(height: 4),
            Text(
              '⭐ ${product.rating.toStringAsFixed(1)} · ${product.reviewCount} yorum',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ],
        const SizedBox(height: 12),
        buildCompareProductHeaderImage(imagePath: imagePath),
      ],
    );
  }
}

/// Özellik compare: header + spec tablosu tek grid (label kolonu hizalı).
class CompareFeaturesPanel extends StatelessWidget {
  const CompareFeaturesPanel({
    super.key,
    required this.productMaps,
    required this.sections,
    this.labelColumnWidth = 180,
  });

  final List<Map<String, dynamic>> productMaps;
  final List<CompareSpecSection> sections;
  final double labelColumnWidth;

  int get _productCount => productMaps.length;

  @override
  Widget build(BuildContext context) {
    if (_productCount <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CompareAlignedProductHeader(
              productMaps: productMaps,
              labelColumnWidth: labelColumnWidth,
            ),
            for (final section in sections) ...[
              _SectionHeader(section.title),
              for (final row in section.rows)
                CompareAlignedSpecRow(
                  label: row.label,
                  values: _padValues(row.values, _productCount),
                  labelColumnWidth: labelColumnWidth,
                  productCount: _productCount,
                ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  List<String> _padValues(List<String> values, int count) {
    final padded = List<String>.from(values);
    while (padded.length < count) {
      padded.add('-');
    }
    return padded.take(count).toList(growable: false);
  }
}

class _CompareFeaturesHeaderCard extends StatelessWidget {
  const _CompareFeaturesHeaderCard(this.productMap);

  final Map<String, dynamic> productMap;

  @override
  Widget build(BuildContext context) {
    final product = productMap['product'] as Product?;
    final imagePath = compareProductImageUrl(productMap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          productMap['name']?.toString() ?? '-',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        buildCompareProductHeaderImage(imagePath: imagePath),
        if (product != null) ...[
          const SizedBox(height: 10),
          Text(
            product.brand,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            product.price,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class CompareAlignedProductHeader extends StatelessWidget {
  const CompareAlignedProductHeader({
    super.key,
    required this.productMaps,
    required this.labelColumnWidth,
  });

  final List<Map<String, dynamic>> productMaps;
  final double labelColumnWidth;

  @override
  Widget build(BuildContext context) {
    final count = productMaps.length;
    final twoColumn = count == 2;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: labelColumnWidth,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  right: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          for (var i = 0; i < count; i++) ...[
            if (i > 0)
              CompareColumnDivider(twoColumn: twoColumn, compact: true),
            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(i == 0 ? 16 : 12, 16, 12, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: _CompareFeaturesHeaderCard(productMaps[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CompareAlignedSpecRow extends StatelessWidget {
  const CompareAlignedSpecRow({
    super.key,
    required this.label,
    required this.values,
    required this.labelColumnWidth,
    required this.productCount,
  });

  final String label;
  final List<String> values;
  final double labelColumnWidth;
  final int productCount;

  @override
  Widget build(BuildContext context) {
    final twoColumn = productCount == 2;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: labelColumnWidth,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                  right: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0)
              CompareColumnDivider(twoColumn: twoColumn, compact: true),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                alignment: Alignment.topCenter,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Text(
                  values[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CompareSpecRow {
  const CompareSpecRow(this.label, this.values);

  final String label;
  final List<String> values;
}

class CompareSpecSection {
  const CompareSpecSection(this.title, this.rows);

  final String title;
  final List<CompareSpecRow> rows;
}

/// Excel-style feature table: fixed label column + equal product columns.
class CompareSpecTable extends StatelessWidget {
  const CompareSpecTable({
    super.key,
    required this.productCount,
    required this.sections,
    this.labelColumnWidth = 180,
  });

  final int productCount;
  final List<CompareSpecSection> sections;
  final double labelColumnWidth;

  @override
  Widget build(BuildContext context) {
    if (productCount <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var s = 0; s < sections.length; s++) ...[
                if (s > 0) const SizedBox(height: 0),
                _SectionHeader(sections[s].title),
                for (final row in sections[s].rows)
                  CompareAlignedSpecRow(
                    label: row.label,
                    values: _padValues(row.values, productCount),
                    labelColumnWidth: labelColumnWidth,
                    productCount: productCount,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _padValues(List<String> values, int count) {
    final padded = List<String>.from(values);
    while (padded.length < count) {
      padded.add('-');
    }
    return padded.take(count).toList(growable: false);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Colors.black87,
        ),
      ),
    );
  }
}

Widget buildCompareEmptyColumn(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    ),
  );
}
