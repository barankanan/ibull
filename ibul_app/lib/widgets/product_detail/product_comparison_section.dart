import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../models/product_model.dart';
import '../../core/constants.dart';
import 'product_detail_content_helper.dart';

class ProductComparisonSection extends StatefulWidget {
  const ProductComparisonSection({super.key});

  @override
  State<ProductComparisonSection> createState() =>
      _ProductComparisonSectionState();
}

class _ProductComparisonSectionState extends State<ProductComparisonSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final currentProduct = viewModel.initialProduct;
    final similarProducts = viewModel.similarProducts;

    var filteredSimilar = similarProducts
        .where((p) => _isComparableProduct(currentProduct, p))
        .toList();
    if (filteredSimilar.isEmpty) {
      final currentCategory = (currentProduct.category ?? '').toLowerCase();
      filteredSimilar = similarProducts.where((p) {
        final pCategory = (p.category ?? '').toLowerCase();
        return currentCategory.isNotEmpty && pCategory == currentCategory;
      }).toList();
    }

    final comparisonProducts = filteredSimilar.take(3).toList();
    if (comparisonProducts.isEmpty) return const SizedBox.shrink();

    // All products including current
    final allProducts = [currentProduct, ...comparisonProducts];

    // Build spec rows
    final allSpecRows = _buildSpecRows(allProducts);
    final visibleRows = _isExpanded
        ? allSpecRows
        : allSpecRows.take(8).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.compare_arrows_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentProduct.name} ile en çok karşılaştırılanlar',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Son güncelleme: Şubat 2026',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Table content
          Padding(
            padding: const EdgeInsets.all(20),
            child: isWide
                ? _buildComparisonTable(allProducts, visibleRows, allSpecRows)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 900,
                      child: _buildComparisonTable(
                        allProducts,
                        visibleRows,
                        allSpecRows,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isComparableProduct(Product currentProduct, Product candidate) {
    final currentSubCategory = (currentProduct.subCategory ?? '')
        .trim()
        .toLowerCase();
    final candidateSubCategory = (candidate.subCategory ?? '')
        .trim()
        .toLowerCase();

    if (currentSubCategory.isNotEmpty && candidateSubCategory.isNotEmpty) {
      return currentSubCategory == candidateSubCategory;
    }

    final currentCategory = (currentProduct.category ?? '')
        .trim()
        .toLowerCase();
    final candidateCategory = (candidate.category ?? '').trim().toLowerCase();
    if (currentCategory.isNotEmpty && candidateCategory.isNotEmpty) {
      return currentCategory == candidateCategory &&
          _inferProductType(currentProduct) == _inferProductType(candidate);
    }

    return _inferProductType(currentProduct) == _inferProductType(candidate);
  }

  String _inferProductType(Product product) {
    final name = product.name.toLowerCase();
    final category = (product.category ?? '').toLowerCase();
    final subCategory = (product.subCategory ?? '').toLowerCase();

    if (name.contains('iphone') ||
        name.contains('galaxy') ||
        category.contains('telefon') ||
        subCategory.contains('telefon') ||
        subCategory.contains('cep telefonu')) {
      return 'phone';
    }
    if (name.contains('macbook') ||
        name.contains('laptop') ||
        name.contains('notebook') ||
        category.contains('bilgisayar') ||
        subCategory.contains('bilgisayar')) {
      return 'computer';
    }
    if (category.contains('yemek') || subCategory.contains('yemek')) {
      return 'food';
    }
    return 'other';
  }

  Widget _buildComparisonTable(
    List<Product> products,
    List<_SpecRow> visibleRows,
    List<_SpecRow> allRows,
  ) {
    return Column(
      children: [
        // Product images & names row
        _buildProductHeaderRow(products),
        const SizedBox(height: 16),

        // Spec rows
        ...visibleRows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return _buildSpecRowWidget(row, products, index % 2 == 0);
        }),

        // "Daha fazla özellik göster" button
        if (allRows.length > 8) ...[
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => setState(() => _isExpanded = !_isExpanded),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isExpanded
                          ? 'Daha az özellik göster'
                          : 'Daha fazla özellik göster',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductHeaderRow(List<Product> products) {
    return Row(
      children: [
        // Label column (empty for header)
        Expanded(flex: 2, child: const SizedBox()),
        // Product columns
        ...products.map((product) {
          return Expanded(
            flex: 2,
            child: Column(
              children: [
                // Product image placeholder
                Container(
                  height: 120,
                  width: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: product.images.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            product.images.first,
                            fit: BoxFit.contain,
                            errorBuilder: (_, error, stackTrace) =>
                                _buildPlaceholderIcon(product),
                          ),
                        )
                      : _buildPlaceholderIcon(product),
                ),
                const SizedBox(height: 8),
                // Product name
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPlaceholderIcon(Product product) {
    IconData icon;
    final category = (product.category ?? '').toLowerCase();
    final name = product.name.toLowerCase();

    if (name.contains('iphone') ||
        name.contains('galaxy') ||
        name.contains('telefon')) {
      icon = Icons.phone_iphone;
    } else if (name.contains('macbook') || name.contains('laptop')) {
      icon = Icons.laptop_mac;
    } else if (name.contains('airpods') || name.contains('kulaklık')) {
      icon = Icons.headphones;
    } else if (category.contains('kişisel') || category.contains('bakım')) {
      icon = Icons.spa;
    } else {
      icon = Icons.shopping_bag_outlined;
    }

    return Center(child: Icon(icon, size: 40, color: Colors.grey[400]));
  }

  Widget _buildSpecRowWidget(
    _SpecRow row,
    List<Product> products,
    bool isEvenRow,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isEvenRow ? Colors.white : Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          // Label
          Expanded(
            flex: 2,
            child: Text(
              row.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          // Values for each product
          ...row.values.map((value) {
            if (row.label == 'Değerlendirmeler') {
              return Expanded(flex: 2, child: _buildRatingCell(value));
            }
            return Expanded(
              flex: 2,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: row.label == 'Fiyat'
                      ? FontWeight.bold
                      : FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRatingCell(String ratingStr) {
    // Parse rating value (format: "4.8")
    final rating = double.tryParse(ratingStr.split(' ').first) ?? 0;
    return Row(
      children: [
        Text(
          ratingStr.split(' ').first,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (i) {
          return Icon(
            i < rating.round() ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.orange,
          );
        }),
      ],
    );
  }

  List<_SpecRow> _buildSpecRows(List<Product> products) {
    final rows = <_SpecRow>[];

    // Fiyat
    rows.add(
      _SpecRow(label: 'Fiyat', values: products.map((p) => p.price).toList()),
    );

    // Değerlendirmeler
    rows.add(
      _SpecRow(
        label: 'Değerlendirmeler',
        values: products.map((p) => '${p.rating}').toList(),
      ),
    );

    // Satıcı
    rows.add(
      _SpecRow(
        label: 'Satıcı',
        values: products.map((p) => p.store ?? '-').toList(),
      ),
    );

    // Dynamic product specs (same source with web/mobile product specs section)
    rows.addAll(_buildDynamicSpecRows(products));

    // Fallback rows if no spec parsed
    if (rows.length <= 3) {
      rows.add(
        _SpecRow(label: 'Marka', values: products.map((p) => p.brand).toList()),
      );
      rows.add(
        _SpecRow(
          label: 'Kategori',
          values: products
              .map((p) => p.subCategory ?? p.category ?? '-')
              .toList(),
        ),
      );
    }

    return rows;
  }

  List<_SpecRow> _buildDynamicSpecRows(List<Product> products) {
    final productSpecMaps = products.map((product) {
      final rawSpecs = ProductDetailContentHelper.buildSpecs(product);
      final map = <String, String>{};
      for (final spec in rawSpecs) {
        final key = (spec['key'] ?? '').trim();
        final value = (spec['value'] ?? '').trim();
        if (key.isEmpty || value.isEmpty) continue;
        map[key] = value;
      }
      return map;
    }).toList();

    final normalizedToDisplay = <String, String>{};
    final orderedKeys = <String>[];

    for (final specMap in productSpecMaps) {
      for (final key in specMap.keys) {
        final normalized = key.toLowerCase();
        if (!normalizedToDisplay.containsKey(normalized)) {
          normalizedToDisplay[normalized] = key;
          orderedKeys.add(normalized);
        }
      }
    }

    final baseRowKeys = {'fiyat', 'değerlendirmeler', 'satıcı'};
    return orderedKeys
        .where((normalized) => !baseRowKeys.contains(normalized))
        .map((normalized) {
          final label = normalizedToDisplay[normalized]!;
          final values = productSpecMaps.map((specMap) {
            final direct = specMap[label];
            if (direct != null && direct.isNotEmpty) return direct;
            return specMap.entries
                    .firstWhere(
                      (entry) => entry.key.toLowerCase() == normalized,
                      orElse: () => const MapEntry('', '-'),
                    )
                    .value
                    .trim()
                    .isEmpty
                ? '-'
                : specMap.entries
                      .firstWhere(
                        (entry) => entry.key.toLowerCase() == normalized,
                        orElse: () => const MapEntry('', '-'),
                      )
                      .value;
          }).toList();
          return _SpecRow(label: label, values: values);
        })
        .toList();
  }
}

class _SpecRow {
  final String label;
  final List<String> values;

  _SpecRow({required this.label, required this.values});
}
