import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';

import '../../ads/services/home_feature_ad_service.dart';
import '../../core/constants.dart';
import '../../core/home_mobile_shortcut.dart';
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
import 'home_discovery_loader.dart';
import 'entries/home_commerce_entry.dart' deferred as commerce;
import 'entries/home_discovery_entry.dart' deferred as discovery;
import 'entries/home_lower_entry.dart' deferred as lower;
import 'entries/home_promotions_entry.dart' deferred as promotions;
import 'entries/home_vehicle_entry.dart' deferred as vehicles;
import 'home_viewport_section.dart';
import 'sections/ibul_delivery_address_section.dart';
import 'sections/ibul_hero_campaign_row.dart';
import 'sections/ibul_mobile_home_chrome.dart';
import 'sections/ibul_opportunity_shortcuts_section.dart';
import '../../services/home_hero_banners_fetch.dart';

/// Above-fold home. Does not load the deferred home library.
class HomeInitialPage extends StatefulWidget {
  const HomeInitialPage({
    super.key,
    this.initialIndex = 0,
    this.initialCategory,
    this.initialSearchQuery,
  });

  final int initialIndex;
  final String? initialCategory;
  final String? initialSearchQuery;

  @override
  State<HomeInitialPage> createState() => _HomeInitialPageState();
}

class _HomeInitialPageState extends State<HomeInitialPage> {
  late String _selectedCategory = widget.initialCategory ?? 'Ana Sayfa';
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
      unawaited(HomeDiscoveryLoader.loadVehicles());
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
    final result = await HomeHeroBannersFetch.fetch(preferMobile: true);
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

  Future<void> _setSelectedCategory(String category) async {
    if (isVehicleHubShortcutTitle(category)) {
      try {
        await vehicle_routes.loadLibrary();
        if (!mounted) return;
        await vehicle_routes.VehicleRoutes.openHub(context);
      } catch (e, st) {
        debugPrint('[HomeInitialPage] openHub failed: $e');
      }
      return;
    }
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = IbulChrome.isWebOf(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            isWeb
                ? WebHeader(
                    onSearch: _onSearch,
                    selectedCategory: _selectedCategory,
                    onCategorySelected: _setSelectedCategory,
                  )
                : CustomHeader(onSearch: _onSearch),
            Expanded(
              child: ListView(
                // 2.5 viewports cache so sections mount early and can
                // monitor their scroll position properly ahead of time.
                cacheExtent: MediaQuery.sizeOf(context).height * 2.5,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  const IbulDeliveryAddressSection(),
                  if (isWeb)
                    IbulOpportunityShortcutsSection(
                      selectedCategory: _selectedCategory,
                      onShortcutTap: _setSelectedCategory,
                    )
                  else
                    IbulMobileHomeChrome(
                      bannerImageUrls: _heroUrls,
                      isLoadingHero: _heroLoading,
                      onShortcutTap: (key, label) {
                        openMobileHomeShortcut(
                          context,
                          shortcutKey: key,
                          label: label,
                          callbacks: HomeMobileShortcutCallbacks(
                            scrollToPersonalizedSection: () {},
                            switchToMapTab: () {
                              unawaited(HomeLazyRoutes.openMap(context));
                            },
                          ),
                        );
                      },
                    ),
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
                    builder: () => commerce.HomeCommerceBlock(),
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
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWeb
          ? null
          : BottomNavigationBar(
              currentIndex: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: Colors.black,
              type: BottomNavigationBarType.fixed,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.home),
                  label: l10n?.home ?? 'Ana Sayfa',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.segment),
                  label: l10n?.categories ?? 'Kategori',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  label: 'Harita',
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: l10n?.cart ?? 'Sepet',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Hesabım',
                ),
              ],
              onTap: (index) {
                if (index == 1) {
                  unawaited(HomeLazyRoutes.openSearch(context, ''));
                } else if (index == 2) {
                  unawaited(HomeLazyRoutes.openMap(context));
                } else if (index == 3) {
                  unawaited(HomeLazyRoutes.openCart(context));
                } else if (index == 4) {
                  unawaited(HomeLazyRoutes.openAccount(context));
                }
              },
            ),
    );
  }
}

