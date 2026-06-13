import 'dart:convert';

import '../../models/mixed_service_order.dart';
import '../../utils/table_labels.dart';

class TableOrderHistoryUtils {
  const TableOrderHistoryUtils._();

  static DateTime? closedAt(Map<dynamic, dynamic> row) {
    for (final key in const <String>[
      'closed_at',
      'archived_at',
      'updated_at',
      'created_at',
    ]) {
      final parsed = DateTime.tryParse(row[key]?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  static bool isWithinRange(
    Map<dynamic, dynamic> row,
    DateTime from,
    DateTime to,
  ) {
    final at = closedAt(row);
    if (at == null) return false;
    final inclusiveTo = _inclusiveRangeEnd(to);
    return !at.isBefore(from) && !at.isAfter(inclusiveTo);
  }

  /// When [to] is midnight (start of day), treat the whole prior calendar day
  /// as inclusive — callers often pass `today + 1 day` at 00:00 as range end.
  static DateTime _inclusiveRangeEnd(DateTime to) {
    if (to.hour == 0 &&
        to.minute == 0 &&
        to.second == 0 &&
        to.millisecond == 0 &&
        to.microsecond == 0) {
      return to.subtract(const Duration(microseconds: 1));
    }
    return to;
  }

  static DateTime endOfLocalDay(DateTime day) {
    return DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
  }

  static double revenue(Map<dynamic, dynamic> row) {
    for (final key in const <String>[
      'grand_total',
      'total',
      'order_total',
      'total_amount',
      'amount',
    ]) {
      final value = _toDouble(row[key]);
      if (value > 0) return value;
    }

    final items = parseJsonList(row['items']);
    if (items.isNotEmpty) {
      final total = items.fold<double>(0, (sum, item) {
        return sum + MixedServiceOrder.itemLineTotal(item);
      });
      if (total > 0) return total;
    }

    final archivedOrders = parseJsonList(row['archived_orders']);
    if (archivedOrders.isNotEmpty) {
      return archivedOrders.fold<double>(0, (sum, order) {
        return sum + revenue(order);
      });
    }

    return 0;
  }

  static List<Map<String, dynamic>> parseJsonList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false);
        }
      } catch (_) {
        return const <Map<String, dynamic>>[];
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static String tableLabel(Map<dynamic, dynamic> row) {
    final direct = _firstNonEmptyLabel(row);
    if (direct.isNotEmpty) return direct;

    for (final order in parseJsonList(row['archived_orders'])) {
      final fromOrder = _firstNonEmptyLabel(order);
      if (fromOrder.isNotEmpty) return fromOrder;
    }

    final area = areaName(row);
    final areaTableNumber = _firstPositiveAreaTableNumber(row);
    if (area.isNotEmpty && areaTableNumber > 0) {
      return '$area $areaTableNumber';
    }

    final tableNumber = _toInt(row['table_number']);
    if (tableNumber > 0) return 'Masa $tableNumber';
    return 'Masa';
  }

  static String _firstNonEmptyLabel(Map<dynamic, dynamic> row) {
    for (final key in const <String>[
      'display_table_label',
      'table_display_name',
      'table_name',
      'display_label',
    ]) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static int _firstPositiveAreaTableNumber(Map<dynamic, dynamic> row) {
    for (final key in const <String>[
      'area_table_number',
      'table_area_number',
      'area_table_no',
    ]) {
      final parsed = _toInt(row[key]);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  /// Canonical label/area fields for history archive writes.
  static Map<String, String> historyIdentityForArchive({
    required int tableNumber,
    String? tableLabel,
    String? tableAreaNameHint,
    Map<String, dynamic>? storeTableRow,
    List<Map<String, dynamic>> orders = const <Map<String, dynamic>>[],
  }) {
    String firstOrderLabel() {
      for (final order in orders) {
        final label = _firstNonEmptyLabel(order);
        if (label.isNotEmpty) return label;
      }
      return '';
    }

    String firstOrderArea() {
      for (final order in orders) {
        final value = TableOrderHistoryUtils.areaName(order);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final resolvedLabel = [
      tableLabel?.trim() ?? '',
      firstOrderLabel(),
      if (storeTableRow != null)
        resolveTableCardTitle(
          tableRow: storeTableRow,
          tableNumber: tableNumber,
        ),
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');

    final resolvedArea = [
      tableAreaNameHint?.trim() ?? '',
      if (storeTableRow != null) TableOrderHistoryUtils.areaName(storeTableRow),
      firstOrderArea(),
    ].firstWhere((value) => value.isNotEmpty, orElse: () => '');

    return <String, String>{
      if (resolvedLabel.isNotEmpty) 'display_table_label': resolvedLabel,
      if (resolvedLabel.isNotEmpty) 'table_display_name': resolvedLabel,
      if (resolvedLabel.isNotEmpty) 'table_name': resolvedLabel,
      if (resolvedArea.isNotEmpty) 'table_area_name': resolvedArea,
    };
  }

  static bool historyRowMissingIdentity(Map<dynamic, dynamic> row) {
    return _firstNonEmptyLabel(row).isEmpty && areaName(row).isEmpty;
  }

  /// Groups rows that belong to the same close chain (RPC may insert one row
  /// per active order with an identical [session_key]).
  static String historyChainKey(Map<dynamic, dynamic> row) {
    final sessionKey = row['session_key']?.toString().trim() ?? '';
    if (sessionKey.isNotEmpty) return 'session:$sessionKey';

    final originalOrderId = row['original_order_id']?.toString().trim() ?? '';
    if (originalOrderId.isNotEmpty) return 'order:$originalOrderId';

    return 'row:${row['id']?.toString() ?? ''}';
  }

  /// Keeps only the latest [closed_at] row per [historyChainKey].
  static List<Map<String, dynamic>> dedupeHistoryRowsLatestPerChain(
    List<Map<String, dynamic>> rows,
  ) {
    if (rows.length <= 1) return rows;

    final latestByChain = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final chainKey = historyChainKey(row);
      final existing = latestByChain[chainKey];
      if (existing == null) {
        latestByChain[chainKey] = row;
        continue;
      }
      final existingAt = closedAt(existing) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final candidateAt = closedAt(row) ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (candidateAt.isAfter(existingAt)) {
        latestByChain[chainKey] = row;
      }
    }

    final deduped = latestByChain.values.toList(growable: false)
      ..sort((a, b) {
        final aAt = closedAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = closedAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
    return deduped;
  }

  static String areaName(Map<dynamic, dynamic> row) {
    for (final key in const <String>[
      'table_area_name',
      'area_name',
      'table_area',
    ]) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String paymentMethodRaw(Map<dynamic, dynamic> row) {
    return row['payment_method']?.toString().trim() ?? '';
  }

  static int orderItemCount(Map<dynamic, dynamic> row) {
    final items = displayItems(row);
    if (items.isEmpty) return 0;
    return items.fold<int>(0, (sum, item) {
      final qty = _toInt(item['quantity']);
      return sum + (qty > 0 ? qty : 1);
    });
  }

  /// Flat item list for UI: prefers top-level [items], else merges archived orders.
  static List<Map<String, dynamic>> displayItems(Map<dynamic, dynamic> row) {
    final items = parseJsonList(row['items']);
    if (items.isNotEmpty) return items;
    final archived = parseJsonList(row['archived_orders']);
    if (archived.isEmpty) return const <Map<String, dynamic>>[];
    final merged = <Map<String, dynamic>>[];
    for (final order in archived) {
      merged.addAll(parseJsonList(order['items']));
    }
    return merged;
  }

  /// Short label for compact cards, e.g. "3 ürün · Lahmacun, Ayran".
  static String productSummary(Map<dynamic, dynamic> row) {
    final items = displayItems(row);
    if (items.isEmpty) return 'Ürün yok';
    final unitCount = orderItemCount(row);
    final names = items
        .map((item) => item['name']?.toString().trim() ?? '')
        .where((name) => name.isNotEmpty)
        .take(2)
        .toList(growable: false);
    if (names.isEmpty) return '$unitCount ürün';
    if (names.length == 1) return '$unitCount ürün · ${names.first}';
    return '$unitCount ürün · ${names.join(', ')}';
  }

  static String closeStatusLabel(Map<dynamic, dynamic> row) {
    final payment = paymentMethodRaw(row).toLowerCase();
    if (payment.isNotEmpty) return 'Hesap kesildi';
    final status = row['status']?.toString().trim().toLowerCase() ?? 'closed';
    if (status == 'closed' || status == 'paid') return 'Kapandı';
    return 'Kapandı';
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0;
  }
}
