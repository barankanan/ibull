import '../../../../ads/models/ad_campaign.dart';
import '../../../../ads/models/ad_metrics.dart';
import '../../../../ads/models/ad_revenue_record.dart';
import '../../../../ads/models/ad_wallet_transaction.dart';
import '../../../../services/admin_service.dart';
import 'admin_finance_commission_helper.dart';
import 'admin_finance_expense_helper.dart';
import 'admin_finance_payout_helper.dart';
import 'admin_finance_revenue_helper.dart';

enum AdminFinanceAlertSeverity { critical, warning, info }

class AdminFinanceAlert {
  const AdminFinanceAlert({
    required this.severity,
    required this.title,
    required this.message,
  });

  final AdminFinanceAlertSeverity severity;
  final String title;
  final String message;
}

class AdminFinanceChartPoint {
  const AdminFinanceChartPoint({
    required this.date,
    required this.label,
    required this.gmv,
    required this.ibulRevenue,
    required this.totalExpense,
    required this.netProfit,
    required this.commission,
    required this.adRevenue,
    required this.cargoRevenue,
    required this.propertyRevenue,
    required this.recurringExpense,
    required this.pendingExpense,
  });

  final DateTime date;
  final String label;
  final double gmv;
  final double ibulRevenue;
  final double totalExpense;
  final double netProfit;
  final double commission;
  final double adRevenue;
  final double cargoRevenue;
  final double propertyRevenue;
  final double recurringExpense;
  final double pendingExpense;

  bool get hasData =>
      gmv != 0 ||
      ibulRevenue != 0 ||
      totalExpense != 0 ||
      netProfit != 0 ||
      commission != 0 ||
      adRevenue != 0 ||
      cargoRevenue != 0;
}

class AdminFinanceReportRow {
  const AdminFinanceReportRow({
    required this.label,
    required this.current,
    required this.previous,
    required this.changePercent,
    required this.status,
  });

  final String label;
  final double current;
  final double previous;
  final double? changePercent;
  final String status;
}

class AdminFinanceAnalyticsBundle {
  const AdminFinanceAnalyticsBundle({
    required this.cashFlowSeries,
    required this.revenueSeries,
    required this.expenseSeries,
    required this.alerts,
    required this.summaryRows,
    required this.revenueSourceRows,
    required this.adTypeRows,
    required this.cargoReport,
    required this.expenseCategoryRows,
    required this.sanityReport,
  });

  final List<AdminFinanceChartPoint> cashFlowSeries;
  final List<AdminFinanceChartPoint> revenueSeries;
  final List<AdminFinanceChartPoint> expenseSeries;
  final List<AdminFinanceAlert> alerts;
  final List<AdminFinanceReportRow> summaryRows;
  final List<AdminFinanceRevenueSourceRow> revenueSourceRows;
  final List<AdminFinanceAdTypeRow> adTypeRows;
  final AdminFinanceCargoReport cargoReport;
  final List<AdminFinanceExpenseCategoryReportRow> expenseCategoryRows;
  final AdminFinanceSanityReport sanityReport;
}

enum AdminFinanceSanityStatus { consistent, needsReview, incompleteData }

class AdminFinanceSanityReport {
  const AdminFinanceSanityReport({
    required this.status,
    required this.label,
    required this.notes,
  });

  final AdminFinanceSanityStatus status;
  final String label;
  final List<String> notes;
}

class AdminFinanceCargoReport {
  const AdminFinanceCargoReport({
    required this.collection,
    required this.cost,
    required this.netRevenue,
    required this.packageCount,
    required this.freeShippingSubsidy,
  });

  final double collection;
  final double cost;
  final double netRevenue;
  final int packageCount;
  final double freeShippingSubsidy;
}

class AdminFinanceExpenseCategoryReportRow {
  const AdminFinanceExpenseCategoryReportRow({
    required this.categoryLabel,
    required this.total,
    required this.count,
    required this.largestTitle,
    required this.largestAmount,
    required this.pendingAmount,
    required this.recurringMonthlyImpact,
  });

  final String categoryLabel;
  final double total;
  final int count;
  final String largestTitle;
  final double largestAmount;
  final double pendingAmount;
  final double recurringMonthlyImpact;
}

