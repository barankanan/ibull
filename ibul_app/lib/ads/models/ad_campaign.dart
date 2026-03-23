import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';
import 'ab_test_variant.dart';
import 'campaign_asset.dart';
import 'campaign_target.dart';

class AdCampaign {
  const AdCampaign({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.type,
    required this.objective,
    required this.status,
    required this.billingModel,
    required this.dailyBudget,
    required this.totalBudget,
    required this.currency,
    required this.startsAt,
    required this.endsAt,
    this.storeId,
    this.description,
    this.spentAmount = 0,
    this.remainingBalance = 0,
    this.bidAmount = 0,
    this.pausedAt,
    this.approvedAt,
    this.rejectedAt,
    this.reviewNotes,
    this.isPremiumPlacementEnabled = false,
    this.useAiSuggestions = false,
    this.frequencyCapPerUser = 3,
    this.targetingVersion = 1,
    this.abTestEnabled = false,
    this.target,
    this.assets = const [],
    this.abTestVariants = const [],
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sellerId;
  final String? storeId;
  final String name;
  final String? description;
  final AdCampaignType type;
  final CampaignObjective objective;
  final CampaignStatus status;
  final BillingModel billingModel;
  final double dailyBudget;
  final double totalBudget;
  final double spentAmount;
  final double remainingBalance;
  final double bidAmount;
  final String currency;
  final DateTime startsAt;
  final DateTime endsAt;
  final DateTime? pausedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? reviewNotes;
  final bool isPremiumPlacementEnabled;
  final bool useAiSuggestions;
  final int frequencyCapPerUser;
  final int targetingVersion;
  final bool abTestEnabled;
  final CampaignTarget? target;
  final List<CampaignAsset> assets;
  final List<AbTestVariant> abTestVariants;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLive =>
      status == CampaignStatus.active ||
      status == CampaignStatus.approved ||
      status == CampaignStatus.scheduled;

  bool get isExpired => endsAt.isBefore(DateTime.now());

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    final nestedTargets = AdJsonHelper.asMapList(json['campaign_targets']);
    final nestedAssets = AdJsonHelper.asMapList(json['campaign_assets']);
    final nestedVariants = AdJsonHelper.asMapList(json['ab_test_variants']);
    final targetMap = AdJsonHelper.asMap(json['target']);
    final startsAt = AdJsonHelper.asDateTime(json['starts_at']);
    final endsAt = AdJsonHelper.asDateTime(json['ends_at']);
    final metadata = <String, dynamic>{
      ...AdJsonHelper.asMap(json['metadata']),
      '_missing_starts_at': startsAt == null,
      '_missing_ends_at': endsAt == null,
    };

    return AdCampaign(
      id: AdJsonHelper.asString(json['id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      storeId: AdJsonHelper.asNullableString(json['store_id']),
      name: AdJsonHelper.asString(json['name'], fallback: '-'),
      description: AdJsonHelper.asNullableString(json['description']),
      type: AdCampaignTypeParser.fromDbValue(json['type']?.toString()),
      objective: CampaignObjectiveParser.fromDbValue(
        json['objective']?.toString(),
      ),
      status: CampaignStatusParser.fromDbValue(json['status']?.toString()),
      billingModel: BillingModelParser.fromDbValue(
        json['billing_model']?.toString(),
      ),
      dailyBudget: AdJsonHelper.asDouble(json['daily_budget']),
      totalBudget: AdJsonHelper.asDouble(json['total_budget']),
      spentAmount: AdJsonHelper.asDouble(json['spent_amount']),
      remainingBalance: AdJsonHelper.asDouble(json['remaining_balance']),
      bidAmount: AdJsonHelper.asDouble(json['bid_amount']),
      currency: AdJsonHelper.asString(json['currency'], fallback: 'TRY'),
      startsAt: startsAt ?? DateTime.now(),
      endsAt: endsAt ?? DateTime.now(),
      pausedAt: AdJsonHelper.asDateTime(json['paused_at']),
      approvedAt: AdJsonHelper.asDateTime(json['approved_at']),
      rejectedAt: AdJsonHelper.asDateTime(json['rejected_at']),
      reviewNotes: AdJsonHelper.asNullableString(json['review_notes']),
      isPremiumPlacementEnabled: AdJsonHelper.asBool(
        json['is_premium_placement_enabled'],
      ),
      useAiSuggestions: AdJsonHelper.asBool(json['use_ai_suggestions']),
      frequencyCapPerUser: AdJsonHelper.asInt(
        json['frequency_cap_per_user'],
        fallback: 3,
      ),
      targetingVersion: AdJsonHelper.asInt(
        json['targeting_version'],
        fallback: 1,
      ),
      abTestEnabled: AdJsonHelper.asBool(json['ab_test_enabled']),
      target: targetMap.isNotEmpty
          ? CampaignTarget.fromJson(targetMap)
          : nestedTargets.isNotEmpty
          ? CampaignTarget.fromJson(nestedTargets.first)
          : null,
      assets: nestedAssets.map(CampaignAsset.fromJson).toList(growable: false),
      abTestVariants: nestedVariants
          .map(AbTestVariant.fromJson)
          .toList(growable: false),
      metadata: metadata,
      createdAt: AdJsonHelper.asDateTime(json['created_at']),
      updatedAt: AdJsonHelper.asDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson({bool includeRelations = true}) {
    final persistedMetadata = Map<String, dynamic>.from(metadata)
      ..remove('_missing_starts_at')
      ..remove('_missing_ends_at');
    return {
      'id': id,
      'seller_id': sellerId,
      'store_id': storeId,
      'name': name,
      'description': description,
      'type': type.dbValue,
      'objective': objective.dbValue,
      'status': status.dbValue,
      'billing_model': billingModel.dbValue,
      'daily_budget': dailyBudget,
      'total_budget': totalBudget,
      'spent_amount': spentAmount,
      'remaining_balance': remainingBalance,
      'bid_amount': bidAmount,
      'currency': currency,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'paused_at': pausedAt?.toUtc().toIso8601String(),
      'approved_at': approvedAt?.toUtc().toIso8601String(),
      'rejected_at': rejectedAt?.toUtc().toIso8601String(),
      'review_notes': reviewNotes,
      'is_premium_placement_enabled': isPremiumPlacementEnabled,
      'use_ai_suggestions': useAiSuggestions,
      'frequency_cap_per_user': frequencyCapPerUser,
      'targeting_version': targetingVersion,
      'ab_test_enabled': abTestEnabled,
      'metadata': persistedMetadata,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
      if (includeRelations) 'target': target?.toJson(),
      if (includeRelations)
        'campaign_assets': assets.map((item) => item.toJson()).toList(),
      if (includeRelations)
        'ab_test_variants': abTestVariants
            .map((item) => item.toJson())
            .toList(),
    };
  }

  AdCampaign copyWith({
    String? id,
    String? sellerId,
    String? storeId,
    String? name,
    String? description,
    AdCampaignType? type,
    CampaignObjective? objective,
    CampaignStatus? status,
    BillingModel? billingModel,
    double? dailyBudget,
    double? totalBudget,
    double? spentAmount,
    double? remainingBalance,
    double? bidAmount,
    String? currency,
    DateTime? startsAt,
    DateTime? endsAt,
    DateTime? pausedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? reviewNotes,
    bool? isPremiumPlacementEnabled,
    bool? useAiSuggestions,
    int? frequencyCapPerUser,
    int? targetingVersion,
    bool? abTestEnabled,
    CampaignTarget? target,
    List<CampaignAsset>? assets,
    List<AbTestVariant>? abTestVariants,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdCampaign(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      objective: objective ?? this.objective,
      status: status ?? this.status,
      billingModel: billingModel ?? this.billingModel,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      totalBudget: totalBudget ?? this.totalBudget,
      spentAmount: spentAmount ?? this.spentAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      bidAmount: bidAmount ?? this.bidAmount,
      currency: currency ?? this.currency,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      pausedAt: pausedAt ?? this.pausedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      isPremiumPlacementEnabled:
          isPremiumPlacementEnabled ?? this.isPremiumPlacementEnabled,
      useAiSuggestions: useAiSuggestions ?? this.useAiSuggestions,
      frequencyCapPerUser: frequencyCapPerUser ?? this.frequencyCapPerUser,
      targetingVersion: targetingVersion ?? this.targetingVersion,
      abTestEnabled: abTestEnabled ?? this.abTestEnabled,
      target: target ?? this.target,
      assets: assets ?? this.assets,
      abTestVariants: abTestVariants ?? this.abTestVariants,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
