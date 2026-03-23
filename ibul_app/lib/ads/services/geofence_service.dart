import '../helpers/geofence_helper.dart';
import '../models/geo_push_trigger.dart';
import '../repositories/ads_repository.dart';

class GeofenceService {
  GeofenceService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<GeoPushTrigger>> getEligibleTriggers({
    required String userId,
    required double latitude,
    required double longitude,
    String? cityCode,
    DateTime? at,
  }) async {
    final current = at ?? DateTime.now();
    final triggers = await _repository.getGeoPushTriggers();
    final recentEvents = await _repository.getUserEvents(
      userId: userId,
      from: current.subtract(const Duration(days: 30)),
    );

    return triggers
        .where((trigger) {
          return GeofenceHelper.isEligible(
            trigger: trigger,
            userLatitude: latitude,
            userLongitude: longitude,
            recentEvents: recentEvents,
            cityCode: cityCode,
            now: current,
            dailyLimit: trigger.maxSendsPerWeek < 2 ? 1 : 2,
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic> buildPushPayload(GeoPushTrigger trigger) {
    return GeofenceHelper.buildPayload(trigger, headline: trigger.title);
  }
}