class AdminFinanceAnalyticsHelper {
  const AdminFinanceAnalyticsHelper._();

  static AdminFinanceAnalyticsBundle build({
    required DateTime start,
    required DateTime endExclusive,
    required DateTime previousStart,
    required DateTime previousEndExclusive,
    required List<AdminFinanceOrderItem> orderItems,
    required List<AdminFinanceOrder> orders,
    required List<AdCampaign> campaigns,
    required List<AdMetrics> adMetrics,
    required List<AdRevenueRecord> adRevenueRecords,
    required List<AdWalletTransaction> adWalletTransactions,
    required List<AdminExpense> expenses,
    required List<AdminRevenue> manualRevenues,
    required List<SellerPayout> payoutRecords,
    required AdminFinanceCommissionConfig commissionConfig,
    required bool Function(String status) isDelivered,
    required bool Function(String status) isRefund,
    required bool Function(String deliveryType) isCourierDelivery,
    required AdminFinancePeriodSnapshot currentSnapshot,
    required AdminFinancePeriodSnapshot previousSnapshot,
    required AdminFinanceExpenseSummary expenseSummary,
    required AdminFinanceExpenseSummary previousExpenseSummary,
    required AdminFinancePayoutPeriodSnapshot payoutSnapshot,
    required AdminFinancePayoutPeriodSnapshot previousPayoutSnapshot,
    required double currentNetProfit,
    required double previousNetProfit,
    required double currentCashIn,
    required double previousCashIn,
    required double currentPendingExpense,
    required double previousPendingExpense,
    required int currentRefundCount,
    required int previousRefundCount,
    required bool hasAnyFinanceData,
  }) {
    final bucketMode = _resolveChartBucketMode(start, endExclusive);
    final series = _buildChartSeries(
      start: start,
      endExclusive: endExclusive,
      bucketMode: bucketMode,
      orderItems: orderItems,
      orders: orders,
      campaigns: campaigns,
      adMetrics: adMetrics,
      adRevenueRecords: adRevenueRecords,
      adWalletTransactions: adWalletTransactions,
      expenses: expenses,
      manualRevenues: manualRevenues,
      commissionConfig: commissionConfig,
      isDelivered: isDelivered,
      isRefund: isRefund,
      isCourierDelivery: isCourierDelivery,
    );

    final core = currentSnapshot.orderCore;
    final prevCore = previousSnapshot.orderCore;

    final summaryRows = _buildSummaryRows(
      current: _SummaryInputs(
        gmv: core.gmv,
        cashIn: currentCashIn,
        commission: core.commission,
        adRevenue: currentSnapshot.adBreakdown.totalCollected,
        cargoRevenue:
            core.cargoNetRevenue + currentSnapshot.manualCargoAdjustment,
        expenses: expenseSummary.totalPaid,
        netProfit: currentNetProfit,
        sellerPayouts: payoutSnapshot.totalNetPayout,
        pendingPayout: payoutSnapshot.pendingPayout,
        refundAmount: core.refundAmount,
      ),
      previous: _SummaryInputs(
        gmv: prevCore.gmv,
        cashIn: previousCashIn,
        commission: prevCore.commission,
        adRevenue: previousSnapshot.adBreakdown.totalCollected,
        cargoRevenue:
            prevCore.cargoNetRevenue + previousSnapshot.manualCargoAdjustment,
        expenses: previousExpenseSummary.totalPaid,
        netProfit: previousNetProfit,
        sellerPayouts: previousPayoutSnapshot.totalNetPayout,
        pendingPayout: previousPayoutSnapshot.pendingPayout,
        refundAmount: prevCore.refundAmount,
      ),
    );

    final expenseCategoryRows = _buildExpenseCategoryReport(
      expenses: expenses,
      start: start,
      endExclusive: endExclusive,
    );

    final alerts = _buildAlerts(
      currentNetProfit: currentNetProfit,
      previousNetProfit: previousNetProfit,
      currentAdRevenue: currentSnapshot.adBreakdown.totalCollected,
      previousAdRevenue: previousSnapshot.adBreakdown.totalCollected,
      currentGmv: core.gmv,
      currentRefundAmount: core.refundAmount,
      previousRefundAmount: prevCore.refundAmount,
      currentRefundCount: currentRefundCount,
      previousRefundCount: previousRefundCount,
      platformRevenue: core.commission +
          currentSnapshot.adBreakdown.totalCollected +
          core.cargoNetRevenue,
      expenses: expenseSummary.totalPaid,
      pendingExpense: currentPendingExpense,
      pendingPayout: payoutSnapshot.pendingPayout,
      paidPayout: payoutSnapshot.paidPayout,
      cargoCollection: core.cargoCollection,
      cargoCost: core.cargoCost,
      hasAnyFinanceData: hasAnyFinanceData,
    );

    return AdminFinanceAnalyticsBundle(
      cashFlowSeries: series,
      revenueSeries: series,
      expenseSeries: series,
      alerts: alerts,
      summaryRows: summaryRows,
      revenueSourceRows: currentSnapshot.sourceRows,
      adTypeRows: currentSnapshot.adBreakdown.rows,
      cargoReport: AdminFinanceCargoReport(
        collection: core.cargoCollection,
        cost: core.cargoCost,
        netRevenue: core.cargoNetRevenue,
        packageCount: core.deliveredPackages,
        freeShippingSubsidy: core.freeShippingSubsidy,
      ),
      expenseCategoryRows: expenseCategoryRows,
      sanityReport: _buildSanityReport(
        hasAnyFinanceData: hasAnyFinanceData,
        commission: core.commission,
        adRevenue: currentSnapshot.adBreakdown.totalCollected,
        cargoNetRevenue: core.cargoNetRevenue,
        paidExpenses: expenseSummary.totalPaid,
        pendingExpenses: expenseSummary.totalPending,
        refundAmount: core.refundAmount,
        currentNetProfit: currentNetProfit,
        gmv: core.gmv,
        sellerPayouts: payoutSnapshot.totalNetPayout,
        pendingPayout: payoutSnapshot.pendingPayout,
        cargoCollection: core.cargoCollection,
        cargoCost: core.cargoCost,
        freeShippingSubsidy: core.freeShippingSubsidy,
      ),
    );
  }

