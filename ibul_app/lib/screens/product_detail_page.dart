import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../viewmodels/product_detail_viewmodel.dart';
import '../widgets/web_header.dart';
import '../widgets/product_detail/product_delivery_info.dart';
import '../widgets/product_detail/product_image_slider.dart';
import '../widgets/product_detail/product_info_section.dart';
import '../widgets/product_detail/product_variant_selector.dart';
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
import 'home_screen.dart';
import 'search_results_page.dart';

class ProductDetailPage extends StatelessWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProductDetailViewModel(
        initialProduct: product,
        appState: Provider.of<AppState>(context, listen: false),
      ),
      child: const _ProductDetailPageContent(),
    );
  }
}

class _ProductDetailPageContent extends StatefulWidget {
  const _ProductDetailPageContent();

  @override
  State<_ProductDetailPageContent> createState() => _ProductDetailPageContentState();
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
    final product = viewModel.initialProduct;
    final parts = <String>[
      'iBul',
      product.brand,
      if (product.category != null) product.category!,
      if (product.subCategory != null) product.subCategory!,
      product.name.length > 40 ? '${product.name.substring(0, 40)}...' : product.name,
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
                        child: Icon(Icons.chevron_right, size: 14, color: Colors.grey),
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
                // LEFT: Product Images + Tabs (açıklama, lokasyon, özellikler)
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      const ProductImageSlider(),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ProductTabsSection(
                          onScrollToDescription: _scrollToDescription,
                          onScrollToSpecs: () {
                            // Find ProductFullSpecs widget position and scroll to it
                            final ctx = _specsKey.currentContext;
                            if (ctx != null) {
                              Scrollable.ensureVisible(
                                ctx,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // CENTER: Product Info + Buttons (beğen, şimdi al, sepete ekle)
                const Expanded(child: _CenterColumn()),
                const SizedBox(width: 16),
                // RIGHT: Seller info + Other stores
                const SizedBox(width: 260, child: _RightColumn()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            const ProductImageSlider(isMobile: true),
            Padding(
              padding: const EdgeInsets.all(16), // Increased padding
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const ProductInfoSection(),
                  const SizedBox(height: 16),
                  const ProductStoreInfo(),
                  const SizedBox(height: 16),
                  const ProductVariantSelector(),
                  const SizedBox(height: 16),
                  const ProductDeliveryInfoSection(), // Delivery Info
                  const SizedBox(height: 16),
                  const ProductOtherStoresCard(),
                  const SizedBox(height: 16),
                  const ProductAdditionalServices(),
                  const SizedBox(height: 16),
                  const ProductReviewsSection(),
                  const SizedBox(height: 16),
                  const ProductComplementarySet(),
                  const SizedBox(height: 16),
                  const SimilarProductsSection(), // Added Similar Products
                  const SizedBox(height: 80), // Space for bottom bar
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductInfoSection(),
          SizedBox(height: 14),
          ProductVariantSelector(),
          SizedBox(height: 12),
          ProductAdditionalServices(),
        ],
      ),
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ProductStoreInfo(),
        SizedBox(height: 10),
        // ProductOtherStoresCard removed as requested
        ProductReviewsSection(),
        SizedBox(height: 10),
        ProductQaCard(),
      ],
    );
  }
}

class _StickyBuyBox extends StatelessWidget {
  const _StickyBuyBox();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ProductInfoSection(), // Price & Rating
              const SizedBox(height: 20),
              const ProductVariantSelector(), // Color/Storage
              const SizedBox(height: 20),
              const ProductBottomBar(), // Add to Cart Button
              const SizedBox(height: 16),
              const ProductAdditionalServices(), // Cargo info etc.
            ],
          ),
        ),
        const SizedBox(height: 16),
        const ProductStoreInfo(),
      ],
    );
  }
}
