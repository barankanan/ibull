import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class CampaignAsset {
  const CampaignAsset({
    required this.campaignId,
    required this.assetType,
    this.id,
    this.entityId,
    this.title,
    this.subtitle,
    this.mediaUrl,
    this.thumbnailUrl,
    this.deepLink,
    this.placements = const [],
    this.priority = 0,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String campaignId;
  final AdAssetType assetType;
  final String? entityId;
  final String? title;
  final String? subtitle;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? deepLink;
  final List<AdPlacement> placements;
  final int priority;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CampaignAsset.fromJson(Map<String, dynamic> json) {
    return CampaignAsset(
      id: AdJsonHelper.asNullableString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      assetType: AdAssetTypeParser.fromDbValue(json['asset_type']?.toString()),
      entityId: AdJsonHelper.asNullableString(json['entity_id']),
      title: AdJsonHelper.asNullableString(json['title']),
      subtitle: AdJsonHelper.asNullableString(json['subtitle']),
      mediaUrl: AdJsonHelper.asNullableString(json['media_url']),
      thumbnailUrl: AdJsonHelper.asNullableString(json['thumbnail_url']),
      deepLink: AdJsonHelper.asNullableString(json['deep_link']),
      placements: AdJsonHelper.asStringList(
        json['placements'],
      ).map(AdPlacementParser.fromDbValue).toList(growable: false),
      priority: AdJsonHelper.asInt(json['priority']),
      metadata: AdJsonHelper.asMap(json['metadata']),
      createdAt: AdJsonHelper.asDateTime(json['created_at']),
      updatedAt: AdJsonHelper.asDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'asset_type': assetType.dbValue,
      'entity_id': entityId,
      'title': title,
      'subtitle': subtitle,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'deep_link': deepLink,
      'placements': placements.map((item) => item.dbValue).toList(),
      'priority': priority,
      'metadata': metadata,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  CampaignAsset copyWith({
    String? id,
    String? campaignId,
    AdAssetType? assetType,
    String? entityId,
    String? title,
    String? subtitle,
    String? mediaUrl,
    String? thumbnailUrl,
    String? deepLink,
    List<AdPlacement>? placements,
    int? priority,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CampaignAsset(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      assetType: assetType ?? this.assetType,
      entityId: entityId ?? this.entityId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      deepLink: deepLink ?? this.deepLink,
      placements: placements ?? this.placements,
      priority: priority ?? this.priority,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
