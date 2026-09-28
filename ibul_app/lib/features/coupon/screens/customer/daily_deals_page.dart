import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../../../models/product_model.dart';
import '../../../../screens/home_lazy_routes.dart';
import '../../../../widgets/web_header.dart';
import '../../../../widgets/web_sticky_footer_scroll_view.dart';
import '../../data/coupon_repository.dart';
import '../../domain/coupon_models.dart';

class DailyDealsPage extends StatefulWidget {
  const DailyDealsPage({super.key});

  @override
  State<DailyDealsPage> createState() => _DailyDealsPageState();
}

class _DailyDealsPageState extends State<DailyDealsPage> {
  final _repo = CouponRepository();
  bool _loading = true;
  String? _error;
  List<DailyDealProduct> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _repo.listDailyDeals(limit: 40);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Fırsatlar yüklenemedi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                OutlinedButton(onPressed: _load, child: const Text('Tekrar dene')),
              ],
            ),
          )
        : _items.isEmpty
        ? const Center(child: Text('Bugün aktif fırsat bulunmuyor.'))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isWeb ? 4 : 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return InkWell(
                onTap: () {
                  HomeLazyRoutes.openProductDetail(
                    context,
                    Product(
                      productId: item.id,
                      name: item.name,
                      brand: item.brand ?? '',
                      price: '${item.discountPrice.toStringAsFixed(0)} TL',
                      oldPrice: '${item.price.toStringAsFixed(0)} TL',
                      rating: 0,
                      reviewCount: 0,
                      tags: const ['indirim'],
                      images: [
                        if ((item.imageUrl ?? '').isNotEmpty) item.imageUrl!,
                      ],
                      store: item.storeName,
                      sellerId: item.sellerId,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEDE9FE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: item.imageUrl == null || item.imageUrl!.isEmpty
                            ? const Center(child: Icon(Icons.image_outlined))
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image_outlined),
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if ((item.storeName ?? '').isNotEmpty)
                        Text(
                          item.storeName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      Text(
                        '${item.price.toStringAsFixed(0)} TL',
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Color(0xFF9CA3AF),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${item.discountPrice.toStringAsFixed(0)} TL',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    if (!isWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Günün Fırsatı')),
        body: body,
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: WebStickyFooterScrollView(
              child: SizedBox(height: 900, child: body),
            ),
          ),
        ],
      ),
    );
  }
}
