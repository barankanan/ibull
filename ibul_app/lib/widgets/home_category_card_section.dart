import 'dart:async';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ad_product_trace.dart';
import '../core/home_data_diagnostics.dart';
import '../core/ibul_chrome.dart';
import '../ads/enums/ad_enums.dart';
import '../ads/helpers/home_feature_ad_display_text.dart';
import '../ads/helpers/home_feature_ad_helper.dart';
import '../ads/models/home_card_template.dart';
import '../ads/services/home_feature_ad_service.dart';
import '../ads/services/home_feature_event_service.dart';
import '../models/ad_linked_products_fetch_report.dart';
import '../models/db_product.dart';
import '../models/product_model.dart';
import '../services/store_service.dart';
import '../services/supabase_service.dart';
import 'home_sponsored_banner.dart';
import 'optimized_image.dart';
import 'product_card.dart';
import 'skeleton_loading.dart';

/// Kategori bazlı ana sayfa kart bölümü: mağaza logoları + banner + ürünler.
/// Yalnızca onaylı home_feature reklamlarından beslenir.
class HomeCategoryCardSection extends StatelessWidget {
  const HomeCategoryCardSection({
    required this.group,
    required this.convertToProduct,
    this.hideCategoryTitle = false,
    super.key,
  });

  final HomeCategoryCardGroup group;
  final Product Function(DBProduct dbProduct) convertToProduct;
  final bool hideCategoryTitle;

  List<HomeFeatureDisplayAd> get _allAds {
    final ads = <HomeFeatureDisplayAd>[];
    for (final card in group.cards) {
      ads.addAll(card.ads.where(_hasDisplayableContent));
    }
    HomeFeatureAdService.sortDisplayAds(ads);
    return ads;
  }

  bool _hasDisplayableContent(HomeFeatureDisplayAd ad) {
    return ad.bannerUrls.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ads = _allAds;
    if (ads.isEmpty) {
      return const SizedBox.shrink();
    }

    if (kDebugMode) {
      debugPrint(
        'HomeCategoryCardSection "${group.categoryName}": ad_count=${ads.length} '
        'stores=${ads.map((a) => a.storeName).join(", ")}',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideCategoryTitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              group.categoryName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        _HomeCardBlock(
          cardTitle: group.cards.isNotEmpty ? group.cards.first.cardTitle : group.categoryName,
          ads: ads,
          convertToProduct: convertToProduct,
        ),
      ],
    );
  }
}

class _HomeCardBlock extends StatefulWidget {
  const _HomeCardBlock({
    required this.cardTitle,
    required this.ads,
    required this.convertToProduct,
  });

  final String cardTitle;
  final List<HomeFeatureDisplayAd> ads;
  final Product Function(DBProduct dbProduct) convertToProduct;

  @override
  State<_HomeCardBlock> createState() => _HomeCardBlockState();
}

class _HomeCardBlockState extends State<_HomeCardBlock> {
  final _eventService = HomeFeatureEventService();
  final _storeService = StoreService();
  final Map<String, String?> _logoCache = {};
  final Map<String, List<DBProduct>> _hydratedProducts = {};
  final Set<String> _hydratingCampaignIds = {};
  int _selectedAdIndex = 0;

  @override
  void initState() {
    super.initState();
    for (final ad in widget.ads) {
      _eventService.track(
        campaignId: ad.campaignId,
        eventType: HomeFeatureEventType.impression,
      );
    }
    _loadLogos();
    for (final ad in widget.ads) {
      unawaited(_hydrateAdProducts(ad));
    }
  }

