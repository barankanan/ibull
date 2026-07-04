import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/web_perf_trace.dart';
import '../../models/db_product.dart';
import '../../models/home_product_preview.dart';
import '../../models/product_model.dart';
import '../../widgets/home_product_preview_card.dart';
import '../../widgets/skeleton_loading.dart';
import '../home_lazy_routes.dart';

/// First-paint product rail — preview cards only, batch-rendered.
class HomeProductPreviewSection extends StatefulWidget {
  const HomeProductPreviewSection({
    super.key,
    required this.products,
    required this.isLoading,
    this.title = 'Sizin İçin Seçtiklerimiz',
    this.initialBatchSize = 8,
    this.onRetry,
    this.errorMessage,
  });

  final List<DBProduct> products;
  final bool isLoading;
  final String title;
  final int initialBatchSize;
  final VoidCallback? onRetry;
  final String? errorMessage;

  @override
  State<HomeProductPreviewSection> createState() =>
      _HomeProductPreviewSectionState();
}

class _HomeProductPreviewSectionState extends State<HomeProductPreviewSection> {
  int _visibleCount = 0;
  bool _secondBatchScheduled = false;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.initialBatchSize.clamp(0, widget.products.length);
    _scheduleSecondBatch();
  }

  @override
  void didUpdateWidget(covariant HomeProductPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.products.length != oldWidget.products.length) {
      final next = widget.initialBatchSize.clamp(0, widget.products.length);
      if (next > _visibleCount) {
        _visibleCount = next;
      }
      _scheduleSecondBatch();
    }
  }

  void _scheduleSecondBatch() {
    if (_secondBatchScheduled || widget.products.isEmpty) return;
    _secondBatchScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 32), () {
        if (!mounted) return;
        final full = widget.products.length;
        if (_visibleCount >= full) return;
        setState(() => _visibleCount = full);
        WebPerfTrace.instance.mark(WebPerfTraceStage.productGridAllVisibleRendered);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.errorMessage != null && widget.products.isEmpty) {
      return _ErrorStrip(message: widget.errorMessage!, onRetry: widget.onRetry);
    }

    if (widget.isLoading && widget.products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: SkeletonLoading(width: double.infinity, height: 280, borderRadius: 12),
      );
    }

    if (widget.products.isEmpty) {
      return const SizedBox.shrink();
    }

    final count = _visibleCount.clamp(0, widget.products.length);
    WebPerfTrace.instance.markProductGridFirstBatch(count: count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 280,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              cacheExtent: 280,
              itemCount: count,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final db = widget.products[index];
                final preview = HomeProductPreview.fromDbProduct(db);
                return SizedBox(
                  width: 168,
                  child: HomeProductPreviewCard(
                    preview: preview,
                    onTap: () => unawaited(
                      HomeLazyRoutes.openProductDetail(
                        context,
                        Product.fromDBProduct(db),
                      ),
                    ),
                    onFirstPaint: index == 0
                        ? () => WebPerfTrace.instance
                            .mark(WebPerfTraceStage.firstPreviewCardRendered)
                        : null,
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

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      ),
    );
  }
}
