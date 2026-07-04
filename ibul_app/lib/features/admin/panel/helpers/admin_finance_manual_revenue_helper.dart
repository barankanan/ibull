import '../../../../services/admin_service.dart';

/// Manuel gelir kategorileri — otomatik sipariş/reklam/kargo gelirinden ayrı tutulur.
class AdminFinanceRevenueCategories {
  const AdminFinanceRevenueCategories._();

  static const List<String> keys = [
    'property_rent',
    'manual_ad',
    'sponsorship',
    'subscription_service',
    'cargo_adjustment',
    'other',
  ];

  static const Map<String, String> labels = {
    'property_rent': 'Emlak / Kira',
    'manual_ad': 'Manuel Reklam Tahsilatı',
    'sponsorship': 'Sponsorluk',
    'subscription_service': 'Abonelik / Hizmet',
    'cargo_adjustment': 'Kargo Düzeltmesi',
    'other': 'Diğer Gelir',
  };

  static String labelFor(String key) =>
      labels[key] ?? (key.trim().isEmpty ? 'Diğer Gelir' : key.trim());

  static bool isPropertyRent(String key) => key == 'property_rent';

  static bool isCargoAdjustment(String key) => key == 'cargo_adjustment';
}

class AdminFinanceManualRevenueSummary {
  const AdminFinanceManualRevenueSummary({
    required this.totalReceived,
    required this.totalPending,
    required this.recurringMonthlyTotal,
    required this.largestCategoryKey,
    required this.largestCategoryAmount,
    required this.propertyRentTotal,
    required this.categoryRows,
  });

  final double totalReceived;
  final double totalPending;
  final double recurringMonthlyTotal;
  final String largestCategoryKey;
  final double largestCategoryAmount;
  final double propertyRentTotal;
  final List<AdminFinanceManualRevenueCategoryRow> categoryRows;
}

class AdminFinanceManualRevenueCategoryRow {
  const AdminFinanceManualRevenueCategoryRow({
    required this.categoryKey,
    required this.label,
    required this.amount,
    required this.count,
  });

  final String categoryKey;
  final String label;
  final double amount;
  final int count;
}

class AdminFinanceManualRevenueBreakdown {
  const AdminFinanceManualRevenueBreakdown({
    required this.propertyRentReceived,
    required this.cargoAdjustmentReceived,
    required this.otherManualReceived,
    required this.totalReceived,
    required this.totalPending,
  });

  final double propertyRentReceived;
  final double cargoAdjustmentReceived;
  final double otherManualReceived;
  final double totalReceived;
  final double totalPending;
}

class AdminFinanceManualRevenueHelper {
  const AdminFinanceManualRevenueHelper._();

