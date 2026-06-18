import 'package:flutter/material.dart';

enum SellerBadgeLevel { bronze, silver, gold, diamond, verified }

enum SellerBadgeStatus {
  locked,
  inProgress,
  earned,
  comingSoon,
  unavailable,
  insufficientData,
  error,
}

enum SellerBadgeCategory {
  onboarding,
  followers,
  orders,
  shippingSpeed,
  packagingQuality,
  messageResponse,
  reviews,
  region,
  verification,
}

enum SellerBadgeMetricType {
  profileComplete,
  productCount,
  followerCount,
  completedOrders,
  onTimeShippingRate,
  packagingScore,
  responseRate,
  reviewScore,
  regionRank,
  storeAgeDays,
  supportProgram,
  storeVerification,
}

/// Mağaza profili tamamlama yönlendirmesi — satıcı paneli Mağaza modülü.
enum SellerStoreProfileFocus {
  logo,
  description,
  category,
  contact,
  region,
  cover,
}

class SellerBadgeDefinition {
  const SellerBadgeDefinition({
    required this.badgeId,
    required this.title,
    required this.description,
    required this.category,
    required this.level,
    required this.requirementLabel,
    required this.metricType,
    required this.icon,
    this.progressTarget = 1,
    this.premiumGlow = false,
    this.publiclyVerifiable = false,
    this.isSupportProgram = false,
    this.regionScoped = false,
    this.howToComplete,
    this.dataSourceLabel,
  });

  final String badgeId;
  final String title;
  final String description;
  final SellerBadgeCategory category;
  final SellerBadgeLevel level;
  final String requirementLabel;
  final SellerBadgeMetricType metricType;
  final IconData icon;
  final int progressTarget;
  final bool premiumGlow;
  final bool publiclyVerifiable;
  final bool isSupportProgram;
  final bool regionScoped;
  final String? howToComplete;
  final String? dataSourceLabel;
}

class SellerBadgeChecklistItem {
  const SellerBadgeChecklistItem({
    required this.label,
    required this.completed,
    this.focus,
  });

  final String label;
  final bool completed;
  final SellerStoreProfileFocus? focus;
}

class SellerBadgeProgress {
  const SellerBadgeProgress({
    required this.definition,
    required this.status,
    this.progressCurrent = 0,
    this.progressTarget = 1,
    this.earnedAt,
    this.isFeaturedOnProfile = false,
    this.statusDetail,
    this.checklistItems = const [],
    this.canRetry = false,
  });

  final SellerBadgeDefinition definition;
  final SellerBadgeStatus status;
  final int progressCurrent;
  final int progressTarget;
  final DateTime? earnedAt;
  final bool isFeaturedOnProfile;
  final String? statusDetail;
  final List<SellerBadgeChecklistItem> checklistItems;
  final bool canRetry;

  double get progressRatio {
    if (progressTarget <= 0) return 0;
    return (progressCurrent / progressTarget).clamp(0.0, 1.0);
  }

  bool get allowsPremiumGlow {
    if (status != SellerBadgeStatus.earned) return false;
    if (definition.badgeId == 'new_seller') return false;
    if (definition.badgeId == 'verified_store' ||
        definition.level == SellerBadgeLevel.verified) {
      return true;
    }
    if (definition.level == SellerBadgeLevel.bronze) return false;
    return definition.premiumGlow ||
        definition.level == SellerBadgeLevel.gold ||
        definition.level == SellerBadgeLevel.diamond ||
        (definition.level == SellerBadgeLevel.silver && definition.premiumGlow);
  }

  /// Glow replay butonu — premium glow destekli kazanılmış rozetler.
  bool get allowsGlowReplay {
    if (status != SellerBadgeStatus.earned) return false;
    if (definition.badgeId == 'new_seller') return false;
    if (definition.badgeId == 'verified_store' ||
        definition.level == SellerBadgeLevel.verified) {
      return true;
    }
    if (definition.level == SellerBadgeLevel.bronze) return false;
    return definition.premiumGlow ||
        definition.level == SellerBadgeLevel.gold ||
        definition.level == SellerBadgeLevel.diamond ||
        (definition.level == SellerBadgeLevel.silver && definition.premiumGlow);
  }

  /// UI: "İkonu İzle" butonu gösterilsin mi.
  bool get showsGlowReplayButton => allowsGlowReplay;

  List<SellerBadgeChecklistItem> get incompleteChecklistItems {
    return checklistItems.where((item) => !item.completed).toList(growable: false);
  }

