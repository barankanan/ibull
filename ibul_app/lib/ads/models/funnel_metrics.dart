import '../helpers/ad_json_helper.dart';

class FunnelMetrics {
  const FunnelMetrics({
    required this.campaignId,
    required this.awarenessCount,
    required this.considerationCount,
    required this.intentCount,
    required this.checkoutCount,
    required this.conversionCount,
    required this.retentionCount,
    required this.dropOffRate,
    required this.windowDays,
    required this.updatedAt,
  });

  final String campaignId;
  final int awarenessCount;
  final int considerationCount;
  final int intentCount;
  final int checkoutCount;
  final int conversionCount;
  final int retentionCount;
  final double dropOffRate;
  final int windowDays;
  final DateTime updatedAt;

  factory FunnelMetrics.fromJson(Map<String, dynamic> json) {
    return FunnelMetrics(
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      awarenessCount: AdJsonHelper.asInt(json['awareness_count']),
      considerationCount: AdJsonHelper.asInt(json['consideration_count']),
      intentCount: AdJsonHelper.asInt(json['intent_count']),
      checkoutCount: AdJsonHelper.asInt(json['checkout_count']),
      conversionCount: AdJsonHelper.asInt(json['conversion_count']),
      retentionCount: AdJsonHelper.asInt(json['retention_count']),
      dropOffRate: AdJsonHelper.asDouble(json['drop_off_rate']),
      windowDays: AdJsonHelper.asInt(json['window_days'], fallback: 30),
      updatedAt: AdJsonHelper.asDateTime(json['updated_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'campaign_id': campaignId,
      'awareness_count': awarenessCount,
      'consideration_count': considerationCount,
      'intent_count': intentCount,
      'checkout_count': checkoutCount,
      'conversion_count': conversionCount,
      'retention_count': retentionCount,
      'drop_off_rate': dropOffRate,
      'window_days': windowDays,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
