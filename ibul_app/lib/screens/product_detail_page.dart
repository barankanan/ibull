import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../viewmodels/product_detail_viewmodel.dart';
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

class _ProductDetailPageContent extends StatelessWidget {
  const _ProductDetailPageContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 60),
                    ProductImageSlider(),
                    SizedBox(height: 16),
                    ProductInfoSection(),
                    SizedBox(height: 16),
                    ProductTabsSection(),
                    SizedBox(height: 16),
                    ProductStoreInfo(),
                    SizedBox(height: 16),
                    ProductVariantSelector(),
                    SizedBox(height: 16),
                    ProductOtherStoresCard(),
                    SizedBox(height: 16),
                    ProductAdditionalServices(),
                    SizedBox(height: 16),
                    ProductReviewsSection(),
                    SizedBox(height: 16),
                    SimilarProductsSection(),
                    SizedBox(height: 100), // Space for fixed bottom bar
                  ],
                ),
              ),
            ],
          ),

          // Back button top left
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Fixed bottom bar
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
}
