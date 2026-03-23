import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class GeoPushTrigger {
  const GeoPushTrigger({
    required this.id,
    required this.campaignId,
    required this.sellerId,
    required this.storeId,
    required this.title,
    required this.body,
    required this.radiusMeters,
    required this.cooldownHours,
    required this.maxSendsPerWeek,
    required this.triggerType,
    this.targetCityCodes = const [],
    this.geohashPrefixes = const [],
    this.productIds = const [],
    this.lastTriggeredAt,
    this.isActive = true,
    this.metadata = const {},
  });

  final String id;
  final String campaignId;
  final String sellerId;
  final String storeId;
  final String title;
  final String body;
  final int radiusMeters;
  final int cooldownHours;
  final int maxSendsPerWeek;
  final GeoTriggerType triggerType;
  final List<String> targetCityCodes;
  final List<String> geohashPrefixes;
  final List<String> productIds;
  final DateTime? lastTriggeredAt;
  final bool isActive;
  final Map<String, dynamic> metadata;

  factory GeoPushTrigger.fromJson(Map<String, dynamic> json) {
    return GeoPushTrigger(
      id: AdJsonHelper.asString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      sellerId: AdJsonHelper.asString(json['seller_id']),
      storeId: AdJsonHelper.asString(json['store_id']),
      title: AdJsonHelper.asString(json['title']),
      body: AdJsonHelper.asString(json['body']),
      radiusMeters: AdJsonHelper.asInt(json['radius_meters']),
      cooldownHours: AdJsonHelper.asInt(json['cooldown_hours'], fallback: 8),
      maxSendsPerWeek: AdJsonHelper.asInt(
        json['max_sends_per_week'],
        fallback: 3,
      ),
      triggerType: GeoTriggerTypeParser.fromDbValue(
        json['trigger_type']?.toString(),
      ),
      targetCityCodes: AdJsonHelper.asStringList(json['target_city_codes']),
      geohashPrefixes: AdJsonHelper.asStringList(json['geohash_prefixes']),
      productIds: AdJsonHelper.asStringList(json['product_ids']),
      lastTriggeredAt: AdJsonHelper.asDateTime(json['last_triggered_at']),
      isActive: AdJsonHelper.asBool(json['is_active'], fallback: true),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'seller_id': sellerId,
      'store_id': storeId,
      'title': title,
      'body': body,
      'radius_meters': radiusMeters,
      'cooldown_hours': cooldownHours,
      'max_sends_per_week': maxSendsPerWeek,
      'trigger_type': triggerType.dbValue,
      'target_city_codes': targetCityCodes,
      'geohash_prefixes': geohashPrefixes,
      'product_ids': productIds,
      'last_triggered_at': lastTriggeredAt?.toUtc().toIso8601String(),
      'is_active': isActive,
      'metadata': metadata,
    };
  }
}
