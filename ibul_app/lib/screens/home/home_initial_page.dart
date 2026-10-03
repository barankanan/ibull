import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ads/services/home_feature_ad_service.dart';
import '../../core/app_motion.dart';
import '../../app/marketplace_paths.dart';
import '../../core/constants.dart';
import '../../widgets/marketplace_content_frame.dart';
import '../../widgets/web_sticky_footer_scroll_view.dart';
import '../../core/ibul_chrome.dart';
import '../../core/qr_initial_params.dart';
import '../../core/web_boot_loader.dart';
import '../../features/vehicle/domain/vehicle_category.dart';
import '../../features/vehicle/navigation/vehicle_routes.dart'
    deferred as vehicle_routes;
import '../../widgets/custom_header.dart';
import '../../widgets/web_header.dart';
import '../../services/supabase_service.dart';
import '../home_lazy_routes.dart';
import '../home_deferred_tab.dart';
import 'home_discovery_loader.dart';
import 'entries/home_commerce_entry.dart' deferred as commerce;
import 'entries/home_discovery_entry.dart' deferred as discovery;
import 'entries/home_lower_entry.dart' deferred as lower;
import 'entries/home_promotions_entry.dart' deferred as promotions;
import 'entries/home_vehicle_entry.dart' deferred as vehicles;
import 'home_viewport_section.dart';
import 'sections/ibul_delivery_address_section.dart';
import 'sections/ibul_hero_campaign_row.dart';
import 'mobile/mobile_home_chrome.dart';
import 'mobile/mobile_home_feed.dart';
import 'mobile/mobile_home_nav.dart';

import '../../services/home_hero_banners_fetch.dart';

/// Above-fold home. Does not load the deferred home library.
class HomeInitialPage extends StatefulWidget {
  const HomeInitialPage({
    super.key,
    this.initialIndex = 0,
    this.initialCategory,
    this.initialSubCategory,
    this.initialSearchQuery,
  });

  final int initialIndex;
  final String? initialCategory;
  final String? initialSubCategory;
  final String? initialSearchQuery;

  @override
  State<HomeInitialPage> createState() => _HomeInitialPageState();
}

class _HomeInitialPageState extends State<HomeInitialPage> {
  late String _selectedCategory = widget.initialCategory ?? 'Ana Sayfa';
  late int _selectedIndex = widget.initialIndex;
  late String? _selectedSubCategory = widget.initialSubCategory;
  var _heroUrls = const <String>[];
  var _heroLoading = true;

  @override
  void initState() {
    super.initState();
    final cached = HomeHeroBannersFetch.readCachedUrlsSync();
    if (cached.isNotEmpty) {
      _heroUrls = cached;
      _heroLoading = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markFlutterFirstFrame();
      dismissWebBootLoader();
      final query = widget.initialSearchQuery?.trim() ?? '';
      if (query.length >= 3) {
        unawaited(HomeLazyRoutes.openSearch(context, query));
      }
      if (QrInitialParams.isQrPath) {
        if (_heroLoading) setState(() => _heroLoading = false);
        return;
      }
      unawaited(_loadHero());

      // Start data fetching for all below-fold sections immediately so they are
      // hot and ready by the time the user scrolls or their code module finishes loading.
      unawaited(SupabaseService.instance.fetchInitialHomeProductsReport());
      unawaited(
        HomeDiscoveryLoader.loadVehicles().then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            debugPrint('[HomeInitialPage] vehicle prefetch failed: $error');
          },
        ),
      );
      unawaited(HomeDiscoveryLoader.resolvePosition());
      unawaited(HomeFeatureAdService().loadHomePageGroups());

