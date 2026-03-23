import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/review_repository.dart';
import '../viewmodels/product_detail_viewmodel.dart';
import '../widgets/web_header.dart';
import '../widgets/product_detail/product_delivery_info.dart';
import '../widgets/product_detail/product_image_slider.dart';
import '../widgets/product_detail/product_info_section_web.dart';
import '../widgets/product_detail/product_info_section_mobile.dart';
import '../widgets/product_detail/product_variant_selector_mobile.dart';
import '../widgets/product_detail/product_service_buttons.dart';
import '../widgets/product_detail/product_tabs_section.dart';
import '../widgets/product_detail/product_store_info.dart';
import '../widgets/product_detail/product_other_stores_card.dart';
import '../widgets/product_detail/product_additional_services.dart';
import '../widgets/product_detail/product_reviews_section.dart';
import '../widgets/product_detail/similar_products_section.dart';
import '../widgets/product_detail/product_bottom_bar.dart';
import '../widgets/product_detail/product_full_description.dart';
import '../widgets/product_detail/product_full_specs.dart';
import '../widgets/product_detail/product_comparison_section.dart';
import '../widgets/product_detail/product_faq_section.dart';
import '../widgets/product_detail/product_other_sellers_full.dart';
import '../widgets/product_detail/product_qa_card.dart';
import '../widgets/product_detail/product_reviews_full_section.dart';
import '../widgets/product_detail/product_qa_full_section.dart';
import '../widgets/product_detail/product_complementary_set.dart';
import '../widgets/product_detail/product_category_cards.dart'; // Import
import 'home_screen.dart';
import 'search_results_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;
  final String? heroTag;

  const ProductDetailPage({super.key, required this.product, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);
    final localReviews = appState.getProductReviewsFor(
      productName: product.name,
      storeName: product.store,
    );
    final initialSummary = ReviewRepository.instance
        .getInitialProductReviewSummary(
          productName: product.name,
          storeName: product.store,
          localReviews: localReviews,
          fallbackRating: product.rating,
          fallbackCount: product.reviewCount,
        );

    if (initialSummary.averageRating > 0 || initialSummary.reviewCount > 0) {
      return _buildResolvedPage(
        context,
        product.copyWith(
          rating: initialSummary.averageRating,
          reviewCount: initialSummary.reviewCount,
        ),
      );
    }

    return FutureBuilder<ReviewSummary>(
      future: ReviewRepository.instance.getProductReviewSummary(
        productName: product.name,
        storeName: product.store,
        localReviews: localReviews,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final resolvedSummary = snapshot.data ?? initialSummary;
        return _buildResolvedPage(
          context,
          product.copyWith(
            rating: resolvedSummary.averageRating,
            reviewCount: resolvedSummary.reviewCount,
          ),
        );
      },
    );
  }

  Widget _buildResolvedPage(BuildContext context, Product resolvedProduct) {
    return ChangeNotifierProvider(
      create: (context) => ProductDetailViewModel(
        initialProduct: resolvedProduct,
        appState: Provider.of<AppState>(context, listen: false),
      ),
      child: _ProductDetailPageContent(heroTag: heroTag),
    );
  }
}

class _ProductDetailPageContent extends StatefulWidget {
  final String? heroTag;

  const _ProductDetailPageContent({this.heroTag});

  @override
  State<_ProductDetailPageContent> createState() =>
      _ProductDetailPageContentState();
}

class _ProductDetailPageContentState extends State<_ProductDetailPageContent> {
  final GlobalKey _descriptionKey = GlobalKey();
  final GlobalKey _specsKey = GlobalKey();

