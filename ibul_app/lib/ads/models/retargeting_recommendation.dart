import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class RetargetingRecommendation {
  const RetargetingRecommendation({
    required this.segment,
    required this.reason,
    required this.priorityScore,
    this.suggestedCampaignType,
    this.entityIds = const [],
    this.metadata = const {},
  });

  final RetargetingSegment segment;
  final String reason;
  final double priorityScore;
  final AdCampaignType? suggestedCampaignType;
  final List<String> entityIds;
  final Map<String, dynamic> metadata;

  factory RetargetingRecommendation.fromJson(Map<String, dynamic> json) {
    return RetargetingRecommendation(
      segment: RetargetingSegmentParser.fromDbValue(
        json['segment']?.toString(),
      ),
      reason: AdJsonHelper.asString(json['reason']),
      priorityScore: AdJsonHelper.asDouble(json['priority_score']),
      suggestedCampaignType: json['suggested_campaign_type'] == null
          ? null
          : AdCampaignTypeParser.fromDbValue(
              json['suggested_campaign_type']?.toString(),
            ),
      entityIds: AdJsonHelper.asStringList(json['entity_ids']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'segment': segment.dbValue,
      'reason': reason,
      'priority_score': priorityScore,
      'suggested_campaign_type': suggestedCampaignType?.dbValue,
      'entity_ids': entityIds,
      'metadata': metadata,
    };
  }
}
