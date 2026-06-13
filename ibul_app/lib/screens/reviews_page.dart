import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../widgets/account_search_filter_row.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/web_header.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';
import 'home_screen.dart';
import 'product_detail_page.dart';
import 'search_results_page.dart';

class ReviewsPage extends StatefulWidget {
  final Product? product;

  const ReviewsPage({super.key, this.product});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  static const Color _surface = Color(0xFFF4F6FA);
  static const Color _cardBorder = Color(0xFFE7EAF0);
  static const Color _labelColor = Color(0xFF667085);
  static const Color _titleColor = Color(0xFF101828);
  static const Color _heroStart = Color(0xFF5A22E0);
  static const Color _heroEnd = Color(0xFF3A0CA3);

  String _selectedTab = 'Tümü';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;
    if (isWeb) {
      return _buildWebView();
    }
    return _buildMobileView();
  }

  List<Map<String, dynamic>> _myProductReviews(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final userId = appState.currentUser?['uid']?.toString();
    if (userId == null || userId.isEmpty) return [];
    final reviews = appState.productReviews.where((review) {
      return review['userId']?.toString() == userId;
    }).toList();
    reviews.sort(
      (a, b) => (b['createdAt']?.toString() ?? '').compareTo(
        a['createdAt']?.toString() ?? '',
      ),
    );
    return reviews;
  }

  List<Map<String, dynamic>> _filteredReviews(BuildContext context) {
    final allReviews = _myProductReviews(context);
    final query = _searchQuery.trim().toLowerCase();
    Iterable<Map<String, dynamic>> results = allReviews;

    if (_selectedTab == 'Değerlendirilmeyen') {
      results = const [];
    } else if (_selectedTab == 'Değerlendirilen') {
      results = allReviews;
    }

    if (query.isNotEmpty) {
      results = results.where((review) {
        return (review['productName']?.toString().toLowerCase().contains(
                  query,
                ) ??
                false) ||
            (review['comment']?.toString().toLowerCase().contains(query) ??
                false) ||
            (review['storeName']?.toString().toLowerCase().contains(query) ??
                false);
      });
    }
    return results.toList();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: _surface,
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
            child: WebStickyFooterScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(
                            activePage: 'Değerlendirmelerim',
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(child: _buildContent(isWeb: true)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Değerlendirmelerim',
          style: TextStyle(
            color: _titleColor,
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: _cardBorder,
          ),
        ),
      ),
      body: _buildContent(isWeb: false),
    );
  }

  Widget _buildContent({required bool isWeb}) {
    final reviews = _filteredReviews(context);
    final allReviews = _myProductReviews(context);
    final reviewedCount = allReviews.length;

    return Container(
      padding: EdgeInsets.all(isWeb ? 28 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 24 : 0),
        border: isWeb ? Border.all(color: _cardBorder) : null,
        boxShadow: isWeb
            ? const [
                BoxShadow(
                  color: Color(0x14101828),
                  blurRadius: 28,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWeb) ...[
            _buildPageHeader(isWeb: true, reviewedCount: reviewedCount),
            const SizedBox(height: 24),
          ],
          AccountSearchFilterRow(
            hintText: 'Ürün, mağaza veya yorum ara',
            onSearchChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 18),
          _buildTabStrip(reviewedCount),
          SizedBox(height: isWeb ? 22 : 18),
          if (reviews.isEmpty)
            _buildEmptyState()
          else if (isWeb)
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildReviewCard(review, compact: false),
              ),
            )
          else
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildReviewCard(review, compact: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageHeader({required bool isWeb, required int reviewedCount}) {
    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Değerlendirmelerim',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _titleColor,
                    letterSpacing: -0.6,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Satın aldığın ürünler için yazdığın yorumları buradan görüntüle.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: _labelColor.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildReviewStatBadge(reviewedCount),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildReviewStatBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_heroStart, _heroEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _heroStart.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'değerlendirme',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(int reviewedCount) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabChip('Tümü', reviewedCount),
          const SizedBox(width: 10),
          _tabChip('Değerlendirilmeyen', 0),
          const SizedBox(width: 10),
          _tabChip('Değerlendirilen', reviewedCount),
        ],
      ),
    );
  }

  Widget _tabChip(String label, int count) {
    final selected = _selectedTab == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedTab = label),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : _cardBorder,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x06101828),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : _titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : _labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    Map<String, dynamic> review, {
    required bool compact,
  }) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment']?.toString() ?? '';
    final createdAt = DateTime.tryParse(review['createdAt']?.toString() ?? '');
    final date = createdAt == null
        ? '-'
        : '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';
    final imageUrl = review['productImageUrl']?.toString() ?? '';
    final productName = review['productName']?.toString() ?? 'Ürün';
    final storeName = review['storeName']?.toString() ?? 'Mağaza';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  storeName,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: compact ? 92 : 104,
                height: compact ? 102 : 116,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F5FC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _ReviewImage(imageUrl: imageUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Değerlendirmeniz',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment,
                      maxLines: compact ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              ...List.generate(5, (index) {
                return Icon(
                  index < rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFF4C542),
                  size: 28,
                );
              }),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _openProduct(review),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: const Text('Ürüne Git'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 52),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAF8FF), Color(0xFFF3EFFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8DEF8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _heroStart.withValues(alpha: 0.16),
                  _heroEnd.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFE4D9F7)),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Henüz değerlendirme yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Değerlendirdiğin ürünler burada listelenecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: _labelColor,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE7E0F2)),
            ),
            child: const Text(
              'Sipariş sonrası ürün detayından yorum bırakabilirsin',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProduct(Map<String, dynamic> review) {
    final productName = review['productName']?.toString() ?? 'Ürün';
    final storeName = review['storeName']?.toString();
    final imageUrl = review['productImageUrl']?.toString() ?? '';
    final product = Product(
      name: productName,
      brand: storeName ?? 'iBul',
      price: '0 TL',
      rating: (review['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: 1,
      tags: const [],
      images: imageUrl.isEmpty ? const [] : [imageUrl],
      store: storeName,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
    );
  }
}

class _ReviewImage extends StatelessWidget {
  final String imageUrl;

  const _ReviewImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('data:image/')) {
      return Image.memory(
        UriData.parse(imageUrl).contentAsBytes(),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (imageUrl.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    if (imageUrl.isEmpty) return _fallback();
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFF1EDF7),
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
  }
}
