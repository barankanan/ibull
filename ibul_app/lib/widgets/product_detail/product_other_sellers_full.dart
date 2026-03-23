import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/store_logo_helper.dart';
import '../../screens/business_detail_page.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../models/product_model.dart';

class ProductOtherSellersFull extends StatefulWidget {
  const ProductOtherSellersFull({super.key});

  @override
  State<ProductOtherSellersFull> createState() => _ProductOtherSellersFullState();
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
      (_scrollController.offset - 280).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _scrollRight() {
    _scrollController.animateTo(
      (_scrollController.offset + 280).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    if (viewModel.loadingOtherStores) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    final items = viewModel.otherStoresWithProducts;
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final sellers = items.map<_SellerData>((item) {
      final store = item['store'] as Map<String, dynamic>;
      final product = item['product'];

      final storeName = store['name']?.toString() ?? '';
      final ratingStr = store['rating']?.toString() ?? '0';
      final rating = double.tryParse(ratingStr) ?? 0;

      Color ratingColor;
      if (rating >= 9.0) {
        ratingColor = const Color(0xFF4CAF50);
      } else if (rating >= 8.0) {
        ratingColor = const Color(0xFFFF8C00);
      } else {
        ratingColor = Colors.grey;
      }

      String price = '';
      if (store['price'] != null) {
        price = store['price'].toString();
      } else if (product is Product) {
        price = product.price;
      }

      return _SellerData(
        name: storeName,
        isVerified: true,
        rating: rating,
        ratingColor: ratingColor,
        badge: null,
        badgeColor: null,
        deliveryInfo: null,
        urgentInfo: null,
        perks: const ['Kargo Bedava'],
        price: price,
      );
    }).toList();

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
          // Header
          const Text(
            'Ürünün Diğer Satıcıları',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Horizontal scrollable seller cards with arrows
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 170,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: sellers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return _buildSellerCard(sellers[index]);
                  },
                ),
              ),
              // Left arrow
              Positioned(
                left: 0,
                child: _buildScrollArrow(Icons.chevron_left, _scrollLeft),
              ),
              // Right arrow
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

  Widget _buildSellerCard(_SellerData seller) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store name + rating
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusinessDetailPage(
                          business: {
                            'name': seller.name,
                            'rating': seller.rating,
                            'verified': seller.isVerified,
                          },
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      if (StoreLogoHelper.hasLogo(seller.name)) ...[
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade200),
                            image: DecorationImage(
                              image: AssetImage(StoreLogoHelper.getStoreLogo(seller.name)!),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ],
                      Flexible(
                        child: Text(
                          seller.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (seller.isVerified) ...[
                        const SizedBox(width: 3),
                        const Icon(Icons.verified, size: 14, color: Color(0xFF1565C0)),
                      ],
                    ],
                  ),
                ),
              ),
              if (seller.rating > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: seller.ratingColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    seller.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),

          // Badge
          if (seller.badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: seller.badgeColor?.withValues(alpha: 0.1) ?? Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: seller.badgeColor?.withValues(alpha: 0.3) ?? Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                seller.badge!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: seller.badgeColor ?? Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Delivery info or urgent info
          if (seller.urgentInfo != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚀 ', style: TextStyle(fontSize: 10)),
                Expanded(
                  child: Text(
                    seller.urgentInfo!,
                    style: const TextStyle(fontSize: 10, color: Colors.black87, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
          ] else if (seller.deliveryInfo != null) ...[
            Text(
              seller.deliveryInfo!,
              style: TextStyle(fontSize: 10, color: Colors.grey[700]),
            ),
            const SizedBox(height: 3),
          ],

          // Perks
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: seller.perks.map((perk) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 10, color: Colors.grey[500]),
                  const SizedBox(width: 3),
                  Text(
                    perk,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              );
            }).toList(),
          ),

          const Spacer(),

          // Price + button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                seller.price,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: Navigate to seller product page
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
}

class _SellerData {
  final String name;
  final bool isVerified;
  final double rating;
  final Color ratingColor;
  final String? badge;
  final Color? badgeColor;
  final String? deliveryInfo;
  final String? urgentInfo;
  final List<String> perks;
  final String price;

  _SellerData({
    required this.name,
    required this.isVerified,
    required this.rating,
    required this.ratingColor,
    this.badge,
    this.badgeColor,
    this.deliveryInfo,
    this.urgentInfo,
    required this.perks,
    required this.price,
  });
}
