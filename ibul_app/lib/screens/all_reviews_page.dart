import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import 'home_screen.dart';
import 'search_results_page.dart';

class AllReviewsPage extends StatefulWidget {
  final String productName;
  final String brand;
  final double rating;
  final int reviewCount;
  final List<String> images;

  const AllReviewsPage({
    super.key,
    required this.productName,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.images,
  });

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  String _sortBy = 'Önerilen Sıralama';
  int? _filterStar;

  late Map<int, int> _starDistribution;
  late List<_FeatureRating> _featureRatings;
  late List<_ReviewData> _allReviews;
  late int _totalReviews;

  @override
  void initState() {
    super.initState();
    _starDistribution = _getStarDistribution(widget.reviewCount);
    _featureRatings = _getFeatureRatings();
    _allReviews = _getReviews();
    _totalReviews = _starDistribution.values.fold<int>(0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Same header as all pages
          WebHeader(
            onSearch: (query) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsPage(query: query, results: const []),
                ),
              );
            },
            onCategorySelected: (category) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          // Content
          Expanded(
            child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
          ),
        ],
      ),
    );
  }

  // ========= WIDE LAYOUT =========
  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Rating summary panel (sticky - doesn't scroll)
          SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: _buildLeftPanel(),
            ),
          ),
          const SizedBox(width: 24),
          // RIGHT: Reviews list (scrollable)
          Expanded(
            child: SingleChildScrollView(
              child: _buildRightPanel(),
            ),
          ),
        ],
      ),
    );
  }

  // ========= NARROW LAYOUT =========
  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildLeftPanel(),
          const SizedBox(height: 16),
          _buildRightPanel(),
        ],
      ),
    );
  }

  // ========= LEFT PANEL: Rating + Stars + Features =========
  Widget _buildLeftPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Product image + Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 100,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: widget.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          widget.images.first,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
                        ),
                      )
                    : Icon(Icons.phone_iphone, size: 32, color: Colors.grey[400]),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.rating.toStringAsFixed(1).replaceAll('.', ','),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      return Icon(
                        i < widget.rating.round() ? Icons.star : Icons.star_border,
                        size: 18,
                        color: AppColors.primary,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Star bars
          _buildStarBars(),
          const SizedBox(height: 12),
          // Değerlendir button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.rate_review_outlined, size: 16),
              label: const Text(
                'Değerlendir',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Öne çıkan özellikler
          _buildFeatureRatingsBox(),
        ],
      ),
    );
  }

  // ========= RIGHT PANEL: Search + Sort + AI + Reviews =========
  Widget _buildRightPanel() {
    final filteredReviews = _filterStar != null
        ? _allReviews.where((r) => r.stars == _filterStar).toList()
        : _allReviews;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Tüm Değerlendirmeler',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < widget.rating.round() ? Icons.star : Icons.star_border,
                    size: 14,
                    color: AppColors.primary,
                  );
                }),
              ),
              const SizedBox(width: 6),
              Text(
                '$_totalReviews Değerlendirme $_totalReviews Yorum',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search + Sort row
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      Icon(Icons.search, size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Değerlendirmelerde Ara',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sort dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600]),
                    style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    elevation: 3,
                    items: const [
                      DropdownMenuItem(value: 'Önerilen Sıralama', child: Text('Önerilen Sıralama')),
                      DropdownMenuItem(value: 'En Yeni', child: Text('En Yeni')),
                      DropdownMenuItem(value: 'En Eski', child: Text('En Eski')),
                      DropdownMenuItem(value: 'En Beğenilen', child: Text('En Beğenilen')),
                    ],
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter icon
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: Icon(Icons.tune, size: 18, color: Colors.grey[600]),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Star filter chips
          _buildStarFilterChips(),
          const SizedBox(height: 14),

          // Review topic tags
          _buildReviewTopicTags(),
          const SizedBox(height: 16),

          // AI Summary
          _buildAiSummaryCard(),
          const SizedBox(height: 16),

          // Fotoğraflı Değerlendirmeler
          _buildPhotoReviews(),
          const SizedBox(height: 20),

          // Review cards
          ...filteredReviews.map((review) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildReviewCard(review),
          )),
        ],
      ),
    );
  }

  // ========= REVIEW TOPIC TAGS =========
  Widget _buildReviewTopicTags() {
    final topics = _getReviewTopics();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topics.map((topic) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${topic.label} (${topic.count})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.add, size: 14, color: Colors.grey[400]),
            ],
          ),
        );
      }).toList(),
    );
  }

  List<_TopicTag> _getReviewTopics() {
    final name = widget.productName.toLowerCase();

    if (name.contains('iphone')) {
      return [
        _TopicTag('sorunsuz', 769),
        _TopicTag('çok hızlı', 597),
        _TopicTag('tavsiye ederim', 556),
        _TopicTag('fiyat performans', 506),
        _TopicTag('batarya performansı', 365),
        _TopicTag('kaliteli telefon', 342),
        _TopicTag('kamera kalitesi', 266),
        _TopicTag('kaliteli kullanışlı', 189),
        _TopicTag('hediyelik', 171),
        _TopicTag('gayet başarılı', 158),
      ];
    } else if (name.contains('galaxy')) {
      return [
        _TopicTag('ekran kalitesi', 845),
        _TopicTag('hızlı şarj', 623),
        _TopicTag('kamera harika', 580),
        _TopicTag('performans', 512),
        _TopicTag('tavsiye ederim', 478),
        _TopicTag('Samsung kalitesi', 390),
        _TopicTag('şık tasarım', 285),
        _TopicTag('pil ömrü', 230),
        _TopicTag('sorunsuz', 198),
        _TopicTag('hızlı kargo', 165),
      ];
    } else if (name.contains('macbook') || name.contains('laptop')) {
      return [
        _TopicTag('performans', 432),
        _TopicTag('hızlı', 380),
        _TopicTag('sessiz çalışıyor', 290),
        _TopicTag('ekran kalitesi', 275),
        _TopicTag('pil ömrü harika', 245),
        _TopicTag('hafif ve taşınabilir', 210),
        _TopicTag('profesyonel', 185),
        _TopicTag('tavsiye ederim', 170),
      ];
    } else {
      return [
        _TopicTag('sorunsuz', 320),
        _TopicTag('kaliteli', 285),
        _TopicTag('hızlı kargo', 240),
        _TopicTag('tavsiye ederim', 210),
        _TopicTag('fiyat performans', 185),
        _TopicTag('çok beğendim', 160),
        _TopicTag('sağlam ambalaj', 130),
        _TopicTag('hediyelik', 95),
      ];
    }
  }

  // ========= STAR BARS =========
  Widget _buildStarBars() {
    final maxCount = _starDistribution.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      children: List.generate(5, (i) {
        final starNum = 5 - i;
        final count = _starDistribution[starNum] ?? 0;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(Icons.star, size: 14, color: AppColors.primary),
              const SizedBox(width: 2),
              SizedBox(
                width: 12,
                child: Text(
                  '$starNum',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black87),
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
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
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

  // ========= FEATURE RATINGS BOX =========
  Widget _buildFeatureRatingsBox() {
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
            children: _featureRatings.map((f) {
              return Expanded(
                child: Column(
                  children: [
                    Icon(f.icon, size: 28, color: Colors.grey[700]),
                    const SizedBox(height: 6),
                    Text(
                      f.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.primary),
                        const SizedBox(width: 2),
                        Text(
                          f.rating.toStringAsFixed(1).replaceAll('.', ','),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
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

  // ========= AI SUMMARY =========
  Widget _buildAiSummaryCard() {
    return Container(
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
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple[400]),
              ),
              const SizedBox(width: 8),
              const Text(
                'Değerlendirme Özeti',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(width: 4),
              Icon(Icons.info_outline, size: 14, color: Colors.grey[400]),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Müşteri yorumları, ürünün sorunsuz ve hızlı bir şekilde teslim edildiğini, özenli paketleme sayesinde hasarsız ulaştığını ve kalitesini yansıttığını vurgulamaktadır. İndirimli fiyatlarla alınması memnuniyet yaratmış, cihazın ön tasarımı ve kullanışlı yapısı öne çıkmıştır. Öte yandan, bazı müşteriler kargo ücreti ödemek zorunda kaldıklarını belirtmiştir. Genel olarak, ürün tavsiye edilir ve güvenilir bir alışveriş deneyimi sunar.',
            style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.6),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Bu özeti faydalı buldunuz mu?',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.thumb_up_outlined, size: 15, color: Colors.grey[400]),
              const SizedBox(width: 6),
              Icon(Icons.thumb_down_outlined, size: 15, color: Colors.grey[400]),
            ],
          ),
        ],
      ),
    );
  }

  // ========= PHOTO REVIEWS =========
  Widget _buildPhotoReviews() {
    final photoUrls = [
      'assets/images/products/iphone13_1.png',
      'assets/images/products/iphone13_2.png',
      'assets/images/products/iphone13_3.png',
      'assets/images/products/iphone13_4.png',
      'assets/images/products/iphone13_5.png',
      'assets/images/products/iphone13_6.png',
      'assets/images/products/iphone13_7.png',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Fotoğraflı Değerlendirmeler',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            TextButton(
              onPressed: () {},
              child: Text(
                'Tümü >',
                style: TextStyle(fontSize: 12, color: Colors.blue[600]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 70,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                  color: Colors.grey[50],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    photoUrls[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.image, size: 24, color: Colors.grey[300]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ========= STAR FILTER CHIPS =========
  Widget _buildStarFilterChips() {
    return Wrap(
      spacing: 8,
      children: [
        _buildFilterChip(null, 'Tümü'),
        ...List.generate(5, (i) {
          final star = 5 - i;
          return _buildFilterChip(star, '$star ★');
        }),
      ],
    );
  }

  Widget _buildFilterChip(int? star, String label) {
    final isSelected = _filterStar == star;
    return GestureDetector(
      onTap: () => setState(() => _filterStar = star),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ========= INDIVIDUAL REVIEW CARD =========
  Widget _buildReviewCard(_ReviewData review) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
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
                    color: AppColors.primary,
                  );
                }),
              ),
              Flexible(
                child: Text(
                  '${review.userName}  •  ${review.date}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Review text
          Text(
            review.text,
            style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
          ),
          // Photo if exists
          if (review.hasPhoto) ...[
            const SizedBox(height: 10),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  review.photoUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.image, size: 24, color: Colors.grey[300]),
                ),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_up_outlined, size: 14, color: Colors.grey[400]),
                  if (review.likes > 0) ...[
                    const SizedBox(width: 3),
                    Text('(${review.likes})', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                  const SizedBox(width: 8),
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
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(0)}K';
    return '$count';
  }

  Map<int, int> _getStarDistribution(int totalReviews) {
    final base = totalReviews > 0 ? totalReviews : 1200;
    return {
      5: (base * 0.72).round(),
      4: (base * 0.12).round(),
      3: (base * 0.06).round(),
      2: (base * 0.03).round(),
      1: (base * 0.07).round(),
    };
  }

  List<_FeatureRating> _getFeatureRatings() {
    final name = widget.productName.toLowerCase();
    final brand = widget.brand.toLowerCase();

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

  List<_ReviewData> _getReviews() {
    final name = widget.productName.toLowerCase();

    if (name.contains('iphone')) {
      return [
        _ReviewData(
          stars: 5,
          userName: 'F** İ**',
          date: '31 Ağustos 2023',
          text: 'Kız arkadaşıma hediye olarak aldım çok memnunuz güzel',
          store: 'Trendyol',
          likes: 20,
          hasPhoto: true,
          photoUrl: 'assets/images/products/iphone13_1.png',
        ),
        _ReviewData(
          stars: 4,
          userName: 'E** A**',
          date: '4 Eylül 2023',
          text: 'Eşim için hediye aldım. İstediği bir telefondu',
          store: 'Erva Teknoloji',
          likes: 1,
        ),
        _ReviewData(
          stars: 4,
          userName: 'Hilal P.',
          date: '31 Ekim 2025',
          text: 'Kardeşime aldık çok beğendi hızlı ve sağlam kargo',
          store: 'Trendyol',
          likes: 0,
        ),
        _ReviewData(
          stars: 4,
          userName: 'C** Y**',
          date: '8 Şubat 2026',
          text: 'çok güzel sorunsuz geldi',
          store: 'Trendyol',
          likes: 0,
          hasPhoto: true,
          photoUrl: 'assets/images/products/iphone13_2.png',
        ),
        _ReviewData(
          stars: 5,
          userName: 'h** b**',
          date: '8 Şubat 2026',
          text: 'çabuk geldi paketi sağlam telefon güzel sorunsuz kızıma aldım memnun tavsiye ederim',
          store: 'Fırsatçını',
          likes: 0,
        ),
        _ReviewData(
          stars: 5,
          userName: 'D** C**',
          date: '8 Şubat 2026',
          text: 'Ürün gayet güzel geldi. Hızlı kargo için teşekkürler. Tavsiye ederim.',
          store: 'iBul',
          likes: 3,
        ),
        _ReviewData(
          stars: 4,
          userName: 'M** K**',
          date: '15 Kasım 2025',
          text: 'Gayet güzel bir telefon, kamerası harika. Pil ömrü biraz kısa ama genel olarak memnunum.',
          store: 'iBul',
          likes: 12,
        ),
        _ReviewData(
          stars: 5,
          userName: 'S** Ö**',
          date: '2 Ocak 2026',
          text: 'İkinci kez aldım. Güvenilir satıcı, hızlı teslimat. Fiyat performans olarak çok iyi.',
          store: 'Trendyol',
          likes: 7,
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
        _ReviewData(
          stars: 5,
          userName: 'R** Y**',
          date: '28 Aralık 2025',
          text: "Ekranı inanılmaz güzel. AMOLED'in farkı gerçekten hissediliyor.",
          store: 'Trendyol',
          likes: 15,
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
        _ReviewData(
          stars: 3,
          userName: 'T** E**',
          date: '15 Ocak 2026',
          text: 'İdare eder, fiyatına göre fena değil.',
          store: 'Trendyol',
          likes: 1,
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
  final bool hasPhoto;
  final String? photoUrl;

  _ReviewData({
    required this.stars,
    required this.userName,
    required this.date,
    required this.text,
    required this.store,
    required this.likes,
    this.hasPhoto = false,
    this.photoUrl,
  });
}

class _TopicTag {
  final String label;
  final int count;
  _TopicTag(this.label, this.count);
}
