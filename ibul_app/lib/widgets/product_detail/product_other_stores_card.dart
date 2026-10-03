import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../models/product_model.dart';
import '../../core/store_logo_helper.dart';

import '../../screens/business_detail_page.dart';
import '../../screens/home_lazy_routes.dart';

class ProductOtherStoresCard extends StatelessWidget {
  const ProductOtherStoresCard({super.key});

  void _showAllStores(BuildContext context, List stores) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tüm Mağazalar',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: stores.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = stores[index];
                    final store = item['store'] is Map ? item['store'] as Map : {};
                    
                    String productName = '';
                    String price = '';
                    
                    if (item['product'] is Product) {
                       final p = item['product'] as Product;
                       productName = p.name;
                       price = p.price;
                    } else if (item['product'] is Map) {
                       final pMap = item['product'] as Map;
                       productName = pMap['name'] ?? '';
                       price = pMap['price'] ?? '';
                    }

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessDetailPage(
                              business: {
                                'name': store['name'] ?? '',
                                'rating': store['rating'] ?? '9.0',
                                'verified': true,
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              alignment: Alignment.center,
                              child: StoreLogoHelper.hasLogo(store['name'] ?? '')
                                  ? ClipOval(
                                      child: Image.asset(
                                        StoreLogoHelper.getStoreLogo(store['name'] ?? '')!,
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : Text(
                                      (store['name'] as String? ?? 'M')[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(store['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(store['rating']?.toString() ?? '9.0', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF673AB7))),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);

    final stores = viewModel.otherStoresWithProducts;

    if (stores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Diğer Mağazalar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              TextButton(
                onPressed: () => _showAllStores(context, stores),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF673AB7),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Tümünü Gör', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal List
        SizedBox(
          height: 140, // Height for the cards
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stores.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = stores[index];
              // Safe access for mock vs real data structure
              final store = item['store'] is Map ? item['store'] as Map : {};
              // Assuming Product model does not have toJson yet or we don't want to rely on it.
              // Just use mock data if item['product'] is Product object for now or extract fields manually.
              
              String productName = '';
              String price = '';
              Product? actualProduct;
              
              if (item['product'] is Product) {
                 final p = item['product'] as Product;
                 actualProduct = p;
                 productName = p.name;
                 price = p.price;
              } else if (item['product'] is Map) {
                 final pMap = item['product'] as Map;
                 productName = pMap['name'] ?? '';
                 price = pMap['price'] ?? '';
              }

              return Container(
                width: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Header
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessDetailPage(
                              business: {
                                'name': store['name'] ?? '',
                                'rating': store['rating'] ?? '9.0',
                                'verified': true,
                              },
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            alignment: Alignment.center,
                            child: StoreLogoHelper.hasLogo(store['name'] ?? '')
                                ? ClipOval(
                                    child: Image.asset(
                                      StoreLogoHelper.getStoreLogo(store['name'] ?? '')!,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Text(
                                    (store['name'] as String? ?? 'M')[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(store['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(store['rating']?.toString() ?? '9.0', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: Colors.blue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Product Row
                    Expanded(
                      child: Row(
                        children: [
                          // Image
                          Container(
                            width: 48,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.phone_iphone, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  price,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Button
                    SizedBox(
                      height: 28,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          if (actualProduct != null) {
                            HomeLazyRoutes.openProductDetail(context, actualProduct);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF673AB7),
                          side: const BorderSide(color: Color(0xFF673AB7)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Ürüne Git', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
