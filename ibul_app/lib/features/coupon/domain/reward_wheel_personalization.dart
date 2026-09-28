import 'coupon_campaign.dart';
import 'coupon_enums.dart';
import 'coupon_models.dart';
import 'reward_wheel_probability.dart';

class RewardWheelSignalSnapshot {
  const RewardWheelSignalSnapshot({
    this.categoryTokens = const {},
    this.storeIds = const {},
    this.productIds = const {},
  });

  final Set<String> categoryTokens;
  final Set<String> storeIds;
  final Set<String> productIds;

  bool get isEmpty =>
      categoryTokens.isEmpty && storeIds.isEmpty && productIds.isEmpty;

  factory RewardWheelSignalSnapshot.fromTokens({
    Iterable<String> categories = const [],
    Iterable<String> storeIds = const [],
    Iterable<String> productIds = const [],
  }) {
    String norm(String value) => value.trim().toLowerCase();
    return RewardWheelSignalSnapshot(
      categoryTokens: {
        for (final item in categories)
          if (norm(item).isNotEmpty) norm(item),
      },
      storeIds: {
        for (final item in storeIds)
          if (item.trim().isNotEmpty) item.trim(),
      },
      productIds: {
        for (final item in productIds)
          if (item.trim().isNotEmpty) item.trim(),
      },
    );
  }
}

/// Relevance picks which rewards appear. Probability stays admin-owned.
abstract final class RewardWheelPersonalization {
  static bool isCouponEligible(CouponCampaign campaign, {DateTime? now}) {
    if (campaign.approvalStatus != CouponApprovalStatus.approved) return false;
    if (campaign.paused) return false;
    final current = now ?? DateTime.now().toUtc();
    if (current.isBefore(campaign.startsAt.toUtc())) return false;
    if (current.isAfter(campaign.endsAt.toUtc())) return false;
    final quota = campaign.totalUsageLimit;
    if (quota != null && campaign.usedCount >= quota) return false;
    if (quota != null && campaign.claimCount >= quota) return false;
    return true;
  }

  static int relevanceScore({
    required RewardWheelItem item,
    CouponCampaign? campaign,
    required RewardWheelSignalSnapshot signals,
  }) {
    if (item.isNoPrize) return 1;
    if (campaign == null || signals.isEmpty) return 0;
    var score = 0;
    final haystack = [
      item.label,
      campaign.name,
      campaign.code,
      ...campaign.categoryNames,
    ].join(' ').toLowerCase();
    for (final token in signals.categoryTokens) {
      if (token.length < 3) continue;
      if (haystack.contains(token)) score += 3;
    }
    for (final name in campaign.categoryNames) {
      if (signals.categoryTokens.contains(name.trim().toLowerCase())) {
        score += 2;
      }
    }
    final storeId = campaign.storeId ?? campaign.sellerId;
    if (storeId != null && signals.storeIds.contains(storeId)) score += 2;
    for (final productId in campaign.productIds) {
      if (signals.productIds.contains(productId)) score += 2;
    }
    return score;
  }

  /// Returns the items the user should see/spin.
  /// Dropped probability is added to "try again" — other bps are unchanged.
  static List<RewardWheelItem> compose({
    required List<RewardWheelItem> items,
    Map<String, CouponCampaign> campaigns = const {},
    RewardWheelSignalSnapshot signals = const RewardWheelSignalSnapshot(),
    bool useGlobalPool = true,
    DateTime? now,
  }) {
    final eligible = <RewardWheelItem>[];
    for (final item in items) {
      if (!item.isActive) continue;
      if (item.isNoPrize) {
        eligible.add(item);
        continue;
      }
      final campaign = item.campaignId == null
          ? null
          : campaigns[item.campaignId];
      if (campaign == null) continue;
      if (!isCouponEligible(campaign, now: now)) continue;
      eligible.add(item);
    }

    if (eligible.isEmpty) return const [];

    List<RewardWheelItem> selected;
    if (useGlobalPool || signals.isEmpty) {
      selected = eligible;
    } else {
      final scored = [
        for (final item in eligible)
          (
            item,
            relevanceScore(
              item: item,
              campaign: item.campaignId == null
                  ? null
                  : campaigns[item.campaignId],
              signals: signals,
            ),
          ),
      ];
      final relevant = scored
          .where((entry) => entry.$1.isNoPrize || entry.$2 > 0)
          .map((entry) => entry.$1)
          .toList();
      final hasCoupon = relevant.any((item) => !item.isNoPrize);
      selected = hasCoupon ? relevant : eligible;
    }

    final selectedIds = selected.map((item) => identityOf(item)).toSet();
    final droppedBps = items
        .where((item) => !selectedIds.contains(identityOf(item)))
        .fold<int>(0, (sum, item) => sum + item.probabilityBps);

    final noPrizeIndex = selected.indexWhere((item) => item.isNoPrize);
    if (droppedBps <= 0 || noPrizeIndex < 0) return selected;

    return [
      for (var i = 0; i < selected.length; i++)
        if (i == noPrizeIndex)
          RewardWheelItem(
            id: selected[i].id,
            campaignId: selected[i].campaignId,
            label: selected[i].label,
            isNoPrize: true,
            probabilityBps:
                (selected[i].probabilityBps + droppedBps).clamp(
                  0,
                  RewardWheelProbability.fullBps,
                ),
            sortOrder: selected[i].sortOrder,
            colorHex: selected[i].colorHex,
            isActive: selected[i].isActive,
          )
        else
          selected[i],
    ];
  }

  static String identityOf(RewardWheelItem item) =>
      item.id ??
      '${item.campaignId ?? 'none'}-${item.label}-${item.sortOrder}';
}
