import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:provider/provider.dart';

import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../widgets/account_sidebar.dart';
import '../widgets/web_footer.dart';
import '../widgets/web_header.dart';
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
      backgroundColor: const Color(0xFFF7F6FB),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
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
                      const WebFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
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
          'Değerlendirmelerim',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade300),
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
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isWeb ? 24 : 0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWeb)
            const Text(
              'Değerlendirmelerim',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
          if (isWeb) const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Arama yap',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8F6FD),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tune, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Filtre',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
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
          ),
          const SizedBox(height: 18),
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

  Widget _tabChip(String label, int count) {
    final selected = _selectedTab == label;
    return InkWell(
      onTap: () => setState(() => _selectedTab = label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6FD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEF1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 58,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 14),
          const Text(
            'Henüz değerlendirme yok',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Değerlendirdiğin ürünler burada listelenecek.',
            style: TextStyle(color: Colors.grey.shade600),
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
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (imageUrl.startsWith('http')) {
      return OptimizedImage(imageUrlOrPath: 
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    if (imageUrl.isEmpty) return _fallback();
    return Image.asset(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallback(),
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
