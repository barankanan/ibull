import 'package:flutter/foundation.dart';

import '../../core/home_data_diagnostics.dart';
import '../../core/home_load_audit.dart';
import '../../core/simple_memory_ttl_cache.dart';
import '../../models/product_list_model.dart';
import '../../services/product_list_service.dart';
import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../repositories/ads_repository.dart';

/// Müşteri ana sayfası için hafif sponsorlu içerik servisi.
/// Admin panel sorgularını kullanmaz.
class HomeSponsoredContentService {
  HomeSponsoredContentService({
    AdsRepository? repository,
    ProductListService? productListService,
  })  : _repository = repository ??
            AdsRepository(usePreviewOnFailure: false),
        _productListService = productListService ?? ProductListService.instance;

  final AdsRepository _repository;
  final ProductListService _productListService;

  static final Map<String, Future<List<ProductList>>> _inFlightByKey = {};
  static final SimpleMemoryTtlCache<List<ProductList>> _listsCache =
      SimpleMemoryTtlCache(defaultTtl: const Duration(minutes: 3));

  /// UTC tabanlı aktif kampanya kontrolü (DB `now()` ile uyumlu).
  @visibleForTesting
  static bool isCampaignActiveNow(
    AdCampaign campaign, {
    DateTime? referenceUtc,
  }) {
    final now = (referenceUtc ?? DateTime.now()).toUtc();
    final starts = campaign.startsAt.toUtc();
    final ends = campaign.endsAt.toUtc();
    return !starts.isAfter(now) && !ends.isBefore(now);
  }

  @visibleForTesting
  static bool supportsPlacement(AdCampaign campaign, AdPlacement placement) {
    final targetPlacements = campaign.target?.placements ?? const [];
    final assetPlacements = campaign.assets.expand((item) => item.placements);
    if (targetPlacements.isEmpty && assetPlacements.isEmpty) return true;
    return targetPlacements.contains(placement) ||
        assetPlacements.contains(placement);
  }

