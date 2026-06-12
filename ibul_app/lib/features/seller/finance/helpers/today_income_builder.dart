import '../../../../utils/order_status_constants.dart';
import '../../../../services/store/table_order_history_utils.dart';
import '../models/finance_models.dart';

List<TodayIncomeLine> buildTodayIncomeLines({
  required DateTime from,
  required DateTime to,
  Iterable<Map<String, dynamic>> historyRows = const <Map<String, dynamic>>[],
  Iterable<Map<String, dynamic>> onlineRows = const <Map<String, dynamic>>[],
  Iterable<Map<String, dynamic>> manualIncomeRows =
      const <Map<String, dynamic>>[],
}) {
  final lines = <TodayIncomeLine>[
    ...buildClosedTableIncomeLines(
      historyRows: historyRows,
      from: from,
      to: to,
    ),
    ...buildOnlineIncomeLines(onlineRows: onlineRows, from: from, to: to),
    ...buildManualIncomeLines(manualIncomeRows: manualIncomeRows),
  ];
  lines.sort(_compareTodayIncomeLines);
  return lines;
}

List<TodayIncomeLine> buildClosedTableIncomeLines({
  required Iterable<Map<String, dynamic>> historyRows,
  required DateTime from,
  required DateTime to,
}) {
  final sessions = <String, _ClosedTableIncomeAccumulator>{};
  for (final raw in historyRows) {
    final row = Map<dynamic, dynamic>.from(raw);
    final status = _normalizedText(row['status']).toLowerCase();
    if (OrderStatusConstants.isCancelledStatus(status)) continue;
    if (!TableOrderHistoryUtils.isWithinRange(row, from, to)) continue;
    final amount = TableOrderHistoryUtils.revenue(row);
    if (amount <= 0) continue;
    final key = _historySessionKey(row, amount);
    final accumulator = sessions.putIfAbsent(
      key,
      () => _ClosedTableIncomeAccumulator(
        label: TableOrderHistoryUtils.tableLabel(row),
        paymentMethod: TableOrderHistoryUtils.paymentMethod(row),
        reference: TableOrderHistoryUtils.reference(row),
        detail: TableOrderHistoryUtils.paymentNote(row),
        tableNumber: TableOrderHistoryUtils.tableNumber(row),
      ),
    );
    accumulator.addRow(row, amount);
  }
  return sessions.values.map((entry) => entry.build()).toList(growable: false);
}

double sumClosedTableIncome({
  required Iterable<Map<String, dynamic>> historyRows,
  required DateTime from,
  required DateTime to,
}) {
  return buildClosedTableIncomeLines(
    historyRows: historyRows,
    from: from,
    to: to,
  ).fold<double>(0, (sum, line) => sum + line.amount);
}

List<TodayIncomeLine> buildOnlineIncomeLines({
  required Iterable<Map<String, dynamic>> onlineRows,
  required DateTime from,
  required DateTime to,
}) {
  final grouped = <String, _OnlineIncomeAccumulator>{};
  for (final row in onlineRows) {
    final status = _normalizedText(row['status']).toLowerCase();
    if (OrderStatusConstants.isCancelledStatus(status)) continue;
    final occurredAt = DateTime.tryParse(
      row['created_at']?.toString() ?? '',
    )?.toLocal();
    if (occurredAt == null ||
        occurredAt.isBefore(from) ||
        occurredAt.isAfter(to)) {
      continue;
    }
    final orderId = _normalizedText(row['order_id']);
    if (orderId.isEmpty) continue;
    final amount = _toDouble(row['total_price']);
    if (amount <= 0) continue;
    final accumulator = grouped.putIfAbsent(
      orderId,
      () =>
          _OnlineIncomeAccumulator(label: 'Online Sipariş', reference: orderId),
    );
    accumulator.addRow(
      amount: amount,
      occurredAt: occurredAt,
      detail: _normalizedText(row['product_name']),
    );
  }
  return grouped.values.map((entry) => entry.build()).toList(growable: false);
}

List<TodayIncomeLine> buildManualIncomeLines({
  required Iterable<Map<String, dynamic>> manualIncomeRows,
}) {
  final lines = <TodayIncomeLine>[];
  for (final row in manualIncomeRows) {
    final amount = _toDouble(row['net_amount']);
    if (amount <= 0) continue;
    final source = _normalizedText(row['source']);
    final incomeType = _normalizedText(row['income_type']);
    final description = _normalizedText(row['description']);
    lines.add(
      TodayIncomeLine(
        label: source.isNotEmpty
            ? source
            : (incomeType.isNotEmpty ? incomeType : 'Manuel Gelir'),
        amount: amount,
        source: row['is_collected'] == true
            ? 'Manuel (Tahsil)'
            : 'Manuel (Bekleyen)',
        detail: description.isNotEmpty ? description : null,
        occurredAt: DateTime.tryParse(
          row['income_date']?.toString() ?? '',
        )?.toLocal(),
        reference: _normalizedText(row['id']).isNotEmpty
            ? _normalizedText(row['id'])
            : null,
      ),
    );
  }
  return lines;
}

