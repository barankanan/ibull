import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_service.dart';
import '../../services/supabase_service.dart';
import '../../models/db_product.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../dynamic_brand_section.dart';

class ProductCategoryCards extends StatefulWidget {
  const ProductCategoryCards({super.key});

  @override
  State<ProductCategoryCards> createState() => _ProductCategoryCardsState();
}

class _ProductCategoryCardsState extends State<ProductCategoryCards> {
  List<Map<String, dynamic>> _cards = [];
  List<DBProduct> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _normalizeCategory(String s) => s.trim().toLowerCase();

  Future<void> _load() async {
    final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
    final productCategory = viewModel.initialProduct.category ?? '';

    if (productCategory.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final allLayouts = await AdminService().getHairCareLayouts();
      final allProducts = await SupabaseService.instance.getAllProducts();

      final filtered = allLayouts.where((layout) {
        final target = layout['target_category'] as String?;
        return _normalizeCategory(target ?? '') == _normalizeCategory(productCategory);
      }).toList()
      ..sort((a, b) {
        final slotA = int.tryParse(a['slot'].toString()) ?? 999;
        final slotB = int.tryParse(b['slot'].toString()) ?? 999;
        return slotA.compareTo(slotB);
      });

      if (mounted) {
        setState(() {
          _cards = filtered;
          _allProducts = allProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    if (_cards.isEmpty) return const SizedBox.shrink();
    return Column(
      children: _cards
          .map(
            (cardData) => Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: DynamicBrandSection(
                layout: cardData,
                allProducts: _allProducts,
              ),
            ),
          )
          .toList(),
    );
  }
}
