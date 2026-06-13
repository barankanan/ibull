import '../../../../services/store/table_order_history_utils.dart';

/// Resolves table area names for finance breakdowns.
///
/// Source of truth order:
/// 1. Persisted history fields (`table_area_name`, `area_name`, …)
/// 2. Live `store_tables` row matched by `table_id`
/// 3. Live `store_tables` row matched by `table_number`
class StoreTableAreaResolver {
  StoreTableAreaResolver._({
    required Map<String, String> byTableId,
    required Map<int, String> byTableNumber,
  }) : _byTableId = byTableId,
       _byTableNumber = byTableNumber;

  final Map<String, String> _byTableId;
  final Map<int, String> _byTableNumber;

  static const unresolvedLabel = 'Belirtilmedi';

  factory StoreTableAreaResolver.fromStoreTables(
    List<Map<String, dynamic>> storeTables,
  ) {
    final byTableId = <String, String>{};
    final byTableNumber = <int, String>{};

    for (final raw in storeTables) {
      final row = Map<String, dynamic>.from(raw);
      final areaName = _normalizeAreaName(row['area_name']);
      if (areaName.isEmpty) continue;

      final tableId = row['id']?.toString().trim() ?? '';
      if (tableId.isNotEmpty) {
        byTableId.putIfAbsent(tableId, () => areaName);
      }

      final tableNumber = _parseTableNumber(row['table_number']);
      if (tableNumber > 0) {
        byTableNumber.putIfAbsent(tableNumber, () => areaName);
      }
    }

    return StoreTableAreaResolver._(
      byTableId: byTableId,
      byTableNumber: byTableNumber,
    );
  }

  String resolveHistoryRow(Map<dynamic, dynamic> row) {
    final persisted = TableOrderHistoryUtils.areaName(row);
    if (persisted.isNotEmpty) return persisted;

    final tableId = row['table_id']?.toString().trim() ?? '';
    if (tableId.isNotEmpty) {
      final fromId = _byTableId[tableId];
      if (fromId != null && fromId.isNotEmpty) return fromId;
    }

    final tableNumber = _parseTableNumber(row['table_number']);
    if (tableNumber > 0) {
      final fromNumber = _byTableNumber[tableNumber];
      if (fromNumber != null && fromNumber.isNotEmpty) return fromNumber;
    }

    return '';
  }

  String displayLabelForHistoryRow(Map<dynamic, dynamic> row) {
    final resolved = resolveHistoryRow(row);
    return resolved.isEmpty ? unresolvedLabel : resolved;
  }

  static String _normalizeAreaName(dynamic value) =>
      value?.toString().trim() ?? '';

  static int _parseTableNumber(dynamic value) {
    if (value is int) return value > 0 ? value : 0;
    if (value is num) return value.toInt() > 0 ? value.toInt() : 0;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
