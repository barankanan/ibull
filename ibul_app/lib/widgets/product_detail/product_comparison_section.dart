import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../models/product_model.dart';
import '../../core/constants.dart';

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

    // Take up to 3 similar products for comparison (current + 3 = 4 columns)
    final comparisonProducts = similarProducts.take(3).toList();
    if (comparisonProducts.isEmpty) return const SizedBox.shrink();

    // All products including current
    final allProducts = [currentProduct, ...comparisonProducts];

    // Build spec rows
    final allSpecRows = _buildSpecRows(allProducts);
    final visibleRows =
        _isExpanded ? allSpecRows : allSpecRows.take(8).toList();

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
                bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.12)),
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
                  child: Icon(Icons.compare_arrows_outlined, size: 18, color: AppColors.primary),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
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
                          allProducts, visibleRows, allSpecRows),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(List<Product> products,
      List<_SpecRow> visibleRows, List<_SpecRow> allRows) {
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
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
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
                            errorBuilder: (_, __, ___) =>
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

    if (name.contains('iphone') || name.contains('galaxy') || name.contains('telefon')) {
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

    return Center(
      child: Icon(icon, size: 40, color: Colors.grey[400]),
    );
  }

  Widget _buildSpecRowWidget(
      _SpecRow row, List<Product> products, bool isEvenRow) {
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
              return Expanded(
                flex: 2,
                child: _buildRatingCell(value),
              );
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
    rows.add(_SpecRow(
      label: 'Fiyat',
      values: products.map((p) => p.price).toList(),
    ));

    // Değerlendirmeler
    rows.add(_SpecRow(
      label: 'Değerlendirmeler',
      values: products.map((p) => '${p.rating}').toList(),
    ));

    // Satıcı
    rows.add(_SpecRow(
      label: 'Satıcı',
      values: products.map((p) => p.store ?? '-').toList(),
    ));

    // Determine category-specific specs
    final mainProduct = products.first;
    final brand = mainProduct.brand.toLowerCase();
    final name = mainProduct.name.toLowerCase();
    final category = (mainProduct.category ?? '').toLowerCase();

    if (name.contains('iphone') || brand.contains('apple') && (name.contains('phone') || category.contains('telefon'))) {
      _addPhoneComparisonSpecs(rows, products, isApple: true);
    } else if (name.contains('galaxy') || brand.contains('samsung')) {
      _addPhoneComparisonSpecs(rows, products, isApple: false);
    } else if (name.contains('macbook') || name.contains('laptop')) {
      _addLaptopComparisonSpecs(rows, products);
    } else if (category.contains('kişisel') || category.contains('bakım')) {
      _addPersonalCareComparisonSpecs(rows, products);
    } else {
      _addGenericComparisonSpecs(rows, products);
    }

    return rows;
  }

  void _addPhoneComparisonSpecs(List<_SpecRow> rows, List<Product> products,
      {required bool isApple}) {
    // Arttırılabilir Hafıza
    rows.add(_SpecRow(
      label: 'Arttırılabilir Hafıza',
      values: products.map((p) {
        if (p.brand.contains('Apple')) return 'Yok';
        return 'Var';
      }).toList(),
    ));

    // Garanti Tipi
    rows.add(_SpecRow(
      label: 'Garanti Tipi',
      values: products.map((p) {
        if (p.brand.contains('Apple')) return 'Apple Türkiye Garantili';
        if (p.brand.contains('Samsung')) return 'Samsung Türkiye Garantili';
        return 'İthalatçı Garantili';
      }).toList(),
    ));

    // Ekran Tipi
    rows.add(_SpecRow(
      label: 'Ekran Tipi',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 17') || n.contains('iphone 16')) return 'Süper Retina';
        if (n.contains('iphone')) return 'OLED';
        if (n.contains('galaxy')) return 'Dynamic AMOLED';
        return '-';
      }).toList(),
    ));

    // Telefon Serisi
    rows.add(_SpecRow(
      label: 'Telefon Serisi',
      values: products.map((p) {
        final n = p.name;
        if (n.contains('iPhone 13')) return 'iPhone 13';
        if (n.contains('iPhone 15')) return 'iPhone 15';
        if (n.contains('iPhone 17')) return 'iPhone 17';
        if (n.contains('iPhone 14')) return 'iPhone 14';
        if (n.contains('iPhone 16')) return 'iPhone 16';
        if (n.contains('Galaxy S24')) return 'Galaxy S24';
        if (n.contains('Galaxy S23')) return 'Galaxy S23';
        return p.brand;
      }).toList(),
    ));

    // Dahili Hafıza
    rows.add(_SpecRow(
      label: 'Dahili Hafıza',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('256')) return '256 GB';
        if (n.contains('512')) return '512 GB';
        if (n.contains('1 tb') || n.contains('1tb')) return '1 TB';
        return '128 GB';
      }).toList(),
    ));

    // Pil Gücü
    rows.add(_SpecRow(
      label: 'Pil Gücü',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 13')) return '3095 mAh';
        if (n.contains('iphone 15 pro max')) return '4422 mAh';
        if (n.contains('iphone 15')) return '3877 mAh';
        if (n.contains('iphone 17')) return '3692 mAh';
        if (n.contains('galaxy s24 ultra')) return '5000 mAh';
        if (n.contains('galaxy s24')) return '4000 mAh';
        return '-';
      }).toList(),
    ));

    // Ekran Boyutu
    rows.add(_SpecRow(
      label: 'Ekran Boyutu',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 13') || n.contains('iphone 15') && !n.contains('max') && !n.contains('plus')) return '6,1 inç';
        if (n.contains('pro max') || n.contains('plus')) return '6,7 inç';
        if (n.contains('galaxy s24 ultra')) return '6,8 inç';
        if (n.contains('iphone 17')) return '6,3 inç';
        return '6,1 inç';
      }).toList(),
    ));

    // İşlemci
    rows.add(_SpecRow(
      label: 'İşlemci',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 13')) return 'A15 Bionic';
        if (n.contains('iphone 15')) return 'A16 Bionic';
        if (n.contains('iphone 17')) return 'A19 Pro';
        if (n.contains('galaxy s24')) return 'Snapdragon 8 Gen 3';
        return '-';
      }).toList(),
    ));

    // 5G Desteği
    rows.add(_SpecRow(
      label: '5G Desteği',
      values: products.map((p) => 'Var').toList(),
    ));

    // Kamera
    rows.add(_SpecRow(
      label: 'Ana Kamera',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 13')) return '12 MP';
        if (n.contains('iphone 15 pro')) return '48 MP';
        if (n.contains('iphone 15')) return '48 MP';
        if (n.contains('iphone 17')) return '48 MP';
        if (n.contains('galaxy s24 ultra')) return '200 MP';
        if (n.contains('galaxy s24')) return '50 MP';
        return '-';
      }).toList(),
    ));

    // RAM
    rows.add(_SpecRow(
      label: 'RAM',
      values: products.map((p) {
        final n = p.name.toLowerCase();
        if (n.contains('iphone 13')) return '4 GB';
        if (n.contains('iphone 15')) return '6 GB';
        if (n.contains('iphone 17')) return '8 GB';
        if (n.contains('galaxy s24 ultra')) return '12 GB';
        if (n.contains('galaxy s24')) return '8 GB';
        return '-';
      }).toList(),
    ));
  }

  void _addLaptopComparisonSpecs(
      List<_SpecRow> rows, List<Product> products) {
    rows.add(_SpecRow(
      label: 'İşlemci',
      values: products.map((p) {
        if (p.name.contains('M3')) return 'Apple M3';
        if (p.name.contains('M2')) return 'Apple M2';
        return 'Intel Core i7';
      }).toList(),
    ));
    rows.add(_SpecRow(
      label: 'RAM',
      values: products.map((_) => '8 GB').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Depolama',
      values: products.map((_) => '256 GB SSD').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Ekran Boyutu',
      values: products.map((_) => '13,6 inç').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Pil Ömrü',
      values: products.map((_) => '18 saat').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Ağırlık',
      values: products.map((_) => '1,24 kg').toList(),
    ));
  }

  void _addPersonalCareComparisonSpecs(
      List<_SpecRow> rows, List<Product> products) {
    rows.add(_SpecRow(
      label: 'Hacim',
      values: products.map((_) => '350 ml').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Saç Tipi',
      values: products.map((_) => 'Tüm Saç Tipleri').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Paraben',
      values: products.map((_) => 'İçermez').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Sülfat',
      values: products.map((_) => 'İçermez').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Menşei',
      values: products.map((_) => 'Türkiye').toList(),
    ));
  }

  void _addGenericComparisonSpecs(
      List<_SpecRow> rows, List<Product> products) {
    rows.add(_SpecRow(
      label: 'Marka',
      values: products.map((p) => p.brand).toList(),
    ));
    rows.add(_SpecRow(
      label: 'Kategori',
      values: products.map((p) => p.subCategory ?? p.category ?? '-').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Garanti',
      values: products.map((_) => '2 Yıl').toList(),
    ));
    rows.add(_SpecRow(
      label: 'Kargo',
      values: products.map((_) => 'Ücretsiz').toList(),
    ));
  }
}

class _SpecRow {
  final String label;
  final List<String> values;

  _SpecRow({required this.label, required this.values});
}
