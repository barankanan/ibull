import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../core/store_logo_helper.dart';
import '../../data/business_data.dart';
import '../../screens/business_detail_page.dart';

class ProductStoreInfo extends StatelessWidget {
  const ProductStoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final storeName = product.store ?? 'Mağaza';

    // Business finding logic
    Map<String, dynamic> business;
    try {
      business = businessData.firstWhere(
        (b) => b['name'].toString().toLowerCase().trim() == storeName.toLowerCase().trim(),
        orElse: () {
          // Smart Fuzzy Match using Word Subset Logic
          return businessData.firstWhere((b) {
             final bName = b['name'].toString().toLowerCase().trim();
             final sName = storeName.toLowerCase().trim();
             
             if (bName.isEmpty || sName.isEmpty) return false;
             
             final bWords = bName.split(RegExp(r'\s+')).toSet();
             final sWords = sName.split(RegExp(r'\s+')).toSet();
             
             // Check if one is a subset of the other (all words match)
             // e.g. "Teknosa" is subset of "Teknosa AVM"
             if (sWords.every((w) => bWords.contains(w))) return true;
             if (bWords.every((w) => sWords.contains(w))) return true;
             
             return false;
          });
        },
      );
    } catch (e) {
       business = {
        'id': storeName.hashCode,
        'name': storeName,
        'logo': storeName.isNotEmpty ? storeName[0] : 'M',
        'rating': product.rating.toString(),
        'followers': '${(product.reviewCount * 15).toString()}K',
        'icon': Icons.store,
        'distance': '500m',
        'images': product.images,
        'location': const LatLng(36.2025, 36.1605),
      };
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessDetailPage(
                business: business,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
               Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: _buildStoreLogo(storeName),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         Text(
                           storeName,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                         ),
                         const SizedBox(width: 4),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                           decoration: BoxDecoration(
                             color: Colors.green,
                             borderRadius: BorderRadius.circular(4),
                           ),
                           child: Row(
                             children: [
                               Text(
                                 business['rating'].toString(),
                                 style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                               ),
                             ],
                           ),
                         ),
                         const SizedBox(width: 4),
                         const Icon(Icons.verified, size: 14, color: Colors.blue),
                       ],
                     ),
                     const SizedBox(height: 2),
                     const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                   ],
                 ),
               ),
               Row(
                 children: [
                   OutlinedButton(
                     onPressed: () {},
                     style: OutlinedButton.styleFrom(
                       foregroundColor: AppColors.primary,
                       side: const BorderSide(color: AppColors.primary),
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       minimumSize: Size.zero,
                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                     ),
                     child: const Text('Takip Et', style: TextStyle(fontSize: 12)),
                   ),
                   const SizedBox(width: 8),
                   ElevatedButton(
                     onPressed: () {},
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.primary,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       minimumSize: Size.zero,
                       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                       elevation: 0,
                     ),
                     child: const Text('Satıcıya Sor', style: TextStyle(fontSize: 12)),
                   ),
                 ],
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreLogo(String storeName) {
    final logoPath = StoreLogoHelper.getStoreLogo(storeName);
    if (logoPath != null) {
      return Image.asset(logoPath, fit: BoxFit.contain);
    }
    return Center(
      child: Text(
        storeName.isNotEmpty ? storeName[0].toUpperCase() : '?',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
