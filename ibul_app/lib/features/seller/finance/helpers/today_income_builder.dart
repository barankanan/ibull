import '../../../../services/store/table_order_history_utils.dart';
import '../../../../utils/order_status_constants.dart';
import '../models/finance_models.dart';

double sumClosedTableIncome({
  required List<Map<String, dynamic>> historyRows,
  required DateTime from,
  required DateTime to,
}) {
  return historyRows.fold<double>(0, (sum, row) {
    final typedRow = Map<dynamic, dynamic>.from(row);
    final status = typedRow['status']?.toString();
    if (OrderStatusConstants.isCancelledStatus(status)) return sum;
    if (!TableOrderHistoryUtils.isWithinRange(typedRow, from, to)) return sum;
    return sum + TableOrderHistoryUtils.revenue(typedRow);
  });
}

List<TodayIncomeLine> buildTodayIncomeLines({
  required DateTime from,
  required DateTime to,
  required List<Map<String, dynamic>> historyRows,
  required List<Map<String, dynamic>> onlineRows,
  required List<Map<String, dynamic>> manualIncomeRows,
}) {
  final lines = <TodayIncomeLine>[];

  final onlineEligibleRows = onlineRows
      .where((row) {
        final status = row['status']?.toString();
        if (OrderStatusConstants.isCancelledStatus(status)) return false;
        final createdAt = DateTime.tryParse(
          row['created_at']?.toString() ?? '',
        )?.toLocal();
        if (createdAt == null) return false;
        return !createdAt.isBefore(from) && !createdAt.isAfter(to);
      })
      .toList(growable: false);

  final onlineAmount = onlineEligibleRows.fold<double>(0, (sum, row) {
    final total = row['total_price'];
    if (total is num) return sum + total.toDouble();
    return sum + (double.tryParse(total?.toString() ?? '') ?? 0);
  });
  if (onlineAmount > 0 || onlineEligibleRows.isNotEmpty) {
    lines.add(
      TodayIncomeLine(
        label: 'Online Siparisler',
        amount: onlineAmount,
        count: onlineEligibleRows.length,
        source: 'online',
        subtitle: 'Siparislerden gelen gelir',
      ),
    );
  }

  final tableAmount = sumClosedTableIncome(
    historyRows: historyRows,
    from: from,
    to: to,
  );
  if (tableAmount > 0 || historyRows.isNotEmpty) {
    lines.add(
      TodayIncomeLine(
        label: 'Masa Siparisleri',
        amount: tableAmount,
        count: historyRows.length,
        source: 'table',
        subtitle: 'Garson kapanis gecmisi',
      ),
    );
  }

  final manualEligibleRows = manualIncomeRows
      .where((row) {
        final raw = row['income_date']?.toString() ?? '';
        final parsed = DateTime.tryParse(raw);
        if (parsed == null) {
          return raw == from.toIso8601String().split('T').first;
        }
        final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
        return !dateOnly.isBefore(DateTime(from.year, from.month, from.day)) &&
            !dateOnly.isAfter(DateTime(to.year, to.month, to.day));
      })
      .toList(growable: false);
  final manualAmount = manualEligibleRows.fold<double>(0, (sum, row) {
    final total = row['net_amount'];
    if (total is num) return sum + total.toDouble();
    return sum + (double.tryParse(total?.toString() ?? '') ?? 0);
  });
  if (manualAmount > 0 || manualEligibleRows.isNotEmpty) {
    lines.add(
      TodayIncomeLine(
        label: 'Manuel Gelirler',
        amount: manualAmount,
        count: manualEligibleRows.length,
        source: 'manual',
        subtitle: 'Finans kayitlarindan',
      ),
    );
  }

  return lines;
}
