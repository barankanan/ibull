import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/home_screen.dart';
import '../../screens/checkout_page.dart';

class ProductBottomBar extends StatefulWidget {
  const ProductBottomBar({super.key});

  @override
  State<ProductBottomBar> createState() => _ProductBottomBarState();
}

class _ProductBottomBarState extends State<ProductBottomBar> {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                Text(
                  viewModel.totalPrice,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF673AB7), // Purple
                  ),
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
            
            // Buttons Area (Right)
            Row(
              children: [
                // Add to Cart Button
                SizedBox(
                  height: 42,
                  width: 140, // Adjusted width
                  child: ElevatedButton(
                    onPressed: () {
                      if (viewModel.isAddedToCart) {
                        viewModel.removeFromCart();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ürün sepetten çıkarıldı'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      } else {
                        viewModel.addToCart();
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
                      backgroundColor: viewModel.isAddedToCart ? Colors.green : const Color(0xFF6200EA), // Green if added, else Purple
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      viewModel.isAddedToCart ? 'SEPETTE' : 'SEPETE EKLE',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Buy Now Button
                SizedBox(
                  height: 42,
                  width: 120,
                  child: OutlinedButton(
                    onPressed: () {
                      // 1. Add to cart (auto-approve)
                      viewModel.addToCart();
                      
                      // 2. Prepare data for checkout
                      double price = _parsePrice(viewModel.totalPrice);
                      
                      final selectedProducts = [
                        {
                          'name': viewModel.initialProduct.name,
                          'image': viewModel.images.isNotEmpty ? viewModel.images.first : null,
                          'price': viewModel.totalPrice,
                          'quantity': 1,
                        }
                      ];

                      // 3. Navigate to Checkout Page
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
                      side: const BorderSide(color: Color(0xFF6200EA), width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'ŞİMDİ AL',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
}
