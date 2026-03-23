import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import 'product_card.dart';

class BrandSection extends StatelessWidget {
  final Map<String, dynamic> brandData;
  final String selectedBrand;
  final Function(String) onBrandSelected;
  final bool pinActionsBottom;
  final bool tightCards;
  final double listHeight;

  const BrandSection({
    super.key,
    required this.brandData,
    required this.selectedBrand,
    required this.onBrandSelected,
    required this.brands,
    required this.title,
    this.pinActionsBottom = false,
    this.tightCards = false,
    this.listHeight = 312,
  });

  final List<String> brands;
  final String title;

  @override
  Widget build(BuildContext context) {
    final selectedData = brandData[selectedBrand];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        _buildBrandSelector(),
        const SizedBox(height: 16),
        if (selectedData != null)
          _buildBrandBannerSlider(selectedData['adUrls']),
        const SizedBox(height: 16),
        _buildProductList(selectedData),
      ],
    );
  }

  Widget _buildBrandBannerSlider(List<dynamic>? adUrls) {
    if (adUrls == null || adUrls.isEmpty) return const SizedBox.shrink();
    final urls = adUrls
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 160,
      width: double.infinity,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                url,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[100],
                  alignment: Alignment.center,
                  child: Icon(Icons.image_outlined, color: Colors.grey[400]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildBrandSelector() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 400,
        itemCount: brands.length,
        itemBuilder: (context, index) {
          String brand = brands[index];
          bool isSelected = brand == selectedBrand;
          String logoUrl = brandData[brand]?['logo'] ?? '';

          return GestureDetector(
            onTap: () => onBrandSelected(brand),
            child: Container(
              margin: const EdgeInsets.only(
                left: 16,
                right: 4,
                top: 2,
                bottom: 2,
              ),
              width: 70,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: ClipOval(
                      child: logoUrl.isNotEmpty
                          ? (logoUrl.startsWith('http')
                                ? Image.network(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        brand.isNotEmpty ? brand[0] : '?',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.asset(
                                    logoUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Text(
                                        brand.isNotEmpty ? brand[0] : '?',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ))
                          : Center(
                              child: Text(
                                brand.isNotEmpty ? brand[0] : '?',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    brand,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected ? AppColors.primary : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList(Map<String, dynamic>? selectedData) {
    final products = selectedData?['products'] as List?;
    if (products == null || products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Bu marka için ürün bulunamadı',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
      );
    }

    return SizedBox(
      height: listHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 500,
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = products[index];
          // Convert generic map to Product model
          final product = Product(
            name: p['name'],
            brand: selectedBrand, // Seçili brand'ı kullan
            price: p['price'],
            rating: p['rating'].toDouble(),
            reviewCount: p['reviews'],
            tags: List<String>.from(p['tags']),
            images: List<String>.from(p['images']),
          );

          return SizedBox(
            width: 198,
            child: ProductCard(
              product: product,
              margin: EdgeInsets.zero,
              pinActionsBottom: pinActionsBottom,
              tight: tightCards,
            ),
          );
        },
      ),
    );
  }
}
