class VehicleCancellationPolicy {
  const VehicleCancellationPolicy({
    this.fullRefundHours = 24,
    this.halfRefundHours = 12,
    this.fullPercent = 100,
    this.halfPercent = 50,
    this.latePercent = 0,
  });

  final int fullRefundHours;
  final int halfRefundHours;
  final double fullPercent;
  final double halfPercent;
  final double latePercent;

  factory VehicleCancellationPolicy.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const VehicleCancellationPolicy();
    }
    int hours(String key, int fallback) {
      final raw = map[key];
      if (raw is num) return raw.toInt();
      return int.tryParse('$raw') ?? fallback;
    }

    double pct(String key, double fallback) {
      final raw = map[key];
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw') ?? fallback;
    }

    return VehicleCancellationPolicy(
      fullRefundHours: hours('full_refund_hours', 24),
      halfRefundHours: hours('half_refund_hours', 12),
      fullPercent: pct('full_percent', 100),
      halfPercent: pct('half_percent', 50),
      latePercent: pct('late_percent', 0),
    );
  }

  Map<String, dynamic> toMap() => {
    'full_refund_hours': fullRefundHours,
    'half_refund_hours': halfRefundHours,
    'full_percent': fullPercent,
    'half_percent': halfPercent,
    'late_percent': latePercent,
  };

  /// Seller-caused cancel is always 100%. Customer uses the hour bands.
  double refundPercent({
    required DateTime startAt,
    required DateTime now,
    required bool sellerCaused,
  }) {
    if (sellerCaused) return 100;
    final hours = startAt.difference(now).inMinutes / 60.0;
    if (hours >= fullRefundHours) return fullPercent;
    if (hours >= halfRefundHours) return halfPercent;
    return latePercent;
  }

  double refundAmount({
    required double paidTotal,
    required DateTime startAt,
    required DateTime now,
    required bool sellerCaused,
  }) {
    final pct = refundPercent(
      startAt: startAt,
      now: now,
      sellerCaused: sellerCaused,
    );
    return ((paidTotal * pct / 100) * 100).roundToDouble() / 100;
  }
}