  void _scrollToDescription() {
    final ctx = _descriptionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToSpecs() {
    final ctx = _specsKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 1100;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              // Header - Only for Web
              if (isWide)
                WebHeader(
                  onSearch: (query) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SearchResultsPage(query: query),
                      ),
                    );
                  },
                  onCategorySelected: (category) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (route) => false,
                    );
                  },
                ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Breadcrumb
                      if (isWide) _buildBreadcrumb(context),
                      // Main content
                      if (isWide)
                        _buildWideLayout(context)
                      else
                        _buildNarrowLayout(context),
                      if (isWide)
                        // Similar Products (full width)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  const ProductComplementarySet(),
                                  const SizedBox(height: 24),
                                  const SimilarProductsSection(),
                                  const SizedBox(height: 24),
                                  ProductFullDescription(key: _descriptionKey),
                                  const SizedBox(height: 24),
                                  ProductFullSpecs(key: _specsKey),
                                  const SizedBox(height: 24),
                                  const ProductComparisonSection(),
                                  const SizedBox(height: 24),
                                  const ProductReviewsFullSection(),
                                  const SizedBox(height: 24),
                                  const ProductQaFullSection(),
                                  const SizedBox(height: 24),
                                  const ProductFaqSection(),
                                  const SizedBox(height: 24),
                                  const ProductCategoryCards(), // Add here
                                  const SizedBox(height: 24),
                                  const ProductOtherSellersFull(),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Mobile Floating Header (Back Button)
          if (!isWide)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF673AB7)),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

          // Sticky Bottom Bar for Mobile
          if (!isWide)
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ProductBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(
      context,
      listen: false,
    );
    final product = viewModel.initialProduct;
    final parts = <String>[
      'iBul',
      product.brand,
      if (product.category != null) product.category!,
      if (product.subCategory != null) product.subCategory!,
      product.name.length > 40
          ? '${product.name.substring(0, 40)}...'
          : product.name,
    ];

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: parts.asMap().entries.map((entry) {
                final i = entry.key;
                final text = entry.value;
                final isLast = i == parts.length - 1;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 11,
                        color: isLast ? Colors.black54 : AppColors.primary,
                        fontWeight: isLast ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                    if (!isLast)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.chevron_right,
                          size: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: Product Images + Tabs
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      ProductImageSlider(heroTag: widget.heroTag),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ProductTabsSection(
                          onScrollToDescription: _scrollToDescription,
                          onScrollToSpecs: _scrollToSpecs,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // CENTER: Product Info & Actions
                Expanded(child: _CenterColumn()),
                const SizedBox(width: 16),
                // RIGHT: Seller & Summaries
                SizedBox(width: 280, child: const _RightSidebar()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    // Ürün verisini al
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final hasVariants =
        product.variants != null && product.variants!.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            children: [
              ProductImageSlider(isMobile: true, heroTag: widget.heroTag),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const ProductInfoSectionMobile(),
                    const SizedBox(height: 16),
                    const ProductStoreInfo(),
                    const SizedBox(height: 16),

                    if (hasVariants) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ürün Seçenekleri',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (hasVariants) ...[
                        const ProductVariantSelectorMobile(),
                        const SizedBox(height: 16),
                      ],
                    ],
                    if (!hasVariants) ...[
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ürün Seçenekleri',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bu ürün için seçenek bulunmuyor.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Ek Hizmetler Başlığı
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ek Hizmetler',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const ProductAdditionalServices(),
                    const SizedBox(height: 16),

                    const ProductDeliveryInfoSection(),
                    const SizedBox(height: 16),
                    const ProductOtherStoresCard(),
                    const SizedBox(height: 16),
                    const ProductReviewsSection(),
                    const SizedBox(height: 16),
                    const ProductQaCard(),
                    const SizedBox(height: 16),
                    const ProductFaqSection(),
                    const SizedBox(height: 16),
                    const ProductCategoryCards(),
                    const SizedBox(height: 16),
                    const ProductComplementarySet(),
                    const SizedBox(height: 16),
                    const SimilarProductsSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenterColumn extends StatelessWidget {
  const _CenterColumn();

  @override
  Widget build(BuildContext context) {
    // Ürünün seçenekleri olup olmadığını kontrol et
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    // Varyant kontrolünü kaldırdık, varsa göstersin
    final hasVariants =
        product.variants != null && product.variants!.isNotEmpty;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                0.05,
              ), // withValues -> withOpacity
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProductInfoSectionWeb(),
            const SizedBox(height: 24),

            // Varyant Seçici Web - Moved to match Mobile logic (conceptually below Store Info which is in Sidebar, but here in main flow)
            // In Web Wide layout, Store Info is in the Right Sidebar.
            // So we keep Variants here in the center column, but above Additional Services.
            if (hasVariants) ...[
              const Text(
                'Ürün Seçenekleri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              if (hasVariants) ...[
                const ProductVariantSelectorMobile(),
                const SizedBox(height: 16),
              ],
            ],
            if (!hasVariants) ...[
              const Text(
                'Ürün Seçenekleri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu ürün için seçenek bulunmuyor.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
            ],

            const ProductBottomBar(),
            const SizedBox(height: 24),

            const Text(
              'Ek Hizmetler',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            const ProductAdditionalServices(),
            const SizedBox(height: 16),
            const ProductServiceButtons(),
          ],
        ),
      ),
    );
  }
}

class _RightSidebar extends StatelessWidget {
  const _RightSidebar();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: const [
          ProductStoreInfo(),
          SizedBox(height: 16),
          _SmallReviewsCard(),
          SizedBox(height: 16),
          _SmallQaCard(),
        ],
      ),
    );
  }
}

class _SmallReviewsCard extends StatelessWidget {
  const _SmallReviewsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star, size: 16, color: Colors.amber),
              SizedBox(width: 4),
              Text(
                'Değerlendirmeler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const ProductReviewsSection(), // Reusing the widget but it will be constrained by width
        ],
      ),
    );
  }
}

class _SmallQaCard extends StatelessWidget {
  const _SmallQaCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.question_answer, size: 16, color: Colors.blue),
              SizedBox(width: 4),
              Text(
                'Soru & Cevap',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const ProductQaCard(), // Reusing the widget but it will be constrained by width
        ],
      ),
    );
  }
}
