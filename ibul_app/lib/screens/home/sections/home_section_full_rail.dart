import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/home_ui_diagnostics.dart';
import '../../../core/web_perf_trace.dart';
import '../../../models/db_product.dart';
import '../../../models/product_model.dart';
import '../../../widgets/product_card.dart' deferred as product_card;
import '../../../widgets/skeleton_loading.dart';

/// Legacy-style horizontal product rail with real [ProductCard].
class HomeFullProductRailSection extends StatefulWidget {
  const HomeFullProductRailSection({
    super.key,
    required this.title,
    required this.products,
    this.isLoading = false,
    this.maxItems = 12,
    this.errorMessage,
    this.onRetry,
    this.showViewAll = true,
  });

  final String title;
  final List<DBProduct> products;
  final bool isLoading;
  final int maxItems;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showViewAll;

  @override
  State<HomeFullProductRailSection> createState() =>
      _HomeFullProductRailSectionState();
}

class _HomeFullProductRailSectionState extends State<HomeFullProductRailSection> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await product_card.loadLibrary();
    if (!mounted) return;
    setState(() => _ready = true);
    WebPerfTrace.instance.mark(WebPerfTraceStage.fullGridLoaded);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || (widget.isLoading && widget.products.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SkeletonLoading(
          width: double.infinity,
          height: 312,
          borderRadius: 12,
        ),
      );
    }

    if (widget.errorMessage != null && widget.products.isEmpty) {
      return _HomeProductEmptyState(
        message: widget.errorMessage!,
        onRetry: widget.onRetry,
      );
    }

    if (widget.products.isEmpty) {
      HomeUiDiagnostics.noProductsEmptyState();
      return _HomeProductEmptyState(
        message: 'Henüz ürün bulunmuyor.',
        onRetry: widget.onRetry,
      );
    }

    final items = widget.products.take(widget.maxItems).toList();
    HomeUiDiagnostics.realProductCard(count: items.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              if (widget.showViewAll)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text(
                    'Tümünü Gör',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 312,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              cacheExtent: 420,
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final db = items[index];
                return SizedBox(
                  width: 198,
                  child: product_card.ProductCard(
                    product: Product.fromDBProduct(db),
                    margin: EdgeInsets.zero,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeProductEmptyState extends StatelessWidget {
  const _HomeProductEmptyState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ],
        ),
      ),
    );
  }
}

Widget buildHomeFullProductRailSection({
  required String title,
  required List<DBProduct> products,
  bool isLoading = false,
  int maxItems = 12,
  String? errorMessage,
  VoidCallback? onRetry,
  bool showViewAll = true,
}) {
  return HomeFullProductRailSection(
    title: title,
    products: products,
    isLoading: isLoading,
    maxItems: maxItems,
    errorMessage: errorMessage,
    onRetry: onRetry,
    showViewAll: showViewAll,
  );
}
