import 'dart:convert';

import '../../models/mixed_service_order.dart';
import '../../utils/order_status_constants.dart';

/// `table_order_history` satırlarını okurken hem migration (closed_at + items)
/// hem de canlı hotfix (archived_at + archived_orders) şemalarını destekler.
class TableOrderHistoryUtils {
  TableOrderHistoryUtils._();

  static DateTime? closedAt(Map<dynamic, dynamic> row) {
    final raw = row['closed_at'] ?? row['archived_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  static bool isWithinRange(
    Map<dynamic, dynamic> row,
    DateTime from,
    DateTime to,
  ) {
    final at = closedAt(row);
    if (at == null) return false;
    return !at.isBefore(from) && !at.isAfter(to);
  }

  static double revenue(Map<dynamic, dynamic> row) {
    if (OrderStatusConstants.isCancelledStatus(row['status']?.toString())) {
      return 0;
    }

    final grand = row['grand_total'];
    if (grand is num && grand > 0) return grand.toDouble();

    final fromItems = _itemsRevenue(row['items']);
    if (fromItems > 0) return fromItems;

    final archived = row['archived_orders'];
    if (archived is List) {
      var sum = 0.0;
      for (final entry in archived) {
        if (entry is! Map) continue;
        sum += _orderRowRevenue(Map<dynamic, dynamic>.from(entry));
      }
      if (sum > 0) return sum;
    }

    return 0;
  }

  static int tableNumber(Map<dynamic, dynamic> row) {
    final raw = row['table_number'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static String tableLabel(Map<dynamic, dynamic> row) {
    final archived = row['archived_orders'];
    if (archived is List) {
      for (final entry in archived) {
        if (entry is! Map) continue;
        final order = Map<dynamic, dynamic>.from(entry);
        for (final key in [
          'display_table_label',
          'table_display_name',
          'table_name',
        ]) {
          final label = order[key]?.toString().trim();
          if (label != null && label.isNotEmpty) return label;
        }
      }
    }
    for (final key in [
      'display_table_label',
      'table_display_name',
      'table_name',
    ]) {
      final label = row[key]?.toString().trim();
      if (label != null && label.isNotEmpty) return label;
    }
    final n = tableNumber(row);
    return n > 0 ? 'Masa $n' : 'Garson Satışı';
  }

  static String? paymentMethod(Map<dynamic, dynamic> row) {
    final value = row['payment_method']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? paymentNote(Map<dynamic, dynamic> row) {
    final value = row['payment_note']?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String reference(Map<dynamic, dynamic> row) {
    for (final key in ['session_key', 'original_order_id', 'id']) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    final closedAt = TableOrderHistoryUtils.closedAt(row);
    final tableNo = tableNumber(row);
    return 'history-$tableNo-${closedAt?.millisecondsSinceEpoch ?? 0}';
  }

  static double _orderRowRevenue(Map<dynamic, dynamic> order) {
    if (OrderStatusConstants.isCancelledStatus(order['status']?.toString())) {
      return 0;
    }
    for (final key in ['grand_total', 'total', 'total_amount']) {
      final raw = order[key];
      if (raw is num && raw > 0) return raw.toDouble();
    }
    return _itemsRevenue(order['items']);
  }

  static double _itemsRevenue(dynamic rawItems) {
    var total = 0.0;
    for (final item in parseJsonList(rawItems)) {
      final normalized = MixedServiceOrder.normalizeOrderItem(item);
      total += MixedServiceOrder.itemLineTotal(normalized);
    }
    return total;
  }

  static List<Map<String, dynamic>> parseJsonList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList(growable: false);
        }
      } catch (_) {
        /* geçersiz JSON */
      }
    }
    return const [];
  }
}
