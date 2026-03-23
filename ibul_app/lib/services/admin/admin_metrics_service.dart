class AdminAnalyticsBucket {
  const AdminAnalyticsBucket({
    required this.label,
    required this.value,
    required this.share,
  });

  final String label;
  final int value;
  final double share;
}

double clampAdminRatio(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}

List<AdminAnalyticsBucket> buildAdminAnalyticsBuckets(
  Map<String, int> source, {
  required int limit,
}) {
  final total = source.values.fold<int>(0, (sum, value) => sum + value);
  final entries = source.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return entries
      .take(limit)
      .map(
        (entry) => AdminAnalyticsBucket(
          label: entry.key,
          value: entry.value,
          share: total == 0 ? 0 : entry.value / total,
        ),
      )
      .toList(growable: false);
}