  SellerBadgeProgress copyWith({
    SellerBadgeStatus? status,
    int? progressCurrent,
    int? progressTarget,
    DateTime? earnedAt,
    bool? isFeaturedOnProfile,
    String? statusDetail,
    List<SellerBadgeChecklistItem>? checklistItems,
    bool? canRetry,
  }) {
    return SellerBadgeProgress(
      definition: definition,
      status: status ?? this.status,
      progressCurrent: progressCurrent ?? this.progressCurrent,
      progressTarget: progressTarget ?? this.progressTarget,
      earnedAt: earnedAt ?? this.earnedAt,
      isFeaturedOnProfile: isFeaturedOnProfile ?? this.isFeaturedOnProfile,
      statusDetail: statusDetail ?? this.statusDetail,
      checklistItems: checklistItems ?? this.checklistItems,
      canRetry: canRetry ?? this.canRetry,
    );
  }
}

class SellerBadgeStoreMetrics {
  const SellerBadgeStoreMetrics({
    this.sellerId = '',
    this.followerCount = 0,
    this.productCount = 0,
    this.completedOrderCount = 0,
    this.positiveReviewCount = 0,
    this.averageRating = 0,
    this.profileComplete = false,
    this.hasLogo = false,
    this.hasDescription = false,
    this.hasCategory = false,
    this.hasContactInfo = false,
    this.hasRegionInfo = false,
    this.hasCoverImage = false,
    this.storeCreatedAt,
    this.featuredBadgeIds = const [],
    this.metricsLoadFailed = false,
    this.isBrandVerified = false,
  });

  final String sellerId;
  final int followerCount;
  final int productCount;
  final int completedOrderCount;
  final int positiveReviewCount;
  final double averageRating;
  final bool profileComplete;
  final bool hasLogo;
  final bool hasDescription;
  final bool hasCategory;
  final bool hasContactInfo;
  final bool hasRegionInfo;
  final bool hasCoverImage;
  final DateTime? storeCreatedAt;
  final List<String> featuredBadgeIds;
  final bool metricsLoadFailed;
  final bool isBrandVerified;

  bool get newSellerProfileComplete {
    return hasLogo && hasDescription && hasCategory && hasContactInfo;
  }

  bool get qualifiesForNewSellerBadge {
    return newSellerProfileComplete && productCount >= 1;
  }

  bool get qualifiesAsNewSeller {
    if (!qualifiesForNewSellerBadge) return false;
    final createdAt = storeCreatedAt;
    if (createdAt != null) {
      final age = DateTime.now().difference(createdAt).inDays;
      if (age <= 30) return true;
    }
    if (completedOrderCount > 0 && completedOrderCount < 20) return true;
    return completedOrderCount == 0;
  }

  SellerBadgeStoreMetrics copyWith({
    int? followerCount,
    List<String>? featuredBadgeIds,
    bool? metricsLoadFailed,
    bool? isBrandVerified,
  }) {
    return SellerBadgeStoreMetrics(
      sellerId: sellerId,
      followerCount: followerCount ?? this.followerCount,
      productCount: productCount,
      completedOrderCount: completedOrderCount,
      positiveReviewCount: positiveReviewCount,
      averageRating: averageRating,
      profileComplete: profileComplete,
      hasLogo: hasLogo,
      hasDescription: hasDescription,
      hasCategory: hasCategory,
      hasContactInfo: hasContactInfo,
      hasRegionInfo: hasRegionInfo,
      hasCoverImage: hasCoverImage,
      storeCreatedAt: storeCreatedAt,
      featuredBadgeIds: featuredBadgeIds ?? this.featuredBadgeIds,
      metricsLoadFailed: metricsLoadFailed ?? this.metricsLoadFailed,
      isBrandVerified: isBrandVerified ?? this.isBrandVerified,
    );
  }
}

class SellerBadgeLevelStyle {
  const SellerBadgeLevelStyle({
    required this.label,
    required this.color,
    required this.background,
    required this.accent,
  });

  final String label;
  final Color color;
  final Color background;
  final Color accent;

