/// Server-authoritative rental price math. Client may preview only.
abstract final class VehicleRentalPricing {
  /// Inclusive calendar days. Same-day pickup/return counts as 1.
  static int rentalDays({
    required DateTime pickupAt,
    required DateTime returnAt,
  }) {
    if (!returnAt.isAfter(pickupAt) && pickupAt != returnAt) {
      throw ArgumentError('returnAt must be on/after pickupAt');
    }
    final pickup = DateTime(pickupAt.year, pickupAt.month, pickupAt.day);
    final ret = DateTime(returnAt.year, returnAt.month, returnAt.day);
    final days = ret.difference(pickup).inDays;
    return days <= 0 ? 1 : days;
  }

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime atHour(DateTime value, {int hour = 10, int minute = 0}) =>
      DateTime(value.year, value.month, value.day, hour, minute);

  /// Inclusive of minDays: pickup 15 Sep + min 3 → earliest return 18 Sep.
  static DateTime earliestReturnAt(DateTime pickupAt, int minDays) {
    final min = minDays < 1 ? 1 : minDays;
    return atHour(dateOnly(pickupAt).add(Duration(days: min)), hour: pickupAt.hour, minute: pickupAt.minute);
  }

  static DateTime latestReturnAt(DateTime pickupAt, int maxDays) {
    final max = maxDays < 1 ? 1 : maxDays;
    return atHour(dateOnly(pickupAt).add(Duration(days: max)), hour: pickupAt.hour, minute: pickupAt.minute);
  }

  static DateTime defaultPickup({DateTime? now}) {
    final n = now ?? DateTime.now();
    return atHour(dateOnly(n).add(const Duration(days: 1)));
  }

  static DateTime defaultReturn(DateTime pickupAt, int minDays) =>
      earliestReturnAt(pickupAt, minDays);

  /// User-facing duration error. Never throw this in UI.
  static String? durationMessage({
    required int days,
    required int minDays,
    required int maxDays,
    required DateTime pickupAt,
  }) {
    if (days < minDays) {
      final earliest = earliestReturnAt(pickupAt, minDays);
      return 'Bu araç minimum $minDays gün kiralanabilir. Lütfen bitiş tarihini '
          '${_dateLabel(earliest)} veya sonrası olarak seçin.';
    }
    if (days > maxDays) {
      final latest = latestReturnAt(pickupAt, maxDays);
      return 'Bu araç en fazla $maxDays gün kiralanabilir. Lütfen bitiş tarihini '
          '${_dateLabel(latest)} veya öncesi olarak seçin.';
    }
    return null;
  }

  static String _dateLabel(DateTime value) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    return '${value.day} ${months[value.month - 1]}';
  }

  static int assertDurationAllowed({
    required int days,
    required int minDays,
    required int maxDays,
  }) {
    if (minDays < 1) {
      throw ArgumentError('minDays must be >= 1');
    }
    if (maxDays < minDays) {
      throw ArgumentError('maxDays must be >= minDays');
    }
    if (days < minDays || days > maxDays) {
      throw StateError('Rental duration $days is outside [$minDays, $maxDays]');
    }
    return days;
  }

  /// Picks the cheapest published band: monthly → weekly → daily.
  static double rentalSubtotal({
    required int days,
    required double dailyPrice,
    double? weeklyPrice,
    double? monthlyPrice,
  }) {
    if (days < 1) throw ArgumentError('days must be >= 1');
    if (dailyPrice < 0) throw ArgumentError('dailyPrice must be >= 0');

    var best = dailyPrice * days;
    if (weeklyPrice != null && weeklyPrice > 0 && days >= 7) {
      final weeks = days / 7.0;
      final weeklyTotal = weeklyPrice * weeks;
      if (weeklyTotal < best) best = weeklyTotal;
    }
    if (monthlyPrice != null && monthlyPrice > 0 && days >= 28) {
      final months = days / 30.0;
      final monthlyTotal = monthlyPrice * months;
      if (monthlyTotal < best) best = monthlyTotal;
    }
    return _roundMoney(best);
  }

  static double extraKmFee({
    required int extraKm,
    required double extraKmPrice,
  }) {
    if (extraKm < 0) throw ArgumentError('extraKm must be >= 0');
    if (extraKmPrice < 0) throw ArgumentError('extraKmPrice must be >= 0');
    return _roundMoney(extraKm * extraKmPrice);
  }

  static double checkoutTotal({
    required double rentalSubtotal,
    required double deliveryFee,
    required double deposit,
  }) {
    if (rentalSubtotal < 0 || deliveryFee < 0 || deposit < 0) {
      throw ArgumentError('Amounts must be >= 0');
    }
    return _roundMoney(rentalSubtotal + deliveryFee + deposit);
  }

  static double _roundMoney(double value) =>
      (value * 100).roundToDouble() / 100;
}
