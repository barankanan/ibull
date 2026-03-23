import '../helpers/ad_json_helper.dart';

class PlacementMixItem {
  const PlacementMixItem({
    required this.entityId,
    required this.isSponsored,
    this.campaignId,
    this.score,
    this.metadata = const {},
  });

  final String entityId;
  final bool isSponsored;
  final String? campaignId;
  final double? score;
  final Map<String, dynamic> metadata;

  factory PlacementMixItem.fromJson(Map<String, dynamic> json) {
    return PlacementMixItem(
      entityId: AdJsonHelper.asString(json['entity_id']),
      isSponsored: AdJsonHelper.asBool(json['is_sponsored']),
      campaignId: AdJsonHelper.asNullableString(json['campaign_id']),
      score: json['score'] == null
          ? null
          : AdJsonHelper.asDouble(json['score']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entity_id': entityId,
      'is_sponsored': isSponsored,
      'campaign_id': campaignId,
      'score': score,
      'metadata': metadata,
    };
  }
}
