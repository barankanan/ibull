import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../data/business_data.dart';
import '../../screens/business_detail_page.dart';

class ProductStoreInfo extends StatelessWidget {
  const ProductStoreInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final product = viewModel.initialProduct;
    final storeName = product.store ?? 'Mağaza';

    Map<String, dynamic> business;
    try {
      business = businessData.firstWhere(
        (b) => b['name'].toString().toLowerCase().trim() == storeName.toLowerCase().trim(),
        orElse: () {
          return businessData.firstWhere((b) {
            final bName = b['name'].toString().toLowerCase().trim();
            final sName = storeName.toLowerCase().trim();
            if (bName.isEmpty || sName.isEmpty) return false;
            final bWords = bName.split(RegExp(r'\s+')).toSet();
            final sWords = sName.split(RegExp(r'\s+')).toSet();
            if (sWords.every((w) => bWords.contains(w))) return true;
            if (bWords.every((w) => sWords.contains(w))) return true;
            return false;
          }, orElse: () => <String, dynamic>{
            'id': storeName.hashCode,
            'name': storeName,
            'logo': storeName.isNotEmpty ? storeName[0] : 'M',
            'rating': product.rating.toString(),
            'followers': '${(product.reviewCount * 15)}K',
            'icon': Icons.store,
            'distance': '500m',
            'images': product.images,
            'location': const LatLng(36.2025, 36.1605),
          });
        },
      );
    } catch (e) {
      business = {
        'id': storeName.hashCode,
        'name': storeName,
        'logo': storeName.isNotEmpty ? storeName[0] : 'M',
        'rating': product.rating.toString(),
        'followers': '${(product.reviewCount * 15)}K',
        'icon': Icons.store,
        'distance': '500m',
        'images': product.images,
        'location': const LatLng(36.2025, 36.1605),
      };
    }

    final rating = double.tryParse(business['rating']?.toString() ?? '0') ?? 0;
    final ratingStr = rating > 10 ? (rating / 10).toStringAsFixed(1) : rating.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.green.shade600, width: 3)),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              storeName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 12, color: Colors.blue),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: Text(ratingStr, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.info_outline, size: 12, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 2),
                Row(children: [Text('${business['followers'] ?? '4,7M'} Takipçi', style: TextStyle(fontSize: 10, color: Colors.grey[600]))]),
                const SizedBox(height: 10),
                _buildActionRow(Icons.add, 'Takip Et', onTap: () {}),
                const SizedBox(height: 6),
                _buildActionRow(Icons.question_answer_outlined, 'Satıcı Soruları (${product.reviewCount})', onTap: () {}),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BusinessDetailPage(business: business)));
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('MAĞAZAYA GİT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(IconData icon, String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: Colors.grey[700]))),
          Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
        ],
      ),
    );
  }
}
