import 'dart:convert';

import '../../models/mixed_service_order.dart';

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
    return !at.isBefore(from) && !at.isAfter(to);
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
    for (final key in const <String>[
      'display_table_label',
      'table_display_name',
      'table_name',
      'display_label',
    ]) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final tableNumber = _toInt(row['table_number']);
    if (tableNumber > 0) return 'Masa $tableNumber';
    return 'Masa';
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