  static AdminFinanceSanityReport _buildSanityReport({
    required bool hasAnyFinanceData,
    required double commission,
    required double adRevenue,
    required double cargoNetRevenue,
    required double paidExpenses,
    required double pendingExpenses,
    required double refundAmount,
    required double currentNetProfit,
    required double gmv,
    required double sellerPayouts,
    required double pendingPayout,
    required double cargoCollection,
    required double cargoCost,
    required double freeShippingSubsidy,
  }) {
    if (!hasAnyFinanceData) {
      return const AdminFinanceSanityReport(
        status: AdminFinanceSanityStatus.incompleteData,
        label: 'Veri eksik',
        notes: ['Finans verisi yüklenemedi veya kayıt yok.'],
      );
    }

    final notes = <String>[];
    final platformRevenue = commission + adRevenue + cargoNetRevenue;
    final expectedNet = platformRevenue - paidExpenses;
    if ((expectedNet - currentNetProfit).abs() > 1) {
      notes.add('Net kâr ile gelir/gider özeti arasında fark var.');
    }

    if (gmv > 0) {
      final payoutPlusCommission = sellerPayouts + commission;
      if ((payoutPlusCommission - gmv).abs() > gmv * 0.05 + 1) {
        notes.add('Satıcı hakedişi + komisyon GMV ile uyumsuz olabilir.');
      }
    }

    final expectedCargoNet =
        cargoCollection - cargoCost - freeShippingSubsidy;
    if ((expectedCargoNet - cargoNetRevenue).abs() > 1) {
      notes.add('Kargo net geliri tahsilat/maliyet özeti ile uyumsuz.');
    }

    if (pendingExpenses > 0) {
      notes.add(
        'Bekleyen giderler net kâra dahil değil (${_formatMoney(pendingExpenses)}).',
      );
    }

    if (refundAmount > 0) {
      notes.add('İade/iptal tutarı ayrı raporlanıyor.');
    }

    if (notes.isEmpty) {
      return const AdminFinanceSanityReport(
        status: AdminFinanceSanityStatus.consistent,
        label: 'Tutarlı',
        notes: ['Temel finans metrikleri birbiriyle uyumlu görünüyor.'],
      );
    }

    return AdminFinanceSanityReport(
      status: AdminFinanceSanityStatus.needsReview,
      label: 'Kontrol gerekli',
      notes: notes,
    );
  }

