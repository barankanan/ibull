import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../viewmodels/product_detail_viewmodel.dart';
import '../widgets/web_header.dart';
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
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Header - same as home page
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
                  _buildBreadcrumb(context),
                  // Main content
                  if (isWide)
                    _buildWideLayout(context)
                  else
                    _buildNarrowLayout(context),
                  const SizedBox(height: 12),
                  // Similar Products (full width)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
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
                          onScrollToSpecs: _scrollToSpecs,
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
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          ProductImageSlider(),
          SizedBox(height: 12),
          ProductTabsSection(),
          SizedBox(height: 12),
          ProductInfoSection(),
          SizedBox(height: 12),
          ProductVariantSelector(),
          SizedBox(height: 12),
          ProductBottomBar(),
          SizedBox(height: 12),
          ProductStoreInfo(),
          SizedBox(height: 12),
          ProductOtherStoresCard(),
          SizedBox(height: 12),
          ProductReviewsSection(),
          SizedBox(height: 12),
          ProductQaCard(),
          SizedBox(height: 12),
          ProductAdditionalServices(),
        ],
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
          ProductBottomBar(),
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
        ProductOtherStoresCard(),
        SizedBox(height: 10),
        ProductReviewsSection(),
        SizedBox(height: 10),
        ProductQaCard(),
      ],
    );
  }
}
