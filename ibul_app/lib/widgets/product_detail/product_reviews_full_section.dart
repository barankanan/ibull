import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../screens/all_reviews_page.dart';
import '../../core/constants.dart';

class ProductReviewsFullSection extends StatelessWidget {
  const ProductReviewsFullSection({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final productName = '${product.brand} ${product.name}';
    final rating = product.rating;
    final reviewCount = product.reviewCount;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    // Fallback review data
    final starDistribution = _getStarDistribution(reviewCount);
    final featureRatings = _getFeatureRatings(product);
    final reviews = _getReviews(product);
    final totalReviews = starDistribution.values.fold<int>(0, (a, b) => a + b);

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
          // ---- TOP SECTION: Rating overview ----
          // Title row
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

          // Rating overview area
          isWide
              ? _buildWideLayout2(
                  rating, starDistribution, featureRatings, product, reviews)
              : _buildNarrowLayout2(
                  rating, starDistribution, featureRatings, product, reviews),

          const SizedBox(height: 16),

          // "TÜM YORUMLARI GÖSTER" button
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
                        errorBuilder: (_, __, ___) =>
                            Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
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
        // Değerlendir button
        SizedBox(
          width: 160,
          height: 36,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.rate_review_outlined, size: 15),
            label: const Text(
              'Değerlendir',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ---- Middle: Star distribution bars ----
  Widget _buildStarBars(Map<int, int> starDistribution) {
    final maxCount =
        starDistribution.values.fold<int>(0, (a, b) => a > b ? a : b);

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
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
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
        ...reviews.take(2).map((review) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildReviewCardVertical(review),
        )),
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
                child: const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
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
              Icon(Icons.thumb_down_outlined, size: 14, color: Colors.grey[500]),
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
          const SizedBox(height: 10),
          // Store + likes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${review.store} satıcısından alındı',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 3),
                  Text(
                    '(${review.likes})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  Text('•', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 4),
                  Icon(Icons.thumb_down_outlined, size: 14, color: Colors.grey[400]),
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

  Map<int, int> _getStarDistribution(int totalReviews) {
    // Realistic distribution based on total review count
    final base = totalReviews > 0 ? totalReviews : 1200;
    return {
      5: (base * 0.72).round(),
      4: (base * 0.12).round(),
      3: (base * 0.06).round(),
      2: (base * 0.03).round(),
      1: (base * 0.07).round(),
    };
  }

  List<_FeatureRating> _getFeatureRatings(dynamic product) {
    final name = product.name.toString().toLowerCase();
    final brand = product.brand.toString().toLowerCase();

    if (name.contains('iphone') || (brand.contains('apple') && name.contains('phone'))) {
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

  List<_ReviewData> _getReviews(dynamic product) {
    final name = product.name.toString().toLowerCase();

    if (name.contains('iphone')) {
      return [
        _ReviewData(
          stars: 5,
          userName: 'F** İ**',
          date: '31 Ağustos 2025',
          text: 'Kız arkadaşıma hediye olarak aldım çok memnunuz güzel',
          store: 'iBul',
          likes: 20,
        ),
        _ReviewData(
          stars: 5,
          userName: 'E** A**',
          date: '04 Eylül 2025',
          text: 'Eşim için hediye aldım. İstediği bir telefondu.',
          store: 'Erva Teknoloji',
          likes: 1,
        ),
        _ReviewData(
          stars: 5,
          userName: 'Hilal P.',
          date: '31 Ekim 2025',
          text: 'Kardeşime aldık çok beğendi hızlı kargo',
          store: 'iBul',
          likes: 5,
        ),
        _ReviewData(
          stars: 4,
          userName: 'M** K**',
          date: '15 Kasım 2025',
          text: 'Gayet güzel bir telefon, kamerası harika. Pil ömrü biraz kısa ama genel olarak memnunum.',
          store: 'iBul',
          likes: 12,
        ),
      ];
    } else if (name.contains('galaxy')) {
      return [
        _ReviewData(
          stars: 5,
          userName: 'A** B**',
          date: '20 Ekim 2025',
          text: 'Samsung kalitesi her zamanki gibi üst düzey. Ekranı muhteşem.',
          store: 'iBul',
          likes: 34,
        ),
        _ReviewData(
          stars: 5,
          userName: 'S** T**',
          date: '05 Kasım 2025',
          text: 'Kamerası inanılmaz güzel fotoğraflar çekiyor. 200MP gerçekten fark yaratıyor.',
          store: 'Samsung Store',
          likes: 18,
        ),
        _ReviewData(
          stars: 4,
          userName: 'K** D**',
          date: '12 Aralık 2025',
          text: 'Çok hızlı bir telefon, oyun performansı harika.',
          store: 'iBul',
          likes: 7,
        ),
      ];
    } else {
      return [
        _ReviewData(
          stars: 5,
          userName: 'Y** K**',
          date: '10 Ocak 2026',
          text: 'Ürün beklediğimden çok daha iyi çıktı. Hızlı kargo için teşekkürler.',
          store: 'iBul',
          likes: 8,
        ),
        _ReviewData(
          stars: 4,
          userName: 'D** A**',
          date: '22 Aralık 2025',
          text: 'Fiyat performans açısından güzel bir ürün. Tavsiye ederim.',
          store: 'iBul',
          likes: 3,
        ),
        _ReviewData(
          stars: 5,
          userName: 'B** C**',
          date: '05 Ocak 2026',
          text: 'Kaliteli ve sağlam. Ambalajı da gayet özenli.',
          store: 'iBul',
          likes: 5,
        ),
      ];
    }
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

  _ReviewData({
    required this.stars,
    required this.userName,
    required this.date,
    required this.text,
    required this.store,
    required this.likes,
  });
}
