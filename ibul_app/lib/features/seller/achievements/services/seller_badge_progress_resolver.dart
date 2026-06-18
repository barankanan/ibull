import '../data/seller_badge_definitions.dart';
import '../models/seller_badge_models.dart';

class SellerBadgeProgressResolver {
  const SellerBadgeProgressResolver._();

  static List<SellerBadgeProgress> resolveAll(SellerBadgeStoreMetrics metrics) {
    if (metrics.metricsLoadFailed) {
      return kSellerBadgeDefinitions
          .where((definition) => !definition.isSupportProgram)
          .map(
            (definition) => SellerBadgeProgress(
              definition: definition,
              status: SellerBadgeStatus.error,
              statusDetail: 'Mağaza verileri yüklenemedi',
              canRetry: true,
            ),
          )
          .toList(growable: false);
    }

    return kSellerBadgeDefinitions
        .where((definition) => !definition.isSupportProgram)
        .map((definition) => _resolve(definition, metrics))
        .toList(growable: false);
  }

  static SellerBadgeProgress? resolveById(
    String badgeId,
    SellerBadgeStoreMetrics metrics,
  ) {
    final definition = sellerBadgeDefinitionById(badgeId);
    if (definition == null || definition.isSupportProgram) return null;
    if (metrics.metricsLoadFailed) {
      return SellerBadgeProgress(
        definition: definition,
        status: SellerBadgeStatus.error,
        statusDetail: 'Mağaza verileri yüklenemedi',
        canRetry: true,
      );
    }
    return _resolve(definition, metrics);
  }

  static SellerBadgeProgress _resolve(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    switch (definition.metricType) {
      case SellerBadgeMetricType.supportProgram:
        return SellerBadgeProgress(
          definition: definition,
          status: SellerBadgeStatus.comingSoon,
        );
      case SellerBadgeMetricType.profileComplete:
        return _resolveProfileBadge(definition, metrics);
      case SellerBadgeMetricType.productCount:
        return _resolveCountBadge(
          definition,
          current: metrics.productCount,
          target: definition.progressTarget,
        );
      case SellerBadgeMetricType.followerCount:
        return _resolveCountBadge(
          definition,
          current: metrics.followerCount,
          target: definition.progressTarget,
        );
      case SellerBadgeMetricType.completedOrders:
        return _resolveOrderBadge(definition, metrics);
      case SellerBadgeMetricType.onTimeShippingRate:
      case SellerBadgeMetricType.packagingScore:
      case SellerBadgeMetricType.responseRate:
        return _unavailableTelemetryBadge(definition);
      case SellerBadgeMetricType.reviewScore:
        return _resolveReviewBadge(definition, metrics);
      case SellerBadgeMetricType.regionRank:
        return _resolveRegionRankBadge(definition, metrics);
      case SellerBadgeMetricType.storeAgeDays:
        return SellerBadgeProgress(
          definition: definition,
          status: SellerBadgeStatus.comingSoon,
        );
      case SellerBadgeMetricType.storeVerification:
        return _resolveVerificationBadge(definition, metrics);
    }
  }

  static SellerBadgeProgress _resolveVerificationBadge(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    return SellerBadgeProgress(
      definition: definition,
      status: metrics.isBrandVerified
          ? SellerBadgeStatus.earned
          : SellerBadgeStatus.locked,
      progressCurrent: metrics.isBrandVerified ? 1 : 0,
      progressTarget: 1,
      statusDetail: metrics.isBrandVerified
          ? null
          : 'Marka onay başvurunuz İBUL tarafından onaylandığında kazanılır',
    );
  }

  static SellerBadgeProgress _unavailableTelemetryBadge(
    SellerBadgeDefinition definition,
  ) {
    return SellerBadgeProgress(
      definition: definition,
      status: SellerBadgeStatus.unavailable,
      progressCurrent: 0,
      progressTarget: definition.progressTarget,
      statusDetail: 'Bu rozet için veri kaynağı henüz hazır değil',
    );
  }

  static SellerBadgeProgress _resolveProfileBadge(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    if (definition.badgeId == 'region_joined') {
      return _resolveBooleanBadge(
        definition,
        earned: metrics.hasRegionInfo,
      );
    }

    if (definition.badgeId == 'new_seller') {
      final checklist = sellerStoreReadyChecklist(metrics);
      final profileDone = metrics.newSellerProfileComplete;
      final productDone = metrics.productCount >= 1;
      final earned = metrics.qualifiesForNewSellerBadge;

      return SellerBadgeProgress(
        definition: definition,
        status: earned
            ? SellerBadgeStatus.earned
            : (profileDone || productDone
                  ? SellerBadgeStatus.inProgress
                  : SellerBadgeStatus.locked),
        progressCurrent: earned ? 1 : 0,
        progressTarget: 1,
        checklistItems: [
          ...checklist,
          SellerBadgeChecklistItem(
            label: 'En az 1 aktif ürün',
            completed: productDone,
          ),
        ],
      );
    }

    if (definition.badgeId == 'store_ready') {
      final checklist = sellerStoreReadyChecklist(metrics);
      final completed = checklist.where((item) => item.completed).length;
      final target = checklist.length;
      final earned = completed >= target;

      return SellerBadgeProgress(
        definition: definition,
        status: earned
            ? SellerBadgeStatus.earned
            : (completed > 0
                  ? SellerBadgeStatus.inProgress
                  : SellerBadgeStatus.locked),
        progressCurrent: completed,
        progressTarget: target,
        checklistItems: checklist,
      );
    }

    final profileScore = <bool>[
      metrics.hasLogo,
      metrics.hasDescription,
      metrics.hasCategory,
      metrics.hasContactInfo,
    ];
    final completed = profileScore.where((value) => value).length;
    final target = profileScore.length;
    final earned = completed >= target;

    return SellerBadgeProgress(
      definition: definition,
      status: earned
          ? SellerBadgeStatus.earned
          : (completed > 0
                ? SellerBadgeStatus.inProgress
                : SellerBadgeStatus.locked),
      progressCurrent: completed,
      progressTarget: target,
    );
  }