int _compareTodayIncomeLines(TodayIncomeLine left, TodayIncomeLine right) {
  final leftAt = left.occurredAt;
  final rightAt = right.occurredAt;
  if (leftAt != null && rightAt != null) {
    final compare = rightAt.compareTo(leftAt);
    if (compare != 0) return compare;
  } else if (leftAt != null) {
    return -1;
  } else if (rightAt != null) {
    return 1;
  }
  final amountCompare = right.amount.compareTo(left.amount);
  if (amountCompare != 0) return amountCompare;
  return left.label.compareTo(right.label);
}

String _historySessionKey(Map<dynamic, dynamic> row, double amount) {
  final sessionKey = _normalizedText(row['session_key']);
  if (sessionKey.isNotEmpty) return 'session:$sessionKey';
  final originalOrderId = _normalizedText(row['original_order_id']);
  if (originalOrderId.isNotEmpty) return 'original:$originalOrderId';
  final id = _normalizedText(row['id']);
  if (id.isNotEmpty) return 'row:$id';
  final closedAt = TableOrderHistoryUtils.closedAt(row);
  return 'fallback:${TableOrderHistoryUtils.tableNumber(row)}:'
      '${closedAt?.toIso8601String() ?? ''}:${amount.toStringAsFixed(2)}';
}

String _historyUnitKey(Map<dynamic, dynamic> row, double amount) {
  final originalOrderId = _normalizedText(row['original_order_id']);
  if (originalOrderId.isNotEmpty) return 'original:$originalOrderId';
  final id = _normalizedText(row['id']);
  if (id.isNotEmpty) return 'row:$id';
  final closedAt = TableOrderHistoryUtils.closedAt(row);
  return 'fallback:${closedAt?.toIso8601String() ?? ''}:'
      '${amount.toStringAsFixed(2)}';
}

String _normalizedText(dynamic value) => value?.toString().trim() ?? '';

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

class _ClosedTableIncomeAccumulator {
  _ClosedTableIncomeAccumulator({
    required this.label,
    required this.paymentMethod,
    required this.reference,
    required this.detail,
    required this.tableNumber,
  });

  final String label;
  final String? paymentMethod;
  final String? reference;
  final String? detail;
  final int tableNumber;
  final Set<String> _unitKeys = <String>{};
  double _amount = 0;
  DateTime? _occurredAt;

  void addRow(Map<dynamic, dynamic> row, double amount) {
    final unitKey = _historyUnitKey(row, amount);
    if (!_unitKeys.add(unitKey)) return;
    _amount += amount;
    final rowOccurredAt = TableOrderHistoryUtils.closedAt(row);
    if (rowOccurredAt != null &&
        (_occurredAt == null || rowOccurredAt.isAfter(_occurredAt!))) {
      _occurredAt = rowOccurredAt;
    }
  }

  TodayIncomeLine build() {
    return TodayIncomeLine(
      label: label.isNotEmpty ? label : 'Garson Satışı',
      amount: _amount,
      source: 'Garson',
      detail: detail?.isNotEmpty == true ? detail : 'Kapatılan masa',
      occurredAt: _occurredAt,
      paymentMethod: paymentMethod,
      reference: reference,
      tableNumber: tableNumber > 0 ? tableNumber : null,
    );
  }
}

class _OnlineIncomeAccumulator {
  _OnlineIncomeAccumulator({required this.label, required this.reference});

  final String label;
  final String reference;
  double _amount = 0;
  String? _detail;
  DateTime? _occurredAt;

  void addRow({
    required double amount,
    required DateTime occurredAt,
    required String detail,
  }) {
    _amount += amount;
    if (_occurredAt == null || occurredAt.isAfter(_occurredAt!)) {
      _occurredAt = occurredAt;
    }
    if (_detail == null && detail.isNotEmpty) {
      _detail = detail;
    }
  }

  TodayIncomeLine build() {
    return TodayIncomeLine(
      label: label,
      amount: _amount,
      source: 'Online',
      detail: _detail,
      occurredAt: _occurredAt,
      reference: reference,
    );
  }
}
