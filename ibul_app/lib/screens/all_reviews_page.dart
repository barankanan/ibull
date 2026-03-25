import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

import '../core/constants.dart';
import '../screens/photo_review_detail_page.dart';
import '../widgets/web_header.dart';
import 'home_screen.dart';
import 'search_results_page.dart';

class AllReviewsPage extends StatefulWidget {
  final String productName;
  final String brand;
  final double rating;
  final int reviewCount;
  final List<String> images;
  final List<Map<String, dynamic>>? customReviews;

  const AllReviewsPage({
    super.key,
    required this.productName,
    required this.brand,
    required this.rating,
    required this.reviewCount,
    required this.images,
    this.customReviews,
  });

  @override
  State<AllReviewsPage> createState() => _AllReviewsPageState();
}

class _AllReviewsPageState extends State<AllReviewsPage> {
  String _searchQuery = '';
  String _sortBy = 'En Yeni';
  int? _filterStar;
  late final List<_ReviewData> _allReviews;

  @override
  void initState() {
    super.initState();
    _allReviews = (widget.customReviews ?? const [])
        .map(_reviewFromMap)
        .where(
          (review) =>
              review.comment.trim().isNotEmpty || review.photoUrls.isNotEmpty,
        )
        .toList();
  }

  List<_ReviewData> get _filteredReviews {
    final query = _searchQuery.trim().toLowerCase();
    final reviews = _allReviews.where((review) {
      final matchesStar = _filterStar == null || review.stars == _filterStar;
      final matchesQuery =
          query.isEmpty ||
          review.userName.toLowerCase().contains(query) ||
          review.comment.toLowerCase().contains(query);
      return matchesStar && matchesQuery;
    }).toList();

    reviews.sort((a, b) {
      switch (_sortBy) {
        case 'En Eski':
          return a.createdAt.compareTo(b.createdAt);
        case 'En Yüksek Puan':
          return b.stars.compareTo(a.stars);
        case 'En Düşük Puan':
          return a.stars.compareTo(b.stars);
        case 'En Yeni':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });
    return reviews;
  }

  Map<int, int> get _distribution {
    final distribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final review in _allReviews) {
      final roundedStars = review.stars.round().clamp(1, 5);
      distribution[roundedStars] = (distribution[roundedStars] ?? 0) + 1;
    }
    return distribution;
  }

  double get _averageRating {
    if (_allReviews.isEmpty) return widget.rating;
    final total = _allReviews.fold<double>(0, (sum, item) => sum + item.stars);
    return total / _allReviews.length;
  }

