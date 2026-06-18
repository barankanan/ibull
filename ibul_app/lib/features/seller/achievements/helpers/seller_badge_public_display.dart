import '../data/seller_badge_definitions.dart';
import '../models/seller_badge_models.dart';
import '../services/seller_badge_progress_resolver.dart';
import '../services/seller_featured_badge_repository.dart';

class SellerBadgePublicDisplay {
  const SellerBadgePublicDisplay._();

  static SellerBadgeStoreMetrics metricsFromBusinessMap(
    Map<String, dynamic> business, {
    List<String> featuredBadgeIds = const [],
  }) {
    return SellerBadgeStoreMetrics(
      sellerId: business['seller_id']?.toString() ??
          business['id']?.toString() ??
          '',
      followerCount: _asInt(business['follower_count']),
      productCount: _asInt(business['product_count']),
      completedOrderCount: _asInt(business['completed_order_count']),
      positiveReviewCount: _asInt(business['positive_review_count']),
      averageRating: _asDouble(business['rating']),
      profileComplete: business['profile_complete'] == true,
      hasLogo: (business['logo_url']?.toString().trim().isNotEmpty ?? false),
      hasDescription:
          (business['description']?.toString().trim().isNotEmpty ?? false),
      hasCategory: (business['category']?.toString().trim().isNotEmpty ?? false),
      hasContactInfo: business['has_contact_info'] == true,
      hasRegionInfo:
          (business['city']?.toString().trim().isNotEmpty ?? false) ||
          (business['district']?.toString().trim().isNotEmpty ?? false),
      storeCreatedAt: DateTime.tryParse(
        business['created_at']?.toString() ?? '',
      ),
      featuredBadgeIds: featuredBadgeIds,
      isBrandVerified: business['is_brand_verified'] == true,
    );
  }

  static List<SellerBadgeProgress> mapPopupBadges(
    SellerBadgeStoreMetrics metrics,
  ) {
    return _selectDisplayBadges(
      metrics: metrics,
      maxCount: SellerFeaturedBadgeRepository.maxMapPopupBadges,
    );
  }

  static List<SellerBadgeProgress> profileBadges(
    SellerBadgeStoreMetrics metrics,
  ) {
    return _selectDisplayBadges(
      metrics: metrics,
      maxCount: SellerFeaturedBadgeRepository.maxProfileBadges,
    );
  }

  static List<SellerBadgeProgress> _selectDisplayBadges({
    required SellerBadgeStoreMetrics metrics,
    required int maxCount,
  }) {
    final all = SellerBadgeProgressResolver.resolveAll(metrics);
    final earned = all
        .where((badge) => badge.status == SellerBadgeStatus.earned)
        .toList(growable: false);

    if (earned.isEmpty) return const [];

    final featured = <SellerBadgeProgress>[];
    for (final badgeId in metrics.featuredBadgeIds) {
      final match = earned.where((b) => b.definition.badgeId == badgeId);
      if (match.isNotEmpty) {
        featured.add(match.first);
      }
      if (featured.length >= maxCount) break;
    }
    if (featured.isNotEmpty) return featured;

    final publicEarned = earned
        .where((badge) => badge.definition.publiclyVerifiable)
        .toList(growable: false);
    publicEarned.sort(_badgePriorityCompare);
    return publicEarned.take(maxCount).toList(growable: false);
  }

  static int _badgePriorityCompare(
    SellerBadgeProgress a,
    SellerBadgeProgress b,
  ) {
    final levelDiff =
        _levelRank(b.definition.level) - _levelRank(a.definition.level);
    if (levelDiff != 0) return levelDiff;
    return b.progressCurrent.compareTo(a.progressCurrent);
  }

  static int _levelRank(SellerBadgeLevel level) {
    switch (level) {
      case SellerBadgeLevel.bronze:
        return 1;
      case SellerBadgeLevel.silver:
        return 2;
      case SellerBadgeLevel.gold:
        return 3;
      case SellerBadgeLevel.diamond:
        return 4;
      case SellerBadgeLevel.verified:
        return 5;
    }
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool isWelcomeSupportActive(SellerBadgeStoreMetrics metrics) {
    return metrics.qualifiesAsNewSeller;
  }

  static SellerBadgeDefinition get welcomeSupportDefinition {
    return sellerBadgeDefinitionById(sellerWelcomeSupportProgramId)!;
  }
}
