import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../screens/all_reviews_page.dart';
import '../../services/review_repository.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductInfoSectionWeb extends StatelessWidget {
  const ProductInfoSectionWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final product = context.select<ProductDetailViewModel, dynamic>(
      (viewModel) => viewModel.initialProduct,
    );
    final summary = context.select<ProductDetailViewModel, ReviewSummary>(
      (viewModel) => viewModel.reviewSummary,
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
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
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
                const SizedBox(width: 8),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '($reviewCount Değerlendirme)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
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
}
