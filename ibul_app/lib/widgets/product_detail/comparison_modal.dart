import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../../core/app_image_cdn.dart';
import '../../models/product_model.dart';
import '../../core/constants.dart';

class ComparisonModal extends StatefulWidget {
  final Product currentProduct;
  final List<Product> similarProducts;

  const ComparisonModal({
    super.key,
    required this.currentProduct,
    required this.similarProducts,
  });

  @override
  State<ComparisonModal> createState() => _ComparisonModalState();
}

class _ComparisonModalState extends State<ComparisonModal> {
  Product? _selectedProduct;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // 90% height
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ürün Karşılaştırma',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Selection Area
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Current Product
                Expanded(child: _buildProductCard(widget.currentProduct, isRemovable: false)),
                
                const SizedBox(width: 12),
                const Icon(Icons.compare_arrows, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                
                // Selected Product or Placeholder
                Expanded(
                  child: _selectedProduct == null
                      ? _buildEmptySlot()
                      : _buildProductCard(_selectedProduct!, isRemovable: true),
                ),
              ],
            ),
          ),

          const Divider(thickness: 4, color: Color(0xFFF5F5F5)),

          // Content Area
          Expanded(
            child: _selectedProduct == null
                ? _buildSuggestionList()
                : _buildComparisonTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, {required bool isRemovable}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: product.images.isNotEmpty
                    ? (product.images.first.startsWith('http')
                        ? OptimizedImage(
                            imageUrlOrPath: product.imageFor(AppImageVariant.card),
                            fit: BoxFit.contain,
                            cacheWidth: 420,
                            cacheHeight: 420,
                          )
                        : Image.asset(product.images.first, fit: BoxFit.contain))
                    : const Icon(Icons.image, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                product.price,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        if (isRemovable)
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => setState(() => _selectedProduct = null),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      height: 160, // Approximate height to match product card
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, color: AppColors.primary, size: 32),
            SizedBox(height: 8),
            Text(
              'Ürün Seç',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionList() {
    // Filter products based on search query
    final filteredProducts = widget.similarProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             p.brand.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Karşılaştırmak için ürün ara...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Önerilen Ürünler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Sonuç bulunamadı',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ListTile(
                      onTap: () => setState(() => _selectedProduct = product),
                      contentPadding: const EdgeInsets.all(8),
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Container(
                        width: 60,
                        height: 60,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: product.images.isNotEmpty
                            ? (product.images.first.startsWith('http')
                                ? OptimizedImage(
                                    imageUrlOrPath: product.imageFor(AppImageVariant.thumb),
                                    fit: BoxFit.contain,
                                    cacheWidth: 160,
                                    cacheHeight: 160,
                                  )
                                : Image.asset(product.images.first, fit: BoxFit.contain))
                            : const Icon(Icons.image),
                      ),
                      title: Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        product.price,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildComparisonTable() {
    final rows = _generateComparisonRows(widget.currentProduct, _selectedProduct!);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final isEven = index % 2 == 0;
        return Container(
          color: isEven ? Colors.grey.shade50 : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  row.label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.value1,
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  row.value2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: row.value1 != row.value2 ? FontWeight.bold : FontWeight.normal,
                    color: row.value1 != row.value2 ? Colors.black : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_ComparisonRow> _generateComparisonRows(Product p1, Product p2) {
    // Basic comparison logic (simplified from ProductComparisonSection)
    final rows = <_ComparisonRow>[];
    
    rows.add(_ComparisonRow('Fiyat', p1.price, p2.price));
    rows.add(_ComparisonRow('Marka', p1.brand, p2.brand));
    rows.add(_ComparisonRow('Puan', '${p1.rating}', '${p2.rating}'));
    rows.add(_ComparisonRow('Satıcı', p1.store ?? '-', p2.store ?? '-'));
    
    // Add dummy specs based on category (simplified)
    if (p1.category == 'Elektronik' || p1.brand == 'Apple' || p1.brand == 'Samsung') {
      rows.add(_ComparisonRow('Ekran', '6.1 inç', '6.7 inç'));
      rows.add(_ComparisonRow('Depolama', '128 GB', '256 GB'));
      rows.add(_ComparisonRow('RAM', '6 GB', '8 GB'));
      rows.add(_ComparisonRow('Pil', '3200 mAh', '4500 mAh'));
      rows.add(_ComparisonRow('5G', 'Var', 'Var'));
      rows.add(_ComparisonRow('Garanti', '2 Yıl', '2 Yıl'));
    } else if (p1.subCategory == 'Saç Bakımı') {
      rows.add(_ComparisonRow('Hacim', '350 ml', '400 ml'));
      rows.add(_ComparisonRow('Saç Tipi', 'Tüm Saçlar', 'Kuru Saçlar'));
      rows.add(_ComparisonRow('Etki', 'Onarıcı', 'Besleyici'));
    }

    return rows;
  }
}

class _ComparisonRow {
  final String label;
  final String value1;
  final String value2;

  _ComparisonRow(this.label, this.value1, this.value2);
}
