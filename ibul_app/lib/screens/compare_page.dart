import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../models/product_model.dart';
import '../core/constants.dart';

class ComparePage extends StatelessWidget {
  final Product baseProduct;
  final List<Product> comparisonProducts;

  const ComparePage({
    super.key,
    required this.baseProduct,
    required this.comparisonProducts,
  });

  @override
  Widget build(BuildContext context) {
    // Combine base product with comparison products
    final allProducts = [baseProduct, ...comparisonProducts];
    
    // We only support comparing 2 or 3 products in this view for now
    // If more, they will be scrollable horizontally
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ürün özellikleri',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Info Banner
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lightbulb, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Seçtiğin ${baseProduct.subCategory ?? 'ürün'} ürünlerin özellik karşılaştırması',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            // Product Headers (Images & Names)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Row(
                  children: [
                    // Empty space for labels column if we had one in header, but design doesn't show it
                    // The design shows evenly distributed products
                    ...allProducts.map((p) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Container(
                              height: 100,
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: p.images.isNotEmpty
                                    ? (p.images.first.startsWith('http')
                                        ? OptimizedImage(imageUrlOrPath: p.images.first, fit: BoxFit.contain)
                                        : Image.asset(p.images.first, fit: BoxFit.contain))
                                    : const Icon(Icons.image, color: Colors.grey),
                              ),
                            ),
                            Text(
                              p.name,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            ),

            // Summary Rows
            _buildSummaryRow(allProducts.map((p) => p.brand).toList()),
            _buildSummaryRow(allProducts.map((p) => p.name).toList(), isFullName: true),
            _buildSummaryRow(allProducts.map((p) => p.price).toList(), isPrice: true),
            _buildSummaryRow(allProducts.map((p) => p.store ?? '').toList()),
            // Another price row if needed, for now using just one

            const SizedBox(height: 24),

            // General Features Section
            _buildSectionHeader('GENEL ÖZELLİKLER'),
            _buildFeatureRow('Kategori', allProducts.map((p) => p.subCategory ?? '-').toList()),
            _buildFeatureRow('Puan', allProducts.map((p) => '${p.rating}').toList()),
            _buildFeatureRow('Değerlendirme', allProducts.map((p) => '${p.reviewCount}').toList()),
            
            // Design Section
            const SizedBox(height: 24),
            _buildSectionHeader('TASARIM'),
            _buildFeatureRow('Marka', allProducts.map((p) => p.brand).toList()),
            _buildFeatureRow('Mağaza', allProducts.map((p) => p.store ?? '-').toList()),
            
            // Extra Specs if any
            if (allProducts.any((p) => p.specifications != null))
               _buildFeatureRow('Özellikler', allProducts.map((p) => _extractSpecs(p)).toList()),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(List<String> values, {bool isPrice = false, bool isFullName = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: values.map((v) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              v,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isPrice ? FontWeight.bold : FontWeight.normal,
                color: isPrice ? AppColors.primary : (isFullName ? Colors.grey : Colors.black87),
                fontSize: isPrice ? 16 : (isFullName ? 12 : 14),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.black87,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String label, List<String> values) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Label Column
            Container(
              width: 100, // Fixed width for label
              padding: const EdgeInsets.all(12),
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
            // Vertical Divider
            VerticalDivider(width: 1, color: Colors.grey.shade200),
            
            // Values
            ...values.map((v) => Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade100),
                  ),
                ),
                child: Text(
                  v,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  String _extractSpecs(Product p) {
    if (p.specifications != null && p.specifications!.isNotEmpty) {
      // Just take first line or short summary
      return p.specifications!.split('\n').first;
    }
    return '-';
  }
}
