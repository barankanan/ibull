class VehicleBusyInterval {
  const VehicleBusyInterval({
    required this.start,
    required this.end,
    this.kind = 'reserved',
  });

  final DateTime start;
  final DateTime end;
  final String kind;

  bool overlaps(DateTime pickupAt, DateTime returnAt) {
    return pickupAt.isBefore(end) && returnAt.isAfter(start);
  }

  static String normalizeKind(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'maintenance':
      case 'bakim':
      case 'bakım':
        return 'maintenance';
      case 'blocked':
      case 'closed':
      case 'kapali':
      case 'kapalı':
        return 'closed';
      default:
        return 'reserved';
    }
  }

  static String? kindOnDay(DateTime day, List<VehicleBusyInterval> busy) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    for (final interval in busy) {
      if (interval.overlaps(start, end)) return interval.kind;
    }
    return null;
  }
}

/// Same vehicle cannot be reserved twice in an overlapping window.
abstract final class VehicleAvailability {
  static bool isFree({
    required DateTime pickupAt,
    required DateTime returnAt,
    required List<VehicleBusyInterval> busy,
  }) {
    if (!returnAt.isAfter(pickupAt)) return false;
    for (final interval in busy) {
      if (interval.overlaps(pickupAt, returnAt)) return false;
    }
    return true;
  }

  static void assertFree({
    required DateTime pickupAt,
    required DateTime returnAt,
    required List<VehicleBusyInterval> busy,
  }) {
    if (!isFree(pickupAt: pickupAt, returnAt: returnAt, busy: busy)) {
      throw StateError('Vehicle is not available in the selected window');
    }
  }
}
