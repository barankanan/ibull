import '../../../../services/admin_service.dart';

/// Admin Finans gider kategorileri — DB text + UI etiketleri.
class AdminFinanceExpenseCategories {
  const AdminFinanceExpenseCategories._();

  static const List<String> keys = [
    'server',
    'software_licenses',
    'marketing',
    'personnel',
    'cargo_subsidy',
    'refund_cost',
    'payment_infra',
    'tax_government',
    'operations',
    'office',
    'other',
  ];

  static const Map<String, String> labels = {
    'server': 'Sunucu',
    'software_licenses': 'Yazılım Lisansları',
    'marketing': 'Pazarlama',
    'personnel': 'Personel',
    'cargo_subsidy': 'Kargo Sübvansiyonu',
    'refund_cost': 'İade Maliyeti',
    'payment_infra': 'Ödeme Altyapısı Komisyonu',
    'tax_government': 'Vergi / Devlet Ödemeleri',
    'operations': 'Operasyon',
    'office': 'Ofis',
    'other': 'Diğer',
  };

  static String labelFor(String key) =>
      labels[key] ?? (key.trim().isEmpty ? 'Diğer' : key.trim());
}

class AdminFinanceExpenseSummary {
  const AdminFinanceExpenseSummary({
    required this.totalPaid,
    required this.totalPending,
    required this.recurringMonthlyTotal,
    required this.largestCategoryKey,
    required this.largestCategoryAmount,
    required this.categoryRows,
    required this.topExpenses,
  });

  final double totalPaid;
  final double totalPending;
  final double recurringMonthlyTotal;
  final String largestCategoryKey;
  final double largestCategoryAmount;
  final List<AdminFinanceExpenseCategoryRow> categoryRows;
  final List<AdminExpense> topExpenses;
}

class AdminFinanceExpenseCategoryRow {
  const AdminFinanceExpenseCategoryRow({
    required this.categoryKey,
    required this.label,
    required this.amount,
    required this.share,
    required this.count,
  });

  final String categoryKey;
  final String label;
  final double amount;
  final double share;
  final int count;
}

class AdminFinanceExpenseHelper {
  const AdminFinanceExpenseHelper._();

  static bool isInPeriod(
    DateTime expenseDate,
    DateTime start,
    DateTime endExclusive,
  ) {
    final day = DateTime(expenseDate.year, expenseDate.month, expenseDate.day);
    return !day.isBefore(start) && day.isBefore(endExclusive);
  }

  static double monthlyEquivalent(AdminExpense expense) {
    if (expense.type != 'recurring') return expense.amount;
    return switch (expense.recurrence) {
      'weekly' => expense.amount * 52 / 12,
      'yearly' => expense.amount / 12,
      _ => expense.amount,
    };
  }

  static List<AdminExpense> filterExpenses({
    required List<AdminExpense> expenses,
    required DateTime start,
    required DateTime endExclusive,
    String? categoryKey,
    String? statusKey,
    String? typeKey,
    bool includeCancelled = false,
  }) {
    return expenses.where((expense) {
      if (!includeCancelled && expense.status == 'cancelled') return false;
      if (!isInPeriod(expense.expenseDate, start, endExclusive)) return false;
      if (categoryKey != null &&
          categoryKey.isNotEmpty &&
          expense.category != categoryKey) {
        return false;
      }
      if (statusKey != null &&
          statusKey.isNotEmpty &&
          expense.status != statusKey) {
        return false;
      }
      if (typeKey != null && typeKey.isNotEmpty && expense.type != typeKey) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  static AdminFinanceExpenseSummary buildSummary({
    required List<AdminExpense> expenses,
    required DateTime start,
    required DateTime endExclusive,
    String? categoryKey,
    String? statusKey,
    String? typeKey,
  }) {
    final visible = filterExpenses(
      expenses: expenses,
      start: start,
      endExclusive: endExclusive,
      categoryKey: categoryKey,
      statusKey: statusKey,
      typeKey: typeKey,
    );

    var totalPaid = 0.0;
    var totalPending = 0.0;
    var recurringMonthlyTotal = 0.0;
    final categoryTotals = <String, double>{};
    final categoryCounts = <String, int>{};

    for (final expense in visible) {
      if (expense.status == 'paid') {
        totalPaid += expense.amount;
      } else if (expense.status == 'pending') {
        totalPending += expense.amount;
      }

      if (expense.type == 'recurring' && expense.status != 'cancelled') {
        recurringMonthlyTotal += monthlyEquivalent(expense);
      }

      if (expense.status == 'cancelled') continue;

      final key = expense.category.trim().isEmpty ? 'other' : expense.category;
      categoryTotals.update(key, (v) => v + expense.amount, ifAbsent: () => expense.amount);
      categoryCounts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }

    final categoryTotal = categoryTotals.values.fold<double>(0, (a, b) => a + b);
    final categoryRows = categoryTotals.entries.map((entry) {
      return AdminFinanceExpenseCategoryRow(
        categoryKey: entry.key,
        label: AdminFinanceExpenseCategories.labelFor(entry.key),
        amount: entry.value,
        share: categoryTotal == 0 ? 0 : entry.value / categoryTotal,
        count: categoryCounts[entry.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    var largestCategoryKey = '';
    var largestCategoryAmount = 0.0;
    if (categoryRows.isNotEmpty) {
      largestCategoryKey = categoryRows.first.categoryKey;
      largestCategoryAmount = categoryRows.first.amount;
    }

    final topExpenses = [...visible]
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return AdminFinanceExpenseSummary(
      totalPaid: totalPaid,
      totalPending: totalPending,
      recurringMonthlyTotal: recurringMonthlyTotal,
      largestCategoryKey: largestCategoryKey,
      largestCategoryAmount: largestCategoryAmount,
      categoryRows: categoryRows,
      topExpenses: topExpenses.take(5).toList(growable: false),
    );
  }

  static double periodPaidTotal({
    required List<AdminExpense> expenses,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return buildSummary(
      expenses: expenses,
      start: start,
      endExclusive: endExclusive,
    ).totalPaid;
  }

  static double periodTaxExpenses({
    required List<AdminExpense> expenses,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    var total = 0.0;
    for (final expense in expenses) {
      if (expense.status != 'paid') continue;
      if (!isInPeriod(expense.expenseDate, start, endExclusive)) continue;
      if (expense.category == 'tax_government') {
        total += expense.amount;
      }
    }
    return total;
  }

  static String statusLabel(String status) => switch (status) {
    'paid' => 'Ödendi',
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