      _scheduleIdleCodePrefetch();
    });
  }

  void _scheduleIdleCodePrefetch() {
    // Pre-load all deferred section libraries after a short idle delay.
    // This ensures bottom sections (Vehicles, Promotions, Lower) have their
    // code ready even if the user hasn't scrolled. Without this, sections
    // beyond viewportExtent * 0.25 never trigger on the first frame and
    // show as empty placeholders.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      unawaited(commerce.loadLibrary());
      unawaited(discovery.loadLibrary());
      unawaited(vehicles.loadLibrary());
      unawaited(promotions.loadLibrary());
      unawaited(lower.loadLibrary());
    });
  }

  Future<void> _loadHero() async {
    final result = await HomeHeroBannersFetch.fetch(
      preferMobile: MediaQuery.sizeOf(context).width < 900,
    );
    if (!mounted) return;
    setState(() {
      _heroUrls = result.imageUrls;
      _heroLoading = false;
    });
  }

  void _onSearch(String query) {
    if (query.trim().length < 3) return;
    unawaited(HomeLazyRoutes.openSearch(context, query.trim()));
  }

  @override
  void didUpdateWidget(HomeInitialPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    var changed = false;
    if (widget.initialCategory != oldWidget.initialCategory) {
      final newCat = widget.initialCategory ?? 'Ana Sayfa';
      if (_selectedCategory != newCat) {
        _selectedCategory = newCat;
        _selectedSubCategory = null;
        changed = true;
      }
    }
    if (widget.initialSubCategory != oldWidget.initialSubCategory) {
      _selectedSubCategory = widget.initialSubCategory;
      changed = true;
    }
    if (widget.initialIndex != oldWidget.initialIndex) {
      if (_selectedIndex != widget.initialIndex) {
        _selectedIndex = widget.initialIndex;
        changed = true;
      }
    }
    // Flutter automatically calls build() after didUpdateWidget,
    // so we don't strictly need setState if we mutate before build,
    // but doing so ensures the framework knows we are dirty if needed.
    if (changed) {
      setState(() {});
    }
  }

  void _syncUrl({String? category, int? index}) {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }

    final cat = category ?? _selectedCategory;
    final idx = index ?? _selectedIndex;

    final Map<String, String> query = {};
    if (cat != 'Ana Sayfa') {
      query['category'] = cat;
    }
    if (_selectedSubCategory != null) {
      query['subcategory'] = _selectedSubCategory!;
    }
    if (idx != 0) {
      query['tab'] = idx.toString();
    }

    final uri = Uri(
      path: MarketplacePaths.home,
      queryParameters: query.isEmpty ? null : query,
    );
    router.go(uri.toString());
  }

  void _applySelection({String? category, int? index}) {
    final nextCategory = category ?? _selectedCategory;
    final nextIndex = index ?? _selectedIndex;
    if (nextCategory == _selectedCategory && nextIndex == _selectedIndex) {
      return;
    }
    setState(() {
      if (nextCategory != _selectedCategory) _selectedSubCategory = null;
      _selectedCategory = nextCategory;
      _selectedIndex = nextIndex;
    });
    _syncUrl(category: _selectedCategory, index: _selectedIndex);
  }

  Future<void> _setSelectedCategory(String category) async {
    if (isVehicleHubShortcutTitle(category)) {
      try {
        await vehicle_routes.loadLibrary();
        if (!mounted) return;
        await vehicle_routes.VehicleRoutes.openHub(context);
      } catch (e) {
        debugPrint('[HomeInitialPage] openHub failed: $e');
      }
      return;
    }
    _applySelection(category: category, index: 0);
  }

  void _onBottomNavTapped(int index) {
    if (IbulChrome.isWebOf(context) && index == 4) {
      unawaited(HomeLazyRoutes.openAccount(context));
      return;
    }
    _applySelection(index: index, category: _selectedCategory);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: isWeb ? AppColors.background : mobileHomeCanvas,
      body: AppAnimatedIndexedStack(
        index: _selectedIndex,
        lazyMount: true,
        children: List.generate(5, (index) => _buildPage(index, isWeb)),
      ),
      bottomNavigationBar: isWeb
          ? null
          : MobileHomeBottomNav(
              stackIndex: _selectedIndex,
              onStack: (index) => _onBottomNavTapped(index),
            ),
    );
  }

  Widget _buildPage(int index, bool isWeb) {
    switch (index) {
      case 0:
        return _buildHomeBody(isWeb);
      case 1:
        return HomeDeferredTab(load: HomeLazyRoutes.categoriesTab);
      case 2:
        return HomeDeferredTab(load: HomeLazyRoutes.mapTab);
      case 3:
        return HomeDeferredTab(load: HomeLazyRoutes.cartTab);
      case 4:
        return HomeDeferredTab(load: HomeLazyRoutes.accountTab);
      default:
        return _buildHomeBody(isWeb);
    }
  }

  Widget _buildHomeBody(bool isWeb) {
    if (!isWeb) {
      return SafeArea(
        bottom: false,
        child: MobileHomeFeed(
          cacheExtent: 900,
          bannerUrls: _heroUrls,
          heroLoading: _heroLoading,
          onSearch: _onSearch,
          onOpenMap: () => _applySelection(index: 2),
          onOpenCategories: () => _applySelection(index: 1),
          onOpenCategoryNode: (node) =>
              showMobileSubcategorySheet(context, node),
          onOpenCategory: (name) => unawaited(_setSelectedCategory(name)),
          onOpenVehicles: () => unawaited(_setSelectedCategory('Araç')),
          trailing: HomeViewportSection(
            placeholderHeight: 8,
            debugName: 'Promotions',
            loadLibrary: promotions.loadLibrary,
            builder: () => promotions.HomePromotionsBlock(),
          ),
        ),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          isWeb
              ? WebHeader(
                  onSearch: _onSearch,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _setSelectedCategory,
                  showCategories: true,
                )
              : CustomHeader(onSearch: _onSearch),
          Expanded(
            child: WebStickyFooterScrollView(
              footerBottomPadding: isWeb ? 0 : 96,
              child: MarketplaceContentFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _homeSectionChildren(isWeb),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _homeSectionChildren(bool isWeb) {
    return [
      const IbulDeliveryAddressSection(),
      if (isWeb)
        IbulHeroCampaignRow(
          heroDelay: Duration.zero,
          sideDelay: Duration.zero,
          bannerImageUrls: _heroUrls,
          isLoadingHero: _heroLoading,
        ),
      HomeViewportSection(
        placeholderHeight: 396,
        debugName: 'Commerce',
        loadLibrary: commerce.loadLibrary,
        builder: () => commerce.HomeCommerceBlock(
          category: _selectedCategory,
          subCategory: _selectedSubCategory,
        ),
      ),
      HomeViewportSection(
        placeholderHeight: 380,
        debugName: 'Discovery',
        loadLibrary: discovery.loadLibrary,
        builder: () => discovery.HomeDiscoveryBlock(),
      ),
      HomeViewportSection(
        placeholderHeight: 380,
        debugName: 'Vehicles',
        loadLibrary: vehicles.loadLibrary,
        builder: () => vehicles.HomeVehicleBlock(),
      ),
      HomeViewportSection(
        placeholderHeight: 160,
        debugName: 'Promotions',
        loadLibrary: promotions.loadLibrary,
        builder: () => promotions.HomePromotionsBlock(),
      ),
      HomeViewportSection(
        placeholderHeight: 220,
        debugName: 'Lower',
        loadLibrary: lower.loadLibrary,
        builder: () => lower.HomeLowerBlock(),
      ),
    ];
  }
}
