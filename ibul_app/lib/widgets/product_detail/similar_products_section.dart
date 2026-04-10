import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../ads/enums/ad_enums.dart';
import '../../core/constants.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../product_card.dart';
import '../skeleton_loading.dart';
import '../sponsored_product_lists_section.dart';

class SimilarProductsSection extends StatefulWidget {
  const SimilarProductsSection({super.key});

  @override
  State<SimilarProductsSection> createState() => _SimilarProductsSectionState();
}

class _SimilarProductsSectionState extends State<SimilarProductsSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      _scrollController.offset - 300,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      _scrollController.offset + 300,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Consumer<ProductDetailViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.loadingSimilarProducts) {
          return _buildLoadingState(isMobile: isMobile);
        }

        final similarProducts = viewModel.similarProducts;
        final categoryFilter =
            (viewModel.initialProduct.category ?? '').trim().isNotEmpty
            ? viewModel.initialProduct.category
            : viewModel.initialProduct.subCategory;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık satırı
            if (similarProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Benzer Ürünler',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Tümünü Gör',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF673AB7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 340,
                child: Stack(
                  children: [
                    ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: similarProducts.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 220,
                          child: ProductCard(
                            product: similarProducts[index],
                            width: 220,
                            compact: false,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        );
                      },
                    ),
                    if (!isMobile) ...[
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildArrowButton(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: _scrollLeft,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: _buildArrowButton(
                            icon: Icons.arrow_forward_ios,
                            onPressed: _scrollRight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SponsoredProductListsSection(
              title: 'Benzer Ürün Listeleri',
              subtitle:
                  'Aynı kategorideki sponsorlu listeler burada gösterilir',
              placement: AdPlacement.relatedProducts,
              categoryFilter: categoryFilter,
              maxItems: 4,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SkeletonLoading(width: 168, height: 22, borderRadius: 8),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: isMobile ? 2 : 3,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                const SizedBox(width: 220, child: ProductCardSkeleton()),
          ),
        ),
      ],
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
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
        icon: Icon(icon, size: 20, color: AppColors.primary),
        onPressed: onPressed,
      ),
    );
  }
}
