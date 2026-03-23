import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../services/review_repository.dart';
import '../../screens/all_reviews_page.dart';

class ProductInfoSectionWeb extends StatelessWidget {
  const ProductInfoSectionWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final appState = Provider.of<AppState>(context);
    final localReviews = appState.getProductReviewsFor(
      productName: product.name,
      storeName: product.store,
    );
    final initialSummary = ReviewSummary.fromReviews(
      localReviews,
      fallbackRating: product.rating,
      fallbackCount: product.reviewCount,
    );

    return FutureBuilder<ReviewSummary>(
      future: ReviewRepository.instance.getProductReviewSummary(
        productName: product.name,
        storeName: product.store,
        localReviews: localReviews,
      ),
      initialData: initialSummary,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? initialSummary;
        final customReviews = summary.reviews;
        final reviewCount = summary.reviewCount;
        final rating = summary.averageRating;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand Name (Clickable)
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

            // Product Name
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

            // Rating and Reviews count
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
      },
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