  static List<AdminFinanceChartPoint> _buildChartSeries({
    required DateTime start,
    required DateTime endExclusive,
    required _ChartBucketMode bucketMode,
    required List<AdminFinanceOrderItem> orderItems,
    required List<AdminFinanceOrder> orders,
    required List<AdCampaign> campaigns,
    required List<AdMetrics> adMetrics,
    required List<AdRevenueRecord> adRevenueRecords,
    required List<AdWalletTransaction> adWalletTransactions,
    required List<AdminExpense> expenses,
    required List<AdminRevenue> manualRevenues,
    required AdminFinanceCommissionConfig commissionConfig,
    required bool Function(String status) isDelivered,
    required bool Function(String status) isRefund,
    required bool Function(String deliveryType) isCourierDelivery,
  }) {
    final buckets = _bucketWindows(start, endExclusive, bucketMode);
    return buckets.map((window) {
      final snapshot = AdminFinanceRevenueHelper.buildSnapshot(
        start: window.start,
        endExclusive: window.end,
        orderItems: orderItems,
        orders: orders,
        campaigns: campaigns,
        metrics: adMetrics,
        revenueRecords: adRevenueRecords,
        walletTransactions: adWalletTransactions,
        commissionConfig: commissionConfig,
        isDelivered: isDelivered,
        isRefund: isRefund,
        isCourierDelivery: isCourierDelivery,
        manualRevenues: manualRevenues,
      );
      final expenseSummary = AdminFinanceExpenseHelper.buildSummary(
        expenses: expenses,
        start: window.start,
        endExclusive: window.end,
      );
      final core = snapshot.orderCore;
      final ibulRevenue = snapshot.totalIbulRevenue;
      final netProfit = ibulRevenue - expenseSummary.totalPaid - core.refundAmount;
      return AdminFinanceChartPoint(
        date: window.start,
        label: window.label,
        gmv: core.gmv,
        ibulRevenue: ibulRevenue,
        totalExpense: expenseSummary.totalPaid,
        netProfit: netProfit,
        commission: core.commission,
        adRevenue: snapshot.adBreakdown.totalCollected,
        cargoRevenue: core.cargoNetRevenue + snapshot.manualCargoAdjustment,
        propertyRevenue: snapshot.propertyRentRevenue,
        recurringExpense: expenseSummary.recurringMonthlyTotal,
        pendingExpense: expenseSummary.totalPending,
      );
    }).toList(growable: false);
  }

  static _ChartBucketMode _resolveChartBucketMode(
    DateTime start,
    DateTime endExclusive,
  ) {
    final days = endExclusive.difference(start).inDays;
    if (days <= 21) return _ChartBucketMode.daily;
    if (days <= 120) return _ChartBucketMode.weekly;
    return _ChartBucketMode.monthly;
  }

  static List<_BucketWindow> _bucketWindows(
    DateTime start,
    DateTime endExclusive,
    _ChartBucketMode mode,
  ) {
    final windows = <_BucketWindow>[];
    late DateTime cursor;
    switch (mode) {
      case _ChartBucketMode.daily:
        cursor = DateTime(start.year, start.month, start.day);
        break;
      case _ChartBucketMode.weekly:
        cursor = DateTime(start.year, start.month, start.day);
        cursor = cursor.subtract(Duration(days: cursor.weekday - 1));
        break;
      case _ChartBucketMode.monthly:
        cursor = DateTime(start.year, start.month, 1);
        break;
    }

    while (cursor.isBefore(endExclusive)) {
      late DateTime next;
      late String label;
      switch (mode) {
        case _ChartBucketMode.daily:
          next = cursor.add(const Duration(days: 1));
          label = '${cursor.day}.${cursor.month}';
          break;
        case _ChartBucketMode.weekly:
          next = cursor.add(const Duration(days: 7));
          label = '${cursor.day} ${_monthLabel(cursor)}';
          break;
        case _ChartBucketMode.monthly:
          next = DateTime(cursor.year, cursor.month + 1, 1);
          label = _monthLabel(cursor);
          break;
      }
      final end = next.isBefore(endExclusive) ? next : endExclusive;
      windows.add(_BucketWindow(start: cursor, end: end, label: label));
      cursor = next;
    }
    return windows;
  }

