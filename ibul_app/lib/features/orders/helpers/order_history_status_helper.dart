import 'package:flutter/material.dart';

import '../models/order_history_models.dart';

class OrderHistoryStatusHelper {
  const OrderHistoryStatusHelper._();

  static String resolveOrderStatus(
    String orderStatus,
    List<Map<String, dynamic>> items,
  ) {
    final itemStatuses = items
        .map((e) => (e['status'] ?? '').toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    final statuses = itemStatuses.isEmpty ? <String>[orderStatus] : itemStatuses;
    if (statuses.any(_isReturnFlowStatus)) return 'return_requested';
    if (statuses.every((s) => s == 'delivered')) return 'delivered';
    if (statuses.any((s) => s == 'cancelled')) return 'cancelled';
    if (statuses.any(
      (s) =>
          s == 'shipped' ||
          s == 'transfer' ||
          s == 'branch' ||
          s == 'out_for_delivery',
    )) {
      return 'shipped';
    }
    if (statuses.any((s) => s == 'preparing' || s == 'ready_to_ship')) {
      return 'preparing';
    }
    if (statuses.any((s) => s == 'confirmed' || s == 'new')) {
      return 'confirmed';
    }
    return orderStatus;
  }

  static bool _isReturnFlowStatus(String status) {
    switch (status) {
      case 'return_requested':
      case 'return_approved':
      case 'return_shipped_back':
      case 'return_received':
      case 'returned':
      case 'refunded':
        return true;
      default:
        return false;
    }
  }

  static Map<String, dynamic> statusPresentation(String status) {
    switch (status) {
      case 'delivered':
        return {
          'label': 'Teslim Edildi',
          'color': const Color(0xFF16A34A),
          'bg': const Color(0xFFDCFCE7),
        };
      case 'preparing':
        return {
          'label': 'Hazırlanıyor',
          'color': const Color(0xFF7C3AED),
          'bg': const Color(0xFFEDE9FE),
        };
      case 'shipped':
        return {
          'label': 'Yolda',
          'color': const Color(0xFF2563EB),
          'bg': const Color(0xFFDBEAFE),
        };
      case 'confirmed':
      case 'new':
        return {
          'label': 'Beklemede',
          'color': const Color(0xFFCA8A04),
          'bg': const Color(0xFFFEF9C3),
        };
      case 'cancelled':
        return {
          'label': 'İptal Edildi',
          'color': const Color(0xFFDC2626),
          'bg': const Color(0xFFFEE2E2),
        };
      case 'return_requested':
      case 'returned':
      case 'refunded':
        return {
          'label': 'İade Edildi',
          'color': const Color(0xFFEA580C),
          'bg': const Color(0xFFFFEDD5),
        };
      default:
        return {
          'label': 'Sipariş',
          'color': const Color(0xFF6B7280),
          'bg': const Color(0xFFF3F4F6),
        };
    }
  }

  static bool matchesStatusFilter(
    String resolvedStatus,
    OrderHistoryStatusFilter filter,
  ) {
    switch (filter) {
      case OrderHistoryStatusFilter.all:
        return true;
      case OrderHistoryStatusFilter.delivered:
        return resolvedStatus == 'delivered';
      case OrderHistoryStatusFilter.preparing:
        return resolvedStatus == 'preparing';
      case OrderHistoryStatusFilter.inTransit:
        return resolvedStatus == 'shipped';
      case OrderHistoryStatusFilter.pending:
        return resolvedStatus == 'confirmed' || resolvedStatus == 'new';
      case OrderHistoryStatusFilter.cancelled:
        return resolvedStatus == 'cancelled';
      case OrderHistoryStatusFilter.returned:
        return resolvedStatus == 'return_requested' ||
            resolvedStatus == 'returned' ||
            resolvedStatus == 'refunded';
    }
  }

  static String formatDateTime(DateTime date) {
    return formatPurchaseDate(date);
  }

  static String formatPurchaseDate(DateTime date) {
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
    final month = months[date.month - 1];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day} $month ${date.year}, $hour:$minute';
  }

  static String shortOrderNo(Map<String, dynamic> order) {
    final raw = order['order_number']?.toString() ?? order['id']?.toString() ?? '';
    if (raw.length <= 10) return raw;
    return raw.substring(raw.length - 8);
  }

  static List<int> availableYears(List<Map<String, dynamic>> orders) {
    final years = <int>{DateTime.now().year};
    for (final order in orders) {
      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (createdAt != null) years.add(createdAt.year);
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }
}
