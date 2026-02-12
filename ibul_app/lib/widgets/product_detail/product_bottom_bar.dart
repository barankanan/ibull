import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/home_screen.dart';

class ProductBottomBar extends StatelessWidget {
  const ProductBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    return Row(
      children: [
        // Favorite button
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              viewModel.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: viewModel.isFavorite ? Colors.red : Colors.grey[600],
              size: 20,
            ),
            onPressed: () => viewModel.toggleFavorite(),
          ),
        ),
        const SizedBox(width: 8),

        // Şimdi Al button (outlined)
        Expanded(
          child: SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                viewModel.addToCart();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Şimdi Al', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Sepete Ekle button (filled)
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 40,
            child: viewModel.isAddedToCart
                ? ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Sepette', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      viewModel.addToCart();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ürün sepete eklendi'), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Sepete Ekle', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
          ),
        ),
      ],
    );
  }
}
