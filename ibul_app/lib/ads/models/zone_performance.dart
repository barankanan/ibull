import '../helpers/ad_json_helper.dart';

class ZonePerformance {
  const ZonePerformance({
    required this.zoneKey,
    required this.latitude,
    required this.longitude,
    this.cityCode,
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.geoEntries = 0,
    this.spend = 0,
    this.revenue = 0,
  });

  final String zoneKey;
  final double latitude;
  final double longitude;
  final String? cityCode;
  final int impressions;
  final int clicks;
  final int conversions;
  final int geoEntries;
  final double spend;
  final double revenue;

  double get ctr => impressions == 0 ? 0 : clicks / impressions;
  double get conversionRate => clicks == 0 ? 0 : conversions / clicks;
  double get geofenceConversionRate =>
      geoEntries == 0 ? 0 : conversions / geoEntries;

  factory ZonePerformance.fromJson(Map<String, dynamic> json) {
    return ZonePerformance(
      zoneKey: AdJsonHelper.asString(json['zone_key']),
      latitude: AdJsonHelper.asDouble(json['latitude']),
      longitude: AdJsonHelper.asDouble(json['longitude']),
      cityCode: AdJsonHelper.asNullableString(json['city_code']),
      impressions: AdJsonHelper.asInt(json['impressions']),
      clicks: AdJsonHelper.asInt(json['clicks']),
      conversions: AdJsonHelper.asInt(json['conversions']),
      geoEntries: AdJsonHelper.asInt(json['geo_entries']),
      spend: AdJsonHelper.asDouble(json['spend']),
      revenue: AdJsonHelper.asDouble(json['revenue']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zone_key': zoneKey,
      'latitude': latitude,
      'longitude': longitude,
      'city_code': cityCode,
      'impressions': impressions,
      'clicks': clicks,
      'conversions': conversions,
      'geo_entries': geoEntries,
      'spend': spend,
      'revenue': revenue,
    };
  }
}
