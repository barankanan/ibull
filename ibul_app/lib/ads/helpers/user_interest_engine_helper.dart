import '../models/user_interest.dart';
import '../models/user_product_event.dart';

class UserInterestEngineHelper {
  const UserInterestEngineHelper._();

  static const Map<String, double> _eventWeights = <String, double>{
    'detail_view': 1.0,
    'favorite': 2.2,
    'add_to_cart': 3.1,
    'checkout_started': 3.8,
    'purchase': 5.0,
    'store_visit': 1.7,
    'collection_open': 1.3,
  };

  static List<UserInterest> buildInterestProfile({
    required String userId,
    required Iterable<UserProductEvent> events,
    Iterable<UserInterest> existing = const [],
  }) {
    final scores = <String, double>{};
    final counts = <String, int>{};
    final timestamps = <String, DateTime>{};
    final types = <String, String>{};

    void addSignal(
      String key,
      String type,
      UserProductEvent event,
      double baseWeight,
    ) {
      final normalizedKey = key.trim().toLowerCase();
      if (normalizedKey.isEmpty) return;
      final recencyMultiplier = _recencyMultiplier(event.createdAt);
      scores[normalizedKey] =
          (scores[normalizedKey] ?? 0) + (baseWeight * recencyMultiplier);
      counts[normalizedKey] = (counts[normalizedKey] ?? 0) + 1;
      types[normalizedKey] = type;
      final previous = timestamps[normalizedKey];
      if (previous == null || previous.isBefore(event.createdAt)) {
        timestamps[normalizedKey] = event.createdAt;
      }
    }

    for (final interest in existing) {
      scores[interest.interestKey.toLowerCase()] =
          interest.affinityScore *
          (interest.sourceEventCount == 0 ? 1 : interest.sourceEventCount);
      counts[interest.interestKey.toLowerCase()] = interest.sourceEventCount;
      types[interest.interestKey.toLowerCase()] = interest.interestType;
      if (interest.lastInteractionAt != null) {
        timestamps[interest.interestKey.toLowerCase()] =
            interest.lastInteractionAt!;
      }
    }

    for (final event in events) {
      final weight = _eventWeights[event.eventType.dbValue] ?? 0.7;
      final metadata = event.metadata;
      final category = metadata['category']?.toString();
      final subcategory = metadata['subcategory']?.toString();
      final tags = (metadata['tags'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false);
      final storeCategory = metadata['store_category']?.toString();
      final collectionTheme = metadata['collection_theme']?.toString();

      if (category != null && category.isNotEmpty) {
        addSignal(category, 'category', event, weight);
      }
      if (subcategory != null && subcategory.isNotEmpty) {
        addSignal(subcategory, 'subcategory', event, weight * 0.85);
      }
      if (storeCategory != null && storeCategory.isNotEmpty) {
        addSignal(storeCategory, 'store_category', event, weight * 0.8);
      }
      if (collectionTheme != null && collectionTheme.isNotEmpty) {
        addSignal(collectionTheme, 'collection', event, weight * 0.9);
      }
      for (final tag in tags) {
        addSignal(tag, 'tag', event, weight * 0.75);
      }
    }

    if (scores.isEmpty) return existing.toList(growable: false);

    final maxScore = scores.values.fold<double>(
      0,
      (max, item) => item > max ? item : max,
    );
    return scores.entries
        .map((entry) {
          final count = counts[entry.key] ?? 0;
          final normalized = maxScore == 0
              ? 0.0
              : (entry.value / maxScore).clamp(0.0, 1.0).toDouble();
          return UserInterest(
            userId: userId,
            interestKey: entry.key,
            interestType: types[entry.key] ?? 'behavioral',
            affinityScore: normalized,
            sourceEventCount: count,
            lastInteractionAt: timestamps[entry.key],
            metadata: <String, dynamic>{
              'raw_score': entry.value,
              'normalized_score': normalized,
            },
          );
        })
        .toList(growable: false)
      ..sort((a, b) => b.affinityScore.compareTo(a.affinityScore));
  }

  static Map<String, double> buildAffinityMap(
    Iterable<UserInterest> interests,
  ) {
    final result = <String, double>{};
    for (final interest in interests) {
      result[interest.interestKey.toLowerCase()] = interest.affinityScore;
    }
    return result;
  }

  static double computeRelevanceScore({
    required Iterable<String> campaignKeys,
    required Iterable<UserInterest> interests,
  }) {
    final affinityMap = buildAffinityMap(interests);
    var score = 0.0;
    var matched = 0;
    for (final key in campaignKeys) {
      final normalized = key.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      final affinity = affinityMap[normalized];
      if (affinity == null) continue;
      score += affinity;
      matched += 1;
    }
    if (matched == 0) return 0;
    return (score / matched).clamp(0.0, 1.0);
  }

  static double _recencyMultiplier(DateTime createdAt) {
    final ageInDays = DateTime.now().difference(createdAt).inDays;
    if (ageInDays <= 2) return 1.2;
    if (ageInDays <= 7) return 1.0;
    if (ageInDays <= 14) return 0.85;
    if (ageInDays <= 30) return 0.65;
    return 0.4;
  }
}
