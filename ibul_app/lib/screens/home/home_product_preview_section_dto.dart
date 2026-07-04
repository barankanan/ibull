import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/perf_debug_config.dart';
import '../../models/home_product_preview.dart';
import '../../widgets/home_product_preview_card.dart';
import '../../widgets/skeleton_loading.dart';
import '../../core/web_perf_trace.dart';
import '../home_lazy_routes.dart';
import '../../models/product_model.dart';
import '../../models/db_product.dart';

/// First-paint preview rail using [HomeProductPreview] DTOs only.
class HomeProductPreviewSectionDto extends StatefulWidget {
  const HomeProductPreviewSectionDto({
    super.key,
    required this.previews,
    required this.isLoading,
    this.title = 'Sizin İçin Seçtiklerimiz',
    this.initialBatchSize = 8,
    this.onRetry,
    this.errorMessage,
    this.errorDetail,
    this.rawCount,
    this.filteredCount,
    this.querySummary,
  });

  final List<HomeProductPreview> previews;
  final bool isLoading;
  final String title;
  final int initialBatchSize;
  final VoidCallback? onRetry;
  final String? errorMessage;
  final String? errorDetail;
  final int? rawCount;
  final int? filteredCount;
  final String? querySummary;

  @override
  State<HomeProductPreviewSectionDto> createState() =>
      _HomeProductPreviewSectionDtoState();
}

class _HomeProductPreviewSectionDtoState
    extends State<HomeProductPreviewSectionDto> {
  int _visible = 0;
  bool _batch2 = false;

  @override
  void initState() {
    super.initState();
    _visible = widget.initialBatchSize.clamp(0, widget.previews.length);
    _scheduleBatch2();
  }

  @override
  void didUpdateWidget(covariant HomeProductPreviewSectionDto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previews.length != oldWidget.previews.length) {
      _visible = widget.initialBatchSize.clamp(0, widget.previews.length);
      _scheduleBatch2();
    }
  }

  void _scheduleBatch2() {
    if (_batch2) return;
    _batch2 = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 48), () {
        if (!mounted) return;
        setState(() => _visible = widget.previews.length);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorMessage != null && widget.previews.isEmpty) {
      final showDebug = perfDebugPanelEnabled;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade400, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (widget.onRetry != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('Tekrar dene'),
                    ),
                ],
              ),
              if (showDebug) ...[
                const SizedBox(height: 10),
                if (widget.querySummary != null)
                  Text('query: ${widget.querySummary}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                Text(
                  'table: products · raw=${widget.rawCount ?? 0} · filtered=${widget.filteredCount ?? 0}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (widget.errorDetail != null)
                  Text(
                    widget.errorDetail!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
              ],
            ],
          ),
        ),
      );
    }
    if (widget.isLoading && widget.previews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SkeletonLoading(width: double.infinity, height: 260, borderRadius: 12),
      );
    }
    if (widget.previews.isEmpty) {
      final message = widget.errorMessage ?? 'Henüz ürün bulunmuyor.';
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.errorMessage != null
                  ? Colors.red.shade100
                  : Colors.grey.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    widget.errorMessage != null
                        ? Icons.error_outline
                        : Icons.inventory_2_outlined,
                    color: widget.errorMessage != null
                        ? Colors.red.shade400
                        : Colors.grey.shade500,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (widget.onRetry != null && widget.errorMessage != null)
                    TextButton(
                      onPressed: widget.onRetry,
                      child: const Text('Tekrar dene'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final count = _visible.clamp(0, widget.previews.length);
    WebPerfTrace.instance.markProductGridFirstBatch(count: count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: HomeProductPreviewCard.defaultHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              cacheExtent: 420,
              itemCount: count,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final preview = widget.previews[index];
                return HomeProductPreviewCard(
                  preview: preview,
                  onTap: () => _openPreview(context, preview),
                  onAddTap: () => _openPreview(context, preview),
                    onFirstPaint: index == 0
                        ? () => WebPerfTrace.instance
                            .mark(WebPerfTraceStage.firstPreviewCardRendered)
                        : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openPreview(BuildContext context, HomeProductPreview preview) {
    final stub = DBProduct(
      id: preview.id,
      name: preview.name,
      brand: preview.brand ?? '',
      store: preview.storeName,
      price: preview.price.toString(),
      oldPrice: preview.discountPrice?.toString(),
      imageUrl: preview.imageUrl,
      category: '',
      rating: 0,
      reviewCount: 0,
      tags: preview.hasDiscount ? '["İndirimde"]' : '[]',
    );
    unawaited(
      HomeLazyRoutes.openProductDetail(
        context,
        Product.fromDBProduct(stub),
      ),
    );
  }
}
