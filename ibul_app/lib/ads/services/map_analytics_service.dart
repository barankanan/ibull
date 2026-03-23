import '../helpers/map_analytics_helper.dart';
import '../models/heatmap_point.dart';
import '../models/zone_performance.dart';
import '../repositories/ads_repository.dart';

class MapAnalyticsService {
  MapAnalyticsService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<ZonePerformance>> getZonePerformance({
    required String userId,
    int lookbackDays = 30,
  }) async {
    final events = await _repository.getUserEvents(
      userId: userId,
      from: DateTime.now().subtract(Duration(days: lookbackDays)),
    );
    return MapAnalyticsHelper.aggregate(events);
  }

  Future<List<HeatmapPoint>> getHeatmap({
    required String userId,
    int lookbackDays = 30,
  }) async {
    final zones = await getZonePerformance(
      userId: userId,
      lookbackDays: lookbackDays,
    );
    return MapAnalyticsHelper.toHeatmapPoints(zones);
  }
}