  static SellerBadgeLevelStyle forLevel(SellerBadgeLevel level) {
    switch (level) {
      case SellerBadgeLevel.bronze:
        return const SellerBadgeLevelStyle(
          label: 'Bronz',
          color: Color(0xFFCD7F32),
          background: Color(0xFFFFF7ED),
          accent: Color(0xFFF59E0B),
        );
      case SellerBadgeLevel.silver:
        return const SellerBadgeLevelStyle(
          label: 'Gümüş',
          color: Color(0xFF64748B),
          background: Color(0xFFF8FAFC),
          accent: Color(0xFFCBD5E1),
        );
      case SellerBadgeLevel.gold:
        return const SellerBadgeLevelStyle(
          label: 'Altın',
          color: Color(0xFFD4A017),
          background: Color(0xFFFFFBEB),
          accent: Color(0xFFFACC15),
        );
      case SellerBadgeLevel.diamond:
        return const SellerBadgeLevelStyle(
          label: 'Elmas',
          color: Color(0xFF7C3AED),
          background: Color(0xFFF5F3FF),
          accent: Color(0xFF22D3EE),
        );
      case SellerBadgeLevel.verified:
        return const SellerBadgeLevelStyle(
          label: 'Doğrulanmış',
          color: Color(0xFF1D4ED8),
          background: Color(0xFFEFF6FF),
          accent: Color(0xFF38BDF8),
        );
    }
  }
}

String sellerBadgeCategoryLabel(SellerBadgeCategory category) {
  switch (category) {
    case SellerBadgeCategory.onboarding:
      return 'Başlangıç';
    case SellerBadgeCategory.followers:
      return 'Takipçi';
    case SellerBadgeCategory.orders:
      return 'Sipariş';
    case SellerBadgeCategory.shippingSpeed:
      return 'Kargo';
    case SellerBadgeCategory.packagingQuality:
      return 'Paketleme';
    case SellerBadgeCategory.messageResponse:
      return 'Mesaj';
    case SellerBadgeCategory.reviews:
      return 'Yorum';
    case SellerBadgeCategory.region:
      return 'Bölgesel';
    case SellerBadgeCategory.verification:
      return 'Doğrulama';
  }
}

String sellerBadgeStatusLabel(SellerBadgeStatus status) {
  switch (status) {
    case SellerBadgeStatus.locked:
      return 'Kilitli';
    case SellerBadgeStatus.inProgress:
      return 'Devam Ediyor';
    case SellerBadgeStatus.earned:
      return 'Kazanıldı';
    case SellerBadgeStatus.comingSoon:
      return 'Yakında';
    case SellerBadgeStatus.unavailable:
      return 'Veri Bekleniyor';
    case SellerBadgeStatus.insufficientData:
      return 'Yetersiz Veri';
    case SellerBadgeStatus.error:
      return 'Hata';
  }
}

String sellerBadgeProgressLabel(SellerBadgeProgress progress) {
  switch (progress.status) {
    case SellerBadgeStatus.comingSoon:
      return 'Yakında aktif olacak';
    case SellerBadgeStatus.unavailable:
      return progress.statusDetail ??
          'Bu rozet için veri kaynağı henüz hazır değil';
    case SellerBadgeStatus.insufficientData:
      return progress.statusDetail ?? 'Henüz yeterli veri oluşmadı';
    case SellerBadgeStatus.error:
      return progress.statusDetail ?? 'Hesaplama başarısız';
    case SellerBadgeStatus.locked:
      return 'Henüz başlamadı';
    case SellerBadgeStatus.earned:
      return 'Tamamlandı';
    case SellerBadgeStatus.inProgress:
      if (progress.checklistItems.isNotEmpty) {
        return '${progress.progressCurrent} / ${progress.progressTarget} tamamlandı';
      }
      return '${progress.progressCurrent} / ${progress.progressTarget}';
  }
}

List<SellerBadgeChecklistItem> sellerStoreReadyChecklist(
  SellerBadgeStoreMetrics metrics,
) {
  return [
    SellerBadgeChecklistItem(
      label: 'Logo yüklendi',
      completed: metrics.hasLogo,
      focus: SellerStoreProfileFocus.logo,
    ),
    SellerBadgeChecklistItem(
      label: 'Mağaza açıklaması eklendi',
      completed: metrics.hasDescription,
      focus: SellerStoreProfileFocus.description,
    ),
    SellerBadgeChecklistItem(
      label: 'Kategori seçildi',
      completed: metrics.hasCategory,
      focus: SellerStoreProfileFocus.category,
    ),
    SellerBadgeChecklistItem(
      label: 'İletişim bilgileri tamam',
      completed: metrics.hasContactInfo,
      focus: SellerStoreProfileFocus.contact,
    ),
  ];
}