  static SellerBadgeProgress _resolveOrderBadge(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    final current = metrics.completedOrderCount;
    final target = definition.progressTarget;
    final earned = current >= target;
    if (definition.badgeId == 'diamond_seller' && earned) {
      final ratingOk = metrics.averageRating >= 4.5;
      return SellerBadgeProgress(
        definition: definition,
        status: ratingOk ? SellerBadgeStatus.earned : SellerBadgeStatus.inProgress,
        progressCurrent: current,
        progressTarget: target,
        statusDetail: ratingOk
            ? null
            : 'Sipariş hedefi tamam; ortalama puan 4.5+ olmalı',
      );
    }
    return _resolveCountBadge(
      definition,
      current: current,
      target: target,
    );
  }

  static SellerBadgeProgress _resolveReviewBadge(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    if (definition.badgeId == 'first_review') {
      return _resolveCountBadge(
        definition,
        current: metrics.positiveReviewCount,
        target: 1,
      );
    }
    if (definition.badgeId == 'customer_favorite') {
      return _resolveCountBadge(
        definition,
        current: metrics.positiveReviewCount,
        target: definition.progressTarget,
      );
    }
    if (definition.badgeId == 'reliable_seller') {
      if (metrics.averageRating <= 0 && metrics.positiveReviewCount == 0) {
        return SellerBadgeProgress(
          definition: definition,
          status: SellerBadgeStatus.insufficientData,
          progressCurrent: 0,
          progressTarget: definition.progressTarget,
          statusDetail: 'Henüz yeterli veri oluşmadı',
        );
      }
      final score = (metrics.averageRating * 10).round();
      final earned = metrics.averageRating >= 4.5;
      return SellerBadgeProgress(
        definition: definition,
        status: earned
            ? SellerBadgeStatus.earned
            : SellerBadgeStatus.inProgress,
        progressCurrent: score,
        progressTarget: 45,
      );
    }
    if (definition.badgeId == 'five_star_experience') {
      if (metrics.positiveReviewCount < 100) {
        return SellerBadgeProgress(
          definition: definition,
          status: SellerBadgeStatus.insufficientData,
          progressCurrent: metrics.positiveReviewCount,
          progressTarget: 100,
          statusDetail:
              'Son 100 değerlendirme için henüz yeterli veri oluşmadı (${metrics.positiveReviewCount}/100)',
        );
      }
      final score = (metrics.averageRating * 10).round();
      final earned = metrics.averageRating >= 4.8;
      return SellerBadgeProgress(
        definition: definition,
        status: earned
            ? SellerBadgeStatus.earned
            : SellerBadgeStatus.inProgress,
        progressCurrent: score,
        progressTarget: 48,
      );
    }
    return SellerBadgeProgress(
      definition: definition,
      status: SellerBadgeStatus.unavailable,
      statusDetail: 'Bu rozet için veri kaynağı henüz hazır değil',
    );
  }

  static SellerBadgeProgress _resolveRegionRankBadge(
    SellerBadgeDefinition definition,
    SellerBadgeStoreMetrics metrics,
  ) {
    if (!metrics.hasRegionInfo) {
      return SellerBadgeProgress(
        definition: definition,
        status: SellerBadgeStatus.locked,
        progressCurrent: 0,
        progressTarget: 1,
        statusDetail: 'Önce bölge bilgilerini tamamla',
      );
    }
    return SellerBadgeProgress(
      definition: definition,
      status: SellerBadgeStatus.unavailable,
      progressCurrent: 0,
      progressTarget: definition.progressTarget,
      statusDetail: 'Bu rozet için veri kaynağı henüz hazır değil',
    );
  }

  static SellerBadgeProgress _resolveBooleanBadge(
    SellerBadgeDefinition definition, {
    required bool earned,
  }) {
    return SellerBadgeProgress(
      definition: definition,
      status: earned ? SellerBadgeStatus.earned : SellerBadgeStatus.locked,
      progressCurrent: earned ? 1 : 0,
      progressTarget: 1,
    );
  }

  static SellerBadgeProgress _resolveCountBadge(
    SellerBadgeDefinition definition, {
    required int current,
    required int target,
  }) {
    final earned = current >= target;
    return SellerBadgeProgress(
      definition: definition,
      status: earned
          ? SellerBadgeStatus.earned
          : (current > 0 ? SellerBadgeStatus.inProgress : SellerBadgeStatus.locked),
      progressCurrent: current.clamp(0, target),
      progressTarget: target,
    );
  }
}
