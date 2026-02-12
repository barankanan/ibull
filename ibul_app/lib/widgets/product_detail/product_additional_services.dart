import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';

class ProductAdditionalServices extends StatelessWidget {
  const ProductAdditionalServices({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    if (viewModel.warrantyTitle.isEmpty) return const SizedBox.shrink();

    final warrantyTitle = viewModel.warrantyTitle;
    final warrantyDesc = viewModel.warrantyDescription;
    final warrantyPrice = viewModel.warrantyPriceFormatted;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Blue banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warrantyTitle, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(warrantyDesc, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
          // Bottom area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: OutlinedButton(
                      onPressed: () => viewModel.toggleWarranty(!viewModel.isWarrantyAdded),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E88E5),
                        side: const BorderSide(color: Color(0xFF1E88E5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: EdgeInsets.zero,
                        backgroundColor: viewModel.isWarrantyAdded ? const Color(0xFF1E88E5).withOpacity(0.1) : null,
                      ),
                      child: Text(viewModel.isWarrantyAdded ? 'Eklendi' : 'Ekle', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFF1E88E5), borderRadius: BorderRadius.circular(6)),
                  child: Text(warrantyPrice, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
