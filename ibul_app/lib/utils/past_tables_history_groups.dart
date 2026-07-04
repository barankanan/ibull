import 'package:intl/intl.dart';

import '../models/restaurant_ops_models.dart';

/// One calendar day of closed-table history records.
class PastTablesHistoryGroup {
  const PastTablesHistoryGroup({
    required this.date,
    required this.label,
    required this.items,
  });

  /// Local calendar date (midnight).
  final DateTime date;

  /// e.g. "30 Haziran 2026 • Pazartesi"
  final String label;

  final List<TableOrderHistoryRecord> items;
}

DateTime _localDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String formatPastTablesGroupLabel(DateTime day) {
  final datePart = DateFormat('d MMMM yyyy', 'tr').format(day);
  final weekdayPart = DateFormat('EEEE', 'tr').format(day);
  return '$datePart • $weekdayPart';
}

/// Groups history records by [TableOrderHistoryRecord.closedAt] local day.
/// Groups are newest-first; items inside each group are newest-first.
List<PastTablesHistoryGroup> groupPastTableHistoryRecords(
  List<TableOrderHistoryRecord> records,
) {
  if (records.isEmpty) return const <PastTablesHistoryGroup>[];

  final grouped = <DateTime, List<TableOrderHistoryRecord>>{};
  for (final record in records) {
    final day = _localDay(record.closedAt);
    grouped.putIfAbsent(day, () => <TableOrderHistoryRecord>[]).add(record);
  }

  final days = grouped.keys.toList(growable: false)
    ..sort((a, b) => b.compareTo(a));

  return days
      .map((day) {
        final items = List<TableOrderHistoryRecord>.from(grouped[day]!)
          ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
        return PastTablesHistoryGroup(
          date: day,
          label: formatPastTablesGroupLabel(day),
          items: items,
        );
      })
      .toList(growable: false);
}
