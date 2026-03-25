import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../core/constants.dart';
import '../models/product_model.dart';

class CompareFeaturesPage extends StatelessWidget {
  final List<Map<String, dynamic>> products;

  const CompareFeaturesPage({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            width: 900,
            height: 650,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildWebHeader(context),
                Expanded(child: _buildContent(context)),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürün özellikleri',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildWebHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.compare_arrows, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ürün Özellikleri',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              Text(
                'Detaylı özellik karşılaştırması',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.grey),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    // Ensure we have at least 2 products to compare, or handle gracefully
    final displayProducts = products.take(2).toList();
    
    return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Container(
                    width: 35,
                    height: 35,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seçtiğin ${displayProducts.isNotEmpty ? (displayProducts[0]['product'] as Product?)?.category ?? 'ürün' : 'ürün'}lerin özellik karşılaştırması',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product Headers
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: displayProducts.map((productMap) {
                  final imagePath = productMap['image'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        children: [
                          Container(
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: imagePath != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imagePath.startsWith('http')
                                          ? OptimizedImage(imageUrlOrPath: imagePath, fit: BoxFit.cover)
                                          : Image.asset(imagePath, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.image, size: 30, color: Colors.grey),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            productMap['name'],
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (displayProducts.isNotEmpty) ...[
              // Extract Product objects
              _buildDynamicComparisonTable(displayProducts),
            ],

            const SizedBox(height: 32),
          ],
        ),
      );
  }

  Widget _buildDynamicComparisonTable(List<Map<String, dynamic>> productMaps) {
    // Helper to get Product object safely
    Product? getProduct(int index) {
      if (index >= productMaps.length) return null;
      return productMaps[index]['product'] as Product?;
    }

    final p1 = getProduct(0);
    final p2 = getProduct(1);

    if (p1 == null) return const SizedBox();

    return Column(
      children: [
        // Price Section
        _buildRow('', [p1.brand, p2?.brand ?? '-'], isHeader: false),
        _buildRow('', [p1.name, p2?.name ?? '-'], isHeader: false),
        _buildRow('', [p1.price, p2?.price ?? '-'], isPriceRow: true),
        
        const SizedBox(height: 16),

        // GENEL ÖZELLİKLER
        _buildSectionHeader('GENEL BİLGİLER'),
        _buildRow('Marka', [p1.brand, p2?.brand ?? '-']),
        _buildRow('Kategori', [p1.category ?? '-', p2?.category ?? '-']),
        _buildRow('Alt Kategori', [p1.subCategory ?? '-', p2?.subCategory ?? '-']),
        _buildRow('Mağaza', [p1.store ?? '-', p2?.store ?? '-']),

        const SizedBox(height: 16),

        // DETAYLAR
        _buildSectionHeader('DETAYLAR'),
        _buildRow('Açıklama', [
          _truncate(p1.description ?? '-', 50), 
          _truncate(p2?.description ?? '-', 50)
        ]),
        _buildRow('Özellikler', [
          _truncate(p1.specifications ?? '-', 50), 
          _truncate(p2?.specifications ?? '-', 50)
        ]),

        const SizedBox(height: 16),

        // DEĞERLENDİRME
        _buildSectionHeader('DEĞERLENDİRME'),
        _buildRow('Puanı', ['⭐ ${p1.rating}', p2 != null ? '⭐ ${p2.rating}' : '-'], isStarRow: true),
        _buildRow('Yorum Sayısı', ['💬 ${p1.reviewCount}', p2 != null ? '💬 ${p2.reviewCount}' : '-'], isIconRow: true),
        
        // Tags can be shown as a comma separated list
        _buildRow('Etiketler', [
          p1.tags.take(2).join(', '), 
          p2?.tags.take(2).join(', ') ?? '-'
        ]),
      ],
    );
  }

  String _truncate(String text, int length) {
    if (text.length <= length) return text;
    return '${text.substring(0, length)}...';
  }


  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildRow(String label, List<String> values, {bool isHeader = false, bool isPriceRow = false, bool isStarRow = false, bool isIconRow = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? AppColors.primary : Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (label.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isHeader ? AppColors.primary : Colors.white,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
                    color: isHeader ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          ...values.map((value) {
            return Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    left: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: isPriceRow ? 12 : 11,
                    fontWeight: isPriceRow ? FontWeight.bold : FontWeight.normal,
                    color: isPriceRow ? AppColors.primary : (isStarRow || isIconRow ? Colors.black : Colors.grey.shade700),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
