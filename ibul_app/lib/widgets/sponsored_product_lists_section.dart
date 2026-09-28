import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../ads/enums/ad_enums.dart';
import '../ads/services/home_sponsored_content_service.dart';
import '../core/app_perf_logger.dart';
import '../core/app_state.dart';
import '../core/constants.dart';
import '../core/home_section_trace.dart';
import '../core/home_data_diagnostics.dart';
import '../core/section_load_state.dart';
import '../models/product_list_model.dart';
import 'optimized_image.dart';
import 'premium_interactions.dart';
import 'skeleton_loading.dart';
import '../screens/list_detail_page.dart';

class SponsoredProductListsSection extends StatefulWidget {
  const SponsoredProductListsSection({
    required this.title,
    required this.placement,
    this.subtitle,
    this.categoryFilter,
    this.maxItems = 6,
    this.loadTimeout = const Duration(seconds: 10),
    this.suppressSkeleton = false,
    this.maxSkeletonDuration = const Duration(seconds: 4),
    super.key,
  });

  final String title;
  final String? subtitle;
  final AdPlacement placement;
  final String? categoryFilter;
  final int maxItems;
  final Duration loadTimeout;
  final bool suppressSkeleton;
  final Duration maxSkeletonDuration;

  @override
  State<SponsoredProductListsSection> createState() =>
      _SponsoredProductListsSectionState();
}