  @override
  void didUpdateWidget(covariant _HomeCardBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedAdIndex >= widget.ads.length) {
      _selectedAdIndex = 0;
    }
    for (final ad in widget.ads) {
      if (_productsForAd(ad).isEmpty && ad.productIds.isNotEmpty) {
        unawaited(_hydrateAdProducts(ad));
      }
    }
  }

  HomeFeatureDisplayAd get _activeAd => widget.ads[_selectedAdIndex];

  List<DBProduct> _productsForAd(HomeFeatureDisplayAd ad) {
    return _hydratedProducts[ad.campaignId] ?? ad.resolvedProducts;
  }

  Future<void> _hydrateAdProducts(HomeFeatureDisplayAd ad) async {
    if (ad.productIds.isEmpty) return;
    if (_productsForAd(ad).isNotEmpty) return;
    if (_hydratingCampaignIds.contains(ad.campaignId)) return;
    _hydratingCampaignIds.add(ad.campaignId);

    traceAdProduct(
      stage: AdProductTraceStage.adProductRenderStarted,
      placement: 'home_feature',
      category: ad.categoryName,
      subcategory: ad.cardTitle,
      adId: ad.campaignId,
      campaignId: ad.campaignId,
      advertiserName: ad.storeName,
      sellerId: ad.sellerId,
      productIds: ad.productIds,
      linkedProductIdCount: ad.productIds.length,
      isBannerOnly: false,
      bannerCount: ad.bannerUrls.length,
      rawProductCount: ad.productIds.length,
    );

    try {
      final report = await SupabaseService.instance.fetchAdLinkedProductsReport(
        ad.productIds,
        context: AdLinkedProductsFetchContext(
          campaignId: ad.campaignId,
          sellerId: ad.sellerId,
          adId: ad.campaignId,
          advertiserName: ad.storeName,
          category: ad.categoryName,
          subcategory: ad.cardTitle,
        ),
      );
      if (!mounted) return;
      final resolved = SupabaseService.instance.orderAdLinkedProducts(
        productIds: ad.productIds,
        products: report.products,
        maxProducts: HomeFeatureAdHelper.maxProducts,
      );

      traceAdProduct(
        stage: resolved.isEmpty
            ? (report.rawDbCount == 0
                ? AdProductTraceStage.adProductFetchEmpty
                : AdProductTraceStage.adProductFilterEmpty)
            : AdProductTraceStage.adProductRenderCompleted,
        placement: 'home_feature',
        category: ad.categoryName,
        subcategory: ad.cardTitle,
        adId: ad.campaignId,
        campaignId: ad.campaignId,
        advertiserName: ad.storeName,
        sellerId: ad.sellerId,
        productIds: ad.productIds,
        linkedProductIdCount: ad.productIds.length,
        isBannerOnly: false,
        bannerCount: ad.bannerUrls.length,
        rawRpcCount: report.rawRpcCount,
        rawSelectCount: report.rawSelectCount,
        rawProductCount: report.rawDbCount,
        filteredProductCount: resolved.length,
        renderedProductCount: resolved.length,
        query: report.query,
        error: report.error,
        rejectionReasons: report.rejectionSummary(),
      );

      if (resolved.isEmpty) return;
      setState(() {
        _hydratedProducts[ad.campaignId] = resolved;
      });
    } catch (e) {
      traceAdProduct(
        stage: AdProductTraceStage.adProductFetchError,
        placement: 'home_feature',
        category: ad.categoryName,
        subcategory: ad.cardTitle,
        adId: ad.campaignId,
        campaignId: ad.campaignId,
        advertiserName: ad.storeName,
        sellerId: ad.sellerId,
        productIds: ad.productIds,
        linkedProductIdCount: ad.productIds.length,
        isBannerOnly: false,
        bannerCount: ad.bannerUrls.length,
        rawProductCount: ad.productIds.length,
        error: e.toString(),
      );
    } finally {
      _hydratingCampaignIds.remove(ad.campaignId);
    }
  }

  Future<void> _loadLogos() async {
    final lookupIds = <String>{};
    for (final ad in widget.ads) {
      final seller = ad.sellerId.trim();
      final store = ad.storeId?.trim() ?? '';
      if (seller.isNotEmpty) lookupIds.add(seller);
      if (store.isNotEmpty) lookupIds.add(store);
    }
    if (lookupIds.isEmpty) return;

    try {
      final infoByLookupId = await _storeService.getStorePublicInfoByIds(
        lookupIds.toList(growable: false),
      );
      if (!mounted || infoByLookupId.isEmpty) return;

      final pending = <String, String?>{};
      for (final ad in widget.ads) {
        final seller = ad.sellerId.trim();
        final store = ad.storeId?.trim() ?? '';
        final info = infoByLookupId[seller] ??
            (store.isNotEmpty ? infoByLookupId[store] : null);
        if (info != null) {
          pending[ad.campaignId] = info['logoUrl']?.toString();
        }
      }
      if (pending.isEmpty) return;
      setState(() {
        _logoCache.addAll(pending);
      });
    } catch (_) {}
  }

  ({double width, double height}) _bannerSize(double availableWidth) {
    return HomeSponsoredBannerDimensions.resolve(
      availableWidth: availableWidth,
      screenWidth: MediaQuery.sizeOf(context).width,
    );
  }

  BoxFit _bannerFit() =>
      HomeSponsoredBannerDimensions.fitForScreen(MediaQuery.sizeOf(context).width);

  double _productCardWidth() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (IbulChrome.isWeb(screenWidth)) return 200;
    if (screenWidth >= 600) return 180;
    return 160;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return const SizedBox.shrink();

    final productCardWidth = _productCardWidth();

    if (kDebugMode) {
      debugPrint(
        'HomeCategoryCardSection block category="${widget.cardTitle}" '
        'ads=${widget.ads.length} '
        'stores=${widget.ads.map((a) => a.storeName).join(", ")} '
        'selectedAdIndex=$_selectedAdIndex',
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kategori başlığıyla aynı/benzer ("Yemek" vs "Yemekler") kart
          // başlığı tekrar yazılmaz — profesyonel görünüm kuralı.
          if (widget.cardTitle.trim().isNotEmpty &&
              !HomeFeatureAdDisplayText.isSimilarTitle(
                widget.cardTitle,
                widget.ads.first.categoryName,
              ))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                widget.cardTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          _buildStoreLogos(),
          const SizedBox(height: 8),
          _buildBannerCarousel(),
          const SizedBox(height: 8),
          _buildProductsRow(productCardWidth),
        ],
      ),
    );
  }

  Widget _buildStoreLogos() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.ads.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final ad = widget.ads[i];
          final logo = _logoCache[ad.campaignId] ?? ad.storeLogoUrl;
          final selected = i == _selectedAdIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedAdIndex = i);
              _eventService.track(
                campaignId: ad.campaignId,
                eventType: HomeFeatureEventType.storeProfileOpen,
                storeId: ad.storeId ?? ad.sellerId,
              );
              _hydrateAdProducts(ad);
            },
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.deepPurple : Colors.grey.shade300,
                      width: selected ? 2.5 : 1,
                    ),
                  ),
                  child: ClipOval(
                    child: logo != null && logo.isNotEmpty
                        ? OptimizedImage(
                            imageUrlOrPath: logo,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorWidget: _storeInitial(ad.storeName),
                          )
                        : _storeInitial(ad.storeName),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 64,
                  child: Text(
                    ad.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _storeInitial(String name) {
    return ColoredBox(
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    final banners = _activeAd.bannerUrls;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = _bannerSize(constraints.maxWidth);
          final fit = _bannerFit();
          final slotHeight = size.height;

          if (banners.isEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: HomeSponsoredBanner(
                width: size.width,
                height: slotHeight,
                fit: fit,
              ),
            );
          }

          if (banners.length == 1) {
            return Align(
              alignment: Alignment.centerLeft,
              child: HomeSponsoredBanner(
                width: size.width,
                height: slotHeight,
                imageUrl: banners.first,
                fit: fit,
                onTap: () => _eventService.track(
                  campaignId: _activeAd.campaignId,
                  eventType: HomeFeatureEventType.bannerClick,
                ),
              ),
            );
          }

          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: size.width,
              height: slotHeight,
              child: CarouselSlider.builder(
                itemCount: banners.length,
                options: CarouselOptions(
                  height: slotHeight,
                  viewportFraction: 1,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  padEnds: true,
                ),
                itemBuilder: (context, index, realIndex) {
                  return HomeSponsoredBanner(
                    width: size.width,
                    height: slotHeight,
                    imageUrl: banners[index],
                    fit: fit,
                    onTap: () => _eventService.track(
                      campaignId: _activeAd.campaignId,
                      eventType: HomeFeatureEventType.bannerClick,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsRow(double productCardWidth) {
    final ad = _activeAd;
    final products = _productsForAd(ad);

    if (ad.productIds.isEmpty) {
      return const SizedBox.shrink();
    }

    if (products.isEmpty) {
      if (!kDebugMode) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'ad trace: linked ids=${ad.productIds.length} resolved=0',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        ),
      );
    }

    final rowHeight = productCardWidth * 1.55;

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: productCardWidth,
            child: GestureDetector(
              onTap: () => _eventService.track(
                campaignId: _activeAd.campaignId,
                eventType: HomeFeatureEventType.productClick,
                productId: product.id,
              ),
              child: ProductCard(
                product: widget.convertToProduct(product),
                width: productCardWidth,
                tight: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tüm kategori gruplarını render eder.
class HomeCategoryCardSections extends StatelessWidget {
  const HomeCategoryCardSections({
    required this.groups,
    required this.convertToProduct,
    this.isLoading = false,
    this.suppressSkeleton = false,
    super.key,
  });

  final List<HomeCategoryCardGroup> groups;
  final Product Function(DBProduct dbProduct) convertToProduct;
  final bool isLoading;
  final bool suppressSkeleton;

  @override
  Widget build(BuildContext context) {
    if (isLoading && groups.isEmpty) {
      if (suppressSkeleton) {
        HomeSectionDiagnostics.hidden(
          section: 'home_feature_ads',
          reason: 'products_loaded',
        );
        return const SizedBox.shrink();
      }
      return const _HomeCategoryCardSectionsSkeleton();
    }
    if (groups.isEmpty) {
      HomeSectionDiagnostics.hidden(
        section: 'home_feature_ads',
        reason: 'empty',
      );
      return const SizedBox.shrink();
    }
    if (kDebugMode) {
      debugPrint(
        'HomeCategoryCardSections: group_count=${groups.length}',
      );
    }
    return Column(
      children: [
        for (final group in groups)
          HomeCategoryCardSection(
            group: group,
            convertToProduct: convertToProduct,
          ),
      ],
    );
  }
}

class _HomeCategoryCardSectionsSkeleton extends StatelessWidget {
  const _HomeCategoryCardSectionsSkeleton();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerSize = HomeSponsoredBannerDimensions.resolve(
      availableWidth: screenWidth - 32,
      screenWidth: screenWidth,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SkeletonLoading(width: 180, height: 22, borderRadius: 8),
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => const Column(
                children: [
                  SkeletonLoading(width: 52, height: 52, borderRadius: 26),
                  SizedBox(height: 4),
                  SkeletonLoading(width: 56, height: 10, borderRadius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HomeSponsoredBanner(
              width: bannerSize.width,
              height: bannerSize.height,
              isLoading: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: IbulChrome.isWeb(screenWidth)
                ? 310
                : screenWidth >= 600
                    ? 279
                    : 248,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final cardWidth = IbulChrome.isWeb(screenWidth)
                    ? 200.0
                    : screenWidth >= 600
                    ? 180.0
                    : 160.0;
                return SkeletonLoading(
                  width: cardWidth,
                  height: cardWidth * 1.55,
                  borderRadius: 12,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
