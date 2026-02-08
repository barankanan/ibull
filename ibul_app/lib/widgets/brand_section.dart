import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import 'product_card.dart';

class BrandSection extends StatelessWidget {
  final Map<String, dynamic> brandData;
  final String selectedBrand;
  final Function(String) onBrandSelected;

  const BrandSection({
    super.key,
    required this.brandData,
    required this.selectedBrand,
    required this.onBrandSelected,
    required this.brands,
    required this.title,
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                '$selectedBrand Reklam Alanı',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(left: 16, right: 4, top: 2, bottom: 2),
              width: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50), // pill shape
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : Border.all(color: Colors.grey.shade200),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[100],
                    backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                    child: logoUrl.isEmpty
                        ? Text(brand[0],
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    brand,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
            child: Text('Bu marka için ürün bulunamadı',
                style: TextStyle(color: Colors.grey[600])),
          ),
        );
    }

    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 500,
        itemCount: products.length,
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
          
          return ProductCard(product: product, width: 200);
        },
      ),
    );
  }
}

