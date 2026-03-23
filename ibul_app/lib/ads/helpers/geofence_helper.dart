import 'package:geolocator/geolocator.dart';

import '../models/geo_push_trigger.dart';
import '../models/user_product_event.dart';

class GeofenceHelper {
  const GeofenceHelper._();

  static bool cooldownPassed({
    required GeoPushTrigger trigger,
    required Iterable<UserProductEvent> events,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final cutoff = current.subtract(Duration(hours: trigger.cooldownHours));
    final hasRecentSend = events.any((event) {
      return event.campaignId == trigger.campaignId &&
          event.metadata['notification_sent'] == true &&
          event.createdAt.isAfter(cutoff);
    });
    if (hasRecentSend) return false;
    if (trigger.lastTriggeredAt == null) return true;
    return trigger.lastTriggeredAt!.isBefore(cutoff);
  }

  static bool withinDailyLimit({
    required GeoPushTrigger trigger,
    required Iterable<UserProductEvent> events,
    required int maxPerDay,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfDay = DateTime(current.year, current.month, current.day);
    final count = events.where((event) {
      return event.campaignId == trigger.campaignId &&
          event.metadata['notification_sent'] == true &&
          !event.createdAt.isBefore(startOfDay);
    }).length;
    return count < maxPerDay;
  }

  static bool isEligible({
    required GeoPushTrigger trigger,
    required double userLatitude,
    required double userLongitude,
    required Iterable<UserProductEvent> recentEvents,
    String? cityCode,
    DateTime? now,
    int dailyLimit = 2,
  }) {
    final current = now ?? DateTime.now();
    if (!trigger.isActive) return false;
    if (cityCode != null &&
        trigger.targetCityCodes.isNotEmpty &&
        !trigger.targetCityCodes.contains(cityCode)) {
      return false;
    }

    final hadRelevantInteraction = recentEvents.any((event) {
      final interactedRecently = event.createdAt.isAfter(
        current.subtract(const Duration(days: 30)),
      );
      final relatedStore = event.storeId == trigger.storeId;
      final relatedProduct = trigger.productIds.contains(event.productId);
      return interactedRecently && (relatedStore || relatedProduct);
    });
    if (!hadRelevantInteraction) return false;

    if (!cooldownPassed(trigger: trigger, events: recentEvents, now: current)) {
      return false;
    }
    if (!withinDailyLimit(
      trigger: trigger,
      events: recentEvents,
      maxPerDay: dailyLimit,
      now: current,
    )) {
      return false;
    }

    final purchasedRecently = recentEvents.any((event) {
      final recentlyPurchased = event.createdAt.isAfter(
        current.subtract(const Duration(days: 21)),
      );
      return recentlyPurchased &&
          event.eventType.dbValue == 'purchase' &&
          (event.storeId == trigger.storeId ||
              trigger.productIds.contains(event.productId));
    });
    if (purchasedRecently && trigger.triggerType.dbValue != 'wishlist_nearby') {
      return false;
    }

    final storeLatitude = (trigger.metadata['store_latitude'] as num?)
        ?.toDouble();
    final storeLongitude = (trigger.metadata['store_longitude'] as num?)
        ?.toDouble();
    if (storeLatitude == null || storeLongitude == null) {
      return true;
    }

    final distance = Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      storeLatitude,
      storeLongitude,
    );
    return distance <= trigger.radiusMeters;
  }

  static Map<String, dynamic> buildPayload(
    GeoPushTrigger trigger, {
    String? headline,
  }) {
    final message = headline ?? _defaultHeadline(trigger);
    return <String, dynamic>{
      'campaign_id': trigger.campaignId,
      'store_id': trigger.storeId,
      'title': message,
      'body': trigger.body,
      'radius_meters': trigger.radiusMeters,
      'deeplink': trigger.metadata['deeplink'] ?? trigger.metadata['deep_link'],
      'product_ids': trigger.productIds,
      ...trigger.metadata,
    };
  }

  static String _defaultHeadline(GeoPushTrigger trigger) {
    return switch (trigger.triggerType) {
      _ when trigger.triggerType.dbValue == 'abandoned_cart_nearby' =>
        'Sepetinde biraktigin urun cok yakininda',
      _ when trigger.triggerType.dbValue == 'wishlist_nearby' =>
        'Begendigin magaza yakinda',
      _ when trigger.triggerType.dbValue == 'repeat_visit' =>
        'Daha once baktigin urunun magazasi yakininda',
      _ => 'Ilgilendigin liste simdi one cikiyor',
    };
  }
}
