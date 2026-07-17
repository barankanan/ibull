import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';
import '../models/ad_campaign.dart';
import '../models/home_card_template.dart';
import 'home_feature_ad_display_text.dart';

class HomeFeatureAdHelper {
  const HomeFeatureAdHelper._();

  static const int maxBannerImages = 3;
  static const int maxProducts = 10;
  static const double recommendedBannerWidth = 1200;
  static const double recommendedBannerHeight = 200;
  static const double recommendedBannerAspectRatio =
      recommendedBannerWidth / recommendedBannerHeight;

  static bool isHomeFeature(AdCampaign campaign) =>
      campaign.type == AdCampaignType.homeFeature;

  static String? cardTemplateId(AdCampaign campaign) =>
      AdJsonHelper.asNullableString(campaign.metadata['card_template_id']);

  static String? categoryId(AdCampaign campaign) =>
      AdJsonHelper.asNullableString(campaign.metadata['category_id']);

  /// Path son parçası + lowercase normalize — "Yemek / Yemekler" → "yemekler"
  static String normalizeCategoryLeaf(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return value;
    if (value.contains('/')) {
      final parts = value
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.isNotEmpty) value = parts.last;
    }
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> categoryNameCandidates(
    AdCampaign campaign,
    HomeCardTemplate? template,
  ) {
    return [
      template?.categoryName,
      categoryName(campaign),
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static HomeFeatureCategoryGrouping? resolveCategoryGrouping({
    required AdCampaign campaign,
    HomeCardTemplate? template,
  }) {
    final names = categoryNameCandidates(campaign, template);
    final metaCatId = categoryId(campaign)?.trim();
    final templateCatId = template?.categoryId?.trim();
    final resolvedCatId = (metaCatId != null && metaCatId.isNotEmpty)
        ? metaCatId
        : templateCatId;
    if ((resolvedCatId == null || resolvedCatId.isEmpty) && names.isEmpty) {
      return null;
    }

    final displayName = _groupDisplayName(names);
    final subtitle = _groupSubtitle(names);
    final leaves = names.map(normalizeCategoryLeaf).where((leaf) => leaf.isNotEmpty);
    final leaf = leaves.isEmpty
        ? normalizeCategoryLeaf(displayName)
        : leaves.reduce((a, b) => a.length >= b.length ? a : b);

    if (resolvedCatId != null && resolvedCatId.isNotEmpty) {
      return HomeFeatureCategoryGrouping(
        key: 'cid:$resolvedCatId',
        displayName: displayName,
        subtitle: subtitle,
        canonicalLeaf: leaf,
      );
    }

    if (leaf.isEmpty) return null;
    return HomeFeatureCategoryGrouping(
      key: 'leaf:$leaf',
      displayName: displayName,
      subtitle: subtitle,
      canonicalLeaf: leaf,
    );
  }

  static String _groupDisplayName(List<String> names) {
    if (names.isEmpty) return 'Diğer';
    final primary = names.first;
    if (primary.contains('/')) {
      final parts = primary
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.length >= 2) return parts.first;
      if (parts.isNotEmpty) return parts.last;
    }
    return primary;
  }

  static String? _groupSubtitle(List<String> names) {
    for (final name in names) {
      if (!name.contains('/')) continue;
      final parts = name
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      if (parts.length >= 2) return parts.last;
    }
    return null;
  }

  static String? ineligibleReason(
    AdCampaign campaign, {
    DateTime? now,
  }) {
    if (campaign.type != AdCampaignType.homeFeature) return 'type_mismatch';

    final at = now ?? DateTime.now();
    switch (campaign.status) {
      case CampaignStatus.approved:
      case CampaignStatus.active:
        break;
      case CampaignStatus.pendingReview:
        return 'status_not_approved';
      case CampaignStatus.rejected:
        return 'status_rejected';
      case CampaignStatus.paused:
        return 'status_paused';
      case CampaignStatus.completed:
      case CampaignStatus.stopped:
      case CampaignStatus.archived:
        return 'status_inactive';
      case CampaignStatus.draft:
        return 'status_draft';
      case CampaignStatus.scheduled:
        return 'status_scheduled';
    }

    if (campaign.startsAt.isAfter(at)) return 'date_not_started';
    if (campaign.endsAt.isBefore(at)) return 'date_expired';

    final placement = AdJsonHelper.asNullableString(campaign.metadata['placement']);
    if (placement != null &&
        placement.isNotEmpty &&
        placement != AdPlacement.homeCard.dbValue) {
      return 'placement_mismatch';
    }

    final targetPlacements = campaign.target?.placements ?? const [];
    if (targetPlacements.isNotEmpty &&
        !targetPlacements.contains(AdPlacement.homeCard)) {
      return 'placement_mismatch';
    }

    final templateId = cardTemplateId(campaign);
    if (templateId == null || templateId.isEmpty) return 'template_missing';

    if (bannerImages(campaign).isEmpty) return 'no_banner';

    return null;
  }

  static AdCampaign? campaignFromActiveViewRow(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final metadata = Map<String, dynamic>.from(AdJsonHelper.asMap(row['metadata']));
    final cardTemplateId = row['card_template_id']?.toString();
    if (cardTemplateId != null &&
        cardTemplateId.isNotEmpty &&
        !metadata.containsKey('card_template_id')) {
      metadata['card_template_id'] = cardTemplateId;
    }
    final categoryNameValue = row['category_name']?.toString();
    if (categoryNameValue != null &&
        categoryNameValue.isNotEmpty &&
        !metadata.containsKey('category_name')) {
      metadata['category_name'] = categoryNameValue;
    }

    final startsAt =
        AdJsonHelper.asDateTime(row['starts_at']) ??
        DateTime.now().subtract(const Duration(days: 1));
    final endsAt =
        AdJsonHelper.asDateTime(row['ends_at']) ??
        DateTime.now().add(const Duration(days: 30));

    return AdCampaign(
      id: id,
      sellerId: AdJsonHelper.asString(row['seller_id']),
      storeId: AdJsonHelper.asNullableString(row['store_id']),
      name: AdJsonHelper.asString(row['name'], fallback: id),
      type: AdCampaignType.homeFeature,
      objective: CampaignObjective.storeVisits,
      status: CampaignStatus.approved,
      billingModel: BillingModel.flat,
      dailyBudget: 0,
      totalBudget: 0,
      currency: 'TRY',
      startsAt: startsAt,
      endsAt: endsAt,
      metadata: metadata,
      createdAt: AdJsonHelper.asDateTime(row['created_at']),
      updatedAt: AdJsonHelper.asDateTime(row['updated_at']),
    );
  }

  static String? categoryName(AdCampaign campaign) =>
      AdJsonHelper.asNullableString(campaign.metadata['category_name']);

  static List<String> bannerImages(AdCampaign campaign) {
    final raw = campaign.metadata['banner_images'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return campaign.assets
        .where((a) => a.assetType == AdAssetType.image)
        .map((a) => a.mediaUrl ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static List<String> selectedProductIds(AdCampaign campaign) {
    final raw = campaign.metadata['selected_product_ids'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return campaign.assets
        .where((a) => a.assetType == AdAssetType.product)
        .map((a) => a.entityId ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Seçilen ürünlerin ana kategorileri (form kayıt sırasında yazılır).
  /// Eski kampanyalarda alan yoktur → boş liste (backward compatible).
  static List<String> selectedProductCategories(AdCampaign campaign) {
    final raw = campaign.metadata['selected_product_categories'];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  /// Kategori hedef eşleşmesi: kampanyanın ürün kategorileri biliniyorsa ve
  /// HİÇBİRİ hedef kategori yaprağıyla benzeşmiyorsa reklam o section'da
  /// gösterilmez (yemek reklamı elektronik alanına düşemez ve tersi).
  /// Ürün kategorisi bilinmiyorsa (eski kampanya) hedef kategoriye güvenilir.
  static bool matchesGroupingCategory(
    AdCampaign campaign,
    HomeFeatureCategoryGrouping grouping,
  ) {
    final productCategories = selectedProductCategories(campaign);
    if (productCategories.isEmpty) return true;
    for (final category in productCategories) {
      if (HomeFeatureAdDisplayText.isSimilarTitle(
            category,
            grouping.canonicalLeaf,
          ) ||
          HomeFeatureAdDisplayText.isSimilarTitle(
            category,
            grouping.displayName,
          ) ||
          (grouping.subtitle != null &&
              HomeFeatureAdDisplayText.isSimilarTitle(
                category,
                grouping.subtitle,
              ))) {
        return true;
      }
    }
    return false;
  }

  static int sortOrder(AdCampaign campaign) =>
      AdJsonHelper.asInt(campaign.metadata['sort_order']);

  static String sortMode(AdCampaign campaign) =>
      AdJsonHelper.asString(campaign.metadata['sort_mode'], fallback: 'manual');

  /// Satıcının kampanya formunda girdiği not (extra_settings veya metadata).
  static String? sellerCampaignNote(AdCampaign campaign) {
    final direct = campaign.metadata['campaign_note']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final extra = campaign.metadata['extra_settings'];
    if (extra is Map) {
      final note = extra['campaign_note']?.toString().trim();
      if (note != null && note.isNotEmpty) return note;
    }
    return null;
  }

  static HomeFeatureMetrics metrics(AdCampaign campaign) =>
      HomeFeatureMetrics.fromMetadata(campaign.metadata);

  static List<String> uniqueOrderedIds(List<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty || seen.contains(value)) continue;
      seen.add(value);
      result.add(value);
    }
    return result;
  }

  static Map<String, dynamic> buildMetadata({
    required String cardTemplateId,
    required String categoryName,
    String? categoryId,
    required List<String> bannerImages,
    required List<String> selectedProductIds,
    int sortOrder = 0,
    String sortMode = 'manual',
    double? aiScore,
    String? storeName,
    String? budgetType,
    double? dailyBudget,
    double? totalBudget,
    int? durationDays,
    List<String>? selectedProductCategories,
    Map<String, dynamic>? extraSettings,
  }) {
    return {
      'card_template_id': cardTemplateId,
      'category_id': categoryId,
      'category_name': categoryName,
      'banner_images': bannerImages,
      'selected_product_ids': selectedProductIds,
      if (selectedProductCategories != null &&
          selectedProductCategories.isNotEmpty)
        'selected_product_categories': selectedProductCategories,
      'selected_banner_order': bannerImages,
      'selected_product_order': selectedProductIds,
      'sort_order': sortOrder,
      'sort_mode': sortMode,
      // ignore: use_null_aware_elements
      if (aiScore != null) 'ai_score': aiScore,
      if (storeName != null && storeName.isNotEmpty) 'store_name': storeName,
      if (budgetType != null && budgetType.isNotEmpty) 'budget_type': budgetType,
      if (dailyBudget != null && dailyBudget > 0) 'daily_budget': dailyBudget,
      if (totalBudget != null && totalBudget > 0) 'total_budget': totalBudget,
      if (durationDays != null && durationDays > 0) 'duration_days': durationDays,
      if (extraSettings != null && extraSettings.isNotEmpty)
        'extra_settings': extraSettings,
      'preview_style': 'home_card',
      'home_metrics': {
        'impressions_count': 0,
        'banner_clicks_count': 0,
        'profile_opens_count': 0,
        'product_clicks_count': 0,
        'favorites_count': 0,
        'message_clicks_count': 0,
      },
      'placement': AdPlacement.homeCard.dbValue,
    };
  }

  static List<String> validateSubmission({
    required String? cardTemplateId,
    required List<String> bannerImages,
    required List<String> productIds,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    final issues = <String>[];
    if (cardTemplateId == null || cardTemplateId.isEmpty) {
      issues.add('Kart şablonu seçmelisiniz.');
    }
    if (bannerImages.isEmpty) {
      issues.add('En az 1 banner görseli eklemelisiniz.');
    }
    if (bannerImages.length > maxBannerImages) {
      issues.add('En fazla $maxBannerImages banner görseli ekleyebilirsiniz.');
    }
    if (productIds.isEmpty) {
      issues.add('Ana sayfada görünmesi için en az 1 ürün seçmelisiniz.');
    }
    if (productIds.length > maxProducts) {
      issues.add('En fazla $maxProducts ürün seçebilirsiniz.');
    }
    if (endsAt.isBefore(startsAt)) {
      issues.add('Bitiş tarihi başlangıçtan sonra olmalı.');
    }
    return issues;
  }

  static String? aspectRatioWarning(double width, double height) {
    if (width <= 0 || height <= 0) return null;
    final ratio = width / height;
    const tolerance = 0.15;
    if ((ratio - recommendedBannerAspectRatio).abs() > tolerance) {
      return 'Önerilen oran 1200×200 (${recommendedBannerAspectRatio.toStringAsFixed(1)}:1). '
          'Yüklediğiniz görsel ${width.toInt()}×${height.toInt()} '
          '(${ratio.toStringAsFixed(1)}:1).';
    }
    return null;
  }

  /// Ana sayfada gösterilebilir mi? Pending/rejected/expired/paused dahil değil.
  static bool isEligibleForHomeDisplay(
    AdCampaign campaign, {
    DateTime? now,
  }) {
    return ineligibleReason(campaign, now: now) == null;
  }

  /// Seller panelde gösterilecek "ana sayfa görünürlüğü" makine-okur kodu.
  /// null → yayında.
  static String? sellerHomeVisibilityReason(
    AdCampaign campaign, {
    DateTime? now,
  }) {
    final reason = ineligibleReason(campaign, now: now);
    if (reason != null) return reason;
    if (selectedProductIds(campaign).isEmpty) return 'no_product';
    final grouping = resolveCategoryGrouping(campaign: campaign);
    if (grouping != null && !matchesGroupingCategory(campaign, grouping)) {
      return 'category_conflict';
    }
    return null;
  }

  /// Seller panelde kullanıcıya gösterilecek net görünürlük etiketi.
  static String sellerHomeVisibilityLabel(
    AdCampaign campaign, {
    DateTime? now,
  }) {
    final reason = sellerHomeVisibilityReason(campaign, now: now);
    switch (reason) {
      case null:
        return 'Yayında';
      case 'status_not_approved':
        return 'Admin onayı bekleniyor. Onaylandıktan sonra ana sayfada görünecek.';
      case 'status_rejected':
        return 'Reddedildi — ana sayfada görünmüyor';
      case 'status_paused':
        return 'Duraklatıldı — ana sayfada görünmüyor';
      case 'status_inactive':
        return 'Pasif — ana sayfada görünmüyor';
      case 'status_draft':
        return 'Taslak — henüz onaya gönderilmedi';
      case 'status_scheduled':
      case 'date_not_started':
        return 'Planlandı — başlangıç tarihini bekliyor';
      case 'date_expired':
        return 'Süresi doldu — ana sayfada görünmüyor';
      case 'no_banner':
      case 'template_missing':
      case 'no_product':
        return 'Reklam görseli veya ürün bağlantısı eksik';
      case 'category_conflict':
        return 'Seçilen ürünlerin kategorisi reklam hedefiyle uyuşmuyor.';
      case 'placement_mismatch':
        return 'Yerleşim uyumsuz — ana sayfada görünmüyor';
      default:
        return 'Ana sayfada görünmüyor';
    }
  }
}
