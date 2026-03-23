import '../models/ab_test_variant.dart';

class AbTestHelper {
  const AbTestHelper._();

  static List<AbTestVariant> activeVariants(Iterable<AbTestVariant> variants) {
    return variants
        .where((variant) => variant.isActive)
        .toList(growable: false);
  }

  static AbTestVariant? resolveVariant({
    required String seed,
    required Iterable<AbTestVariant> variants,
  }) {
    final active = activeVariants(variants);
    if (active.isEmpty) return null;
    final totalWeight = active.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    final bucket = totalWeight == 0
        ? 0.0
        : (_stableHash(seed) % 10000) / 10000 * totalWeight;
    var cursor = 0.0;
    for (final variant in active) {
      cursor += variant.weight;
      if (bucket <= cursor) {
        return variant;
      }
    }
    return active.last;
  }

  static Map<String, double> impressionSplit(Iterable<AbTestVariant> variants) {
    final active = activeVariants(variants);
    final totalWeight = active.fold<double>(
      0,
      (sum, item) => sum + item.weight,
    );
    if (totalWeight == 0) {
      return {
        for (final variant in active)
          variant.id ?? variant.name: active.isEmpty ? 0 : 1 / active.length,
      };
    }
    return {
      for (final variant in active)
        variant.id ?? variant.name: variant.weight / totalWeight,
    };
  }

  static AbTestVariant? winner({
    required Iterable<AbTestVariant> variants,
    int minimumImpressions = 150,
  }) {
    final candidates = activeVariants(
      variants,
    ).where((variant) => variant.impressions >= minimumImpressions);
    AbTestVariant? leader;
    var leaderScore = -1.0;
    for (final variant in candidates) {
      final score = performanceScore(variant);
      if (score > leaderScore) {
        leader = variant;
        leaderScore = score;
      }
    }
    return leader;
  }

  static List<Map<String, dynamic>> comparePerformance(
    Iterable<AbTestVariant> variants,
  ) {
    return activeVariants(variants)
        .map((variant) {
          final ctr = variant.impressions == 0
              ? 0.0
              : variant.clicks / variant.impressions;
          final conversionRate = variant.clicks == 0
              ? 0.0
              : variant.conversions / variant.clicks;
          return <String, dynamic>{
            'variant_id': variant.id ?? variant.name,
            'variant_name': variant.name,
            'ctr': ctr,
            'conversion_rate': conversionRate,
            'performance_score': performanceScore(variant),
          };
        })
        .toList(growable: false)
      ..sort(
        (a, b) => (b['performance_score'] as double).compareTo(
          a['performance_score'] as double,
        ),
      );
  }

  static double performanceScore(AbTestVariant variant) {
    final ctr = variant.impressions == 0
        ? 0.0
        : variant.clicks / variant.impressions;
    final conversionRate = variant.clicks == 0
        ? 0.0
        : variant.conversions / variant.clicks;
    return ((ctr * 0.45) + (conversionRate * 0.55)) * 100;
  }

  static int _stableHash(String seed) {
    var hash = 0;
    for (final unit in seed.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
