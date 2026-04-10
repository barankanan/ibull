import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../screens/home_screen.dart';
import '../../screens/checkout_page.dart';
import '../../screens/business_detail_page.dart';
import '../../core/app_state.dart';
import '../../core/interaction_feedback.dart';
import '../../screens/login_page.dart';

class ProductBottomBar extends StatefulWidget {
  const ProductBottomBar({super.key});

  @override
  State<ProductBottomBar> createState() => _ProductBottomBarState();
}

class _ProductBottomBarState extends State<ProductBottomBar> {
  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Giriş Yap'),
        content: const Text('Bu işlemi yapmak için giriş yapmanız gerekiyor.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text('Giriş Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductDetailViewModel>(
      builder: (context, viewModel, child) {
        final product = viewModel.displayProduct;
        final category = (product.category ?? '').toLowerCase();
        final isFoodCategory = category.contains('yemek');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Price Area (Left)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // ⬆️ ikonu - sadece 2.el/hasarlı ürünlerde ve parça varsa (fiyatın SOLUNDA)
                        if (viewModel.isSecondHandDamaged &&
                            viewModel.selectedParts.isNotEmpty)
                          GestureDetector(
                            onTap: () => _showPartsPopup(
                              context,
                              viewModel.selectedParts,
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.arrow_upward,
                                    color: Color(0xFF7C4DFF),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${viewModel.selectedParts.length}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF7C4DFF),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Text(
                          viewModel.totalPrice,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF673AB7), // Purple
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Ücretsiz Kargo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                Row(
                  children: [
                    if (isFoodCategory) ...[
                      SizedBox(
                        height: 40,
                        width: 120,
                        child: ElevatedButton(
                          onPressed: () => _onDiningMode(context, viewModel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6200EA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'MEKANDA',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 40,
                        width: 105,
                        child: OutlinedButton(
                          onPressed: () => _onOnlineOrder(context, viewModel),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6200EA),
                            side: const BorderSide(
                              color: Color(0xFF6200EA),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'ONLINE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        height: 40,
                        width: 120,
                        child: ElevatedButton(
                          onPressed: () {
                            final appState = AppState();
                            if (!appState.isLoggedIn) {
                              _showLoginRequiredDialog(context);
                              return;
                            }
                            InteractionFeedback.forInteraction(
                              InteractionFeedbackType.addToCart,
                            );
                            if (viewModel.isAddedToCart) {
                              viewModel.removeFromCart();
                              InteractionFeedback.forInteraction(
                                InteractionFeedbackType.successState,
                                channel: 'cart_remove_success',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ürün sepetten çıkarıldı'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            } else {
                              viewModel.addToCart();
                              InteractionFeedback.forInteraction(
                                InteractionFeedbackType.successState,
                                channel: 'cart_add_success',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ürün sepete eklendi'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: viewModel.isAddedToCart
                                ? Colors.green
                                : const Color(0xFF6200EA),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            viewModel.isAddedToCart ? 'SEPETTE' : 'SEPETE EKLE',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 40,
                        width: 105,
                        child: OutlinedButton(
                          onPressed: () {
                            final appState = AppState();
                            if (!appState.isLoggedIn) {
                              _showLoginRequiredDialog(context);
                              return;
                            }
                            InteractionFeedback.forInteraction(
                              InteractionFeedbackType.mainCta,
                            );
                            viewModel.addToCart();
                            double price = _parsePrice(viewModel.totalPrice);
                            final selectedProducts = [
                              {
                                'productId': product.productId,
                                'name': product.name,
                                'brand': product.brand,
                                'storeName': product.store,
                                'sellerId': product.sellerId,
                                'category': product.category,
                                'image': viewModel.images.isNotEmpty
                                    ? viewModel.images.first
                                    : null,
                                'price': viewModel.totalPrice,
                                'quantity': 1,
                                'services': viewModel.selectedServices,
                                'productObject': product.copyWith(
                                  selectedServices: viewModel.selectedServices,
                                  selectedParts: viewModel.selectedParts,
                                ),
                              },
                            ];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CheckoutPage(
                                  totalPrice: price,
                                  selectedProducts: selectedProducts,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6200EA),
                            side: const BorderSide(
                              color: Color(0xFF6200EA),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'ŞİMDİ AL',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _parsePrice(String priceStr) {
    try {
      String clean = priceStr.replaceAll('TL', '').trim();

      // Handle 1.234,56 format (Turkish) vs 1,234.56 (English)
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.lastIndexOf(',') > clean.lastIndexOf('.')) {
          // 1.234,56 -> 1234.56
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // 1,234.56 -> 1234.56
          clean = clean.replaceAll(',', '');
        }
      } else if (clean.contains(',')) {
        // 1234,56 -> 1234.56
        clean = clean.replaceAll(',', '.');
      } else if (clean.contains('.')) {
        // 25.000 -> 25000 (Turkish thousand separator)
        // Remove dots as they are thousand separators
        clean = clean.replaceAll('.', '');
      }

      return double.tryParse(clean) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  void _onDiningMode(BuildContext context, ProductDetailViewModel viewModel) {
    InteractionFeedback.forInteraction(InteractionFeedbackType.mainCta);
    final product = viewModel.displayProduct;
    final storeName = (product.store ?? product.brand).toString();
    final business = {
      'id': storeName.hashCode,
      'name': storeName,
      'category': 'restoran',
      'logo': storeName.isNotEmpty ? storeName[0] : '',
      'distance': '-',
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => BusinessDetailPage(
          business: business,
          storeProducts: [product],
          forceTableSelection: true,
        ),
      ),
    );
  }

  void _onOnlineOrder(BuildContext context, ProductDetailViewModel viewModel) {
    final appState = AppState();
    if (!appState.isLoggedIn) {
      _showLoginRequiredDialog(context);
      return;
    }
    InteractionFeedback.forInteraction(InteractionFeedbackType.mainCta);
    viewModel.addToCart();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const HomeScreen(initialIndex: 3),
      ),
      (route) => false,
    );
  }

  // Seçili parçaları gösteren popup
  void _showPartsPopup(BuildContext context, List<dynamic> parts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.build, color: Color(0xFF7C4DFF)),
            const SizedBox(width: 8),
            const Text('Seçili Parçalar'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: parts.length,
            itemBuilder: (context, index) {
              final part = parts[index];
              return ListTile(
                leading: part.images != null && part.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          part.images[0],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[200],
                              child: Icon(Icons.image, color: Colors.grey[400]),
                            );
                          },
                        ),
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
                title: Text(
                  part.name ?? 'Parça',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  part.price ?? '0 TL',
                  style: const TextStyle(color: Color(0xFF7C4DFF)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
