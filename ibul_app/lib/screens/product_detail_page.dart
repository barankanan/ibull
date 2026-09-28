import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../services/review_repository.dart';
import '../viewmodels/product_detail_viewmodel.dart';
import '../widgets/catalog_detail/catalog_detail_breadcrumb.dart';
import '../widgets/catalog_detail/catalog_detail_card.dart';
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
import '../widgets/product_detail/product_detail_ads_section.dart';
import '../core/home_navigation.dart';
import '../core/ibul_chrome.dart';
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

    final resolvedProduct =
        initialSummary.averageRating > 0 || initialSummary.reviewCount > 0
        ? product.copyWith(
            rating: initialSummary.averageRating,
            reviewCount: initialSummary.reviewCount,
          )
        : product;

    return _buildResolvedPage(context, resolvedProduct);
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
                    HomeNavigation.openHome(context);
                  },
                ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
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
                            constraints: IbulChrome.contentConstraints,
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
                                  const ProductDetailAdsSection(),
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
                      color: Colors.black.withValues(alpha: 0.1),
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
    return CatalogDetailBreadcrumb(parts: parts);
  }

  Widget _buildWideLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: IbulChrome.contentConstraints,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      ProductImageSlider(
                        heroTag: widget.heroTag,
                        topLeftOverlay: _webProductBackButton(context),
                      ),
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
                const SizedBox(width: 32),
                Expanded(child: _CenterColumn()),
                const SizedBox(width: 32),
                SizedBox(width: 280, child: const _RightSidebar()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _webProductBackButton(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Tooltip(
        message: 'Geri',
        child: Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              final nav = Navigator.of(context);
              if (nav.canPop()) {
                nav.pop();
                return;
              }
              HomeNavigation.openHome(context);
            },
            child: const Center(
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: Colors.white,
              ),
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
                    const ProductDetailAdsSection(),
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
      child: CatalogDetailCard(
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
                  fontWeight: FontWeight.w500,
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
                  fontWeight: FontWeight.w500,
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
                fontWeight: FontWeight.w500,
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
