import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../services/review_repository.dart';
import '../../screens/map_page.dart';
import '../../screens/all_reviews_page.dart';
import '../../screens/spare_parts_page.dart';
import '../../models/product_model.dart';

class ProductInfoSectionMobile extends StatelessWidget {
  const ProductInfoSectionMobile({super.key});

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
            // Brand Name (üstte)
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
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Ratings + Parça Seç + Yakın Lokasyon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Sol Taraf: Puanlama
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

                // Sağ Taraf: Butonlar
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Parça Seç chip (sadece hasarlı ürünlerde)
                    if (_isDamagedProduct(product)) ...[
                      GestureDetector(
                        onTap: () async {
                          // Yeni sayfaya yönlendir ve sonucu bekle
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SparePartsPage(
                                product: product,
                                initialSelectedParts: viewModel.selectedParts,
                              ),
                            ),
                          );

                          // Parçalar seçildiyse viewModel'e aktar (varolanların üzerine ekle)
                          if (result != null &&
                              result is Map<String, dynamic>) {
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.build_circle,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              const Text(
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

                    // Yakın Lokasyon butonu (En Sağda)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MapPage(
                              product: product,
                              initialSearchQuery:
                                  product.name, // Pass product name to search
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
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            const Text(
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

            // Price (Mobile specific, although user asked to remove it from here if duplicated,
            // but typically mobile info section might include it if not fixed at bottom.
            // Following previous instruction: removed from here as it is in bottom bar)
            // _buildPrice(product),
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

  // Hasarlı ürün kontrolu (adında "Hasarlı" geçen veya ilgili tag'leri olan ürünler)
  bool _isDamagedProduct(dynamic product) {
    // Ürün adında "Hasarlı" veya "Kırık" geçiyorsa
    final nameLower = product.name.toLowerCase();
    if (nameLower.contains('hasarlı') || nameLower.contains('kırık')) {
      return true;
    }

    // Tag'lerde "2.El Hasarlı" varsa
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
