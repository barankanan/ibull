import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../services/review_repository.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../screens/all_reviews_page.dart';

class ProductReviewsSection extends StatelessWidget {
  const ProductReviewsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final product = context.select<ProductDetailViewModel, dynamic>(
      (viewModel) => viewModel.initialProduct,
    );
    final summary = context.select<ProductDetailViewModel, ReviewSummary>(
      (viewModel) => viewModel.reviewSummary,
    );
    final dynamicReviews = summary.reviews;
    final reviewCount = summary.reviewCount;
    final rating = summary.averageRating;
    final hasReviews = reviewCount > 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Değerlendirmeler',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          if (hasReviews) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Text(
                        rating.toStringAsFixed(1).replaceAll('.', ','),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < rating.round() ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$reviewCount Kişi',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 36,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Henüz değerlendirme yok',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bu ürünü satın alan kullanıcılar değerlendirme yapabilir.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Tooltip(
            message: 'Değerlendirme yapmak için ürünü satın almanız gerekiyor.',
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.zero,
                  disabledForegroundColor: Colors.grey,
                ),
                child: const Text(
                  'Değerlendirme Yaz',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AllReviewsPage(
                      productName: product.name,
                      brand: product.brand,
                      rating: rating,
                      reviewCount: reviewCount,
                      images: List<String>.from(product.images),
                      customReviews: dynamicReviews,
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                hasReviews ? 'Tüm Değerlendirmeleri Gör' : 'Değerlendirmeler',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
