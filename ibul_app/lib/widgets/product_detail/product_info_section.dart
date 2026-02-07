import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/parts_selection_page.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({super.key});

  void _showSimulatedNotification(BuildContext context, String productName) {
    // Show a top snackbar-like overlay to simulate push notification
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ibul',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Şimdi',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '🔔 Fiyat Düştü!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Takip ettiğiniz "$productName" ürününün fiyatı düştü. Fırsatı kaçırma!',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove notification after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;

    // Local state for Price Alert
    // Note: In a real app, this should be in the ViewModel
    final ValueNotifier<bool> isPriceAlertActive = ValueNotifier(false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Price Alert Button
              ValueListenableBuilder<bool>(
                valueListenable: isPriceAlertActive,
                builder: (context, isActive, child) {
                  return IconButton(
                    onPressed: () {
                      isPriceAlertActive.value = !isActive;
                      final newState = !isActive;
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newState 
                                ? 'Fiyat alarmı kuruldu! Fiyat düştüğünde bildirim alacaksınız.' 
                                : 'Fiyat alarmı kaldırıldı.',
                          ),
                          backgroundColor: newState ? Colors.green : Colors.grey,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      // Simulate Push Notification
                      if (newState) {
                        Future.delayed(const Duration(seconds: 3), () {
                          if (context.mounted) {
                            _showSimulatedNotification(context, product.name);
                          }
                        });
                      }
                    },
                    icon: Icon(
                      isActive ? Icons.notifications_active : Icons.notifications_none,
                      color: isActive ? AppColors.primary : Colors.grey,
                      size: 28,
                    ),
                    tooltip: 'Fiyat Alarmı',
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < product.rating.round() ? Icons.star : Icons.star_border,
                    size: 16,
                    color: Colors.amber,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Text(
                product.rating.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(width: 4),
              Text(
                '${product.reviewCount} Değerlendirme',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
            ],
          ),
          
          // Parça Seç button ONLY for damaged products
          if (product.name.toLowerCase().contains('hasarlı') || 
              product.tags.any((tag) => tag.toLowerCase().contains('hasarlı'))) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PartsSelectionPage(
                        productName: product.name,
                        productImage: product.images.isNotEmpty ? product.images.first : '',
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.build_circle_outlined, color: AppColors.primary, size: 20),
                label: const Text(
                  'Parça Seç',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
