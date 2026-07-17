import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:provider/provider.dart';

import '../ads/models/home_card_template.dart';
import '../ads/services/home_feature_ad_service.dart';
import '../core/app_motion.dart';
import '../core/app_state.dart';
import '../core/config/runtime_config.dart';
import '../core/constants.dart';
import '../core/home_boot_diagnostics.dart';
import '../core/home_data_diagnostics.dart';
import '../core/home_for_you_helper.dart';
import '../core/home_snapshot_cache.dart';
import '../core/home_ui_diagnostics.dart';
import '../core/perf_debug_config.dart';
import '../core/product_load_trace.dart';
import '../core/qr_initial_params.dart';
import '../core/single_flight_guard.dart';
import '../core/web_boot_step_profiler.dart';
import '../core/web_perf_logger.dart';
import '../core/web_perf_trace.dart';
import '../core/mobile_app_download_prompt_controller.dart';
import '../models/db_product.dart';
import '../models/home_products_fetch_report.dart';
import '../models/product_model.dart';
import '../services/home_hero_banners_fetch.dart';
import '../services/supabase_service.dart';
import '../widgets/home_boot_timeout_banner.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/custom_header.dart';
import '../widgets/web_header.dart';
import '../widgets/web_perf_debug_panel.dart';
import '../widgets/web_sticky_footer_scroll_view.dart';
import '../widgets/home_category_card_section.dart';
import 'home_deferred_tab.dart';
import 'home_lazy_routes.dart';
import 'home/deferred/deferred_home_full_rail_section.dart';
import 'home/deferred/deferred_home_sponsored_section.dart';
import 'home/sections/ibul_delivery_address_section.dart';
import 'home/sections/ibul_hero_campaign_row.dart';
import 'home/sections/ibul_opportunity_shortcuts_section.dart';
import 'home/sections/ibul_trust_bar_section.dart';

/// Lean home entry — gerçek İBUL tasarımı, ağır modüller deferred.
class HomeScreenCore extends StatefulWidget {
  const HomeScreenCore({super.key, this.initialIndex = 0, this.initialCategory});

  final int initialIndex;
  final String? initialCategory;

  @override
  State<HomeScreenCore> createState() => _HomeScreenCoreState();
}

enum _HomeBootTimeoutPhase { none, slowWarning, fallbackApplied }

class _HomeScreenCoreState extends State<HomeScreenCore> {
  static const int kPreviewBatchSize = 8;
  static const Duration kCategoryRevealDelay = Duration(milliseconds: 300);
  static const Duration kProductsRevealDelay = Duration(milliseconds: 500);
  static const Duration kHeroDelay = Duration(milliseconds: 800);
  static const Duration kSideDelay = Duration(milliseconds: 800);
  static const Duration kSponsoredDelay = Duration(milliseconds: 1000);
  static const Duration kDeferredSkeletonMax = Duration(seconds: 4);
  static const Duration kSlowLoadBannerDelay = Duration(seconds: 5);
  static const Duration kFallbackLoadDelay = Duration(seconds: 8);

  late final ValueNotifier<int> _selectedIndexNotifier;
  late String _selectedCategory;
  final ProductLoadTraceNotifier _productLoadTrace = ProductLoadTraceNotifier();
  final SingleFlightGuard _productFetchGuard = SingleFlightGuard();
  final SingleFlightGuard _heroFetchGuard = SingleFlightGuard();
  final SingleFlightGuard _featureAdsFetchGuard = SingleFlightGuard();
  final HomeFeatureAdService _homeFeatureAdService = HomeFeatureAdService();

  List<DBProduct> _products = [];
  List<String> _heroBannerUrls = [];
  List<HomeCategoryCardGroup> _homeFeatureAdGroups = [];
  bool _isLoadingProducts = true;
  bool _isLoadingHero = true;
  bool _isLoadingFeatureAds = true;
  String? _productError;
  String? _productErrorDetail;
  bool _loggedFirstFrame = false;
  bool _stagedRevealScheduled = false;
  bool _sectionsRevealed = true;
  _HomeBootTimeoutPhase _timeoutPhase = _HomeBootTimeoutPhase.none;
  Timer? _watchdogTimer;
  bool _didScheduleInitialFetch = false;
  int _bootStartedMs = 0;

