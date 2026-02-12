import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_detail_page.dart';
import '../../models/product_model.dart';

class ProductOtherStoresCard extends StatelessWidget {
  const ProductOtherStoresCard({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    if (viewModel.otherStoresWithProducts.isEmpty && !viewModel.loadingOtherStores) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Diğer Satıcılar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('${viewModel.otherStoresWithProducts.length} satıcı', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ),
          const Divider(height: 1),

          if (viewModel.loadingOtherStores)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            ...viewModel.otherStoresWithProducts.take(3).map((item) {
              final store = item['store'] as Map<String, dynamic>;
              final product = item['product'] as Product;
              final price = store['price'] as String;
              final rating = store['rating'] as String;

              return InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(product: product)));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                  child: Row(
                    children: [
                      // Store info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(store['name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(3)),
                                  child: Text(rating, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 10, color: Colors.grey[500]),
                                const SizedBox(width: 3),
                                Text('Kargo Bedava', style: TextStyle(fontSize: 9, color: Colors.green[700])),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Price
                      Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ],
                  ),
                ),
              );
            }),

          // See all button
          if (viewModel.otherStoresWithProducts.length > 3)
            Padding(
              padding: const EdgeInsets.all(8),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: Text('TÜMÜNÜ GÖR (${viewModel.otherStoresWithProducts.length})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
