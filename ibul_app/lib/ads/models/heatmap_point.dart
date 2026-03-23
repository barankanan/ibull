import '../helpers/ad_json_helper.dart';

class HeatmapPoint {
  const HeatmapPoint({
    required this.latitude,
    required this.longitude,
    required this.intensity,
    this.zoneKey,
    this.metadata = const {},
  });

  final double latitude;
  final double longitude;
  final double intensity;
  final String? zoneKey;
  final Map<String, dynamic> metadata;

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      latitude: AdJsonHelper.asDouble(json['latitude']),
      longitude: AdJsonHelper.asDouble(json['longitude']),
      intensity: AdJsonHelper.asDouble(json['intensity']),
      zoneKey: AdJsonHelper.asNullableString(json['zone_key']),
      metadata: AdJsonHelper.asMap(json['metadata']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'intensity': intensity,
      'zone_key': zoneKey,
      'metadata': metadata,
    };
  }
}
