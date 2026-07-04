import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/store_logo_helper.dart';
import '../../models/product_model.dart';
import '../../screens/business_detail_page.dart';
import '../../screens/product_detail_page.dart';
import '../../utils/product_image_resolver.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../optimized_image.dart';
import '../product_list_thumbnail.dart';
import '../skeleton_loading.dart';

class ProductOtherSellersFull extends StatefulWidget {
  const ProductOtherSellersFull({super.key});

  @override
  State<ProductOtherSellersFull> createState() =>
      _ProductOtherSellersFullState();
}

class _ProductOtherSellersFullState extends State<ProductOtherSellersFull> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _scrollController.animateTo(
      (_scrollController.offset - 280).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 280).clamp(
        0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadingOtherStores = context.select<ProductDetailViewModel, bool>(
      (viewModel) => viewModel.loadingOtherStores,
    );

    if (loadingOtherStores) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonLoading(width: 220, height: 22, borderRadius: 8),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 2,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) => Container(
                  width: 270,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoading(width: 132, height: 16, borderRadius: 6),
                      SizedBox(height: 10),
                      SkeletonLoading(width: 88, height: 12, borderRadius: 6),
                      SizedBox(height: 18),
                      SkeletonLoading(width: 110, height: 20, borderRadius: 6),
                      Spacer(),
                      SkeletonLoading(
                        width: double.infinity,
                        height: 34,
                        borderRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final items = context
        .select<ProductDetailViewModel, List<Map<String, dynamic>>>(
          (viewModel) => viewModel.otherStoresWithProducts,
        );
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ürünün Diğer Satıcıları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 190,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return _buildSellerCard(context, items[index]);
                  },
                ),
              ),
              Positioned(
                left: 0,
                child: _buildScrollArrow(Icons.chevron_left, _scrollLeft),
              ),
              Positioned(
                right: 0,
                child: _buildScrollArrow(Icons.chevron_right, _scrollRight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScrollArrow(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildSellerCard(BuildContext context, Map<String, dynamic> item) {
    final store = item['store'] is Map
        ? Map<String, dynamic>.from(item['store'] as Map)
        : <String, dynamic>{};
    final product = item['product'] is Product
        ? item['product'] as Product
        : null;
    if (product == null) return const SizedBox.shrink();

    final storeName = store['name']?.toString().trim() ?? product.store ?? '';
    final logoUrl = store['logoUrl']?.toString().trim();
    final variantSummary = _variantSummary(product);
    final imageUrl = ProductImageResolver.primaryUrl(images: product.images);
    final hasFreeShipping = product.tags.any(
      (tag) => tag.toLowerCase().contains('ücretsiz kargo'),
    );

    return Container(
      width: 270,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStoreLogo(storeName: storeName, logoUrl: logoUrl),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _openStore(context, storeName, store),
                  child: Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductListThumbnail(
                imageUrlOrPath: imageUrl,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.all(4),
                fallbackIconSize: 20,
                cacheWidth: 112,
                cacheHeight: 112,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (variantSummary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        variantSummary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 12,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  hasFreeShipping ? 'Ücretsiz Kargo' : 'Kargo bilgisi mağazada',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  product.price,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(product: product),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 32),
                  elevation: 0,
                ),
                child: const Text(
                  'Ürüne Git',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStoreLogo({required String storeName, String? logoUrl}) {
    if (logoUrl != null && logoUrl.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: OptimizedImage(
          imageUrlOrPath: logoUrl,
          width: 24,
          height: 24,
          fit: BoxFit.contain,
        ),
      );
    }
    if (StoreLogoHelper.hasLogo(storeName)) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade200),
          image: DecorationImage(
            image: AssetImage(StoreLogoHelper.getStoreLogo(storeName)!),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        storeName.isNotEmpty ? storeName[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _openStore(
    BuildContext context,
    String storeName,
    Map<String, dynamic> store,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BusinessDetailPage(
          business: {
            'name': storeName,
            'seller_id': store['sellerId']?.toString() ?? '',
          },
        ),
      ),
    );
  }

  String? _variantSummary(Product product) {
    final attributes = product.attributes;
    if (attributes != null && attributes.isNotEmpty) {
      return attributes.take(3).join(' · ');
    }
    final variantOptions = product.variantOptions?.trim();
    if (variantOptions != null && variantOptions.isNotEmpty) {
      return variantOptions.replaceAll('|', ' · ');
    }
    final subCategory = product.subCategory?.trim();
    if (subCategory != null && subCategory.isNotEmpty) {
      return subCategory;
    }
    return null;
  }
}