  @override
  void initState() {
    super.initState();
    _bootStartedMs = DateTime.now().millisecondsSinceEpoch;
    HomeBootDiagnostics.markInitState();
    WebPerfTrace.instance.mark(WebPerfTraceStage.homeCoreChunkLoaded);
    _selectedIndexNotifier = ValueNotifier(widget.initialIndex);
    _selectedCategory = widget.initialCategory ?? 'Ana Sayfa';
    HomeUiDiagnostics.demoDataDisabled();
    _hydrateFromCacheSync();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeBootDiagnostics.logPostFrameScheduled();
      if (!_loggedFirstFrame) {
        _loggedFirstFrame = true;
        WebPerfLogger.logFirstFrame();
        WebBootStepProfiler.done('home_first_frame');
      }
      _scheduleStagedReveal();
      _startWatchdog();
      if (!AppRuntimeConfig.safeBootMode && !_didScheduleInitialFetch) {
        _didScheduleInitialFetch = true;
        HomeBootDiagnostics.logStageScheduled('products');
        unawaited(_fetchHomeProducts());
        unawaited(_fetchHeroBanners());
        unawaited(_fetchHomeFeatureAds());
      }
      if (QrInitialParams.isQrPath) {
        unawaited(_openQrDeferred());
      }
      
      // Show mobile app download prompt if applicable (delay slightly to let home load)
      final screenWidth = MediaQuery.sizeOf(context).width;
      debugPrint('[MobileAppPrompt] schedule source=HomeScreenCore width=$screenWidth');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          MobileAppDownloadPromptController.checkAndShowPrompt(context);
        }
      });
    });
  }

  void _hydrateFromCacheSync() {
    final heroUrls = HomeHeroBannersFetch.readCachedUrlsSync();
    if (heroUrls.isNotEmpty) {
      _heroBannerUrls = heroUrls;
      _isLoadingHero = false;
      HomeUiDiagnostics.realBanners(count: heroUrls.length);
    }

    final cachedProducts = HomeSnapshotCache.instance.readPopularProducts();
    if (cachedProducts != null && cachedProducts.isNotEmpty) {
      _products = cachedProducts.take(kPreviewBatchSize).toList(growable: false);
      _isLoadingProducts = false;
      _sectionsRevealed = true;
      HomeUiDiagnostics.cacheProducts(count: _products.length);
    }
  }

  void _ensureSectionsVisible({required String reason}) {
    if (_sectionsRevealed) return;
    HomeBootDiagnostics.logSetState('sections_revealed:$reason');
    setState(() => _sectionsRevealed = true);
  }

  void _scheduleStagedReveal() {
    if (_stagedRevealScheduled) return;
    _stagedRevealScheduled = true;
    HomeBootDiagnostics.logStageScheduled('categories');
    HomeBootDiagnostics.logStageScheduled('products');
    // Critical sections render immediately; delays only mark perf stages.
    _ensureSectionsVisible(reason: 'immediate');
    Future<void>.delayed(kCategoryRevealDelay, () {
      if (!mounted) return;
      HomeBootDiagnostics.logStageCompleted('categories');
    });
    Future<void>.delayed(kProductsRevealDelay, () {
      if (!mounted) return;
      _ensureSectionsVisible(reason: 'products_delay');
      HomeBootDiagnostics.logStageCompleted('products');
    });
    HomeBootDiagnostics.logStageScheduled('ads');
    HomeBootDiagnostics.logStageScheduled('forYou');
    // Failsafe — never leave body hidden if timers stall.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _ensureSectionsVisible(reason: 'failsafe_2s');
    });
  }

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      HomeBootDiagnostics.logWatchdogTick();
      if (!_isLoadingProducts && _products.isNotEmpty) {
        _watchdogTimer?.cancel();
        HomeBootDiagnostics.logStageCompleted('boot');
        return;
      }
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - _bootStartedMs;
      if (elapsedMs >= kFallbackLoadDelay.inMilliseconds &&
          _timeoutPhase != _HomeBootTimeoutPhase.fallbackApplied) {
        HomeBootDiagnostics.logBlockedStage('products');
        _applyWatchdogFallback();
        return;
      }
      if (elapsedMs >= kSlowLoadBannerDelay.inMilliseconds &&
          _timeoutPhase == _HomeBootTimeoutPhase.none) {
        HomeBootDiagnostics.logBlockedStage('products');
        setState(() => _timeoutPhase = _HomeBootTimeoutPhase.slowWarning);
      }
    });
  }

  bool get _productsReady => !_isLoadingProducts && _products.isNotEmpty;

  bool get _suppressBelowFoldSkeleton =>
      _productsReady || (!_isLoadingProducts && _productError != null);

  Future<void> _fetchHeroBanners() async {
    if (!_heroFetchGuard.tryBegin()) return;
    try {
      final result = await HomeHeroBannersFetch.fetch();
      if (!mounted) return;
      setState(() {
        _heroBannerUrls = result.imageUrls;
        _isLoadingHero = false;
      });
      if (result.imageUrls.isNotEmpty) {
        HomeAdsDiagnostics.heroRaw(count: result.rawCount);
        HomeAdsDiagnostics.heroActive(count: result.imageUrls.length);
        HomeAdsDiagnostics.heroRendered(count: result.imageUrls.length);
        HomeUiDiagnostics.realBanners(count: result.imageUrls.length);
      } else {
        final reason = result.error ?? 'empty';
        HomeAdsDiagnostics.heroHidden(reason: reason);
        HomeUiDiagnostics.noBannersHidden();
      }
    } finally {
      _heroFetchGuard.finish();
    }
  }

  Future<void> _fetchHomeFeatureAds() async {
    if (!_featureAdsFetchGuard.tryBegin()) return;
    HomeAdsDiagnostics.demoDisabled();
    HomeAdsDiagnostics.requestStart(source: 'web_home');
    try {
      final groups = await _homeFeatureAdService.loadHomePageGroups();
      if (!mounted) return;
      setState(() {
        _homeFeatureAdGroups = groups;
        _isLoadingFeatureAds = false;
      });
      HomeAdsDiagnostics.featureRaw(count: groups.length);
      if (groups.isEmpty) {
        HomeAdsDiagnostics.hidden(reason: 'empty');
        HomeSectionDiagnostics.hidden(
          section: 'home_feature_ads',
          reason: 'empty',
        );
      } else {
        final adCount = groups.fold<int>(
          0,
          (sum, group) =>
              sum +
              group.cards.fold<int>(
                0,
                (cardSum, card) => cardSum + card.ads.length,
              ),
        );
        HomeAdsDiagnostics.activeCount(count: adCount);
        HomeAdsDiagnostics.rendered(count: adCount, placement: 'web_home');
        HomeAdsDiagnostics.featureRendered(count: adCount);
        HomeSectionDiagnostics.render(section: 'home_feature_ads', itemCount: adCount);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingFeatureAds = false);
      HomeAdsDiagnostics.hidden(reason: 'error');
      HomeSectionDiagnostics.state(section: 'home_feature_ads', state: 'error');
    } finally {
      _featureAdsFetchGuard.finish();
    }
  }

  Future<void> _fetchHomeProducts() async {
    if (!_productFetchGuard.tryBegin()) return;
    try {
      _productLoadTrace.update(
        stage: ProductLoadTraceStage.fetchStarted,
        table: 'products',
        query: 'home initial products fetch',
      );
      HomeBootDiagnostics.logProductsRequestStart();
      HomeDataDiagnostics.requestStart(source: 'home_screen_core');
      WebPerfLogger.recordSupabaseInitialRequest();
      debugPrint('[WebPerf] home_data_start');
      final fetchStarted = DateTime.now().millisecondsSinceEpoch;
      final report = await SupabaseService.instance
          .fetchInitialHomeProductsReport()
          .timeout(const Duration(seconds: 5));
      final fetchMs = DateTime.now().millisecondsSinceEpoch - fetchStarted;
      debugPrint('[WebPerf] home_data_done ms=$fetchMs');
      final products = report.products.take(kPreviewBatchSize).toList(growable: false);
      HomeBootDiagnostics.logProductsRequestDone(
        count: products.length,
        ms: fetchMs,
      );
      WebPerfTrace.instance.mark(WebPerfTraceStage.previewProductsFetch);
      WebPerfTrace.instance.setProductCounts(
        raw: report.rawCount,
        filtered: report.filteredCount,
        render: products.length,
      );
      if (!mounted) return;
      HomeBootDiagnostics.logSetState('products_loaded');
      setState(() {
        _products = products;
        _isLoadingProducts = false;
        _productError = products.isEmpty
            ? (report.error != null
                ? 'Ürünler yüklenemedi'
                : report.outcome == HomeProductsFetchOutcome.filterEmpty
                    ? 'Görünür ürün bulunamadı'
                    : null)
            : null;
        _productErrorDetail = report.error?.toString();
        _timeoutPhase = _HomeBootTimeoutPhase.none;
        _sectionsRevealed = true;
      });
      if (products.isNotEmpty) {
        HomeDataDiagnostics.requestSuccess(
          count: products.length,
          source: 'home_screen_core',
          ms: fetchMs,
        );
        HomeSkeletonDiagnostics.hide(
          source: 'home_products',
          reason: 'products_loaded',
        );
        HomeSectionDiagnostics.hidden(
          section: 'below_fold_skeleton',
          reason: 'products_loaded',
        );
        HomeUiDiagnostics.realProducts(count: products.length, source: 'network');
        unawaited(
          HomeSnapshotCache.instance.writePopularProductsPersisted(products),
        );
      } else {
        HomeUiDiagnostics.noProductsEmptyState();
      }
      _productLoadTrace.update(
        stage: products.isEmpty
            ? (report.error != null
                ? ProductLoadTraceStage.fetchError
                : ProductLoadTraceStage.fetchEmpty)
            : ProductLoadTraceStage.renderStarted,
        rawCount: report.rawCount,
        filteredCount: report.filteredCount,
        error: report.error?.toString(),
        detail: report.lastParseError ?? report.error?.toString(),
        query: report.querySummary,
      );
      WebPerfLogger.logCriticalProductsLoaded(count: products.length, ms: fetchMs);
      HomeBootDiagnostics.logStageCompleted('products');
    } catch (error, stack) {
      HomeBootDiagnostics.logSetState('products_error');
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _productError ??= 'Ürünler yüklenemedi';
        _productErrorDetail ??= error.toString();
        _sectionsRevealed = true;
      });
      HomeUiDiagnostics.noProductsEmptyState();
      _ensureSectionsVisible(reason: 'fetch_error');
      _productLoadTrace.update(
        stage: ProductLoadTraceStage.fetchError,
        table: 'products',
        error: error.toString(),
        detail: stack.toString(),
      );
    } finally {
      _productFetchGuard.finish();
    }
  }

  List<DBProduct> get _forYouProducts {
    return computeForYouFeaturedSliceWithFallback(
      _products,
      limit: kPreviewBatchSize,
    );
  }

  void _applyWatchdogFallback() {
    if (!mounted || _products.isNotEmpty) return;
    final snap = HomeSnapshotCache.instance.readMemory();
    if (snap != null && snap.products.isNotEmpty) {
      HomeBootDiagnostics.logSetState('watchdog_cache_fallback');
      setState(() {
        _products = snap.products.take(kPreviewBatchSize).toList(growable: false);
        _isLoadingProducts = false;
        _timeoutPhase = _HomeBootTimeoutPhase.fallbackApplied;
        _productError = null;
        _sectionsRevealed = true;
      });
      HomeUiDiagnostics.cacheProducts(count: _products.length);
      return;
    }
    HomeBootDiagnostics.logSetState('watchdog_empty_fallback');
    setState(() {
      _isLoadingProducts = false;
      _timeoutPhase = _HomeBootTimeoutPhase.fallbackApplied;
      _productError ??= 'Ürünler şu an yüklenemedi';
      _sectionsRevealed = true;
    });
    HomeUiDiagnostics.noProductsEmptyState();
  }

  Future<void> _openQrDeferred() async {
    final params = QrInitialParams.consume(source: 'HomeScreenCore');
    final sellerId = (params['seller'] ?? params['seller_id'] ?? '').trim();
    if (sellerId.isEmpty || !mounted) return;
    await HomeLazyRoutes.openBusinessDetail(
      context,
      business: {'name': sellerId, 'seller_id': sellerId},
      fromQr: true,
    );
  }

  void _onSearch(String query) {
    if (query.trim().length < 3) return;
    unawaited(HomeLazyRoutes.openSearch(context, query.trim()));
  }

  void _onItemTapped(int index) {
    if (_selectedIndexNotifier.value == index) return;
    _selectedIndexNotifier.value = index;
  }

  void _setSelectedCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
  }

  Widget _buildCartIcon({required bool isActive}) {
    return ValueListenableBuilder<int>(
      valueListenable: context.read<AppState>().cartCountNotifier,
      builder: (context, count, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined),
            if (count > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWeb = MediaQuery.sizeOf(context).width >= 1100;
    final visibleCards = _sectionsRevealed
        ? _products.length.clamp(0, kPreviewBatchSize)
        : 0;
    HomeBootDiagnostics.logBuild(
      productCardCount: visibleCards,
      imageScheduled: visibleCards,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(isWeb),
          ListenableBuilder(
            listenable: _productLoadTrace,
            builder: (context, _) => WebPerfDebugPanel(
              productSnapshot: _productLoadTrace.snapshot,
              visible: perfDebugPanelEnabled,
            ),
          ),
        ],
      ),
      floatingActionButton: isWeb
          ? FloatingActionButton(
              onPressed: () => unawaited(HomeLazyRoutes.openAiChat(context)),
              backgroundColor: AppColors.primary,
              tooltip: 'Yapay Zekaya Danış',
              child: const Icon(Icons.psychology, color: Colors.white),
            )
          : null,
      bottomNavigationBar: isWeb
          ? null
          : Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: ValueListenableBuilder<int>(
                valueListenable: _selectedIndexNotifier,
                builder: (context, index, _) => BottomNavigationBar(
                  currentIndex: index,
                  onTap: _onItemTapped,
                  selectedItemColor: AppColors.primary,
                  unselectedItemColor: Colors.black,
                  type: BottomNavigationBarType.fixed,
                  showUnselectedLabels: true,
                  selectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: l10n?.home ?? 'Ana Sayfa',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.segment),
                      label: l10n?.categories ?? 'Kategori',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.map_outlined),
                      activeIcon: Icon(Icons.map),
                      label: 'Harita',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildCartIcon(isActive: false),
                      activeIcon: _buildCartIcon(isActive: true),
                      label: l10n?.cart ?? 'Sepet',
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      activeIcon: const Icon(Icons.person),
                      label: l10n?.profile ?? 'Hesap',
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBody(bool isWeb) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedIndexNotifier,
      builder: (context, index, _) {
        return AppAnimatedIndexedStack(
          index: index,
          lazyMount: true,
          children: List<Widget>.generate(5, (tabIndex) {
            return _buildCurrentPageForIndex(tabIndex, isWeb);
          }),
        );
      },
    );
  }

  Widget _buildCurrentPageForIndex(int tabIndex, bool isWeb) {
    switch (tabIndex) {
      case 0:
        return _buildHomeTab(isWeb);
      case 1:
        return HomeDeferredTab(load: HomeLazyRoutes.categoriesTab);
      case 2:
        return HomeDeferredTab(load: HomeLazyRoutes.mapTab);
      case 3:
        return HomeDeferredTab(load: HomeLazyRoutes.cartTab);
      case 4:
        return HomeDeferredTab(load: HomeLazyRoutes.accountTab);
      default:
        return _buildHomeTab(isWeb);
    }
  }

  List<Widget> _buildHomeSections(bool isWeb) {
    if (!_sectionsRevealed) {
      return [
        const IbulDeliveryAddressSection(),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SkeletonLoading(
            width: double.infinity,
            height: 120,
            borderRadius: 12,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SkeletonLoading(
            width: double.infinity,
            height: 260,
            borderRadius: 12,
          ),
        ),
        const IbulTrustBarSection(),
      ];
    }

    return [
      const IbulDeliveryAddressSection(),
      IbulOpportunityShortcutsSection(
        selectedCategory: _selectedCategory,
        onShortcutTap: _setSelectedCategory,
      ),
      if (isWeb)
        IbulHeroCampaignRow(
          heroDelay: _heroBannerUrls.isNotEmpty ? Duration.zero : kHeroDelay,
          sideDelay: kSideDelay,
          bannerImageUrls: _heroBannerUrls,
          isLoadingHero: _isLoadingHero,
        )
      else
        const SizedBox(height: 8),
      DeferredHomeFullRailSection(
        title: 'Popüler Ürünler',
        products: _products,
        isLoading: _isLoadingProducts,
        maxItems: kPreviewBatchSize,
        errorMessage: _productError,
        onRetry: _fetchHomeProducts,
        delay: _productsReady ? Duration.zero : Duration.zero,
        suppressSkeleton: _productsReady,
        maxSkeletonDuration: kDeferredSkeletonMax,
      ),
      if (_homeFeatureAdGroups.isNotEmpty)
        HomeCategoryCardSections(
          groups: _homeFeatureAdGroups,
          convertToProduct: Product.fromDBProduct,
        )
      else if (_isLoadingFeatureAds && !_suppressBelowFoldSkeleton)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SkeletonLoading(
            width: double.infinity,
            height: 120,
            borderRadius: 12,
          ),
        ),
      DeferredHomeSponsoredSection(
        delay: _suppressBelowFoldSkeleton ? Duration.zero : kSponsoredDelay,
        suppressSkeleton: _suppressBelowFoldSkeleton,
        maxSkeletonDuration: kDeferredSkeletonMax,
      ),
      if (_forYouProducts.isNotEmpty)
        DeferredHomeFullRailSection(
          delay: Duration.zero,
          title: 'Sizin İçin Seçtiklerimiz',
          products: _forYouProducts,
          isLoading: false,
          maxItems: kPreviewBatchSize,
          showViewAll: false,
          suppressSkeleton: _suppressBelowFoldSkeleton,
          maxSkeletonDuration: kDeferredSkeletonMax,
        ),
      const IbulTrustBarSection(),
    ];
  }

  Widget _buildWebHomeScrollBody(bool isWeb) {
    final sections = _buildHomeSections(isWeb);
    return WebStickyFooterScrollView(
      contentAlignment: Alignment.topCenter,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: sections,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(bool isWeb) {
    return SafeArea(
      child: Column(
        children: [
          if (_timeoutPhase == _HomeBootTimeoutPhase.slowWarning &&
              _isLoadingProducts &&
              _products.isEmpty)
            HomeBootTimeoutBanner(
              message:
                  'Ürünler yükleniyor, bağlantı yavaş olabilir.',
              onRetry: _fetchHomeProducts,
            ),
          isWeb
              ? WebHeader(
                  onSearch: _onSearch,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _setSelectedCategory,
                )
              : CustomHeader(onSearch: _onSearch),
          Expanded(
            child: isWeb
                ? _buildWebHomeScrollBody(isWeb)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    children: _buildHomeSections(isWeb),
                  ),
          ),
        ],
      ),
    );
  }
}
