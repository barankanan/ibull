import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../core/store_logo_helper.dart';
import '../../data/business_data.dart';
import '../../screens/business_detail_page.dart';
import '../../screens/chat_page.dart';

class ProductStoreInfo extends StatelessWidget {
  const ProductStoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final storeName = product.store ?? 'Teknosa'; // Default to Teknosa as per screenshot example if null

    // Mock Business Logic (Simplified for UI update)
    final business = {
      'name': storeName,
      'logo': 'assets/images/teknosa_logo.png', // You might need a real asset or network image
      'rating': '9.0',
      'verified': true,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BusinessDetailPage(business: business),
                ),
              );
            },
            child: Row(
              children: [
                // Logo Area
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  alignment: Alignment.center,
                  // Logo placeholder or actual image if available
                  child: StoreLogoHelper.hasLogo(storeName)
                      ? Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Image.asset(
                            StoreLogoHelper.getStoreLogo(storeName)!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Text(
                          storeName.isNotEmpty ? storeName[0].toUpperCase() : 'T', 
                          style: const TextStyle(color: Color(0xFF673AB7), fontSize: 20, fontWeight: FontWeight.bold)
                        ),
                ),
                const SizedBox(width: 12),
                
                // Name & Verification
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              storeName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF333333),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, size: 16, color: Colors.blue),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '9.8',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Mağaza Puanı',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF673AB7),
                      side: const BorderSide(color: Color(0xFF673AB7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Takip Et', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () {
                      final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
                      final product = viewModel.initialProduct;
                      final storeName = product.store ?? 'Teknosa';

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            seller: {
                              'id': storeName,
                              'name': storeName,
                              'logo': storeName.isNotEmpty ? storeName[0].toUpperCase() : 'S',
                            },
                            product: {
                              'name': product.name,
                              'image': product.images.isNotEmpty ? product.images[0] : null,
                              'rating': product.rating.toString(),
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF673AB7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      elevation: 0,
                    ),
                    child: const Text('Satıcıya Sor', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
