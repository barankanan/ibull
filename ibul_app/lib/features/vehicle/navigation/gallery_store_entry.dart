import 'package:flutter/material.dart';

import '../../../screens/business_detail_page.dart';
import '../../seller/domain/store_vertical.dart';

/// Opens the shared public storefront shell for a gallery store.
/// Design lives on [BusinessDetailPage]; this only stamps gallery identity.
class PublicGalleryStoreView extends StatelessWidget {
  const PublicGalleryStoreView({super.key, required this.business});

  final Map<String, dynamic> business;

  static bool matches(Map<String, dynamic> business) {
    return isGalleryStoreRecord(business);
  }

  static Map<String, dynamic> businessRecord({
    required String sellerId,
    String? name,
    Map<String, dynamic>? extras,
  }) {
    final resolvedName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : extras?['name']?.toString().trim();
    return {
      ...?extras,
      'id': sellerId,
      'seller_id': sellerId,
      'name': (resolvedName != null && resolvedName.isNotEmpty)
          ? resolvedName
          : 'Galeri',
      'category':
          extras?['store_category'] ?? extras?['category'] ?? 'Galerici',
      'store_category':
          extras?['store_category'] ?? extras?['category'] ?? 'Galerici',
    };
  }

  @override
  Widget build(BuildContext context) {
    return BusinessDetailPage(
      business: businessRecord(
        sellerId:
            business['seller_id']?.toString() ??
            business['id']?.toString() ??
            '',
        name: business['name']?.toString(),
        extras: business,
      ),
    );
  }
}
