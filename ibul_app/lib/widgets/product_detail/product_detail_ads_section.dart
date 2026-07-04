import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ads/models/home_card_template.dart';
import '../../ads/services/product_detail_ads_service.dart';
import '../../core/lazy_section_loader.dart';
import '../../models/db_product.dart';
import '../../models/product_model.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../home_category_card_section.dart';

/// Category-based sponsored block below product detail (replaces legacy layouts).
class ProductDetailAdsSection extends StatefulWidget {
  const ProductDetailAdsSection({super.key});

  @override
  State<ProductDetailAdsSection> createState() => _ProductDetailAdsSectionState();
}

class _ProductDetailAdsSectionState extends State<ProductDetailAdsSection> {
  final ProductDetailAdsService _adsService = ProductDetailAdsService();
  HomeCategoryCardGroup? _group;

  Future<void> _load() async {
    final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
    final product = viewModel.initialProduct;
    final group = await _adsService.loadCategoryAds(
      mainCategory: product.category,
      subCategory: product.subCategory,
    );
    if (!mounted) return;
    setState(() => _group = group);
  }

  Product _convertToProduct(DBProduct dbProduct) {
    return Product(
      name: dbProduct.name,
      price: dbProduct.price,
      oldPrice: dbProduct.oldPrice,
      images: dbProduct.imageUrl.isNotEmpty ? [dbProduct.imageUrl] : const [],
      category: dbProduct.category,
      brand: dbProduct.brand,
      description: dbProduct.description,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: const [],
      subCategory: dbProduct.subCategory,
      store: dbProduct.store,
      sellerId: dbProduct.sellerId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LazySectionLoader(
      sectionName: 'productDetailAds',
      skeleton: const SizedBox.shrink(),
      loader: _load,
      builder: (_) {
        final group = _group;
        if (group == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Öne Çıkanlar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Sponsorlu',
                style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6)),
              ),
            ),
            HomeCategoryCardSection(
              group: group,
              convertToProduct: _convertToProduct,
              hideCategoryTitle: true,
            ),
          ],
        );
      },
    );
  }
}
