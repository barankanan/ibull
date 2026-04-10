import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';
import '../../services/review_repository.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../screens/all_reviews_page.dart';

class ProductReviewsFullSection extends StatelessWidget {
  const ProductReviewsFullSection({super.key});

  @override
  Widget build(BuildContext context) {
    final product = context.select<ProductDetailViewModel, dynamic>(
      (viewModel) => viewModel.initialProduct,
    );
    final summary = context.select<ProductDetailViewModel, ReviewSummary>(
      (viewModel) => viewModel.reviewSummary,
    );
    final productName = '${product.brand} ${product.name}';
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final customReviews = summary.reviews;
    final rating = summary.averageRating;
    final reviewCount = summary.reviewCount;
    final starDistribution = _getStarDistribution(reviewCount, customReviews);
    final featureRatings = _getFeatureRatings(product);
    final reviews = _getReviews(product, customReviews);
    final totalReviews = starDistribution.values.fold<int>(0, (a, b) => a + b);
    final hasReviews = totalReviews > 0 && reviews.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '$productName Değerlendirmeleri',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Text(
                'Tüm Değerlendirmeler ($totalReviews)',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          hasReviews
              ? (isWide
                    ? _buildWideLayout2(
                        rating,
                        starDistribution,
                        featureRatings,
                        product,
                        reviews,
                      )
                    : _buildNarrowLayout2(
                        rating,
                        starDistribution,
                        featureRatings,
                        product,
                        reviews,
                      ))
              : _buildEmptyReviewsState(context, product),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 320,
              height: 44,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllReviewsPage(
                        productName: product.name,
                        brand: product.brand,
                        rating: rating,
                        reviewCount: reviewCount,
                        images: List<String>.from(product.images),
                        customReviews: customReviews,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TÜM DEĞERLENDİRMELERİ GÖSTER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========= WIDE LAYOUT: 2 sections =========
  // TOP: (image+rating+bars) LEFT | feature ratings RIGHT
  // BOTTOM: AI summary LEFT + review cards 2-col grid
  Widget _buildWideLayout2(
    double rating,
    Map<int, int> starDistribution,
    List<_FeatureRating> featureRatings,
    dynamic product,
    List<_ReviewData> reviews,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT column: rating + bars + öne çıkan özellikler
        SizedBox(
          width: 420,
          child: Column(
            children: [
              // Rating + bars
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: _buildRatingLeftSection(rating, product),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStarBars(starDistribution)),
                ],
              ),
              const SizedBox(height: 16),
              // Öne çıkan özellikler
              _buildFeatureRatingsBox(featureRatings),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // RIGHT column: review cards (vertical) - limited width
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: _buildVerticalReviewCards(reviews),
          ),
        ),
      ],
    );
  }

  // ========= NARROW LAYOUT: stacked =========
  Widget _buildNarrowLayout2(
    double rating,
    Map<int, int> starDistribution,
    List<_FeatureRating> featureRatings,
    dynamic product,
    List<_ReviewData> reviews,
  ) {
    return Column(
      children: [
        _buildRatingLeftSection(rating, product),
        const SizedBox(height: 16),
        _buildStarBars(starDistribution),
        const SizedBox(height: 16),
        _buildFeatureRatingsBox(featureRatings),
        const SizedBox(height: 16),
        _buildVerticalReviewCards(reviews),
      ],
    );
  }

  // ---- Left: Product image + rating + stars + button ----
  Widget _buildRatingLeftSection(double rating, dynamic product) {
    return Column(
      children: [
        // Image + Rating + Stars in a row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product image
            Container(
              height: 100,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: product.images.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        product.images.first,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.phone_iphone,
                          size: 32,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),
            // Rating number + Stars
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating.toStringAsFixed(1).replaceAll('.', ','),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    return Icon(
                      i < rating.round() ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.orange,
                    );
                  }),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Değerlendir - sadece satın alanlar için (devre dışı)
        Tooltip(
          message: 'Değerlendirme yapmak için ürünü satın almanız gerekiyor.',
          child: SizedBox(
            width: 160,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.rate_review_outlined, size: 15),
              label: const Text(
                'Değerlendir',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.grey.shade600,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Middle: Star distribution bars ----
  Widget _buildStarBars(Map<int, int> starDistribution) {
    final maxCount = starDistribution.values.fold<int>(
      0,
      (a, b) => a > b ? a : b,
    );

    return Column(
      children: List.generate(5, (i) {
        final starNum = 5 - i;
        final count = starDistribution[starNum] ?? 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Icons.star, size: 14, color: Colors.orange),
              const SizedBox(width: 2),
              SizedBox(
                width: 14,
                child: Text(
                  '$starNum',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: Text(
                  _formatCount(count),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ---- Right: Feature ratings box ----
  Widget _buildFeatureRatingsBox(List<_FeatureRating> features) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Öne çıkan özellikler',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: features.map((f) {
              return Expanded(
                child: Column(
                  children: [
                    Icon(f.icon, size: 28, color: Colors.grey[700]),
                    const SizedBox(height: 6),
                    Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text(
                          f.rating.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(${_formatCount(f.count)})',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ========= VERTICAL REVIEW CARDS (single column) =========
  Widget _buildVerticalReviewCards(List<_ReviewData> reviews) {
    return Column(
      children: [
        // AI summary card
        _buildAiSummaryCardVertical(),
        const SizedBox(height: 12),
        // Review cards - single column, one per row
        ...reviews
            .take(2)
            .map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildReviewCardVertical(review),
              ),
            ),
      ],
    );
  }

  // AI Summary card (vertical, no fixed height)
  Widget _buildAiSummaryCardVertical() {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD4C8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C5DC7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Değerlendirme Özeti',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5B3CA0),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Müşteri yorumları, ürünün sorunsuz ve hızlı bir şekilde teslim edildiğini, özenli paketleme sayesinde hasarsız ulaştığını ve kalitesini yansıttığını vurgulamaktadır. İndirimli fiyatlarla alınması memnuniyet yaratmış...',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF4A3580),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Devamını Oku',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7C5DC7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Bu özeti faydalı buldunuz mu?',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(width: 6),
              Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Icon(
                Icons.thumb_down_outlined,
                size: 14,
                color: Colors.grey[500],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Review card (vertical, full width)
  Widget _buildReviewCardVertical(_ReviewData review) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stars + Name + Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.stars ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.orange,
                  );
                }),
              ),
              Flexible(
                child: Text(
                  '${review.userName}  •  ${review.date}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Review text
          Text(
            review.text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.photoUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final photoUrl = review.photoUrls[index];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      child: _ReviewImage(url: photoUrl),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Store + likes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${review.store} satıcısından alındı',
                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.thumb_up_outlined,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '(${review.likes})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.thumb_down_outlined,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========= HELPERS =========
  String _formatCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(0)}K';
    }
    return '$count';
  }

  Map<int, int> _getStarDistribution(
    int totalReviews,
    List<Map<String, dynamic>> customReviews,
  ) {
    if (customReviews.isNotEmpty) {
      final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final review in customReviews) {
        final rating = ((review['rating'] as num?)?.round() ?? 0).clamp(1, 5);
        distribution[rating] = (distribution[rating] ?? 0) + 1;
      }
      return distribution;
    }
    if (totalReviews <= 0) return {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    return {
      5: (totalReviews * 0.72).round(),
      4: (totalReviews * 0.12).round(),
      3: (totalReviews * 0.06).round(),
      2: (totalReviews * 0.03).round(),
      1: (totalReviews * 0.07).round(),
    };
  }

  Widget _buildEmptyReviewsState(BuildContext context, dynamic product) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz değerlendirme yok',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu ürünü satın alan kullanıcılar değerlendirme yapabilir.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<_FeatureRating> _getFeatureRatings(dynamic product) {
    if (product.reviewCount <= 0) return [];
    final name = product.name.toString().toLowerCase();
    final brand = product.brand.toString().toLowerCase();

    if (name.contains('iphone') ||
        (brand.contains('apple') && name.contains('phone'))) {
      return [
        _FeatureRating(Icons.battery_full, 'Batarya', 4.6, 24768),
        _FeatureRating(Icons.phone_iphone, 'Ekran', 4.8, 24465),
        _FeatureRating(Icons.camera_alt_outlined, 'Kamera', 4.8, 24383),
        _FeatureRating(Icons.memory, 'İşlemci', 4.8, 24329),
      ];
    } else if (name.contains('galaxy') || brand.contains('samsung')) {
      return [
        _FeatureRating(Icons.battery_full, 'Batarya', 4.7, 18200),
        _FeatureRating(Icons.phone_iphone, 'Ekran', 4.9, 17800),
        _FeatureRating(Icons.camera_alt_outlined, 'Kamera', 4.8, 17500),
        _FeatureRating(Icons.memory, 'İşlemci', 4.7, 17300),
      ];
    } else if (name.contains('macbook') || name.contains('laptop')) {
      return [
        _FeatureRating(Icons.battery_full, 'Batarya', 4.8, 6200),
        _FeatureRating(Icons.laptop_mac, 'Ekran', 4.9, 6100),
        _FeatureRating(Icons.speed, 'Performans', 4.9, 6050),
        _FeatureRating(Icons.keyboard, 'Klavye', 4.7, 5800),
      ];
    } else {
      return [
        _FeatureRating(Icons.star, 'Kalite', 4.5, 3200),
        _FeatureRating(Icons.local_shipping, 'Kargo', 4.6, 3100),
        _FeatureRating(Icons.inventory_2, 'Ambalaj', 4.7, 2900),
        _FeatureRating(Icons.thumb_up, 'Değer', 4.4, 2800),
      ];
    }
  }

  List<_ReviewData> _getReviews(
    dynamic product,
    List<Map<String, dynamic>> customReviews,
  ) {
    if (customReviews.isEmpty) return [];
    return customReviews.map((review) {
      final createdAt = DateTime.tryParse(
        review['createdAt']?.toString() ?? '',
      );
      final imageUrls = ((review['imageUrls'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      return _ReviewData(
        stars: ((review['rating'] as num?)?.round() ?? 0).clamp(1, 5),
        userName: review['userName']?.toString() ?? 'Kullanıcı',
        date: createdAt != null
            ? '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}'
            : '',
        text: review['comment']?.toString() ?? '',
        store:
            review['storeName']?.toString() ?? product.store?.toString() ?? '',
        likes: (review['likes'] as num?)?.toInt() ?? 0,
        photoUrls: imageUrls,
      );
    }).toList();
  }
}

class _FeatureRating {
  final IconData icon;
  final String label;
  final double rating;
  final int count;

  _FeatureRating(this.icon, this.label, this.rating, this.count);
}

class _ReviewData {
  final int stars;
  final String userName;
  final String date;
  final String text;
  final String store;
  final int likes;
  final List<String> photoUrls;

  _ReviewData({
    required this.stars,
    required this.userName,
    required this.date,
    required this.text,
    required this.store,
    required this.likes,
    this.photoUrls = const [],
  });
}

class _ReviewImage extends StatelessWidget {
  const _ReviewImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('data:image/')) {
      final bytes = UriData.parse(url).contentAsBytes();
      return Image.memory(bytes, fit: BoxFit.cover);
    }
    if (url.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: url,
        fit: BoxFit.cover,
        errorWidget: _fallback(),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}