class _SponsoredProductListsSectionState
    extends State<SponsoredProductListsSection> {
  final HomeSponsoredContentService _sponsoredContentService =
      HomeSponsoredContentService();
  final AppState _appState = AppState();

  SectionLoadState _loadState = SectionLoadState.beginLoading();
  List<ProductList> _lists = const [];
  bool _skeletonTimedOut = false;
  Timer? _skeletonTimer;

  @override
  void initState() {
    super.initState();
    HomeSectionDiagnostics.loading(section: 'sponsored_lists');
    _skeletonTimer = Timer(widget.maxSkeletonDuration, () {
      if (!mounted || _skeletonTimedOut || !_loadState.isLoading) return;
      setState(() => _skeletonTimedOut = true);
      HomeSkeletonDiagnostics.timeout(source: 'sponsored_lists');
      HomeSectionDiagnostics.hidden(
        section: 'sponsored_lists',
        reason: 'timeout',
      );
    });
    unawaited(_loadLists());
  }

  @override
  void dispose() {
    _skeletonTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SponsoredProductListsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement ||
        oldWidget.categoryFilter != widget.categoryFilter ||
        oldWidget.maxItems != widget.maxItems) {
      setState(() {
        _loadState = SectionLoadState.beginLoading();
        _lists = const [];
      });
      unawaited(_loadLists());
    }
  }

  Future<void> _loadLists() async {
    final started = DateTime.now().millisecondsSinceEpoch;
    var source = 'network';
    var state = SectionLoadPhase.loaded;
    String? error;

    try {
      final lists = await _sponsoredContentService
          .fetchActiveSponsoredHomeLists(
            placement: widget.placement,
            limit: widget.maxItems,
            categoryFilter: widget.categoryFilter,
          )
          .timeout(widget.loadTimeout);

      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loadState = lists.isEmpty
            ? const SectionLoadState(phase: SectionLoadPhase.empty)
            : const SectionLoadState(phase: SectionLoadPhase.loaded);
      });
      state = lists.isEmpty ? SectionLoadPhase.empty : SectionLoadPhase.loaded;
      if (lists.isEmpty) {
        HomeAdsDiagnostics.sponsoredHidden(reason: 'empty');
        HomeSectionDiagnostics.hidden(
          section: 'sponsored_lists',
          reason: widget.suppressSkeleton
              ? 'empty_after_products_loaded'
              : 'empty',
        );
      } else {
        HomeAdsDiagnostics.sponsoredRaw(count: lists.length);
        HomeAdsDiagnostics.sponsoredRendered(
          count: lists.length,
          widget: 'SponsoredProductListsSection',
        );
        HomeSectionDiagnostics.render(
          section: 'sponsored_lists',
          itemCount: lists.length,
        );
      }
    } on TimeoutException {
      source = 'timeout';
      state = SectionLoadPhase.empty;
      error = 'timeout';
      if (!mounted) return;
      setState(() {
        _lists = const [];
        _loadState = const SectionLoadState(phase: SectionLoadPhase.empty);
      });
    } catch (e) {
      source = 'network';
      state = SectionLoadPhase.error;
      error = e.toString();
      if (!mounted) return;
      setState(() {
        _lists = const [];
        _loadState = SectionLoadState(
          phase: SectionLoadPhase.error,
          errorMessage: error,
          startedAt: DateTime.now(),
        );
      });
    }

    if (!mounted) return;
    final resolved = SectionLoadState(
      phase: state,
      errorMessage: error,
      startedAt: _loadState.startedAt,
    );
    AppPerfLogger.logHomeSection(
      sectionName: 'sponsoredLists',
      source: source,
      state: resolved.logStateLabel,
      itemCount: _lists.length,
      ms: DateTime.now().millisecondsSinceEpoch - started,
      error: error,
    );
    notifyHomeSectionLoadOutcome(
      sectionName: 'sponsoredLists',
      source: source,
      state: resolved.logStateLabel,
      elapsedMs: DateTime.now().millisecondsSinceEpoch - started,
      itemCount: _lists.length,
      error: error,
      timeoutMs: widget.loadTimeout.inMilliseconds,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadState.isLoading) {
      if (widget.suppressSkeleton || _skeletonTimedOut) {
        HomeSkeletonDiagnostics.hide(
          source: 'sponsored_lists',
          reason: widget.suppressSkeleton ? 'products_loaded' : 'timeout',
        );
        return const SizedBox.shrink();
      }
      HomeSkeletonDiagnostics.show(
        source: 'sponsored_lists',
        reason: 'fetch_pending',
      );
      return const _SponsoredListsSectionSkeleton();
    }

    if (_loadState.shouldShowError) {
      HomeSkeletonDiagnostics.hide(
        source: 'sponsored_lists',
        reason: 'error',
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sponsorlu listeler şu an yüklenemedi.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loadState = SectionLoadState.beginLoading();
                    _skeletonTimedOut = false;
                  });
                  unawaited(_loadLists());
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_lists.isEmpty) {
      HomeSkeletonDiagnostics.hide(
        source: 'sponsored_lists',
        reason: 'ads_empty',
      );
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if ((widget.subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Sponsorlu',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 252,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _lists.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) => SizedBox(
                width: 250,
                child: _SponsoredListCard(
                  list: _lists[index],
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (routeContext) => ListDetailPage(
                          listData: _appState.productListToMap(
                            _lists[index],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SponsoredListCard extends StatelessWidget {
  const _SponsoredListCard({required this.list, required this.onTap});

  final ProductList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = (list.iconUrl ?? '').trim();
    final previewProducts = list.products.take(3).toList(growable: false);

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: PremiumPressable(
          hoverLift: 2,
          hoverScale: 1.008,
          pressedScale: 0.982,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RepaintBoundary(
                    child: Container(
                      height: 120,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        color: Color(0xFFF8FAFC),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: cover.isNotEmpty
                          ? OptimizedImage(
                              imageUrlOrPath: cover,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              cacheWidth: 640,
                              cacheHeight: 320,
                              errorWidget: _buildCoverFallback(),
                            )
                          : _buildCoverFallback(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (list.description ?? '').trim().isEmpty
                                ? '${list.productCount} ürün'
                                : list.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                          const Spacer(),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(
                                icon: Icons.inventory_2_outlined,
                                label: '${list.productCount} ürün',
                              ),
                              if ((list.category ?? '').trim().isNotEmpty)
                                _MetaChip(
                                  icon: Icons.category_outlined,
                                  label: list.category!,
                                ),
                            ],
                          ),
                          if (previewProducts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              previewProducts
                                  .map((product) => product.name)
                                  .join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: const [
                              Text(
                                'Listeyi aç',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFallback() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      child: const Center(
        child: Icon(
          Icons.collections_bookmark_outlined,
          color: Color(0xFF64748B),
          size: 36,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF475569)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}

class _SponsoredListsSectionSkeleton extends StatelessWidget {
  const _SponsoredListsSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: const [
              Expanded(
                child: SkeletonLoading(width: 160, height: 20, borderRadius: 6),
              ),
              SizedBox(width: 12),
              SkeletonLoading(width: 72, height: 24, borderRadius: 999),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 252,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 3,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) => const SkeletonLoading(
              width: 220,
              height: 252,
              borderRadius: 16,
            ),
          ),
        ),
      ],
    );
  }
}
