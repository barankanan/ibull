import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ad_product_trace.dart';
import '../../core/simple_memory_ttl_cache.dart';
import '../../models/ad_linked_products_fetch_report.dart';
import '../../services/supabase_service.dart';
import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';
import '../helpers/home_feature_ad_helper.dart';
import '../models/ad_campaign.dart';
import '../models/campaign_asset.dart';
import '../models/campaign_target.dart';
import '../models/home_card_template.dart';
import '../repositories/ads_repository.dart';
import 'home_card_template_service.dart';

class HomeFeatureAdService {
  HomeFeatureAdService({
    AdsRepository? repository,
    HomeCardTemplateService? templateService,
    SupabaseClient? client,
  })  : _repository = repository ?? AdsRepository(usePreviewOnFailure: false),
        _templateService = templateService ?? HomeCardTemplateService(),
        _client = client ?? Supabase.instance.client;

  final AdsRepository _repository;
  final HomeCardTemplateService _templateService;
  final SupabaseClient _client;

  static final SimpleMemoryTtlCache<List<HomeCategoryCardGroup>> _groupsCache =
      SimpleMemoryTtlCache(defaultTtl: const Duration(minutes: 3));
  static const _groupsCacheKey = 'home_page_groups_v2';

  Future<AdCampaign> createHomeFeatureAd({
    required String sellerId,
    required String storeId,
    required String storeName,
    required HomeCardTemplate template,
    required List<String> bannerUrls,
    required List<String> productIds,
    required DateTime startsAt,
    required DateTime endsAt,
    String? campaignName,
    String budgetType = 'total',
    double dailyBudget = 0,
    double totalBudget = 0,
    Map<String, dynamic>? extraSettings,
  }) async {
    final uniqueBannerUrls = HomeFeatureAdHelper.uniqueOrderedIds(bannerUrls);
    final uniqueProductIds = HomeFeatureAdHelper.uniqueOrderedIds(productIds);

    final issues = HomeFeatureAdHelper.validateSubmission(
      cardTemplateId: template.id,
      bannerImages: uniqueBannerUrls,
      productIds: uniqueProductIds,
      startsAt: startsAt,
      endsAt: endsAt,
    );
    if (issues.isNotEmpty) {
      throw StateError(issues.join(' '));
    }

    await _assertProductsBelongToSeller(sellerId, uniqueProductIds);

    final now = DateTime.now();
    final campaignId = 'hfa-${now.microsecondsSinceEpoch}';
    final durationDays = endsAt.difference(startsAt).inDays + 1;
    final double resolvedTotalBudget = totalBudget > 0
        ? totalBudget
        : (dailyBudget > 0 ? dailyBudget * durationDays : 0.0);
    final double resolvedDailyBudget = dailyBudget > 0
        ? dailyBudget
        : (resolvedTotalBudget > 0 && durationDays > 0
            ? resolvedTotalBudget / durationDays
            : 0.0);

    final metadata = HomeFeatureAdHelper.buildMetadata(
      cardTemplateId: template.id,
      categoryName: template.categoryName ?? template.title,
      categoryId: template.categoryId,
      bannerImages: uniqueBannerUrls,
      selectedProductIds: uniqueProductIds,
      storeName: storeName,
      budgetType: budgetType,
      dailyBudget: resolvedDailyBudget > 0 ? resolvedDailyBudget : null,
      totalBudget: resolvedTotalBudget > 0 ? resolvedTotalBudget : null,
      durationDays: durationDays,
      extraSettings: extraSettings,
    );

    final assets = <CampaignAsset>[
      ...uniqueBannerUrls.asMap().entries.map(
            (e) => CampaignAsset(
              campaignId: campaignId,
              assetType: AdAssetType.image,
              mediaUrl: e.value,
              priority: e.key,
              placements: const [AdPlacement.homeCard],
            ),
          ),
      ...uniqueProductIds.asMap().entries.map(
            (e) => CampaignAsset(
              campaignId: campaignId,
              assetType: AdAssetType.product,
              entityId: e.value,
              priority: e.key,
              placements: const [AdPlacement.homeCard],
            ),
          ),
    ];

    final campaign = AdCampaign(
      id: campaignId,
      sellerId: sellerId,
      storeId: storeId,
      name: campaignName ?? 'Ana Sayfa — ${template.displayLabel}',
      description: 'Ana sayfa öne çıkarma reklamı',
      type: AdCampaignType.homeFeature,
      objective: CampaignObjective.storeVisits,
      status: CampaignStatus.pendingReview,
      billingModel: BillingModel.flat,
      dailyBudget: resolvedDailyBudget,
      totalBudget: resolvedTotalBudget,
      spentAmount: 0,
      remainingBalance: resolvedTotalBudget,
      bidAmount: 0,
      currency: 'TRY',
      startsAt: startsAt,
      endsAt: endsAt,
      target: CampaignTarget(
        campaignId: campaignId,
        objective: CampaignObjective.storeVisits,
        placements: const [AdPlacement.homeCard],
        categories: template.categoryName != null
            ? [template.categoryName!]
            : const [],
      ),
      assets: assets,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    return _repository.upsertCampaign(campaign);
  }

  Future<List<AdCampaign>> getHomeFeatureAdsForSeller(String sellerId) async {
    final all = await _repository.getCampaigns(sellerId: sellerId, limit: 200);
    return all
        .where((c) => c.type == AdCampaignType.homeFeature)
        .toList(growable: false);
  }

  Future<List<AdCampaign>> getApprovedHomeFeatureAds({
    bool includeExpired = false,
  }) async {
    try {
      if (!includeExpired) {
        final fromView = await _fetchApprovedFromActiveView();
        if (fromView.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              'HomeFeatureAdService.getApprovedHomeFeatureAds: '
              'active_home_feature_ads count=${fromView.length}',
            );
          }
          return fromView;
        }
      }

      var query = _client
          .from('campaigns')
          .select('*, campaign_targets(*), campaign_assets(*)')
          .eq('type', AdCampaignType.homeFeature.dbValue)
          .inFilter('status', [
            CampaignStatus.approved.dbValue,
            CampaignStatus.active.dbValue,
          ]);

      if (!includeExpired) {
        final now = DateTime.now().toUtc().toIso8601String();
        query = query.lte('starts_at', now).gte('ends_at', now);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List)
          .map((e) => AdCampaign.fromJson(Map<String, dynamic>.from(e)))
          .where(HomeFeatureAdHelper.isEligibleForHomeDisplay)
          .toList();
    } catch (e) {
      debugPrint('HomeFeatureAdService.getApprovedHomeFeatureAds: $e');
      return [];
    }
  }

  Future<List<AdCampaign>> _fetchApprovedFromActiveView() async {
    try {
      final viewRes = await _client
          .from('active_home_feature_ads')
          .select('*')
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false)
          .limit(20);
      final viewRows = (viewRes as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(growable: false);
      if (viewRows.isEmpty) return const [];

      final ids = viewRows
          .map((row) => row['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      if (ids.isEmpty) return const [];

      final fullRes = await _client
          .from('campaigns')
          .select('*, campaign_targets(*), campaign_assets(*)')
          .inFilter('id', ids);
      final byId = <String, AdCampaign>{};
      for (final raw in fullRes as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        byId[id] = AdCampaign.fromJson(row);
      }

      final campaigns = <AdCampaign>[];
      for (final viewRow in viewRows) {
        final id = viewRow['id']?.toString() ?? '';
        var campaign = byId[id];
        if (campaign == null) {
          campaign = HomeFeatureAdHelper.campaignFromActiveViewRow(viewRow);
          if (kDebugMode && campaign != null) {
            debugPrint(
              'HomeFeatureAdService._fetchApprovedFromActiveView: '
              'view fallback build id=$id',
            );
          }
        }
        if (campaign == null) {
          if (kDebugMode) {
            debugPrint(
              'HomeFeatureAdService._fetchApprovedFromActiveView: '
              'skip id=$id reason=campaign_not_found',
            );
          }
          continue;
        }
        final skipReason = HomeFeatureAdHelper.ineligibleReason(campaign);
        if (skipReason != null) {
          if (kDebugMode) {
            debugPrint(
              'HomeFeatureAdService._fetchApprovedFromActiveView: '
              'skip id=$id store=${campaign.metadata['store_name']} reason=$skipReason',
            );
          }
          continue;
        }
        campaigns.add(campaign);
      }
      return campaigns;
    } catch (e) {
      debugPrint('HomeFeatureAdService._fetchApprovedFromActiveView: $e');
      return const [];
    }
  }

  Future<List<HomeCategoryCardGroup>> loadHomePageGroups({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _groupsCache.read(_groupsCacheKey);
      if (cached != null) return cached;
    }

    final templates = await _templateService.getActiveTemplates();
    final templateById = {for (final t in templates) t.id: t};
    final campaigns = await getApprovedHomeFeatureAds();
    traceAdProduct(
      stage: AdProductTraceStage.adBannerFetchStarted,
      placement: 'home_feature',
    );
    if (kDebugMode) {
      debugPrint(
        'HomeFeatureAdService.loadHomePageGroups: fetched ${campaigns.length} home_feature campaigns',
      );
    }
    if (campaigns.isEmpty) return const [];

    traceAdProduct(
      stage: AdProductTraceStage.adBannerFetchSuccess,
      placement: 'home_feature',
      bannerCount: campaigns.length,
    );

    final storeLookup = await _fetchActiveStoreKeys(
      sellerIds: campaigns.map((c) => c.sellerId).toSet(),
      storeIds: campaigns
          .map((c) => c.storeId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet(),
    );
    if (kDebugMode && storeLookup.failed) {
      debugPrint(
        'HomeFeatureAdService.loadHomePageGroups: store lookup failed, '
        'using permissive seller/store id check',
      );
    }

    final adsByGroupKey = <String, _CategoryBucket>{};
    var skippedInactiveStore = 0;
    var skippedMissingCategory = 0;
    var skippedNoBanner = 0;

    for (final campaign in campaigns) {
      if (campaign.type != AdCampaignType.homeFeature) continue;

      final templateId = HomeFeatureAdHelper.cardTemplateId(campaign);
      final template = _resolveTemplate(templateById, templateId);
      final bannerUrls = HomeFeatureAdHelper.bannerImages(campaign);
      final productIds = HomeFeatureAdHelper.selectedProductIds(campaign);
      final storeName = AdJsonHelper.asString(
        campaign.metadata['store_name'],
        fallback: campaign.name,
      );

      if (kDebugMode) {
        debugPrint(
          'HomeFeatureAdService.loadHomePageGroups: campaign '
          'id=${campaign.id} '
          'store="$storeName" '
          'seller_id=${campaign.sellerId} '
          'store_id=${campaign.storeId ?? '-'} '
          'category_id=${HomeFeatureAdHelper.categoryId(campaign) ?? '-'} '
          'category_name=${HomeFeatureAdHelper.categoryName(campaign) ?? '-'} '
          'card_template_id=${templateId ?? '-'} '
          'banners=${bannerUrls.length} '
          'product_ids=${productIds.length}',
        );
      }

      if (!_isCampaignStoreActive(
        campaign,
        storeLookup.keys,
        lookupFailed: storeLookup.failed,
      )) {
        skippedInactiveStore++;
        if (kDebugMode) {
          debugPrint(
            'HomeFeatureAdService.loadHomePageGroups: skip id=${campaign.id} '
            'store="$storeName" reason=inactive_store',
          );
        }
        continue;
      }

      final grouping = HomeFeatureAdHelper.resolveCategoryGrouping(
        campaign: campaign,
        template: template,
      );
      if (grouping == null) {
        skippedMissingCategory++;
        if (kDebugMode) {
          debugPrint(
            'HomeFeatureAdService.loadHomePageGroups: skip id=${campaign.id} '
            'store="$storeName" reason=category_missing',
          );
        }
        continue;
      }

      if (bannerUrls.isEmpty) {
        skippedNoBanner++;
        if (kDebugMode) {
          debugPrint(
            'HomeFeatureAdService.loadHomePageGroups: skip id=${campaign.id} '
            'store="$storeName" reason=no_banner',
          );
        }
        continue;
      }

      var bucketKey = grouping.key;
      for (final entry in adsByGroupKey.entries) {
        if (entry.value.canonicalLeaf.isNotEmpty &&
            entry.value.canonicalLeaf == grouping.canonicalLeaf) {
          bucketKey = entry.key;
          break;
        }
      }

      final bucket = adsByGroupKey.putIfAbsent(
        bucketKey,
        () => _CategoryBucket(
          displayName: grouping.displayName,
          subtitle: grouping.subtitle,
          canonicalLeaf: grouping.canonicalLeaf,
        ),
      );

      final ad = HomeFeatureDisplayAd(
        campaignId: campaign.id,
        sellerId: campaign.sellerId,
        storeId: campaign.storeId,
        storeName: storeName,
        cardTemplateId: template?.id ?? templateId ?? campaign.id,
        cardTitle: template?.title ?? grouping.subtitle ?? grouping.displayName,
        categoryName: grouping.displayName,
        bannerUrls: bannerUrls,
        productIds: productIds,
        sortOrder: HomeFeatureAdHelper.sortOrder(campaign),
        sortMode: HomeFeatureAdHelper.sortMode(campaign),
        createdAt: campaign.createdAt,
      );
      if (bucket.ads.any((existing) => existing.campaignId == ad.campaignId)) {
        continue;
      }
      bucket.ads.add(ad);
    }

    if (adsByGroupKey.isEmpty) return const [];

    for (final bucket in adsByGroupKey.values) {
      for (var i = 0; i < bucket.ads.length; i++) {
        final ad = bucket.ads[i];
        if (ad.productIds.isEmpty) {
          traceAdProduct(
            stage: AdProductTraceStage.adBannerOnlyNoProductRow,
            placement: 'home_feature',
            category: ad.categoryName,
            subcategory: ad.cardTitle,
            adId: ad.campaignId,
            campaignId: ad.campaignId,
            advertiserName: ad.storeName,
            sellerId: ad.sellerId,
            productIds: const [],
            isBannerOnly: true,
            bannerCount: ad.bannerUrls.length,
          );
          continue;
        }

        traceAdProduct(
          stage: AdProductTraceStage.adProductFetchStarted,
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
          query: 'rpc:get_ad_linked_products_by_ids',
        );

        AdLinkedProductsFetchReport fetchReport;
        try {
          fetchReport = await SupabaseService.instance.fetchAdLinkedProductsReport(
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
            error: e.toString(),
          );
          fetchReport = AdLinkedProductsFetchReport(
            products: const [],
            requestedIdCount: ad.productIds.length,
            rawRpcCount: 0,
            rawSelectCount: 0,
            rawDbCount: 0,
            filteredCount: 0,
            query: 'rpc:get_ad_linked_products_by_ids',
            error: e.toString(),
          );
        }

        final resolved = SupabaseService.instance.orderAdLinkedProducts(
          productIds: ad.productIds,
          products: fetchReport.products,
          maxProducts: HomeFeatureAdHelper.maxProducts,
        );

        if (resolved.isEmpty) {
          traceAdProduct(
            stage: fetchReport.rawDbCount == 0
                ? AdProductTraceStage.adProductFetchEmpty
                : AdProductTraceStage.adProductFilterEmpty,
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
            rawRpcCount: fetchReport.rawRpcCount,
            rawSelectCount: fetchReport.rawSelectCount,
            rawProductCount: fetchReport.rawDbCount,
            filteredProductCount: 0,
            renderedProductCount: 0,
            query: fetchReport.query,
            error: fetchReport.error ?? 'linked_product_ids_not_resolved',
            rejectionReasons: fetchReport.rejectionSummary(),
          );
        } else {
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
            rawRpcCount: fetchReport.rawRpcCount,
            rawSelectCount: fetchReport.rawSelectCount,
            rawProductCount: fetchReport.rawDbCount,
            filteredProductCount: resolved.length,
            renderedProductCount: resolved.length,
            query: fetchReport.query,
          );
        }

        if (kDebugMode && ad.productIds.isNotEmpty && resolved.isEmpty) {
          debugPrint(
            'HomeFeatureAdService.loadHomePageGroups: ad "${ad.storeName}" '
            'campaign=${ad.campaignId} resolvedProducts=0 '
            '(product_ids=${ad.productIds.length} raw_rpc=${fetchReport.rawRpcCount} '
            'raw_select=${fetchReport.rawSelectCount} query=${fetchReport.query} '
            'detail=${fetchReport.rejectionSummary()})',
          );
        } else if (kDebugMode) {
          debugPrint(
            'HomeFeatureAdService.loadHomePageGroups: ad "${ad.storeName}" '
            'resolvedProducts=${resolved.length}',
          );
        }
        bucket.ads[i] = ad.copyWithResolvedProducts(resolved);
      }
    }

    if (kDebugMode) {
      debugPrint(
        'HomeFeatureAdService.loadHomePageGroups: skipped '
        'inactive_store=$skippedInactiveStore '
        'missing_category=$skippedMissingCategory '
        'no_banner=$skippedNoBanner',
      );
    }

    final groups = <HomeCategoryCardGroup>[];
    for (final entry in adsByGroupKey.entries) {
      final bucket = entry.value;
      final allAds = List<HomeFeatureDisplayAd>.from(bucket.ads);
      if (allAds.isEmpty) continue;

      _sortDisplayAds(allAds);
      if (kDebugMode) {
        debugPrint(
          'HomeFeatureAdService.loadHomePageGroups: group key=${entry.key} '
          'title="${bucket.displayName}" ad_count=${allAds.length} '
          'stores=${allAds.map((a) => a.storeName).join(", ")}',
        );
      }

      groups.add(
        HomeCategoryCardGroup(
          categoryName: bucket.displayName,
          cards: [
            HomeCardDisplayGroup(
              templateId: allAds.first.cardTemplateId,
              cardTitle: bucket.subtitle ?? allAds.first.cardTitle,
              templateSortOrder: allAds.first.sortOrder,
              ads: allAds,
            ),
          ],
        ),
      );
    }

    groups.sort((a, b) => a.categoryName.compareTo(b.categoryName));
    if (kDebugMode) {
      debugPrint(
        'HomeFeatureAdService.loadHomePageGroups: category_group_count=${groups.length}',
      );
    }
    if (groups.isNotEmpty && !_hasUnresolvedAdProducts(groups)) {
      _groupsCache.write(_groupsCacheKey, groups);
    }
    return groups;
  }

  static bool _hasUnresolvedAdProducts(List<HomeCategoryCardGroup> groups) {
    for (final group in groups) {
      for (final card in group.cards) {
        for (final ad in card.ads) {
          if (ad.productIds.isNotEmpty && ad.resolvedProducts.isEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static void invalidateHomePageGroupsCache() {
    _groupsCache.invalidate(_groupsCacheKey);
  }

  static HomeCardTemplate? _resolveTemplate(
    Map<String, HomeCardTemplate> templateById,
    String? templateId,
  ) {
    if (templateId == null || templateId.isEmpty) return null;
    final direct = templateById[templateId];
    if (direct != null) return direct;
    for (final entry in templateById.entries) {
      if (entry.key.toLowerCase() == templateId.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  static void sortDisplayAds(List<HomeFeatureDisplayAd> ads) => _sortDisplayAds(ads);

  static void _sortDisplayAds(List<HomeFeatureDisplayAd> ads) {
    ads.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreated.compareTo(aCreated);
    });
  }

  static bool _isCampaignStoreActive(
    AdCampaign campaign,
    Set<String> activeStoreKeys, {
    bool lookupFailed = false,
  }) {
    if (lookupFailed) {
      return campaign.sellerId.isNotEmpty ||
          (campaign.storeId?.isNotEmpty ?? false);
    }
    if (campaign.sellerId.isNotEmpty &&
        activeStoreKeys.contains(campaign.sellerId)) {
      return true;
    }
    final storeId = campaign.storeId;
    return storeId != null &&
        storeId.isNotEmpty &&
        activeStoreKeys.contains(storeId);
  }

  Future<({Set<String> keys, bool failed})> _fetchActiveStoreKeys({
    required Set<String> sellerIds,
    required Set<String> storeIds,
  }) async {
    if (sellerIds.isEmpty && storeIds.isEmpty) {
      return (keys: const <String>{}, failed: false);
    }
    try {
      final keys = <String>{};
      final lookupIds = <String>{
        ...sellerIds,
        ...storeIds,
      }.where((id) => id.isNotEmpty).toList(growable: false);
      if (lookupIds.isEmpty) return (keys: keys, failed: false);

      final res = await _client
          .from('stores')
          .select('seller_id')
          .inFilter('seller_id', lookupIds);
      for (final row in res as List) {
        final sellerId = row['seller_id']?.toString();
        if (sellerId != null && sellerId.isNotEmpty) keys.add(sellerId);
      }
      return (keys: keys, failed: false);
    } catch (e) {
      debugPrint('HomeFeatureAdService._fetchActiveStoreKeys: $e');
      return (keys: const <String>{}, failed: true);
    }
  }

  Future<void> _assertProductsBelongToSeller(
    String sellerId,
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return;
    final res = await _client
        .from('products')
        .select('id')
        .eq('seller_id', sellerId)
        .inFilter('id', productIds);
    final found = (res as List)
        .map((row) => row['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (found.length != productIds.length) {
      throw StateError(
        'Seçilen ürünlerin bir kısmı mağazanıza ait değil veya bulunamadı.',
      );
    }
  }

  Future<void> updateSortOrder(String campaignId, int sortOrder) async {
    try {
      await _client.rpc(
        'update_home_feature_sort_order',
        params: {'p_campaign_id': campaignId, 'p_sort_order': sortOrder},
      );
    } catch (e) {
      debugPrint('HomeFeatureAdService.updateSortOrder fallback: $e');
      final campaign = await _repository.getCampaignById(campaignId);
      if (campaign == null) return;
      final metadata = Map<String, dynamic>.from(campaign.metadata)
        ..['sort_order'] = sortOrder;
      await _repository.upsertCampaign(
        campaign.copyWith(metadata: metadata, updatedAt: DateTime.now()),
      );
    }
  }

  Future<void> enrichWithStoreInfo(List<HomeFeatureDisplayAd> ads) async {
    // Store info enrichment done at widget level via StoreService
  }
}

class _CategoryBucket {
  _CategoryBucket({
    required this.displayName,
    required this.canonicalLeaf,
    this.subtitle,
  });

  final String displayName;
  final String? subtitle;
  final String canonicalLeaf;
  final List<HomeFeatureDisplayAd> ads = [];
}
