import '../helpers/ad_json_helper.dart';

class AbTestVariant {
  const AbTestVariant({
    required this.campaignId,
    required this.name,
    required this.weight,
    this.id,
    this.headline,
    this.ctaLabel,
    this.assetOverrides = const {},
    this.targetOverrides = const {},
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.isControl = false,
    this.isActive = true,
    this.createdAt,
  });

  final String? id;
  final String campaignId;
  final String name;
  final double weight;
  final String? headline;
  final String? ctaLabel;
  final Map<String, dynamic> assetOverrides;
  final Map<String, dynamic> targetOverrides;
  final int impressions;
  final int clicks;
  final int conversions;
  final bool isControl;
  final bool isActive;
  final DateTime? createdAt;

  factory AbTestVariant.fromJson(Map<String, dynamic> json) {
    return AbTestVariant(
      id: AdJsonHelper.asNullableString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      name: AdJsonHelper.asString(json['name']),
      weight: AdJsonHelper.asDouble(json['weight'], fallback: 0.5),
      headline: AdJsonHelper.asNullableString(json['headline']),
      ctaLabel: AdJsonHelper.asNullableString(json['cta_label']),
      assetOverrides: AdJsonHelper.asMap(json['asset_overrides']),
      targetOverrides: AdJsonHelper.asMap(json['target_overrides']),
      impressions: AdJsonHelper.asInt(json['impressions']),
      clicks: AdJsonHelper.asInt(json['clicks']),
      conversions: AdJsonHelper.asInt(json['conversions']),
      isControl: AdJsonHelper.asBool(json['is_control']),
      isActive: AdJsonHelper.asBool(json['is_active'], fallback: true),
      createdAt: AdJsonHelper.asDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'name': name,
      'weight': weight,
      'headline': headline,
      'cta_label': ctaLabel,
      'asset_overrides': assetOverrides,
      'target_overrides': targetOverrides,
      'impressions': impressions,
      'clicks': clicks,
      'conversions': conversions,
      'is_control': isControl,
      'is_active': isActive,
      'created_at': createdAt?.toUtc().toIso8601String(),
    };
  }

  AbTestVariant copyWith({
    String? id,
    String? campaignId,
    String? name,
    double? weight,
    String? headline,
    String? ctaLabel,
    Map<String, dynamic>? assetOverrides,
    Map<String, dynamic>? targetOverrides,
    int? impressions,
    int? clicks,
    int? conversions,
    bool? isControl,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return AbTestVariant(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      headline: headline ?? this.headline,
      ctaLabel: ctaLabel ?? this.ctaLabel,
      assetOverrides: assetOverrides ?? this.assetOverrides,
      targetOverrides: targetOverrides ?? this.targetOverrides,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      conversions: conversions ?? this.conversions,
      isControl: isControl ?? this.isControl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
