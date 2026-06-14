import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/constants.dart';
import '../core/review_state.dart';
import '../models/product_model.dart';
import '../services/review_repository.dart';

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
    for (final url in product.images) {
      if (url.trim().isNotEmpty) return url.trim();
    }
  }
  final fallback = productMap['image']?.toString().trim();
  return (fallback != null && fallback.isNotEmpty) ? fallback : null;
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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 140,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: imagePath != null
                ? (imagePath.startsWith('http')
                    ? OptimizedImage(
                        imageUrlOrPath: imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 140,
                      )
                    : Image.asset(imagePath, fit: BoxFit.contain))
                : const Center(
                    child: Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
        ),
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
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 140,
            width: double.infinity,
            color: Colors.grey.shade100,
            child: imagePath != null
                ? (imagePath.startsWith('http')
                    ? OptimizedImage(
                        imageUrlOrPath: imagePath,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: 140,
                      )
                    : Image.asset(imagePath, fit: BoxFit.contain))
                : const Center(
                    child: Icon(Icons.image, size: 40, color: Colors.grey),
                  ),
          ),
        ),
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
