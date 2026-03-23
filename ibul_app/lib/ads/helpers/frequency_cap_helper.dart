import '../models/ad_metrics.dart';
import '../models/user_product_event.dart';

class FrequencyCapHelper {
  const FrequencyCapHelper._();

  static bool isWithinCampaignCap({
    required String campaignId,
    required Iterable<UserProductEvent> events,
    required int maxPerDay,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final startOfDay = DateTime(current.year, current.month, current.day);
    final impressionsToday = events.where((event) {
      return event.campaignId == campaignId &&
          !event.createdAt.isBefore(startOfDay) &&
          event.eventType.dbValue == 'impression';
    }).length;
    return impressionsToday < maxPerDay;
  }

  static bool isStoreNotificationAllowed({
    required String storeId,
    required Iterable<UserProductEvent> events,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final cutoff = current.subtract(const Duration(hours: 24));
    final sentRecently = events.any((event) {
      return event.storeId == storeId &&
          event.createdAt.isAfter(cutoff) &&
          event.metadata['notification_sent'] == true;
    });
    return !sentRecently;
  }

  static Set<String> recentlySeenEntityIds(
    Iterable<UserProductEvent> events, {
    int maxItems = 6,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final cutoff = current.subtract(const Duration(hours: 12));
    final seen = <String>{};
    for (final event in events) {
      if (event.createdAt.isBefore(cutoff)) continue;
      final entityId = event.productId ?? event.storeId ?? event.collectionId;
      if ((entityId ?? '').isEmpty) continue;
      seen.add(entityId!);
      if (seen.length >= maxItems) break;
    }
    return seen;
  }

  static double adFatigueScore({
    required AdMetrics metrics,
    required int maxFrequencyCap,
  }) {
    final frequencyPenalty = metrics.frequencyProxy == 0
        ? 0.0
        : (metrics.frequencyProxy / maxFrequencyCap).clamp(0.0, 2.0);
    final ctrPenalty = metrics.ctr == 0
        ? 0.4
        : (0.025 / metrics.ctr).clamp(0.0, 1.5);
    final repeatedLowEngagementPenalty =
        metrics.impressions > 1500 && metrics.clicks < 20 ? 0.5 : 0.0;
    return (frequencyPenalty + ctrPenalty + repeatedLowEngagementPenalty).clamp(
      0.0,
      3.0,
    );
  }
}
