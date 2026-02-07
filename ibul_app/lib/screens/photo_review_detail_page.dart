import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../core/app_state.dart';

class PhotoReviewDetailPage extends StatelessWidget {
  final Map<String, dynamic> review;
  final Product? product;

  const PhotoReviewDetailPage({
    super.key,
    required this.review,
    this.product,
  });

  @override
  Widget build(BuildContext context) {
    // Determine image URL (network or asset)
    final String imageUrl = review['productImage'] ?? '';
    final bool isNetworkImage = imageUrl.startsWith('http');
    
    // Get product price info or use fallback
    final String price = product?.price ?? '1.569,60 TL';
    final String? oldPrice = product?.oldPrice;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Image (Centered)
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: isNetworkImage
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 60,
                      ),
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
            ),
          ),

          // Top Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Fotoğraflı Değerlendirmeler 1/1', // Dynamic count could be added
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Content
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 0),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black87,
                    Colors.black,
                  ],
                  stops: [0.0, 0.3, 1.0],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stars
                  Row(
                    children: List.generate(5, (index) {
                      final rating = review['rating'] as double? ?? 0.0;
                      if (index < rating.floor()) {
                        return const Icon(Icons.star, color: Colors.amber, size: 20);
                      } else if (index < rating) {
                        return const Icon(Icons.star_half, color: Colors.amber, size: 20);
                      }
                      return const Icon(Icons.star_border, color: Colors.grey, size: 20);
                    }),
                  ),
                  const SizedBox(height: 8),

                  // User Info
                  Row(
                    children: [
                      Text(
                        review['userName'] ?? 'Kullanıcı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 8),
                      Text(
                        review['date'] ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Review Text
                  Text(
                    review['reviewText'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Seller Info
                  Text(
                    'Bu ürün ${review['seller'] ?? 'SATICI'} satıcısından alındı.',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Bar (Price & Button)
                  Container(
                    padding: EdgeInsets.only(
                      top: 16,
                      bottom: MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (oldPrice != null)
                              Text(
                                oldPrice,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 13,
                                ),
                              ),
                            Text(
                              price,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () {
                              if (product != null) {
                                final appState = AppState();
                                appState.addToCart(product!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ürün sepete eklendi'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary, // Purple color
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                            ),
                            child: const Text(
                              'Sepete Ekle',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
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
}
