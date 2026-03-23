import '../constants/ads_defaults.dart';
import '../enums/ad_enums.dart';
import '../helpers/ad_campaign_helper.dart';
import '../models/ab_test_variant.dart';
import '../models/ad_campaign.dart';
import '../models/ad_metrics.dart';
import '../models/ad_revenue_record.dart';
import '../models/ad_wallet_transaction.dart';
import '../models/campaign_asset.dart';
import '../models/campaign_review.dart';
import '../models/campaign_target.dart';
import '../models/geo_push_trigger.dart';
import '../models/user_interest.dart';
import '../models/user_product_event.dart';

class AdsPreviewDataSource {
  AdsPreviewDataSource({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _seed();
  }

  final DateTime Function() _clock;

  final List<AdCampaign> _campaigns = <AdCampaign>[];
  final List<AdMetrics> _metrics = <AdMetrics>[];
  final List<AdRevenueRecord> _revenueRecords = <AdRevenueRecord>[];
  final List<AdWalletTransaction> _walletTransactions = <AdWalletTransaction>[];
  final List<CampaignReview> _reviews = <CampaignReview>[];
  final List<UserInterest> _interests = <UserInterest>[];
  final List<UserProductEvent> _events = <UserProductEvent>[];
  final List<GeoPushTrigger> _geoTriggers = <GeoPushTrigger>[];
  int _sequence = 0;

  List<AdCampaign> getCampaigns({
    String? sellerId,
    List<CampaignStatus>? statuses,
    AdCampaignType? type,
    CampaignObjective? objective,
    int? limit,
  }) {
    final filtered =
        _campaigns
            .where((campaign) {
              final matchesSeller =
                  sellerId == null || campaign.sellerId == sellerId;
              final matchesStatus =
                  statuses == null || statuses.contains(campaign.status);
              final matchesType = type == null || campaign.type == type;
              final matchesObjective =
                  objective == null || campaign.objective == objective;
              return matchesSeller &&
                  matchesStatus &&
                  matchesType &&
                  matchesObjective;
            })
            .toList(growable: false)
          ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    if (limit == null || filtered.length <= limit) {
      return filtered;
    }
    return filtered.take(limit).toList(growable: false);
  }

  AdCampaign? getCampaignById(String campaignId) {
    for (final campaign in _campaigns) {
      if (campaign.id == campaignId) return campaign;
    }
    return null;
  }

  AdCampaign upsertCampaign(AdCampaign campaign) {
    final index = _campaigns.indexWhere((item) => item.id == campaign.id);
    final normalized = campaign.copyWith(
      updatedAt: _clock(),
      createdAt: campaign.createdAt ?? _clock(),
      remainingBalance: (campaign.totalBudget - campaign.spentAmount).clamp(
        0,
        campaign.totalBudget,
      ),
    );
    if (index >= 0) {
      _campaigns[index] = normalized;
      return normalized;
    }
    _campaigns.add(normalized);
    return normalized;
  }

  void deleteCampaign(String campaignId) {
    _campaigns.removeWhere((item) => item.id == campaignId);
    _metrics.removeWhere((item) => item.campaignId == campaignId);
    _revenueRecords.removeWhere((item) => item.campaignId == campaignId);
    _reviews.removeWhere((item) => item.campaignId == campaignId);
    _geoTriggers.removeWhere((item) => item.campaignId == campaignId);
  }

  AdCampaign? setCampaignStatus(
    String campaignId,
    CampaignStatus status, {
    String? reviewNotes,
  }) {
    final campaign = getCampaignById(campaignId);
    if (campaign == null) return null;
    final updated = campaign.copyWith(
      status: status,
      pausedAt: status == CampaignStatus.paused ? _clock() : campaign.pausedAt,
      approvedAt: status == CampaignStatus.approved
          ? _clock()
          : campaign.approvedAt,
      rejectedAt: status == CampaignStatus.rejected
          ? _clock()
          : campaign.rejectedAt,
      reviewNotes: reviewNotes ?? campaign.reviewNotes,
      updatedAt: _clock(),
    );
    return upsertCampaign(updated);
  }

  List<AdMetrics> getMetrics({
    List<String>? campaignIds,
    DateTime? from,
    DateTime? to,
  }) {
    return _metrics
        .where((item) {
          final matchesCampaign =
              campaignIds == null || campaignIds.contains(item.campaignId);
          final matchesFrom = from == null || !item.date.isBefore(from);
          final matchesTo = to == null || !item.date.isAfter(to);
          return matchesCampaign && matchesFrom && matchesTo;
        })
        .toList(growable: false);
  }

  AdMetrics upsertDailyMetrics(AdMetrics metrics) {
    final day = DateTime(
      metrics.date.year,
      metrics.date.month,
      metrics.date.day,
    );
    final index = _metrics.indexWhere((item) {
      final itemDay = DateTime(item.date.year, item.date.month, item.date.day);
      return item.campaignId == metrics.campaignId && itemDay == day;
    });
    if (index >= 0) {
      _metrics[index] = metrics;
      return metrics;
    }
    _metrics.add(metrics);
    return metrics;
  }

  List<AdRevenueRecord> getRevenueRecords({
    String? sellerId,
    String? campaignId,
    DateTime? from,
    DateTime? to,
  }) {
    return _revenueRecords
        .where((item) {
          final matchesSeller = sellerId == null || item.sellerId == sellerId;
          final matchesCampaign =
              campaignId == null || item.campaignId == campaignId;
          final matchesFrom = from == null || !item.recordedAt.isBefore(from);
          final matchesTo = to == null || !item.recordedAt.isAfter(to);
          return matchesSeller && matchesCampaign && matchesFrom && matchesTo;
        })
        .toList(growable: false);
  }

  List<AdWalletTransaction> getWalletTransactions({
    String? sellerId,
    String? campaignId,
  }) {
    return _walletTransactions
        .where((item) {
          final matchesSeller = sellerId == null || item.sellerId == sellerId;
          final matchesCampaign =
              campaignId == null || item.campaignId == campaignId;
          return matchesSeller && matchesCampaign;
        })
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  AdWalletTransaction addWalletTransaction(AdWalletTransaction transaction) {
    _walletTransactions.add(transaction);
    return transaction;
  }

  AdRevenueRecord addRevenueRecord(AdRevenueRecord record) {
    _revenueRecords.add(record);
    return record;
  }

  List<CampaignReview> getCampaignReviews({
    String? campaignId,
    CampaignReviewStatus? status,
  }) {
    return _reviews
        .where((item) {
          final matchesCampaign =
              campaignId == null || item.campaignId == campaignId;
          final matchesStatus = status == null || item.status == status;
          return matchesCampaign && matchesStatus;
        })
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  CampaignReview addCampaignReview(CampaignReview review) {
    _reviews.add(review);
    return review;
  }

  List<UserInterest> getUserInterests({String? userId}) {
    return _interests
        .where((item) => userId == null || item.userId == userId)
        .toList(growable: false);
  }

  List<UserProductEvent> getUserEvents({String? userId, DateTime? from}) {
    return _events
        .where((item) {
          final matchesUser = userId == null || item.userId == userId;
          final matchesFrom = from == null || !item.createdAt.isBefore(from);
          return matchesUser && matchesFrom;
        })
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  UserProductEvent addUserEvent(UserProductEvent event) {
    _events.add(event);
    return event;
  }

  List<GeoPushTrigger> getGeoPushTriggers({
    String? sellerId,
    String? campaignId,
    bool activeOnly = true,
  }) {
    return _geoTriggers
        .where((item) {
          final matchesSeller = sellerId == null || item.sellerId == sellerId;
          final matchesCampaign =
              campaignId == null || item.campaignId == campaignId;
          final matchesActive = !activeOnly || item.isActive;
          return matchesSeller && matchesCampaign && matchesActive;
        })
        .toList(growable: false);
  }

  GeoPushTrigger upsertGeoPushTrigger(GeoPushTrigger trigger) {
    final index = _geoTriggers.indexWhere((item) => item.id == trigger.id);
    if (index >= 0) {
      _geoTriggers[index] = trigger;
      return trigger;
    }
    _geoTriggers.add(trigger);
    return trigger;
  }

  List<AbTestVariant> getAbTestVariants(String campaignId) {
    return getCampaignById(campaignId)?.abTestVariants ?? const [];
  }

  String nextId(String prefix) {
    _sequence += 1;
    return '$prefix-${_clock().millisecondsSinceEpoch}$_sequence';
  }

  void _seed() {
    if (_campaigns.isNotEmpty) return;
    final now = _clock();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final campaign1Id = 'cmp-product-1';
    final campaign2Id = 'cmp-store-1';
    final campaign3Id = 'cmp-collection-1';
    final campaign4Id = 'cmp-geo-1';

    final campaign1 = AdCampaign(
      id: campaign1Id,
      sellerId: 'seller-1',
      storeId: 'store-101',
      name: 'Premium Hair Dryer Boost',
      description: 'High intent product boost for home and search surfaces.',
      type: AdCampaignType.productBoost,
      objective: CampaignObjective.orders,
      status: CampaignStatus.active,
      billingModel: BillingModel.cpa,
      dailyBudget: 380,
      totalBudget: 5200,
      spentAmount: 1920,
      remainingBalance: 3280,
      bidAmount: 5.1,
      currency: AdsDefaults.defaultCurrency,
      startsAt: startOfToday.subtract(const Duration(days: 12)),
      endsAt: startOfToday.add(const Duration(days: 18)),
      isPremiumPlacementEnabled: true,
      useAiSuggestions: true,
      frequencyCapPerUser: 3,
      target: CampaignTarget(
        id: 'target-1',
        campaignId: campaign1Id,
        objective: CampaignObjective.orders,
        placements: AdCampaignHelper.defaultPlacementsForType(
          AdCampaignType.productBoost,
        ),
        categories: const ['small-appliances', 'hair-care'],
        keywords: const ['hair dryer', 'styling', 'premium care'],
        cityCodes: const ['IST', 'ANK'],
        eventLookbackDays: 21,
        frequencyCapPerDay: 3,
        retargetingWindowDays: 14,
      ),
      assets: [
        CampaignAsset(
          id: 'asset-1',
          campaignId: campaign1Id,
          assetType: AdAssetType.product,
          entityId: 'product-501',
          title: 'Dyson style result without salon visit',
          subtitle: 'Sponsored product',
          mediaUrl: 'https://images.example.com/product-501.jpg',
          placements: [
            AdPlacement.homeFeed,
            AdPlacement.relatedProducts,
            AdPlacement.searchResults,
          ],
          priority: 1,
        ),
      ],
      abTestEnabled: true,
      abTestVariants: [
        AbTestVariant(
          id: 'variant-1a',
          campaignId: campaign1Id,
          name: 'Hero before-after',
          weight: 0.55,
          headline: 'Salon finish at home',
          ctaLabel: 'Discover now',
          isControl: true,
        ),
        AbTestVariant(
          id: 'variant-1b',
          campaignId: campaign1Id,
          name: 'Promo angle',
          weight: 0.45,
          headline: 'Boost your styling routine',
          ctaLabel: 'Shop today',
        ),
      ],
      createdAt: startOfToday.subtract(const Duration(days: 14)),
      updatedAt: now,
    );

    final campaign2 = AdCampaign(
      id: campaign2Id,
      sellerId: 'seller-1',
      storeId: 'store-101',
      name: 'Store Map Visibility Surge',
      description: 'Drive map discovery for users nearby.',
      type: AdCampaignType.storeBoost,
      objective: CampaignObjective.storeVisits,
      status: CampaignStatus.pendingReview,
      billingModel: BillingModel.cpc,
      dailyBudget: 240,
      totalBudget: 2800,
      spentAmount: 620,
      remainingBalance: 2180,
      bidAmount: 3.8,
      currency: AdsDefaults.defaultCurrency,
      startsAt: startOfToday.subtract(const Duration(days: 3)),
      endsAt: startOfToday.add(const Duration(days: 22)),
      frequencyCapPerUser: 2,
      target: CampaignTarget(
        id: 'target-2',
        campaignId: campaign2Id,
        objective: CampaignObjective.storeVisits,
        placements: AdCampaignHelper.defaultPlacementsForType(
          AdCampaignType.storeBoost,
        ),
        cityCodes: const ['IST'],
        radiusMeters: 2500,
        eventLookbackDays: 14,
        frequencyCapPerDay: 2,
        retargetingWindowDays: 10,
      ),
      assets: [
        CampaignAsset(
          id: 'asset-2',
          campaignId: campaign2Id,
          assetType: AdAssetType.store,
          entityId: 'store-101',
          title: 'Visit our flagship showroom',
          subtitle: 'Sponsored store',
          mediaUrl: 'https://images.example.com/store-101.jpg',
          placements: [
            AdPlacement.storeMap,
            AdPlacement.storeSearch,
            AdPlacement.storeList,
          ],
          priority: 1,
        ),
      ],
      createdAt: startOfToday.subtract(const Duration(days: 5)),
      updatedAt: now,
    );

    final campaign3 = AdCampaign(
      id: campaign3Id,
      sellerId: 'seller-2',
      storeId: 'store-205',
      name: 'Spring Collection Discovery',
      description: 'Promote curated seasonal collection on discovery surfaces.',
      type: AdCampaignType.collectionBoost,
      objective: CampaignObjective.collectionDiscovery,
      status: CampaignStatus.active,
      billingModel: BillingModel.cpc,
      dailyBudget: 190,
      totalBudget: 2100,
      spentAmount: 860,
      remainingBalance: 1240,
      bidAmount: 2.9,
      currency: AdsDefaults.defaultCurrency,
      startsAt: startOfToday.subtract(const Duration(days: 9)),
      endsAt: startOfToday.add(const Duration(days: 12)),
      frequencyCapPerUser: 4,
      target: CampaignTarget(
        id: 'target-3',
        campaignId: campaign3Id,
        objective: CampaignObjective.collectionDiscovery,
        placements: AdCampaignHelper.defaultPlacementsForType(
          AdCampaignType.collectionBoost,
        ),
        categories: const ['spring', 'home-decor'],
        keywords: const ['spring collection', 'decor refresh'],
        cityCodes: const ['IST', 'IZM'],
      ),
      assets: [
        CampaignAsset(
          id: 'asset-3',
          campaignId: campaign3Id,
          assetType: AdAssetType.collection,
          entityId: 'collection-901',
          title: 'Spring ready homes',
          subtitle: 'Sponsored collection',
          mediaUrl: 'https://images.example.com/collection-901.jpg',
          placements: [
            AdPlacement.homeFeed,
            AdPlacement.productDetail,
            AdPlacement.explore,
          ],
          priority: 1,
        ),
      ],
      createdAt: startOfToday.subtract(const Duration(days: 11)),
      updatedAt: now,
    );

    final campaign4 = AdCampaign(
      id: campaign4Id,
      sellerId: 'seller-2',
      storeId: 'store-205',
      name: 'Nearby Reminder Push',
      description: 'Geo-triggered push for loyal and high intent users.',
      type: AdCampaignType.geoPush,
      objective: CampaignObjective.driveNearbyTraffic,
      status: CampaignStatus.approved,
      billingModel: BillingModel.flat,
      dailyBudget: 300,
      totalBudget: 3000,
      spentAmount: 900,
      remainingBalance: 2100,
      bidAmount: 4.0,
      currency: AdsDefaults.defaultCurrency,
      startsAt: startOfToday.subtract(const Duration(days: 6)),
      endsAt: startOfToday.add(const Duration(days: 20)),
      target: CampaignTarget(
        id: 'target-4',
        campaignId: campaign4Id,
        objective: CampaignObjective.driveNearbyTraffic,
        placements: const [AdPlacement.pushNotification],
        cityCodes: const ['IST'],
        radiusMeters: 1200,
        eventLookbackDays: 14,
        frequencyCapPerDay: 1,
        retargetingWindowDays: 7,
      ),
      assets: [
        CampaignAsset(
          id: 'asset-4',
          campaignId: campaign4Id,
          assetType: AdAssetType.notification,
          entityId: 'store-205',
          title: 'You are close to your favorite store',
          subtitle: 'Limited offer nearby',
          placements: [AdPlacement.pushNotification],
          priority: 1,
        ),
      ],
      createdAt: startOfToday.subtract(const Duration(days: 8)),
      updatedAt: now,
    );

    _campaigns.addAll([campaign1, campaign2, campaign3, campaign4]);

    for (var day = 0; day < 14; day += 1) {
      final date = startOfToday.subtract(Duration(days: day));
      _metrics.addAll([
        AdMetrics(
          campaignId: campaign1Id,
          date: date,
          impressions: 880 + (day * 18),
          clicks: 86 + day,
          detailViews: 54 + day,
          favorites: 18 + (day % 4),
          addToCarts: 24 + (day % 5),
          orders: 9 + (day % 3),
          conversions: 11 + (day % 3),
          uniqueUsers: 410 + (day * 7),
          spend: 118 + (day * 4.2),
          revenue: 540 + (day * 17),
        ),
        AdMetrics(
          campaignId: campaign2Id,
          date: date,
          impressions: 620 + (day * 12),
          clicks: 43 + (day % 5),
          storeVisits: 25 + (day % 4),
          conversions: 7 + (day % 2),
          uniqueUsers: 280 + (day * 5),
          spend: 75 + (day * 2.6),
          revenue: 220 + (day * 9),
        ),
        AdMetrics(
          campaignId: campaign3Id,
          date: date,
          impressions: 710 + (day * 14),
          clicks: 57 + (day % 6),
          detailViews: 29 + (day % 5),
          collectionOpens: 34 + (day % 4),
          conversions: 9 + (day % 3),
          uniqueUsers: 320 + (day * 6),
          spend: 92 + (day * 2.2),
          revenue: 310 + (day * 11),
        ),
        AdMetrics(
          campaignId: campaign4Id,
          date: date,
          impressions: 190 + (day * 4),
          clicks: 22 + (day % 3),
          notificationsSent: 66 + (day % 6),
          notificationsOpened: 19 + (day % 4),
          storeVisits: 11 + (day % 3),
          conversions: 5 + (day % 2),
          uniqueUsers: 88 + (day * 2),
          spend: 48 + (day * 1.3),
          revenue: 175 + (day * 6),
        ),
      ]);
    }

    _walletTransactions.addAll([
      AdWalletTransaction(
        id: 'wallet-1',
        sellerId: 'seller-1',
        type: WalletTransactionType.topUp,
        status: WalletTransactionStatus.succeeded,
        amount: 4000,
        balanceBefore: 1200,
        balanceAfter: 5200,
        reference: 'iban-topup-001',
        note: 'Initial ad budget load',
        createdAt: startOfToday.subtract(const Duration(days: 16)),
      ),
      AdWalletTransaction(
        id: 'wallet-2',
        sellerId: 'seller-1',
        campaignId: campaign1Id,
        type: WalletTransactionType.spend,
        status: WalletTransactionStatus.succeeded,
        amount: 1920,
        balanceBefore: 5200,
        balanceAfter: 3280,
        reference: campaign1Id,
        note: 'Campaign spend sync',
        createdAt: startOfToday.subtract(const Duration(days: 1)),
      ),
      AdWalletTransaction(
        id: 'wallet-3',
        sellerId: 'seller-2',
        type: WalletTransactionType.topUp,
        status: WalletTransactionStatus.succeeded,
        amount: 2500,
        balanceBefore: 900,
        balanceAfter: 3400,
        reference: 'iban-topup-002',
        note: 'Collection campaign top-up',
        createdAt: startOfToday.subtract(const Duration(days: 10)),
      ),
    ]);

    _revenueRecords.addAll([
      AdRevenueRecord(
        id: 'revenue-1',
        campaignId: campaign1Id,
        sellerId: 'seller-1',
        walletTransactionId: 'wallet-2',
        grossAmount: 1920,
        netAmount: 1627,
        taxAmount: 173,
        platformFee: 120,
        currency: AdsDefaults.defaultCurrency,
        recordedAt: startOfToday.subtract(const Duration(days: 1)),
        sourceStatus: 'approved',
      ),
      AdRevenueRecord(
        id: 'revenue-2',
        campaignId: campaign3Id,
        sellerId: 'seller-2',
        grossAmount: 860,
        netAmount: 724,
        taxAmount: 77,
        platformFee: 59,
        currency: AdsDefaults.defaultCurrency,
        recordedAt: startOfToday.subtract(const Duration(days: 2)),
        sourceStatus: 'approved',
      ),
      AdRevenueRecord(
        id: 'revenue-3',
        campaignId: campaign2Id,
        sellerId: 'seller-1',
        grossAmount: 620,
        netAmount: 0,
        taxAmount: 0,
        platformFee: 0,
        currency: AdsDefaults.defaultCurrency,
        recordedAt: startOfToday,
        sourceStatus: 'pending',
      ),
    ]);

    _reviews.addAll([
      CampaignReview(
        id: 'review-1',
        campaignId: campaign2Id,
        sellerId: 'seller-1',
        reviewerId: 'admin-1',
        status: CampaignReviewStatus.pending,
        note: 'Awaiting manual map placement validation.',
        reasons: const ['Map radius exceeds default whitelist threshold'],
        createdAt: startOfToday.subtract(const Duration(hours: 12)),
      ),
      CampaignReview(
        id: 'review-2',
        campaignId: campaign1Id,
        sellerId: 'seller-1',
        reviewerId: 'admin-1',
        status: CampaignReviewStatus.approved,
        note: 'Creative and product title comply with policy.',
        createdAt: startOfToday.subtract(const Duration(days: 12)),
        reviewedAt: startOfToday.subtract(const Duration(days: 12)),
      ),
    ]);

    _interests.addAll([
      UserInterest(
        userId: 'user-1',
        interestKey: 'hair-care',
        interestType: 'category',
        affinityScore: 0.91,
        sourceEventCount: 18,
        lastInteractionAt: startOfToday.subtract(const Duration(hours: 4)),
      ),
      UserInterest(
        userId: 'user-1',
        interestKey: 'small-appliances',
        interestType: 'category',
        affinityScore: 0.74,
        sourceEventCount: 9,
        lastInteractionAt: startOfToday.subtract(const Duration(days: 1)),
      ),
      UserInterest(
        userId: 'user-1',
        interestKey: 'spring',
        interestType: 'collection',
        affinityScore: 0.56,
        sourceEventCount: 6,
        lastInteractionAt: startOfToday.subtract(const Duration(days: 2)),
      ),
    ]);

    _events.addAll([
      UserProductEvent(
        id: 'event-1',
        userId: 'user-1',
        productId: 'product-501',
        storeId: 'store-101',
        eventType: UserEventType.detailView,
        sourcePlacement: AdPlacement.searchResults,
        campaignId: campaign1Id,
        cityCode: 'IST',
        createdAt: startOfToday.subtract(const Duration(hours: 3)),
      ),
      UserProductEvent(
        id: 'event-2',
        userId: 'user-1',
        productId: 'product-501',
        storeId: 'store-101',
        eventType: UserEventType.addToCart,
        campaignId: campaign1Id,
        cityCode: 'IST',
        createdAt: startOfToday.subtract(const Duration(hours: 1)),
      ),
      UserProductEvent(
        id: 'event-3',
        userId: 'user-1',
        collectionId: 'collection-901',
        storeId: 'store-205',
        eventType: UserEventType.collectionOpen,
        sourcePlacement: AdPlacement.explore,
        campaignId: campaign3Id,
        cityCode: 'IST',
        createdAt: startOfToday.subtract(const Duration(days: 2)),
      ),
    ]);

    _geoTriggers.addAll([
      GeoPushTrigger(
        id: 'geo-1',
        campaignId: campaign4Id,
        sellerId: 'seller-2',
        storeId: 'store-205',
        title: 'You are 10 minutes away',
        body: 'Drop by today and see the latest collection.',
        radiusMeters: AdsDefaults.defaultGeoRadiusMeters,
        cooldownHours: AdsDefaults.defaultGeoCooldownHours,
        maxSendsPerWeek: AdsDefaults.defaultGeoWeeklySendCap,
        triggerType: GeoTriggerType.wishlistNearby,
        targetCityCodes: const ['IST'],
        productIds: const ['product-811', 'product-815'],
        metadata: const {'store_latitude': 41.0422, 'store_longitude': 29.0083},
      ),
    ]);
  }
}