  List<Map<String, dynamic>> get _galleryItems {
    final items = <Map<String, dynamic>>[];
    for (final review in _filteredReviews) {
      for (final imageUrl in review.photoUrls) {
        items.add({
          'imageUrl': imageUrl,
          'userName': review.userName,
          'comment': review.comment,
          'date': review.dateLabel,
          'rating': review.stars,
          'productName': widget.productName,
        });
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 720;
    if (isMobile) {
      return _buildMobileScaffold(context);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FA),
      body: Column(
        children: [
          WebHeader(
            onSearch: (query) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchResultsPage(query: query),
                ),
              );
            },
            onCategorySelected: (_) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 360,
                        child: _buildSummaryPanel(context, compact: false),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildReviewsPanel(context, compact: false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Değerlendirmeler',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryPanel(context, compact: true),
                const SizedBox(height: 14),
                _buildReviewsPanel(context, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel(BuildContext context, {required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 78 : 96,
                height: compact ? 92 : 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F4FC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8E2F3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: widget.images.isNotEmpty
                      ? _ReviewImage(
                          imageUrl: widget.images.first,
                          fit: BoxFit.contain,
                        )
                      : Icon(Icons.image_outlined, color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.brand,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_allReviews.length} kullanıcı değerlendirdi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...List.generate(5, (index) {
            final star = 5 - index;
            final count = _distribution[star] ?? 0;
            final ratio = _allReviews.isEmpty
                ? 0.0
                : count / _allReviews.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '$star★',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFF0EBF7),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_galleryItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Fotoğraflı değerlendirmeler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: compact ? 74 : 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _galleryItems.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final galleryItem = _galleryItems[index];
                  return GestureDetector(
                    onTap: () => _openGallery(context, index),
                    child: Container(
                      width: compact ? 74 : 86,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCCEF5)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _ReviewImage(
                          imageUrl: galleryItem['imageUrl']?.toString() ?? '',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsPanel(BuildContext context, {required bool compact}) {
    final reviews = _filteredReviews;
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE9E4F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Değerlendirmelerde ara',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: const Color(0xFFF8F6FD),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sortBy,
                    borderRadius: BorderRadius.circular(18),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: const [
                      DropdownMenuItem(
                        value: 'En Yeni',
                        child: Text('En Yeni'),
                      ),
                      DropdownMenuItem(
                        value: 'En Eski',
                        child: Text('En Eski'),
                      ),
                      DropdownMenuItem(
                        value: 'En Yüksek Puan',
                        child: Text('En Yüksek Puan'),
                      ),
                      DropdownMenuItem(
                        value: 'En Düşük Puan',
                        child: Text('En Düşük Puan'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortBy = value);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Tümü', null, _allReviews.length),
                const SizedBox(width: 8),
                for (var star = 5; star >= 1; star--) ...[
                  _buildFilterChip(
                    '$star Yıldız',
                    star,
                    _distribution[star] ?? 0,
                  ),
                  if (star != 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (reviews.isEmpty)
            _buildEmptyState()
          else
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: compact
                    ? _buildMobileReviewCard(review, reviews)
                    : _buildDesktopReviewCard(review, reviews),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int? star, int count) {
    final selected = _filterStar == star;
    return InkWell(
      onTap: () => setState(() => _filterStar = star),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2DAF1),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileReviewCard(
    _ReviewData review,
    List<_ReviewData> reviewSource,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E0F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                review.dateLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                review.stars.toStringAsFixed(1).replaceAll('.0', '.0'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                return Icon(
                  index < review.stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 22,
                  color: const Color(0xFFF4C542),
                );
              }),
              const SizedBox(width: 8),
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const Spacer(),
              if (review.photoUrls.isNotEmpty)
                _buildPhotoPreview(review, reviewSource),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopReviewCard(
    _ReviewData review,
    List<_ReviewData> reviewSource,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E0F2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      review.dateLabel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  review.comment,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(
                      review.stars.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ...List.generate(5, (index) {
                      return Icon(
                        index < review.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 22,
                        color: const Color(0xFFF4C542),
                      );
                    }),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 20,
                      color: Colors.grey.shade700,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (review.photoUrls.isNotEmpty) ...[
            const SizedBox(width: 18),
            _buildPhotoPreview(review, reviewSource),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(
    _ReviewData review,
    List<_ReviewData> reviewSource,
  ) {
    final allPhotoEntries = _buildGalleryEntries(reviewSource);
    final initialIndex = allPhotoEntries.indexWhere(
      (entry) =>
          entry['imageUrl']?.toString() == review.photoUrls.first &&
          entry['userName']?.toString() == review.userName &&
          entry['comment']?.toString() == review.comment,
    );

    return GestureDetector(
      onTap: () => _openGalleryFromEntries(
        allPhotoEntries,
        initialIndex < 0 ? 0 : initialIndex,
      ),
      child: Container(
        width: 84,
        height: 84,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD2C5E8)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: _ReviewImage(imageUrl: review.photoUrls.first),
              ),
            ),
            if (review.photoUrls.length > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '(+${review.photoUrls.length - 1})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 58,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz değerlendirme yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'İlk değerlendirmeyi yapan kullanıcı burada görünecek.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    _openGalleryFromEntries(_galleryItems, initialIndex);
  }

  void _openGalleryFromEntries(
    List<Map<String, dynamic>> entries,
    int initialIndex,
  ) {
    if (entries.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PhotoReviewDetailPage(
          galleryItems: entries,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          final offsetAnimation =
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildGalleryEntries(
    List<_ReviewData> reviewSource,
  ) {
    final items = <Map<String, dynamic>>[];
    for (final review in reviewSource) {
      for (final imageUrl in review.photoUrls) {
        items.add({
          'imageUrl': imageUrl,
          'userName': review.userName,
          'comment': review.comment,
          'date': review.dateLabel,
          'rating': review.stars,
          'productName': widget.productName,
        });
      }
    }
    return items;
  }

  _ReviewData _reviewFromMap(Map<String, dynamic> review) {
    final createdAt =
        DateTime.tryParse(review['createdAt']?.toString() ?? '') ??
        DateTime.now();
    final imageUrls = ((review['imageUrls'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    return _ReviewData(
      userName: review['userName']?.toString() ?? 'Kullanıcı',
      stars: ((review['rating'] as num?)?.toDouble() ?? 0)
          .clamp(1, 5)
          .toDouble(),
      comment: review['comment']?.toString() ?? '',
      createdAt: createdAt,
      photoUrls: imageUrls,
    );
  }
}

class _ReviewData {
  final String userName;
  final double stars;
  final String comment;
  final DateTime createdAt;
  final List<String> photoUrls;

  const _ReviewData({
    required this.userName,
    required this.stars,
    required this.comment,
    required this.createdAt,
    required this.photoUrls,
  });

  String get dateLabel =>
      '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
}

class _ReviewImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const _ReviewImage({required this.imageUrl, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      return Image.memory(
        UriData.parse(imageUrl).contentAsBytes(),
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (imageUrl.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (imageUrl.isEmpty) {
      return _fallback();
    }
    return Image.asset(
      imageUrl,
      fit: fit,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFF2EEF8),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
  }
}
