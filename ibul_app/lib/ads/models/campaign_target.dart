import '../enums/ad_enums.dart';
import '../helpers/ad_json_helper.dart';

class CampaignTarget {
  const CampaignTarget({
    required this.campaignId,
    required this.objective,
    this.id,
    this.placements = const [],
    this.categories = const [],
    this.keywords = const [],
    this.cityCodes = const [],
    this.geohashPrefixes = const [],
    this.minPrice,
    this.maxPrice,
    this.radiusMeters,
    this.eventLookbackDays = 30,
    this.frequencyCapPerDay = 3,
    this.retargetingWindowDays = 14,
    this.metadata = const {},
  });

  final String? id;
  final String campaignId;
  final CampaignObjective objective;
  final List<AdPlacement> placements;
  final List<String> categories;
  final List<String> keywords;
  final List<String> cityCodes;
  final List<String> geohashPrefixes;
  final double? minPrice;
  final double? maxPrice;
  final int? radiusMeters;
  final int eventLookbackDays;
  final int frequencyCapPerDay;
  final int retargetingWindowDays;
  final Map<String, dynamic> metadata;

  factory CampaignTarget.fromJson(Map<String, dynamic> json) {
    return CampaignTarget(
      id: AdJsonHelper.asNullableString(json['id']),
      campaignId: AdJsonHelper.asString(json['campaign_id']),
      objective: CampaignObjectiveParser.fromDbValue(
        json['objective']?.toString(),
      ),
      placements: AdJsonHelper.asStringList(
        json['placements'],
      ).map(AdPlacementParser.fromDbValue).toList(growable: false),
      categories: AdJsonHelper.asStringList(json['categories']),
      keywords: AdJsonHelper.asStringList(json['keywords']),
      cityCodes: AdJsonHelper.asStringList(json['city_codes']),
      geohashPrefixes: AdJsonHelper.asStringList(json['geohash_prefixes']),
      minPrice: json['min_price'] == null
          ? null
          : AdJsonHelper.asDouble(json['min_price']),
      maxPrice: json['max_price'] == null
          ? null
          : AdJsonHelper.asDouble(json['max_price']),
      radiusMeters: json['radius_meters'] == null
          ? null
          : AdJsonHelper.asInt(json['radius_meters']),
      eventLookbackDays: AdJsonHelper.asInt(
        json['event_lookback_days'],
        fallback: 30,
      ),
      frequencyCapPerDay: AdJsonHelper.asInt(
        json['frequency_cap_per_day'],
        fallback: 3,
      ),
      retargetingWindowDays: AdJsonHelper.asInt(
        json['retargeting_window_days'],
        fallback: 14,
      ),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'objective': objective.dbValue,
      'placements': placements.map((item) => item.dbValue).toList(),
      'categories': categories,
      'keywords': keywords,
      'city_codes': cityCodes,
      'geohash_prefixes': geohashPrefixes,
      'min_price': minPrice,
      'max_price': maxPrice,
      'radius_meters': radiusMeters,
      'event_lookback_days': eventLookbackDays,
      'frequency_cap_per_day': frequencyCapPerDay,
      'retargeting_window_days': retargetingWindowDays,
      'metadata': metadata,
    };
  }

  CampaignTarget copyWith({
    String? id,
    String? campaignId,
    CampaignObjective? objective,
    List<AdPlacement>? placements,
    List<String>? categories,
    List<String>? keywords,
    List<String>? cityCodes,
    List<String>? geohashPrefixes,
    double? minPrice,
    double? maxPrice,
    int? radiusMeters,
    int? eventLookbackDays,
    int? frequencyCapPerDay,
    int? retargetingWindowDays,
    Map<String, dynamic>? metadata,
  }) {
    return CampaignTarget(
      id: id ?? this.id,
      campaignId: campaignId ?? this.campaignId,
      objective: objective ?? this.objective,
      placements: placements ?? this.placements,
      categories: categories ?? this.categories,
      keywords: keywords ?? this.keywords,
      cityCodes: cityCodes ?? this.cityCodes,
      geohashPrefixes: geohashPrefixes ?? this.geohashPrefixes,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      eventLookbackDays: eventLookbackDays ?? this.eventLookbackDays,
      frequencyCapPerDay: frequencyCapPerDay ?? this.frequencyCapPerDay,
      retargetingWindowDays:
          retargetingWindowDays ?? this.retargetingWindowDays,
      metadata: metadata ?? this.metadata,
    );
  }
}