  @visibleForTesting
  static String? collectionId(AdCampaign campaign) {
    for (final asset in campaign.assets) {
      final id = asset.entityId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  /// Ana sayfada gösterilecek aktif sponsorlu ürün listelerini döndürür.
  Future<List<ProductList>> fetchActiveSponsoredHomeLists({
    AdPlacement placement = AdPlacement.homeFeed,
    int limit = 6,
    String? categoryFilter,
    bool forceRefresh = false,
  }) {
    final cacheKey = '${placement.dbValue}|$limit|${categoryFilter ?? ''}';
    if (!forceRefresh) {
      final cached = _listsCache.read(cacheKey);
      if (cached != null) return Future.value(cached);
    }
    return _inFlightByKey.putIfAbsent(
      cacheKey,
      () => _fetchActiveSponsoredHomeLists(
        placement: placement,
        limit: limit,
        categoryFilter: categoryFilter,
        cacheKey: cacheKey,
      ).whenComplete(() => _inFlightByKey.remove(cacheKey)),
    );
  }

  Future<List<ProductList>> _fetchActiveSponsoredHomeLists({
    required AdPlacement placement,
    required int limit,
    String? categoryFilter,
    required String cacheKey,
  }) async {
    try {
      HomeAdsDiagnostics.sponsoredRequestStart(source: 'home_sponsored_content');
      HomeLoadAudit.recordSponsoredContent();
      final campaigns = await _repository.getActiveHomeCollectionCampaigns(
        limit: (limit * 3).clamp(limit, 18),
      );
      HomeAdsDiagnostics.sponsoredRaw(count: campaigns.length);

      final listIds = <String>[];
      final campaignByCollectionId = <String, AdCampaign>{};
      final seen = <String>{};
      var afterDate = 0;
      var afterPlacement = 0;
      for (final campaign in campaigns) {
        if (!isCampaignActiveNow(campaign)) continue;
        afterDate++;
        if (!supportsPlacement(campaign, placement)) continue;
        afterPlacement++;
        final id = collectionId(campaign);
        if (id == null || id.isEmpty) continue;
        if (seen.add(id)) {
          listIds.add(id);
          campaignByCollectionId[id] = campaign;
        }
        if (listIds.length >= limit) break;
      }
      HomeAdsDiagnostics.sponsoredAfterDateFilter(count: afterDate);
      HomeAdsDiagnostics.sponsoredAfterPlacementFilter(
        count: afterPlacement,
        placement: placement.dbValue,
      );

      if (listIds.isEmpty) {
        HomeAdsDiagnostics.sponsoredHidden(reason: 'empty');
        HomeSectionDiagnostics.hidden(
          section: 'sponsored_lists',
          reason: 'no_active_collections',
        );
        return const [];
      }

      HomeLoadAudit.recordSponsoredContent();
      final hydratedLists =
          await _productListService.getHomePreviewListsByIds(listIds);
      HomeAdsDiagnostics.sponsoredHydration(count: hydratedLists.length);
      final lists = _resolveSponsoredPreviewLists(
        listIds: listIds,
        hydratedLists: hydratedLists,
        campaignByCollectionId: campaignByCollectionId,
      );
      HomeAdsDiagnostics.sponsoredAfterApprovalFilter(count: lists.length);
      final fallbackCount = lists.length - hydratedLists.length;
      if (fallbackCount > 0) {
        HomeAdsDiagnostics.sponsoredRpcFallback(count: fallbackCount);
      }
      if (lists.isEmpty) {
        HomeAdsDiagnostics.sponsoredHidden(reason: 'lists_unresolved');
        HomeSectionDiagnostics.hidden(
          section: 'sponsored_lists',
          reason: 'preview_lists_empty',
        );
        return const [];
      }

      final filter = _normalize(categoryFilter);
      final filtered = filter.isEmpty
          ? lists
          : lists.where((list) => _matchesCategory(list, filter)).toList(
              growable: false,
            );

      final resolved = filtered.take(limit).toList(growable: false);
      if (resolved.isEmpty) {
        HomeAdsDiagnostics.sponsoredHidden(reason: 'category_filter_empty');
        HomeSectionDiagnostics.hidden(
          section: 'sponsored_lists',
          reason: 'category_filter_empty',
        );
        return const [];
      }

      HomeAdsDiagnostics.activeCount(count: resolved.length);
      HomeAdsDiagnostics.sponsoredRendered(
        count: resolved.length,
        widget: 'SponsoredProductListsSection',
      );
      _listsCache.write(cacheKey, resolved);
      return resolved;
    } catch (e) {
      HomeAdsDiagnostics.sponsoredHidden(reason: 'error');
      if (kDebugMode) {
        debugPrint('HomeSponsoredContentService.fetchActiveSponsoredHomeLists: $e');
      }
      return const [];
    }
  }

  String _normalize(String? value) => (value ?? '').trim().toLowerCase();

  /// RPC kampanya metadata'sından liste kartı üretir (RLS list sorgusu boş dönerse).
  @visibleForTesting
  static ProductList? previewListFromCampaign(AdCampaign campaign) {
    final id = collectionId(campaign);
    if (id == null || id.isEmpty) return null;
    final asset = campaign.assets.isNotEmpty ? campaign.assets.first : null;
    final cover = (asset?.thumbnailUrl ?? asset?.mediaUrl ?? '').trim();
    final title = campaign.name.trim();
    return ProductList(
      id: id,
      name: title.isEmpty ? 'Öne Çıkan Liste' : title,
      iconUrl: cover.isEmpty ? null : cover,
      sellerId: campaign.sellerId,
      storeName: campaign.storeId,
      productIds: const [],
      createdAt: campaign.startsAt,
      updatedAt: campaign.startsAt,
    );
  }

  @visibleForTesting
  static List<ProductList> resolveSponsoredPreviewLists({
    required List<String> listIds,
    required List<ProductList> hydratedLists,
    required Map<String, AdCampaign> campaignByCollectionId,
  }) {
    final byId = {for (final list in hydratedLists) list.id: list};
    final resolved = <ProductList>[];
    for (final id in listIds) {
      final hydrated = byId[id];
      if (hydrated != null) {
        resolved.add(hydrated);
        continue;
      }
      final fallback = previewListFromCampaign(campaignByCollectionId[id]!);
      if (fallback != null) {
        resolved.add(fallback);
      }
    }
    return resolved;
  }

  List<ProductList> _resolveSponsoredPreviewLists({
    required List<String> listIds,
    required List<ProductList> hydratedLists,
    required Map<String, AdCampaign> campaignByCollectionId,
  }) {
    return resolveSponsoredPreviewLists(
      listIds: listIds,
      hydratedLists: hydratedLists,
      campaignByCollectionId: campaignByCollectionId,
    );
  }

  bool _matchesCategory(ProductList list, String filter) {
    final listCategory = _normalize(list.category);
    final listSubCategory = _normalize(list.subCategory);
    return listCategory == filter || listSubCategory == filter;
  }
}
