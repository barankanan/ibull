import 'package:flutter/material.dart';

import '../../../core/web_perf_trace.dart';
import '../../../models/db_product.dart';
import '../../../widgets/skeleton_loading.dart';
import '../home_section_error.dart';
import '../sections/home_section_full_rail.dart' deferred as full_rail_section;

/// Lazy full product rail — must call [full_rail_section.loadLibrary] before factory.
class DeferredHomeFullRailSection extends StatefulWidget {
  const DeferredHomeFullRailSection({
    super.key,
    this.delay = Duration.zero,
    required this.title,
    required this.products,
    this.isLoading = false,
    this.maxItems = 12,
    this.errorMessage,
    this.onRetry,
    this.showViewAll = true,
  });

  final Duration delay;
  final String title;
  final List<DBProduct> products;
  final bool isLoading;
  final int maxItems;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final bool showViewAll;

  @override
  State<DeferredHomeFullRailSection> createState() =>
      _DeferredHomeFullRailSectionState();
}

class _DeferredHomeFullRailSectionState extends State<DeferredHomeFullRailSection> {
  Future<void>? _loadFuture;
  bool _scheduled = false;
  bool _renderStartedLogged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleLoad());
  }

  Future<void> _scheduleLoad() async {
    if (_scheduled) return;
    _scheduled = true;
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (!mounted) return;
    setState(() => _loadFuture = _loadLibrary());
  }

  Future<void> _loadLibrary() async {
    WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailLoadStarted);
    try {
      await full_rail_section.loadLibrary();
      WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailLoadCompleted);
    } catch (error) {
      WebPerfTrace.instance.mark(
        WebPerfTraceStage.fullRailLoadError,
        error: error.toString(),
      );
      rethrow;
    }
  }

  void _retry() {
    setState(() => _loadFuture = _loadLibrary());
  }

  void _logRenderStartedOnce() {
    if (_renderStartedLogged) return;
    _renderStartedLogged = true;
    WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailRenderStarted);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WebPerfTrace.instance.mark(WebPerfTraceStage.fullRailRenderCompleted);
    });
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SkeletonLoading(
        width: double.infinity,
        height: 280,
        borderRadius: 12,
      ),
    );

    final future = _loadFuture;
    if (future == null) return placeholder;

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return placeholder;
        }
        if (snapshot.hasError) {
          return HomeSectionError(
            message: 'Ürün bölümü şu an yüklenemedi.',
            onRetry: _retry,
          );
        }
        _logRenderStartedOnce();
        return full_rail_section.buildHomeFullProductRailSection(
          title: widget.title,
          products: widget.products,
          isLoading: widget.isLoading,
          maxItems: widget.maxItems,
          errorMessage: widget.errorMessage,
          onRetry: widget.onRetry,
          showViewAll: widget.showViewAll,
        );
      },
    );
  }
}
