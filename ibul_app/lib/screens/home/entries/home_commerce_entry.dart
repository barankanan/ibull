import 'package:flutter/material.dart';

import '../../../models/db_product.dart';
import '../../../services/supabase_service.dart';
import '../deferred/deferred_home_full_rail_section.dart';

/// Commerce rails. Fetches only after this library is loaded.
class HomeCommerceBlock extends StatefulWidget {
  const HomeCommerceBlock({super.key});

  @override
  State<HomeCommerceBlock> createState() => _HomeCommerceBlockState();
}

class _HomeCommerceBlockState extends State<HomeCommerceBlock> {
  List<DBProduct> _products = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final report = await SupabaseService.instance
          .fetchInitialHomeProductsReport()
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() {
        _products = report.products.take(24).toList(growable: false);
        _loading = false;
        _error = _products.isEmpty ? 'Görünür ürün bulunamadı' : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Ürünler yüklenemedi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DeferredHomeFullRailSection(
      title: 'Popüler Ürünler',
      products: _products,
      isLoading: _loading,
      maxItems: 12,
      grouped: true,
      errorMessage: _error,
      onRetry: _load,
    );
  }
}
