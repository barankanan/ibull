import '../models/heatmap_point.dart';
import '../models/user_product_event.dart';
import '../models/zone_performance.dart';

class MapAnalyticsHelper {
  const MapAnalyticsHelper._();

  static List<ZonePerformance> aggregate(
    Iterable<UserProductEvent> events, {
    int precision = 2,
  }) {
    final aggregates = <String, ZonePerformance>{};

    for (final event in events) {
      final latitude = event.latitude;
      final longitude = event.longitude;
      if (latitude == null || longitude == null) continue;

      final zoneLat = _round(latitude, precision);
      final zoneLng = _round(longitude, precision);
      final zoneKey = '${event.cityCode ?? 'NA'}:$zoneLat:$zoneLng';
      final current =
          aggregates[zoneKey] ??
          ZonePerformance(
            zoneKey: zoneKey,
            latitude: zoneLat,
            longitude: zoneLng,
            cityCode: event.cityCode,
          );

      aggregates[zoneKey] = ZonePerformance(
        zoneKey: current.zoneKey,
        latitude: current.latitude,
        longitude: current.longitude,
        cityCode: current.cityCode,
        impressions:
            current.impressions +
            (event.eventType.dbValue == 'impression' ? 1 : 0),
        clicks: current.clicks + (event.eventType.dbValue == 'click' ? 1 : 0),
        conversions:
            current.conversions +
            (event.eventType.dbValue == 'purchase' ? 1 : 0),
        geoEntries:
            current.geoEntries +
            (event.eventType.dbValue == 'geo_enter' ? 1 : 0),
        spend:
            current.spend +
            ((event.metadata['ad_spend'] as num?)?.toDouble() ?? 0),
        revenue:
            current.revenue +
            ((event.metadata['order_value'] as num?)?.toDouble() ?? 0),
      );
    }

    return aggregates.values.toList(growable: false)
      ..sort((a, b) => b.ctr.compareTo(a.ctr));
  }

  static List<HeatmapPoint> toHeatmapPoints(Iterable<ZonePerformance> zones) {
    return zones
        .map((zone) {
          final intensity =
              (zone.ctr * 0.45) +
              (zone.conversionRate * 0.4) +
              (zone.geofenceConversionRate * 0.15);
          return HeatmapPoint(
            latitude: zone.latitude,
            longitude: zone.longitude,
            intensity: intensity,
            zoneKey: zone.zoneKey,
            metadata: <String, dynamic>{
              'city_code': zone.cityCode,
              'impressions': zone.impressions,
              'clicks': zone.clicks,
              'conversions': zone.conversions,
            },
          );
        })
        .toList(growable: false)
      ..sort((a, b) => b.intensity.compareTo(a.intensity));
  }

  static double _round(double value, int precision) {
    var multiplier = 1.0;
    for (var index = 0; index < precision; index += 1) {
      multiplier *= 10;
    }
    return (value * multiplier).roundToDouble() / multiplier;
  }
}