  static String _monthLabel(DateTime date) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return months[date.month - 1];
  }

  static double? _changePercent(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return ((current - previous) / previous) * 100;
  }

  static String _rowStatus(double current, double previous, {bool lowerIsBetter = false}) {
    if (current == 0 && previous == 0) return 'Kayıt yok';
    final change = _changePercent(current, previous) ?? 0;
    if (change.abs() < 1) return 'Stabil';
    if (lowerIsBetter) return change < 0 ? 'İyileşti' : 'Yükseldi';
    return change > 0 ? 'Yükseldi' : 'Düştü';
  }

  static List<AdminFinanceReportRow> _buildSummaryRows({
    required _SummaryInputs current,
    required _SummaryInputs previous,
  }) {
    AdminFinanceReportRow row(
      String label,
      double cur,
      double prev, {
      bool lowerIsBetter = false,
    }) {
      return AdminFinanceReportRow(
        label: label,
        current: cur,
        previous: prev,
        changePercent: _changePercent(cur, prev),
        status: _rowStatus(cur, prev, lowerIsBetter: lowerIsBetter),
      );
    }

    return [
      row('GMV', current.gmv, previous.gmv),
      row('Kasaya Giren', current.cashIn, previous.cashIn),
      row('Komisyon', current.commission, previous.commission),
      row('Reklam Geliri', current.adRevenue, previous.adRevenue),
      row('Kargo Geliri', current.cargoRevenue, previous.cargoRevenue),
      row('Toplam Gider', current.expenses, previous.expenses, lowerIsBetter: true),
      row('Net Kâr', current.netProfit, previous.netProfit),
      row('Satıcı Hakedişi', current.sellerPayouts, previous.sellerPayouts),
      row('Bekleyen Hakediş', current.pendingPayout, previous.pendingPayout, lowerIsBetter: true),
      row('İade / İptal', current.refundAmount, previous.refundAmount, lowerIsBetter: true),
    ];
  }

  static List<AdminFinanceExpenseCategoryReportRow> _buildExpenseCategoryReport({
    required List<AdminExpense> expenses,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    final visible = AdminFinanceExpenseHelper.filterExpenses(
      expenses: expenses,
      start: start,
      endExclusive: endExclusive,
      includeCancelled: false,
    );
    if (visible.isEmpty) return const [];

    final byCategory = <String, List<AdminExpense>>{};
    for (final expense in visible) {
      byCategory.putIfAbsent(expense.category, () => []).add(expense);
    }

    return byCategory.entries.map((entry) {
      final items = entry.value;
      final total = items.fold<double>(0, (s, e) => s + e.amount);
      final pending = items
          .where((e) => e.status == 'pending')
          .fold<double>(0, (s, e) => s + e.amount);
      final recurring = items
          .where((e) => e.type == 'recurring' && e.status != 'cancelled')
          .fold<double>(0, (s, e) => s + AdminFinanceExpenseHelper.monthlyEquivalent(e));
      final largest = items.reduce(
        (a, b) => a.amount >= b.amount ? a : b,
      );
      return AdminFinanceExpenseCategoryReportRow(
        categoryLabel: AdminFinanceExpenseCategories.labelFor(entry.key),
        total: total,
        count: items.length,
        largestTitle: largest.title,
        largestAmount: largest.amount,
        pendingAmount: pending,
        recurringMonthlyImpact: recurring,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  static List<AdminFinanceAlert> _buildAlerts({
    required double currentNetProfit,
    required double previousNetProfit,
    required double currentAdRevenue,
    required double previousAdRevenue,
    required double currentGmv,
    required double currentRefundAmount,
    required double previousRefundAmount,
    required int currentRefundCount,
    required int previousRefundCount,
    required double platformRevenue,
    required double expenses,
    required double pendingExpense,
    required double pendingPayout,
    required double paidPayout,
    required double cargoCollection,
    required double cargoCost,
    required bool hasAnyFinanceData,
  }) {
    final alerts = <AdminFinanceAlert>[];

    if (!hasAnyFinanceData) {
      alerts.add(
        const AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.info,
          title: 'Veri eksik',
          message: 'Bu dönem finans verisi eksik veya henüz kayıt yok.',
        ),
      );
      return alerts;
    }

    if (currentNetProfit < 0) {
      alerts.add(
        AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.critical,
          title: 'Net kâr negatif',
          message:
              'Seçili dönemde net kâr/zarar ${_formatMoney(currentNetProfit)}.',
        ),
      );
    }

    if (cargoCost > cargoCollection && cargoCollection > 0) {
      alerts.add(
        const AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.warning,
          title: 'Kargo maliyeti yüksek',
          message: 'Kargo maliyeti kargo tahsilatını geçti.',
        ),
      );
    } else if (cargoCost > 0 && cargoCollection <= 0) {
      alerts.add(
        const AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.warning,
          title: 'Kargo maliyeti',
          message: 'Kargo maliyeti var ancak tahsilat kaydı yok.',
        ),
      );
    }

    if (pendingPayout > 0 &&
        (paidPayout == 0 || pendingPayout >= paidPayout)) {
      alerts.add(
        AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.warning,
          title: 'Bekleyen hakediş yüksek',
          message: 'Ödenmemiş satıcı hakedişi ${_formatMoney(pendingPayout)}.',
        ),
      );
    }

    if (platformRevenue > 0 && expenses / platformRevenue >= 0.5) {
      alerts.add(
        const AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.warning,
          title: 'Gider oranı yüksek',
          message: 'Giderler platform gelirinin %50\'sini geçti.',
        ),
      );
    }

    if (previousAdRevenue > 0 &&
        currentAdRevenue < previousAdRevenue * 0.9) {
      alerts.add(
        const AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.info,
          title: 'Reklam geliri düştü',
          message: 'Reklam geliri önceki döneme göre azaldı.',
        ),
      );
    }

    if (currentGmv > 0) {
      final currentRate = currentRefundAmount / currentGmv;
      if (currentRefundCount > previousRefundCount &&
          currentRate > 0.05 &&
          currentRefundAmount > previousRefundAmount) {
        alerts.add(
          const AdminFinanceAlert(
            severity: AdminFinanceAlertSeverity.warning,
            title: 'İade/iptal arttı',
            message: 'İade ve iptal tutarı veya adedi yükseldi.',
          ),
        );
      }
    }

    if (pendingExpense > 0) {
      alerts.add(
        AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.info,
          title: 'Bekleyen gider',
          message: 'Onay/bekleyen gider tutarı ${_formatMoney(pendingExpense)}.',
        ),
      );
    }

    if (pendingPayout > 0) {
      alerts.add(
        AdminFinanceAlert(
          severity: AdminFinanceAlertSeverity.info,
          title: 'Ödenmemiş hakediş',
          message: 'Ödeme bekleyen hakediş kaydı var.',
        ),
      );
    }

    return alerts;
  }

  static String _formatMoney(double value) {
    final prefix = value < 0 ? '-₺' : '₺';
    return '$prefix${value.abs().toStringAsFixed(0)}';
  }
}

class _SummaryInputs {
  const _SummaryInputs({
    required this.gmv,
    required this.cashIn,
    required this.commission,
    required this.adRevenue,
    required this.cargoRevenue,
    required this.expenses,
    required this.netProfit,
    required this.sellerPayouts,
    required this.pendingPayout,
    required this.refundAmount,
  });

  final double gmv;
  final double cashIn;
  final double commission;
  final double adRevenue;
  final double cargoRevenue;
  final double expenses;
  final double netProfit;
  final double sellerPayouts;
  final double pendingPayout;
  final double refundAmount;
}

class _BucketWindow {
  const _BucketWindow({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
}

enum _ChartBucketMode { daily, weekly, monthly }
