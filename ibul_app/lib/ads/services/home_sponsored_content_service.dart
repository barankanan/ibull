import 'package:flutter/foundation.dart';

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
  })  : _repository = repository ?? AdsRepository(),
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
      HomeLoadAudit.recordSponsoredContent();
      final campaigns = await _repository.getActiveHomeCollectionCampaigns(
        limit: (limit * 3).clamp(limit, 18),
      );

      final listIds = <String>[];
      final seen = <String>{};
      for (final campaign in campaigns) {
        if (!isCampaignActiveNow(campaign)) continue;
        if (!supportsPlacement(campaign, placement)) continue;
        final id = collectionId(campaign);
        if (id == null || id.isEmpty) continue;
        if (seen.add(id)) {
          listIds.add(id);
        }
        if (listIds.length >= limit) break;
      }
      if (listIds.isEmpty) return const [];

      HomeLoadAudit.recordSponsoredContent();
      final lists = await _productListService.getHomePreviewListsByIds(listIds);
      if (lists.isEmpty) return const [];

      final filter = _normalize(categoryFilter);
      final filtered = filter.isEmpty
          ? lists
          : lists.where((list) => _matchesCategory(list, filter)).toList(
              growable: false,
            );

      final resolved = filtered.take(limit).toList(growable: false);
      if (resolved.isNotEmpty) {
        _listsCache.write(cacheKey, resolved);
      }
      return resolved;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HomeSponsoredContentService.fetchActiveSponsoredHomeLists: $e');
      }
      return const [];
    }
  }

  String _normalize(String? value) => (value ?? '').trim().toLowerCase();

  bool _matchesCategory(ProductList list, String filter) {
    final listCategory = _normalize(list.category);
    final listSubCategory = _normalize(list.subCategory);
    return listCategory == filter || listSubCategory == filter;
  }
}
