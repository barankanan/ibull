import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../models/product_model.dart';
import '../../screens/all_reviews_page.dart';
import '../../screens/map_page.dart';
import '../../screens/spare_parts_page.dart';
import '../../services/review_repository.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductInfoSectionMobile extends StatelessWidget {
  const ProductInfoSectionMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ProductDetailViewModel>();
    final product = context.select<ProductDetailViewModel, dynamic>(
      (model) => model.initialProduct,
    );
    final summary = context.select<ProductDetailViewModel, ReviewSummary>(
      (model) => model.reviewSummary,
    );
    final customReviews = summary.reviews;
    final reviewCount = summary.reviewCount;
    final rating = summary.averageRating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {},
          child: Text(
            product.brand,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AllReviewsPage(
                        productName: product.name,
                        brand: product.brand,
                        rating: rating,
                        reviewCount: reviewCount,
                        images: product.images,
                        customReviews: customReviews,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    _buildRatingStars(rating),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '($reviewCount)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isDamagedProduct(product)) ...[
                  GestureDetector(
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SparePartsPage(
                            product: product,
                            initialSelectedParts: viewModel.selectedParts,
                          ),
                        ),
                      );

                      if (result is Map<String, dynamic>) {
                        final parts = result['parts'] as List<dynamic>?;
                        if (parts != null) {
                          viewModel.setSelectedParts(parts.cast<Product>());
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.build_circle,
                            size: 11,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Parça Seç',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapPage(
                          product: product,
                          initialSearchQuery: product.name,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Yakın Lokasyon',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, color: Colors.amber, size: 16);
        } else if (index < rating) {
          return const Icon(Icons.star_half, color: Colors.amber, size: 16);
        }
        return Icon(Icons.star_border, color: Colors.grey[300], size: 16);
      }),
    );
  }

  bool _isDamagedProduct(dynamic product) {
    final nameLower = product.name.toLowerCase();
    if (nameLower.contains('hasarlı') || nameLower.contains('kırık')) {
      return true;
    }

    if (product.tags != null && product.tags is List) {
      final tags = product.tags as List<String>;
      return tags.any(
        (tag) =>
            tag.toLowerCase().contains('hasarlı') ||
            tag.toLowerCase().contains('kırık') ||
            tag.toLowerCase().contains('2.el hasarlı'),
      );
    }

    return false;
  }
}
