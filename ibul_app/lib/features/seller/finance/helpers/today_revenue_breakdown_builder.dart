import '../../../../models/restaurant_ops_models.dart';
import '../../../../services/store/table_order_history_utils.dart';
import '../../../../utils/order_status_constants.dart';
import '../models/finance_models.dart';
import 'store_table_area_resolver.dart';
import 'today_income_builder.dart';

String paymentMethodLabel(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) return 'Belirtilmedi';
  return TablePaymentMethod.fromValue(normalized).label;
}

TodayRevenueBreakdown buildTodayRevenueBreakdown({
  required DateTime from,
  required DateTime to,
  required List<Map<String, dynamic>> historyRows,
  required List<Map<String, dynamic>> onlineRows,
  required List<Map<String, dynamic>> manualIncomeRows,
  List<Map<String, dynamic>> storeTableRows = const [],
}) {
  final areaResolver = StoreTableAreaResolver.fromStoreTables(storeTableRows);
  final tableLines = <TableRevenueLine>[];
  final areaTotals = <String, RevenueSlice>{};
  final paymentTotals = <String, RevenueSlice>{};
  var hasPersistedPaymentMethods = false;
  var hasPersistedAreaNames = false;

  for (final raw in historyRows) {
    final row = Map<dynamic, dynamic>.from(raw);
    final status = row['status']?.toString();
    if (OrderStatusConstants.isCancelledStatus(status)) continue;
    if (!TableOrderHistoryUtils.isWithinRange(row, from, to)) continue;

    final amount = TableOrderHistoryUtils.revenue(row);
    if (amount <= 0) continue;

    final paymentRaw = TableOrderHistoryUtils.paymentMethodRaw(row);
    if (paymentRaw.isNotEmpty) hasPersistedPaymentMethods = true;
    final persistedArea = TableOrderHistoryUtils.areaName(row);
    if (persistedArea.isNotEmpty) hasPersistedAreaNames = true;
    final resolvedArea = areaResolver.displayLabelForHistoryRow(row);
    final areaKey = resolvedArea == StoreTableAreaResolver.unresolvedLabel
        ? 'unknown'
        : resolvedArea.toLowerCase();

    final paymentKey = paymentRaw.isEmpty ? 'unknown' : paymentRaw.toLowerCase();

    tableLines.add(
      TableRevenueLine(
        tableName: TableOrderHistoryUtils.tableLabel(row),
        areaName: resolvedArea,
        paymentMethod: paymentKey,
        paymentLabel: paymentMethodLabel(paymentRaw),
        closedAt: TableOrderHistoryUtils.closedAt(row),
        amount: amount,
        orderItemCount: TableOrderHistoryUtils.orderItemCount(row),
        tableNumber: int.tryParse(row['table_number']?.toString() ?? ''),
        source: 'table',
      ),
    );

    _addSlice(areaTotals, areaKey, resolvedArea, amount);
    _addSlice(
      paymentTotals,
      paymentKey,
      paymentMethodLabel(paymentRaw),
      amount,
    );
  }

  for (final raw in onlineRows) {
    final row = Map<String, dynamic>.from(raw);
    final status = row['status']?.toString();
    if (OrderStatusConstants.isCancelledStatus(status)) continue;
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    if (createdAt == null || createdAt.isBefore(from) || createdAt.isAfter(to)) {
      continue;
    }
    final amount = _toDouble(row['total_price']);
    if (amount <= 0) continue;
    tableLines.add(
      TableRevenueLine(
        tableName: row['product_name']?.toString().trim().isNotEmpty == true
            ? row['product_name'].toString().trim()
            : 'Online sipariş',
        areaName: 'Online',
        paymentMethod: 'online',
        paymentLabel: 'Online / QR',
        closedAt: createdAt,
        amount: amount,
        orderItemCount: 1,
        source: 'online',
      ),
    );
    _addSlice(areaTotals, 'online', 'Online', amount);
    _addSlice(paymentTotals, 'online', 'Online / QR', amount);
    hasPersistedPaymentMethods = true;
    hasPersistedAreaNames = true;
  }

  for (final raw in manualIncomeRows) {
    final row = Map<String, dynamic>.from(raw);
    final rawDate = row['income_date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate);
    final dateOnly = parsed != null
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : null;
    final inRange = dateOnly != null
        ? !dateOnly.isBefore(DateTime(from.year, from.month, from.day)) &&
              !dateOnly.isAfter(DateTime(to.year, to.month, to.day))
        : rawDate == from.toIso8601String().split('T').first;
    if (!inRange) continue;

    final amount = _toDouble(row['net_amount']);
    if (amount <= 0) continue;
    final label = row['source']?.toString().trim().isNotEmpty == true
        ? row['source'].toString().trim()
        : 'Manuel gelir';
    tableLines.add(
      TableRevenueLine(
        tableName: label,
        areaName: 'Manuel',
        paymentMethod: 'manual',
        paymentLabel: 'Manuel kayıt',
        closedAt: dateOnly,
        amount: amount,
        orderItemCount: 1,
        source: 'manual',
      ),
    );
    _addSlice(areaTotals, 'manual', 'Manuel', amount);
    _addSlice(paymentTotals, 'manual', 'Manuel kayıt', amount);
  }

  tableLines.sort((a, b) {
    final left = a.closedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.closedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });

  final byArea = _sortedSlices(areaTotals);
  final byPayment = _sortedSlices(paymentTotals);
  final totalRevenue = sumClosedTableIncome(
        historyRows: historyRows,
        from: from,
        to: to,
      ) +
      _sumOnline(onlineRows, from, to) +
      _sumManual(manualIncomeRows, from, to);

  return TodayRevenueBreakdown(
    totalRevenue: totalRevenue,
    tableLines: tableLines,
    byArea: byArea,
    byPaymentMethod: byPayment,
    topArea: byArea.isEmpty ? null : byArea.first,
    topPaymentMethod: byPayment.isEmpty ? null : byPayment.first,
    hasPersistedPaymentMethods: hasPersistedPaymentMethods,
    hasPersistedAreaNames: hasPersistedAreaNames,
  );
}

void _addSlice(
  Map<String, RevenueSlice> map,
  String key,
  String label,
  double amount,
) {
  final existing = map[key];
  map[key] = RevenueSlice(
    key: key,
    label: label,
    amount: (existing?.amount ?? 0) + amount,
    count: (existing?.count ?? 0) + 1,
  );
}

List<RevenueSlice> _sortedSlices(Map<String, RevenueSlice> map) {
  return map.values.toList(growable: false)
    ..sort((a, b) => b.amount.compareTo(a.amount));
}

double _sumOnline(
  List<Map<String, dynamic>> rows,
  DateTime from,
  DateTime to,
) {
  return rows.fold<double>(0, (sum, row) {
    final status = row['status']?.toString();
    if (OrderStatusConstants.isCancelledStatus(status)) return sum;
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    if (createdAt == null || createdAt.isBefore(from) || createdAt.isAfter(to)) {
      return sum;
    }
    return sum + _toDouble(row['total_price']);
  });
}

double _sumManual(
  List<Map<String, dynamic>> rows,
  DateTime from,
  DateTime to,
) {
  return rows.fold<double>(0, (sum, row) {
    final rawDate = row['income_date']?.toString() ?? '';
    final parsed = DateTime.tryParse(rawDate);
    final dateOnly = parsed != null
        ? DateTime(parsed.year, parsed.month, parsed.day)
        : null;
    final inRange = dateOnly != null
        ? !dateOnly.isBefore(DateTime(from.year, from.month, from.day)) &&
              !dateOnly.isAfter(DateTime(to.year, to.month, to.day))
        : rawDate == from.toIso8601String().split('T').first;
    if (!inRange) return sum;
    return sum + _toDouble(row['net_amount']);
  });
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