  static bool isInPeriod(
    DateTime revenueDate,
    DateTime start,
    DateTime endExclusive,
  ) {
    final day = DateTime(revenueDate.year, revenueDate.month, revenueDate.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  static double monthlyEquivalent(AdminRevenue revenue) {
    if (revenue.type != 'recurring') return revenue.amount;
    return switch (revenue.recurrence) {
      'weekly' => revenue.amount * 52 / 12,
      'yearly' => revenue.amount / 12,
      _ => revenue.amount,
    };
  }

  static List<AdminRevenue> filterRevenues({
    required List<AdminRevenue> revenues,
    required DateTime start,
    required DateTime endExclusive,
    String? categoryKey,
    String? statusKey,
    String? typeKey,
    bool includeCancelled = false,
  }) {
    return revenues.where((revenue) {
      if (!includeCancelled && revenue.status == 'cancelled') return false;
      if (!isInPeriod(revenue.revenueDate, start, endExclusive)) return false;
      if (categoryKey != null &&
          categoryKey.isNotEmpty &&
          revenue.category != categoryKey) {
        return false;
      }
      if (statusKey != null &&
          statusKey.isNotEmpty &&
          revenue.status != statusKey) {
        return false;
      }
      if (typeKey != null && typeKey.isNotEmpty && revenue.type != typeKey) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static AdminFinanceManualRevenueBreakdown computeBreakdown({
    required List<AdminRevenue> revenues,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    var propertyRent = 0.0;
    var cargoAdjustment = 0.0;
    var otherManual = 0.0;
    var totalReceived = 0.0;
    var totalPending = 0.0;

    for (final revenue in revenues) {
      if (!isInPeriod(revenue.revenueDate, start, endExclusive)) continue;
      if (revenue.status == 'cancelled') continue;

      if (revenue.status == 'pending') {
        totalPending += revenue.amount;
        continue;
      }
      if (revenue.status != 'received') continue;

      totalReceived += revenue.amount;
      final key = revenue.category.trim().isEmpty ? 'other' : revenue.category;
      if (AdminFinanceRevenueCategories.isPropertyRent(key)) {
        propertyRent += revenue.amount;
      } else if (AdminFinanceRevenueCategories.isCargoAdjustment(key)) {
        cargoAdjustment += revenue.amount;
      } else {
        otherManual += revenue.amount;
      }
    }

    return AdminFinanceManualRevenueBreakdown(
      propertyRentReceived: propertyRent,
      cargoAdjustmentReceived: cargoAdjustment,
      otherManualReceived: otherManual,
      totalReceived: totalReceived,
      totalPending: totalPending,
    );
  }

  static AdminFinanceManualRevenueSummary buildSummary({
    required List<AdminRevenue> revenues,
    required DateTime start,
    required DateTime endExclusive,
    String? categoryKey,
    String? statusKey,
    String? typeKey,
  }) {
    final visible = filterRevenues(
      revenues: revenues,
      start: start,
      endExclusive: endExclusive,
      categoryKey: categoryKey,
      statusKey: statusKey,
      typeKey: typeKey,
    );

    var totalReceived = 0.0;
    var totalPending = 0.0;
    var recurringMonthlyTotal = 0.0;
    var propertyRentTotal = 0.0;
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final revenue in visible) {
      if (revenue.status == 'received') {
        totalReceived += revenue.amount;
        if (AdminFinanceRevenueCategories.isPropertyRent(revenue.category)) {
          propertyRentTotal += revenue.amount;
        }
      } else if (revenue.status == 'pending') {
        totalPending += revenue.amount;
      }

      if (revenue.type == 'recurring' && revenue.status != 'cancelled') {
        recurringMonthlyTotal += monthlyEquivalent(revenue);
      }

      if (revenue.status == 'cancelled') continue;

      final key = revenue.category.trim().isEmpty ? 'other' : revenue.category;
      categoryTotals.update(key, (v) => v + revenue.amount, ifAbsent: () => revenue.amount);
      categoryCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    final categoryRows = categoryTotals.entries
        .map(
          (entry) => AdminFinanceManualRevenueCategoryRow(
            categoryKey: entry.key,
            label: AdminFinanceRevenueCategories.labelFor(entry.key),
            amount: entry.value,
            count: categoryCounts[entry.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    var largestCategoryKey = '';
    var largestCategoryAmount = 0.0;
    if (categoryRows.isNotEmpty) {
      largestCategoryKey = categoryRows.first.categoryKey;
      largestCategoryAmount = categoryRows.first.amount;
    }

    return AdminFinanceManualRevenueSummary(
      totalReceived: totalReceived,
      totalPending: totalPending,
      recurringMonthlyTotal: recurringMonthlyTotal,
      largestCategoryKey: largestCategoryKey,
      largestCategoryAmount: largestCategoryAmount,
      propertyRentTotal: propertyRentTotal,
      categoryRows: categoryRows,
    );
  }

  static double periodReceivedTotal({
    required List<AdminRevenue> revenues,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return computeBreakdown(
      revenues: revenues,
      start: start,
      endExclusive: endExclusive,
    ).totalReceived;
  }

  static String statusLabel(String status) => switch (status) {
    'received' => 'Alındı',
    'pending' => 'Bekliyor',
    'cancelled' => 'İptal',
    _ => status,
  };

  static String typeLabel(String type) =>
      type == 'recurring' ? 'Tekrarlayan' : 'Tek seferlik';

  static String recurrenceLabel(String? recurrence) => switch (recurrence) {
    'weekly' => 'Haftalık',
    'monthly' => 'Aylık',
    'yearly' => 'Yıllık',
    _ => '',
  };
}
