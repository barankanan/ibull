import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class AdPlacementResult {
  const AdPlacementResult({
    required this.placement,
    required this.campaignId,
    required this.campaignType,
    required this.score,
    required this.reason,
    this.assetId,
    this.entityId,
    this.bidAmount = 0,
    this.sponsoredWeight = 0,
    this.relevanceWeight = 0,
    this.qualityWeight = 0,
    this.distanceWeight = 0,
    this.performanceWeight = 0,
    this.conversionProbability = 0,
    this.fatiguePenalty = 0,
    this.estimatedCtr = 0,
    this.estimatedConversionRate = 0,
    this.isRetargeted = false,
    this.isGeoMatched = false,
    this.metadata = const {},
  });

  final AdPlacement placement;
  final String campaignId;
  final AdCampaignType campaignType;
  final double score;
  final String reason;
  final String? assetId;
  final String? entityId;
  final double bidAmount;
  final double sponsoredWeight;
  final double relevanceWeight;
  final double qualityWeight;
  final double distanceWeight;
  final double performanceWeight;
  final double conversionProbability;
  final double fatiguePenalty;
  final double estimatedCtr;
  final double estimatedConversionRate;
  final bool isRetargeted;
  final bool isGeoMatched;
  final Map<String, dynamic> metadata;

  factory AdPlacementResult.fromJson(Map<String, dynamic> json) {
    return AdPlacementResult(
      placement: AdPlacementParser.fromDbValue(json['placement']?.toString()),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      campaignType: AdCampaignTypeParser.fromDbValue(
        json['campaign_type']?.toString(),
      ),
      score: AdJsonHelper.asDouble(json['score']),
      reason: AdJsonHelper.asString(json['reason']),
      assetId: AdJsonHelper.asNullableString(json['asset_id']),
      entityId: AdJsonHelper.asNullableString(json['entity_id']),
      bidAmount: AdJsonHelper.asDouble(json['bid_amount']),
      sponsoredWeight: AdJsonHelper.asDouble(json['sponsored_weight']),
      relevanceWeight: AdJsonHelper.asDouble(json['relevance_weight']),
      qualityWeight: AdJsonHelper.asDouble(json['quality_weight']),
      distanceWeight: AdJsonHelper.asDouble(json['distance_weight']),
      performanceWeight: AdJsonHelper.asDouble(json['performance_weight']),
      conversionProbability: AdJsonHelper.asDouble(
        json['conversion_probability'],
      ),
      fatiguePenalty: AdJsonHelper.asDouble(json['fatigue_penalty']),
      estimatedCtr: AdJsonHelper.asDouble(json['estimated_ctr']),
      estimatedConversionRate: AdJsonHelper.asDouble(
        json['estimated_conversion_rate'],
      ),
      isRetargeted: AdJsonHelper.asBool(json['is_retargeted']),
      isGeoMatched: AdJsonHelper.asBool(json['is_geo_matched']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placement': placement.dbValue,
      'campaign_id': campaignId,
      'campaign_type': campaignType.dbValue,
      'score': score,
      'reason': reason,
      'asset_id': assetId,
      'entity_id': entityId,
      'bid_amount': bidAmount,
      'sponsored_weight': sponsoredWeight,
      'relevance_weight': relevanceWeight,
      'quality_weight': qualityWeight,
      'distance_weight': distanceWeight,
      'performance_weight': performanceWeight,
      'conversion_probability': conversionProbability,
      'fatigue_penalty': fatiguePenalty,
      'estimated_ctr': estimatedCtr,
      'estimated_conversion_rate': estimatedConversionRate,
      'is_retargeted': isRetargeted,
      'is_geo_matched': isGeoMatched,
      'metadata': metadata,
    };
  }
}
