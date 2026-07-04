import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../features/admin/panel/helpers/admin_finance_commission_helper.dart';
import '../../features/admin/panel/helpers/admin_finance_analytics_helper.dart';
import '../../features/admin/panel/helpers/admin_finance_expense_helper.dart';
import '../../features/admin/panel/helpers/admin_finance_payout_helper.dart';
import '../../features/admin/panel/helpers/admin_finance_manual_revenue_helper.dart';
import '../../features/admin/panel/helpers/admin_finance_revenue_helper.dart';
import '../../features/admin/panel/helpers/admin_panel_density.dart';
import '../../features/admin/panel/widgets/admin_finance_alerts_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_charts_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_expense_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_payout_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_manual_revenue_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_revenue_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_segment_header.dart';
import '../../features/admin/panel/widgets/admin_finance_commission_settings_dialog.dart';
import '../../features/admin/panel/widgets/admin_finance_calculator_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_reports_panel.dart';
import '../../features/admin/panel/widgets/admin_finance_summary_table_panel.dart';
import '../../ads/models/ad_campaign.dart';
import '../../ads/models/ad_metrics.dart';
import '../../ads/models/ad_revenue_record.dart';
import '../../ads/models/ad_wallet_transaction.dart';
import '../../services/admin_service.dart';
import '../../utils/browser_file_download.dart';

class FinanceAdminPage extends StatefulWidget {
  const FinanceAdminPage({super.key});

  @override
  State<FinanceAdminPage> createState() => _FinanceAdminPageState();
}

class _FinanceAdminPageState extends State<FinanceAdminPage> {
  static const List<int> _investmentFilterOptions = [3, 6, 12, 0];
  static const String _financeLocale = 'tr_TR';

  AdminFinanceCommissionConfig _commissionConfig =
      const AdminFinanceCommissionConfig();
  List<Map<String, dynamic>> _financeCategoryOptions = const [];

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: _financeLocale,
    symbol: '₺',
    decimalDigits: 0,
  );
  final AdminService _adminService = AdminService();
  late final Future<void> _localeReadyFuture;

  _FinanceSegment _segment = _FinanceSegment.summary;
  _FinancePeriodPreset _selectedPeriod = _FinancePeriodPreset.months6;
  DateTime? _customPeriodStart;
  DateTime? _customPeriodEnd;
  _FinanceChartRange _selectedChartRange = _FinanceChartRange.last30Days;
  int _selectedInvestmentFilterMonths = 12;
  List<AdminFinanceOrderItem> _financeOrderItems = const [];
  List<AdminFinanceOrder> _financeOrders = const [];
  List<AdminFinanceStoreEntry> _financeStores = const [];
  List<AdCampaign> _financeCampaigns = const [];
  List<AdMetrics> _financeAdMetrics = const [];
  List<AdRevenueRecord> _financeAdRevenueRecords = const [];
  List<AdWalletTransaction> _financeAdWalletTransactions = const [];
  int _openStoreCount = 0;
  bool _isLoadingOperationsData = true;
  String? _operationsDataError;
  List<String> _operationsDataWarnings = const [];
  final TextEditingController _investmentSourceController =
      TextEditingController();
  final TextEditingController _investmentAmountController =
      TextEditingController();
  final TextEditingController _allocationCategoryController =
      TextEditingController();
  final TextEditingController _allocationAmountController =
      TextEditingController();
  final TextEditingController _allocationNoteController =
      TextEditingController();
  DateTime _selectedInvestmentDate = DateTime(2026, 3, 3);
  DateTime _selectedAllocationDate = DateTime(2026, 3, 3);
  List<AdminInvestmentEntry> _investmentEntries = const [];
  List<AdminInvestmentAllocation> _investmentAllocations = const [];
  List<AdminExpense> _adminExpenses = const [];
  List<AdminRevenue> _adminRevenues = const [];
  bool _isLoadingExpenseData = true;
  bool _isLoadingRevenueData = true;
  String? _expenseDataError;
  String? _revenueDataError;
  String? _expenseCategoryFilter;
  String? _expenseStatusFilter;
  String? _expenseTypeFilter;
  String? _revenueCategoryFilter;
  String? _revenueStatusFilter;
  String? _revenueTypeFilter;
  List<SellerPayout> _sellerPayoutRecords = const [];
  bool _isLoadingPayoutData = true;
  String? _payoutDataError;
  String? _payoutStatusFilter;
  String _payoutSearchQuery = '';
  bool _isLoadingInvestmentData = true;
  bool _isSavingInvestment = false;
  bool _isSavingAllocation = false;
  String? _investmentDataError;
  String? _editingInvestmentId;
  String? _editingAllocationId;
  int _operationsDataVersion = 0;
  int _investmentDataVersion = 0;
  int _expenseDataVersion = 0;
  int _revenueDataVersion = 0;
  int _payoutDataVersion = 0;
  int _commissionConfigVersion = 0;
  String? _allFinanceDataCacheKey;
  List<_FinanceMonthData>? _allFinanceDataCache;
  String? _dailyFinanceSeriesCacheKey;
  List<_FinanceChartPoint>? _dailyFinanceSeriesCache;
  String? _investmentTimelinePointsCacheKey;
  List<_InvestmentTimelinePoint>? _investmentTimelinePointsCache;
  String? _investmentAllocationBreakdownCacheKey;
  List<_InvestmentBreakdownRow>? _investmentAllocationBreakdownCache;
  String? _operationCardsCacheKey;
  List<_FinanceSummaryCard>? _operationCardsCache;
  String? _financeSnapshotCacheKey;
  AdminFinancePeriodSnapshot? _financeSnapshotCache;
  String? _analyticsBundleCacheKey;
  AdminFinanceAnalyticsBundle? _analyticsBundleCache;

  @override
  void initState() {
    super.initState();
    _localeReadyFuture = initializeDateFormatting(_financeLocale);
    _loadCommissionConfig();
    _loadOperationsData();
    _loadInvestmentData();
    _loadExpenseData();
    _loadRevenueData();
    _loadPayoutData();
  }

  @override
  void dispose() {
    _investmentSourceController.dispose();
    _investmentAmountController.dispose();
    _allocationCategoryController.dispose();
    _allocationAmountController.dispose();
    _allocationNoteController.dispose();
    super.dispose();
  }

  double _growthPercent(double current, double previous) {
    if (previous == 0) {
      return current == 0 ? 0 : 100;
    }
    return ((current - previous) / previous) * 100;
  }

  String _formatCurrency(double value) => _currencyFormatter.format(value);

  String _formatCompactCurrency(double value) {
    final absolute = value.abs();
    final prefix = value < 0 ? '-₺' : '₺';
    if (absolute >= 1000000) {
      return '$prefix${(absolute / 1000000).toStringAsFixed(1)} Mn';
    }
    if (absolute >= 1000) {
      return '$prefix${(absolute / 1000).toStringAsFixed(0)} Bin';
    }
    return _formatCurrency(value);
  }

  String _formatPercent(double value) {
    final sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  String _formatChangePercent(double? value) {
    if (value == null) return '—';
    return _formatPercent(value);
  }

  Color _trendColor(double value) {
    if (value > 0) return const Color(0xFF15803D);
    if (value < 0) return const Color(0xFFDC2626);
    return const Color(0xFF6B7280);
  }

  String _bucketKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  String _dayBucketKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime _dayStart(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String get _periodCacheKey =>
      '$_operationsDataVersion|$_investmentDataVersion|$_expenseDataVersion|$_payoutDataVersion|$_selectedPeriod|'
      '${_customPeriodStart?.millisecondsSinceEpoch}|'
      '${_customPeriodEnd?.millisecondsSinceEpoch}';

  (DateTime start, DateTime endExclusive) get _selectedPeriodBounds {
    final now = DateTime.now();
    final end = _dayStart(now.add(const Duration(days: 1)));
    switch (_selectedPeriod) {
      case _FinancePeriodPreset.days7:
        return (_dayStart(now.subtract(const Duration(days: 6))), end);
      case _FinancePeriodPreset.days30:
        return (_dayStart(now.subtract(const Duration(days: 29))), end);
      case _FinancePeriodPreset.months3:
        return (DateTime(now.year, now.month - 2, 1), end);
      case _FinancePeriodPreset.months6:
        return (DateTime(now.year, now.month - 5, 1), end);
      case _FinancePeriodPreset.months12:
        return (DateTime(now.year, now.month - 11, 1), end);
      case _FinancePeriodPreset.custom:
        final start = _customPeriodStart ?? DateTime(now.year, now.month - 5, 1);
        final customEnd = _customPeriodEnd == null
            ? end
            : _dayStart(_customPeriodEnd!.add(const Duration(days: 1)));
        return (start, customEnd);
    }
  }

  (DateTime start, DateTime endExclusive) get _previousPeriodBounds {
    final (currentStart, currentEnd) = _selectedPeriodBounds;
    final duration = currentEnd.difference(currentStart);
    return (currentStart.subtract(duration), currentStart);
  }

  String get _selectedPeriodLabel {
    switch (_selectedPeriod) {
      case _FinancePeriodPreset.days7:
        return '7 Gün';
      case _FinancePeriodPreset.days30:
        return '30 Gün';
      case _FinancePeriodPreset.months3:
        return '3 Ay';
      case _FinancePeriodPreset.months6:
        return '6 Ay';
      case _FinancePeriodPreset.months12:
        return '12 Ay';
      case _FinancePeriodPreset.custom:
        if (_customPeriodStart != null && _customPeriodEnd != null) {
          final formatter = DateFormat('d MMM', 'tr_TR');
          return '${formatter.format(_customPeriodStart!)} - '
              '${formatter.format(_customPeriodEnd!)}';
        }
        return 'Özel Tarih';
    }
  }

  AdminFinancePeriodSnapshot _buildFinanceSnapshot(
    DateTime start,
    DateTime endExclusive,
  ) {
    return AdminFinanceRevenueHelper.buildSnapshot(
      start: start,
      endExclusive: endExclusive,
      orderItems: _financeOrderItems,
      orders: _financeOrders,
      campaigns: _financeCampaigns,
      metrics: _financeAdMetrics,
      revenueRecords: _financeAdRevenueRecords,
      walletTransactions: _financeAdWalletTransactions,
      commissionConfig: _commissionConfig,
      isDelivered: _isDeliveredStatus,
      isRefund: _isRefundStatus,
      isCourierDelivery: _isCourierDelivery,
      manualRevenues: _adminRevenues,
    );
  }

  AdminFinancePeriodSnapshot get _financeSnapshot {
    final cacheKey =
        '$_operationsDataVersion|$_revenueDataVersion|$_periodCacheKey|$_commissionConfigVersion';
    if (_financeSnapshotCacheKey == cacheKey && _financeSnapshotCache != null) {
      return _financeSnapshotCache!;
    }

    final (start, end) = _selectedPeriodBounds;
    final (prevStart, prevEnd) = _previousPeriodBounds;
    final current = _buildFinanceSnapshot(start, end);
    final previous = _buildFinanceSnapshot(prevStart, prevEnd);

    final prevByKey = {for (final row in previous.sourceRows) row.key: row};
    final enrichedRows = current.sourceRows.map((row) {
      final prevAmount = prevByKey[row.key]?.amount ?? 0;
      return row.copyWithChange(_growthPercent(row.amount, prevAmount));
    }).toList(growable: false);

    final resolved = AdminFinancePeriodSnapshot(
      orderCore: current.orderCore,
      adBreakdown: current.adBreakdown,
      sourceRows: enrichedRows,
      totalIbulRevenue: current.totalIbulRevenue,
      propertyRentRevenue: current.propertyRentRevenue,
      otherRevenue: current.otherRevenue,
      manualCargoAdjustment: current.manualCargoAdjustment,
    );
    _financeSnapshotCacheKey = cacheKey;
    _financeSnapshotCache = resolved;
    return resolved;
  }

  AdminFinanceCargoBreakdown get _cargoBreakdown {
    final core = _financeSnapshot.orderCore;
    final manualCargo = _financeSnapshot.manualCargoAdjustment;
    final avg = core.deliveredPackages == 0
        ? 0.0
        : core.cargoCollection / core.deliveredPackages;
    return AdminFinanceCargoBreakdown(
      collection: core.cargoCollection,
      cost: core.cargoCost,
      freeShippingSubsidy: core.freeShippingSubsidy,
      netRevenue: core.cargoNetRevenue + manualCargo,
      packageCount: core.deliveredPackages,
      averageCollection: avg,
    );
  }

  _PeriodFinanceMetrics get _periodMetrics {
    final cacheKey = _periodCacheKey;
    if (_periodMetricsCacheKey == cacheKey && _periodMetricsCache != null) {
      return _periodMetricsCache!;
    }
    final (start, end) = _selectedPeriodBounds;
    final resolved = _computePeriodMetrics(start, end);
    _periodMetricsCacheKey = cacheKey;
    _periodMetricsCache = resolved;
    return resolved;
  }

  _PeriodFinanceMetrics get _previousPeriodMetrics {
    final cacheKey = 'prev|$_periodCacheKey';
    if (_previousPeriodMetricsCacheKey == cacheKey &&
        _previousPeriodMetricsCache != null) {
      return _previousPeriodMetricsCache!;
    }
    final (start, end) = _previousPeriodBounds;
    final resolved = _computePeriodMetrics(start, end);
    _previousPeriodMetricsCacheKey = cacheKey;
    _previousPeriodMetricsCache = resolved;
    return resolved;
  }

  _PeriodFinanceMetrics _computePeriodMetrics(
    DateTime start,
    DateTime endExclusive,
  ) {
    final snapshot = _buildFinanceSnapshot(start, endExclusive);
    final core = snapshot.orderCore;
    final adRevenue = snapshot.adBreakdown.totalCollected;
    final manualReceived = AdminFinanceManualRevenueHelper.periodReceivedTotal(
      revenues: _adminRevenues,
      start: start,
      endExclusive: endExclusive,
    );
    final courierRevenue =
        core.cargoNetRevenue + snapshot.manualCargoAdjustment;

    var expenses = AdminFinanceExpenseHelper.periodPaidTotal(
      expenses: _adminExpenses,
      start: start,
      endExclusive: endExclusive,
    );

    final payoutSnapshot = _buildPayoutSnapshot(start, endExclusive);
    final sellerPayouts = payoutSnapshot.totalNetPayout;
    final pendingPayout = payoutSnapshot.pendingPayout;
    final platformRevenue = snapshot.totalIbulRevenue;
    final taxExpenses = AdminFinanceExpenseHelper.periodTaxExpenses(
      expenses: _adminExpenses,
      start: start,
      endExclusive: endExclusive,
    );
    final taxEstimate = AdminFinanceCommissionHelper.estimateTaxes(
      taxableRevenue: platformRevenue,
      recordedTaxExpenses: taxExpenses,
      config: _commissionConfig,
    );
    final ibulNetRevenue = platformRevenue - expenses - core.refundAmount;
    final netProfit = platformRevenue - expenses;
    final cashIn = core.gmv + core.cargoCollection + adRevenue + manualReceived;

    return _PeriodFinanceMetrics(
      gmv: core.gmv,
      cashIn: cashIn,
      ibulNetRevenue: ibulNetRevenue,
      commission: core.commission,
      adRevenue: adRevenue,
      courierRevenue: courierRevenue,
      sellerPayouts: sellerPayouts,
      expenses: expenses,
      netProfit: netProfit,
      refundAmount: core.refundAmount,
      refundCount: core.refundCount,
      pendingPayout: pendingPayout,
      averageBasket: core.averageBasket,
      completedOrders: core.completedOrders,
      estimatedKdv: taxEstimate.kdvEstimate,
      governmentExpenses: taxEstimate.totalGovernmentBurden,
      netAfterTax: netProfit - taxEstimate.totalGovernmentBurden,
    );
  }

  String? _periodMetricsCacheKey;
  _PeriodFinanceMetrics? _periodMetricsCache;
  String? _previousPeriodMetricsCacheKey;
  _PeriodFinanceMetrics? _previousPeriodMetricsCache;

  DateTime get _operationsStartDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month - 11, 1);
  }

  bool _isDeliveredStatus(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    return OrderStatusConstants.isEcommerceTerminal(status) || status == 'teslim edildi';
  }

  bool _isRefundStatus(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    return status.contains('refund') ||
        status.contains('return') ||
        status.contains('iade') ||
        status == OrderStatusConstants.ecommerceCancelled ||
        status == 'iptal edildi';
  }

  bool _isCourierDelivery(String rawDeliveryType) {
    final deliveryType = rawDeliveryType.trim().toLowerCase();
    return deliveryType.contains('courier') || deliveryType.contains('kurye');
  }

  List<_FinanceMonthData> get _allFinanceData {
    final cacheKey = '$_operationsDataVersion|$_investmentDataVersion|$_expenseDataVersion';
    if (_allFinanceDataCacheKey == cacheKey && _allFinanceDataCache != null) {
      return _allFinanceDataCache!;
    }

    final now = DateTime.now();
    final monthStarts = List.generate(
      12,
      (index) => DateTime(now.year, now.month - 11 + index, 1),
    );

    final deliveredByMonth = <String, List<AdminFinanceOrderItem>>{};
    for (final item in _financeOrderItems) {
      if (!_isDeliveredStatus(item.status)) continue;
      deliveredByMonth
          .putIfAbsent(
            _bucketKey(item.createdAt),
            () => <AdminFinanceOrderItem>[],
          )
          .add(item);
    }

    final expensesByMonth = <String, double>{};
    for (final expense in _adminExpenses) {
      if (expense.status != 'paid') continue;
      final key = _bucketKey(expense.expenseDate);
      expensesByMonth.update(
        key,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final courierByMonth = <String, double>{};
    for (final order in _financeOrders) {
      if (!_isDeliveredStatus(order.status) &&
          !_isCourierDelivery(order.deliveryType)) {
        continue;
      }
      final amount = order.shippingAmount;
      if (amount <= 0) continue;
      final key = _bucketKey(order.createdAt);
      courierByMonth.update(
        key,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final resolved = monthStarts
        .map((monthStart) {
          final key = _bucketKey(monthStart);
          final items =
              deliveredByMonth[key] ?? const <AdminFinanceOrderItem>[];
          final gross = items.fold<double>(
            0,
            (sum, item) => sum + item.totalPrice,
          );
          final commission = items.fold<double>(
            0,
            (sum, item) =>
                sum +
                AdminFinanceCommissionHelper.commissionForItem(
                  item: item,
                  config: _commissionConfig,
                ),
          );
          final courierRevenue = courierByMonth[key] ?? 0;
          final expenses = expensesByMonth[key] ?? 0;
          final orderIds = items
              .map((item) => item.orderId)
              .where((id) => id.isNotEmpty)
              .toSet();
          final storeKeys = items
              .map(
                (item) => item.sellerId.trim().isNotEmpty
                    ? item.sellerId.trim()
                    : item.storeName.trim().toLowerCase(),
              )
              .where((value) => value.isNotEmpty)
              .toSet();

          return _FinanceMonthData(
            periodStart: monthStart,
            label: DateFormat('MMM yy', 'tr_TR').format(monthStart),
            gmvCollected: gross,
            commissionRevenue: commission,
            courierRevenue: courierRevenue,
            sellerPayouts: gross - commission,
            totalExpenses: expenses,
            completedOrders: orderIds.length,
            activeStores: storeKeys.length,
          );
        })
        .toList(growable: false);
    _allFinanceDataCacheKey = cacheKey;
    _allFinanceDataCache = resolved;
    return resolved;
  }

  List<_FinanceChartPoint> _buildDailyFinanceSeries() {
    final cacheKey = '$_operationsDataVersion|$_investmentDataVersion|$_expenseDataVersion';
    if (_dailyFinanceSeriesCacheKey == cacheKey &&
        _dailyFinanceSeriesCache != null) {
      return _dailyFinanceSeriesCache!;
    }

    final now = DateTime.now();
    final startDate = _dayStart(now.subtract(const Duration(days: 29)));

    final deliveredByDay = <String, double>{};
    for (final item in _financeOrderItems) {
      if (!_isDeliveredStatus(item.status)) continue;
      if (item.createdAt.isBefore(startDate)) continue;
      final key = _dayBucketKey(_dayStart(item.createdAt));
      deliveredByDay.update(
        key,
        (value) => value + item.totalPrice,
        ifAbsent: () => item.totalPrice,
      );
    }

    final expenseByDay = <String, double>{};
    for (final expense in _adminExpenses) {
      if (expense.status != 'paid') continue;
      final day = _dayStart(expense.expenseDate);
      if (day.isBefore(startDate)) continue;
      final key = _dayBucketKey(day);
      expenseByDay.update(
        key,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final courierByDay = <String, double>{};
    for (final order in _financeOrders) {
      if (order.createdAt.isBefore(startDate)) continue;
      if (!_isCourierDelivery(order.deliveryType) &&
          order.shippingAmount <= 0) {
        continue;
      }
      final key = _dayBucketKey(_dayStart(order.createdAt));
      courierByDay.update(
        key,
        (value) => value + order.shippingAmount,
        ifAbsent: () => order.shippingAmount,
      );
    }

    final resolved = List.generate(30, (index) {
      final date = startDate.add(Duration(days: index));
      final key = _dayBucketKey(date);
      final grossOrderFlow = deliveredByDay[key] ?? 0;
      final courierRevenue = courierByDay[key] ?? 0;
      final expense = expenseByDay[key] ?? 0;
      final commissionRevenue =
          grossOrderFlow * (_commissionConfig.defaultPercent / 100);
      return _FinanceChartPoint(
        date: date,
        axisLabel: DateFormat('EEE', 'tr_TR').format(date),
        grossRevenue: grossOrderFlow + courierRevenue,
        netRevenue: (commissionRevenue + courierRevenue) - expense,
        expense: expense,
        courierEarnings: courierRevenue,
      );
    });
    _dailyFinanceSeriesCacheKey = cacheKey;
    _dailyFinanceSeriesCache = resolved;
    return resolved;
  }

  List<_FinanceChartPoint> get _dailyFinanceSeries =>
      _buildDailyFinanceSeries();

  List<_FinanceChartPoint> _buildMonthlyChartSeries(int count) {
    final startIndex = math.max(0, _allFinanceData.length - count);
    final source = _allFinanceData.sublist(startIndex);

    return source
        .map((item) {
          return _FinanceChartPoint(
            date: item.periodStart,
            axisLabel: DateFormat('MMM', 'tr_TR').format(item.periodStart),
            grossRevenue: item.cashIn,
            netRevenue: item.netProfit,
            expense: item.totalExpenses,
            courierEarnings: item.courierRevenue,
          );
        })
        .toList(growable: false);
  }

  List<_FinanceChartPoint> get _selectedChartPoints {
    switch (_selectedChartRange) {
      case _FinanceChartRange.last7Days:
        return _dailyFinanceSeries.sublist(
          math.max(0, _dailyFinanceSeries.length - 7),
        );
      case _FinanceChartRange.last30Days:
        return _dailyFinanceSeries;
      case _FinanceChartRange.last3Months:
        return _buildMonthlyChartSeries(3);
      case _FinanceChartRange.last6Months:
        return _buildMonthlyChartSeries(6);
      case _FinanceChartRange.custom:
        return _buildMonthlyChartSeries(12);
    }
  }

  String _formatChartRangeCaption(List<_FinanceChartPoint> points) {
    if (points.isEmpty) return '-';
    final formatter = DateFormat('d MMM yyyy', 'tr_TR');
    return '${formatter.format(points.first.date)} - ${formatter.format(points.last.date)}';
  }

  String _formatChartAxisValue(double value) {
    if (value <= 0) return '₺0';
    if (value >= 1000000) {
      return '₺${(value / 1000000).toStringAsFixed(1)}Mn';
    }
    if (value >= 1000) {
      return '₺${(value / 1000).round()}B';
    }
    return '₺${value.round()}';
  }

  List<Widget> _buildPerformanceYAxisLabels(double maxValue) {
    return List.generate(5, (index) {
      final step = 4 - index;
      final value = (maxValue / 4) * step;
      return Text(
        _formatChartAxisValue(value),
        style: const TextStyle(
          color: Color(0xFF8B8B8B),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
    });
  }

  List<int> _buildXAxisIndices(List<_FinanceChartPoint> points) {
    if (points.isEmpty) return const [];
    final labelCount = math.min(points.length, 6);
    if (labelCount == 1) return const [0];

    final indices = <int>{};
    for (var i = 0; i < labelCount; i++) {
      final ratio = i / (labelCount - 1);
      indices.add(((points.length - 1) * ratio).round());
    }
    final ordered = indices.toList()..sort();
    return ordered;
  }

  double _parseCurrencyInput(String raw) {
    final normalized = raw
        .trim()
        .replaceAll('.', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(normalized) ?? 0;
  }

  double get _totalInvestmentReceived =>
      _investmentEntries.fold<double>(0, (sum, item) => sum + item.amount);

  double get _totalInvestmentSpent =>
      _investmentAllocations.fold<double>(0, (sum, item) => sum + item.amount);

  double get _remainingInvestmentBalance =>
      _totalInvestmentReceived - _totalInvestmentSpent;

  DateTime? get _investmentFilterCutoff {
    if (_selectedInvestmentFilterMonths == 0) return null;
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month - _selectedInvestmentFilterMonths + 1,
      1,
    );
  }

  List<_InvestmentTimelinePoint> get _investmentTimelinePoints {
    final cacheKey = '$_investmentDataVersion|$_selectedInvestmentFilterMonths';
    if (_investmentTimelinePointsCacheKey == cacheKey &&
        _investmentTimelinePointsCache != null) {
      return _investmentTimelinePointsCache!;
    }

    final entries = [..._investmentEntries].where((entry) {
      final cutoff = _investmentFilterCutoff;
      return cutoff == null || !entry.investmentDate.isBefore(cutoff);
    }).toList()..sort((a, b) => a.investmentDate.compareTo(b.investmentDate));
    var runningTotal = 0.0;
    final resolved = entries
        .map((entry) {
          runningTotal += entry.amount;
          return _InvestmentTimelinePoint(
            label: DateFormat('MMM yy', 'tr_TR').format(entry.investmentDate),
            value: runningTotal,
          );
        })
        .toList(growable: false);
    _investmentTimelinePointsCacheKey = cacheKey;
    _investmentTimelinePointsCache = resolved;
    return resolved;
  }

  List<_InvestmentBreakdownRow> get _investmentAllocationBreakdown {
    final cacheKey = '$_investmentDataVersion';
    if (_investmentAllocationBreakdownCacheKey == cacheKey &&
        _investmentAllocationBreakdownCache != null) {
      return _investmentAllocationBreakdownCache!;
    }

    final totals = <String, double>{};
    for (final allocation in _investmentAllocations) {
      totals.update(
        allocation.category,
        (value) => value + allocation.amount,
        ifAbsent: () => allocation.amount,
      );
    }
    final totalSpent = _totalInvestmentSpent;
    final colors = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFEA580C),
      const Color(0xFF0F766E),
      const Color(0xFFDB2777),
      const Color(0xFF16A34A),
    ];
    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final resolved = List.generate(rows.length, (index) {
      final row = rows[index];
      return _InvestmentBreakdownRow(
        label: row.key,
        amount: row.value,
        share: totalSpent == 0 ? 0 : row.value / totalSpent,
        color: colors[index % colors.length],
      );
    });
    _investmentAllocationBreakdownCacheKey = cacheKey;
    _investmentAllocationBreakdownCache = resolved;
    return resolved;
  }

  AdminFinanceExpenseSummary get _expenseSummary {
    final (start, end) = _selectedPeriodBounds;
    return AdminFinanceExpenseHelper.buildSummary(
      expenses: _adminExpenses,
      start: start,
      endExclusive: end,
      categoryKey: _expenseCategoryFilter,
      statusKey: _expenseStatusFilter,
      typeKey: _expenseTypeFilter,
    );
  }

  List<AdminExpense> get _filteredExpenses {
    final (start, end) = _selectedPeriodBounds;
    return AdminFinanceExpenseHelper.filterExpenses(
      expenses: _adminExpenses,
      start: start,
      endExclusive: end,
      categoryKey: _expenseCategoryFilter,
      statusKey: _expenseStatusFilter,
      typeKey: _expenseTypeFilter,
      includeCancelled: _expenseStatusFilter == 'cancelled',
    );
  }

  AdminFinanceManualRevenueSummary get _manualRevenueSummary {
    final (start, end) = _selectedPeriodBounds;
    return AdminFinanceManualRevenueHelper.buildSummary(
      revenues: _adminRevenues,
      start: start,
      endExclusive: end,
      categoryKey: _revenueCategoryFilter,
      statusKey: _revenueStatusFilter,
      typeKey: _revenueTypeFilter,
    );
  }

  List<AdminRevenue> get _filteredRevenues {
    final (start, end) = _selectedPeriodBounds;
    return AdminFinanceManualRevenueHelper.filterRevenues(
      revenues: _adminRevenues,
      start: start,
      endExclusive: end,
      categoryKey: _revenueCategoryFilter,
      statusKey: _revenueStatusFilter,
      typeKey: _revenueTypeFilter,
      includeCancelled: _revenueStatusFilter == 'cancelled',
    );
  }

  AdminFinancePayoutPeriodSnapshot get _payoutSnapshot {
    final (start, end) = _selectedPeriodBounds;
    return _buildPayoutSnapshot(start, end);
  }

  AdminFinancePayoutPeriodSnapshot _buildPayoutSnapshot(
    DateTime start,
    DateTime endExclusive, {
    String? statusFilter,
    String searchQuery = '',
  }) {
    return AdminFinancePayoutHelper.buildSnapshot(
      periodStart: start,
      periodEndExclusive: endExclusive,
      orderItems: _financeOrderItems,
      payoutRecords: _sellerPayoutRecords,
      commissionConfig: _commissionConfig,
      isDelivered: _isDeliveredStatus,
      isRefund: _isRefundStatus,
      statusFilter: statusFilter ?? _payoutStatusFilter,
      searchQuery: searchQuery.isEmpty ? _payoutSearchQuery : searchQuery,
      allStores: _financeStores,
    );
  }

  AdminFinanceExpenseSummary _buildExpenseSummaryForPeriod(
    DateTime start,
    DateTime endExclusive,
  ) {
    return AdminFinanceExpenseHelper.buildSummary(
      expenses: _adminExpenses,
      start: start,
      endExclusive: endExclusive,
    );
  }

  bool get _hasAnyFinanceData {
    if (_isLoadingOperationsData ||
        _isLoadingExpenseData ||
        _isLoadingRevenueData ||
        _isLoadingPayoutData) {
      return true;
    }
    return _financeOrderItems.isNotEmpty ||
        _financeOrders.isNotEmpty ||
        _financeCampaigns.isNotEmpty ||
        _adminExpenses.isNotEmpty ||
        _adminRevenues.isNotEmpty ||
        _sellerPayoutRecords.isNotEmpty;
  }

  AdminFinanceAnalyticsBundle get _analyticsBundle {
    final cacheKey =
        'analytics|$_operationsDataVersion|$_expenseDataVersion|$_revenueDataVersion|$_payoutDataVersion|$_periodCacheKey|$_commissionConfigVersion';
    if (_analyticsBundleCacheKey == cacheKey && _analyticsBundleCache != null) {
      return _analyticsBundleCache!;
    }

    final (start, end) = _selectedPeriodBounds;
    final (prevStart, prevEnd) = _previousPeriodBounds;
    final currentSnapshot = _financeSnapshot;
    final previousSnapshot = _buildFinanceSnapshot(prevStart, prevEnd);
    final expenseSummary = _buildExpenseSummaryForPeriod(start, end);
    final previousExpenseSummary =
        _buildExpenseSummaryForPeriod(prevStart, prevEnd);
    final payoutSnapshot = _buildPayoutSnapshot(
      start,
      end,
      statusFilter: '',
      searchQuery: '',
    );
    final previousPayoutSnapshot = _buildPayoutSnapshot(
      prevStart,
      prevEnd,
      statusFilter: '',
      searchQuery: '',
    );
    final metrics = _periodMetrics;
    final previousMetrics = _previousPeriodMetrics;

    final resolved = AdminFinanceAnalyticsHelper.build(
      start: start,
      endExclusive: end,
      previousStart: prevStart,
      previousEndExclusive: prevEnd,
      orderItems: _financeOrderItems,
      orders: _financeOrders,
      campaigns: _financeCampaigns,
      adMetrics: _financeAdMetrics,
      adRevenueRecords: _financeAdRevenueRecords,
      adWalletTransactions: _financeAdWalletTransactions,
      expenses: _adminExpenses,
      manualRevenues: _adminRevenues,
      payoutRecords: _sellerPayoutRecords,
      commissionConfig: _commissionConfig,
      isDelivered: _isDeliveredStatus,
      isRefund: _isRefundStatus,
      isCourierDelivery: _isCourierDelivery,
      currentSnapshot: currentSnapshot,
      previousSnapshot: previousSnapshot,
      expenseSummary: expenseSummary,
      previousExpenseSummary: previousExpenseSummary,
      payoutSnapshot: payoutSnapshot,
      previousPayoutSnapshot: previousPayoutSnapshot,
      currentNetProfit: metrics.netProfit,
      previousNetProfit: previousMetrics.netProfit,
      currentCashIn: metrics.cashIn,
      previousCashIn: previousMetrics.cashIn,
      currentPendingExpense: expenseSummary.totalPending,
      previousPendingExpense: previousExpenseSummary.totalPending,
      currentRefundCount: metrics.refundCount,
      previousRefundCount: previousMetrics.refundCount,
      hasAnyFinanceData: _hasAnyFinanceData,
    );
    _analyticsBundleCacheKey = cacheKey;
    _analyticsBundleCache = resolved;
    return resolved;
  }

  (DateTime, DateTime) get _payoutPeriodBounds {
    final (start, endExclusive) = _selectedPeriodBounds;
    final end = endExclusive.subtract(const Duration(days: 1));
    return (start, end);
  }

  Future<void> _loadPayoutData() async {
    setState(() {
      _isLoadingPayoutData = true;
      _payoutDataError = null;
    });
    try {
      final rows = await _adminService.fetchSellerPayouts(
        from: _operationsStartDate,
      );
      if (!mounted) return;
      setState(() {
        _sellerPayoutRecords = rows;
        _payoutDataVersion++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _payoutDataError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingPayoutData = false);
      }
    }
  }

  Future<void> _loadCommissionConfig() async {
    try {
      final results = await Future.wait<dynamic>([
        _adminService.fetchFinanceCommissionConfigRaw(),
        _adminService.fetchFinanceCategoryOptions(),
      ]);
      if (!mounted) return;
      setState(() {
        _commissionConfig = AdminFinanceCommissionConfig.fromJson(results[0]);
        _financeCategoryOptions =
            List<Map<String, dynamic>>.from(results[1] as List);
        _commissionConfigVersion++;
        _financeSnapshotCache = null;
        _analyticsBundleCache = null;
        _operationCardsCache = null;
      });
    } catch (error) {
      debugPrint('Finance commission config load failed: $error');
    }
  }

  Future<void> _openCommissionSettings(AdminPanelDensity density) async {
    await AdminFinanceCommissionSettingsDialog.show(
      context,
      density: density,
      initialConfig: _commissionConfig,
      categoryOptions: _financeCategoryOptions,
      onSave: (config) async {
        await _adminService.saveFinanceCommissionConfig(config.toJson());
        if (!mounted) return;
        setState(() {
          _commissionConfig = config;
          _commissionConfigVersion++;
          _financeSnapshotCache = null;
          _analyticsBundleCache = null;
          _operationCardsCache = null;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Komisyon ayarları kaydedildi.')),
        );
      },
    );
  }

  Future<SellerPayout> _ensurePayoutRecord(
    AdminFinancePayoutSellerRow row, {
    required String status,
    String? note,
  }) async {
    final (periodStart, periodEnd) = _payoutPeriodBounds;
    return _adminService.createOrRefreshSellerPayout(
      sellerId: row.sellerId,
      storeId: row.storeId,
      storeName: row.storeName,
      periodStart: periodStart,
      periodEnd: periodEnd,
      grossAmount: row.grossAmount,
      commissionAmount: row.commissionAmount,
      refundAmount: row.refundAmount,
      deductionsAmount: row.deductionsAmount,
      netPayoutAmount: row.netPayoutAmount,
      orderCount: row.orderCount,
      itemCount: row.itemCount,
      status: status,
      note: note,
      existingId: row.payoutRecordId,
    );
  }

  Future<void> _approveSellerPayout(AdminFinancePayoutSellerRow row) async {
    if (row.status == 'paid') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu hakediş zaten ödendi.')),
      );
      return;
    }
    if (row.status == 'approved') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu hakediş zaten onaylı.')),
      );
      return;
    }
    if (!SellerPayoutStatusTransition.canTransition(row.status, 'approved')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SellerPayoutStatusTransition.errorMessage(row.status, 'approved'),
          ),
        ),
      );
      return;
    }
    try {
      await _ensurePayoutRecord(row, status: 'approved');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakediş onaylandı.')),
      );
      await _loadPayoutData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _markSellerPayoutPaid(
    AdminFinancePayoutSellerRow row,
    AdminPayoutPaymentDraft draft,
  ) async {
    try {
      var record = await _ensurePayoutRecord(row, status: 'approved');
      record = await _adminService.markSellerPayoutPaid(
        payoutId: record.id,
        paymentMethod: draft.paymentMethod,
        paymentReference: draft.paymentReference,
        paidAt: draft.paidAt,
        note: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakediş ödendi olarak işaretlendi.')),
      );
      await _loadPayoutData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _disputeSellerPayout(AdminFinancePayoutSellerRow row) async {
    if (!SellerPayoutStatusTransition.canTransition(row.status, 'disputed')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SellerPayoutStatusTransition.errorMessage(row.status, 'disputed'),
          ),
        ),
      );
      return;
    }
    try {
      await _ensurePayoutRecord(row, status: 'disputed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakediş itirazlı olarak işaretlendi.')),
      );
      await _loadPayoutData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _cancelSellerPayout(AdminFinancePayoutSellerRow row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hakedişi iptal et'),
        content: Text('"${row.storeName}" hakediş kaydını iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('İptal et')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (!SellerPayoutStatusTransition.canTransition(row.status, 'cancelled')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            SellerPayoutStatusTransition.errorMessage(row.status, 'cancelled'),
          ),
        ),
      );
      return;
    }
    try {
      await _ensurePayoutRecord(row, status: 'cancelled');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakediş iptal edildi.')),
      );
      await _loadPayoutData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _loadExpenseData() async {
    setState(() {
      _isLoadingExpenseData = true;
      _expenseDataError = null;
    });
    try {
      final rows = await _adminService
          .fetchAdminExpenses(from: _operationsStartDate)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _adminExpenses = rows;
        _expenseDataVersion++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _expenseDataError = _formatExpenseLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingExpenseData = false);
      }
    }
  }

  String _formatExpenseLoadError(Object error) {
    final msg = '$error';
    if (msg.contains('admin_expenses') ||
        msg.contains('PGRST205') ||
        msg.contains('migration')) {
      return 'admin_expenses migration uygulanmamış olabilir.';
    }
    if (msg.contains('42501') ||
        msg.contains('Yetki') ||
        msg.contains('RLS') ||
        msg.contains('permission denied')) {
      return 'Gider kayıtları yüklenemedi. Yetki veya Supabase migration kontrol edilmeli.';
    }
    if (error is TimeoutException) {
      return 'Gider kayıtları yüklenemedi. Bağlantı zaman aşımına uğradı.';
    }
    return 'Gider kayıtları yüklenemedi. Yetki veya Supabase migration kontrol edilmeli.';
  }

  String _formatRevenueLoadError(Object error) {
    final msg = '$error';
    if (msg.contains('admin_revenues') ||
        msg.contains('PGRST205') ||
        msg.contains('migration')) {
      return 'admin_revenues migration uygulanmamış olabilir.';
    }
    if (msg.contains('42501') ||
        msg.contains('Yetki') ||
        msg.contains('RLS') ||
        msg.contains('permission denied')) {
      return 'Gelir kayıtları yüklenemedi. Yetki veya Supabase migration kontrol edilmeli.';
    }
    if (error is TimeoutException) {
      return 'Gelir kayıtları yüklenemedi. Bağlantı zaman aşımına uğradı.';
    }
    return 'Gelir kayıtları yüklenemedi. Yetki veya Supabase migration kontrol edilmeli.';
  }

  Future<void> _loadRevenueData() async {
    setState(() {
      _isLoadingRevenueData = true;
      _revenueDataError = null;
    });
    try {
      final rows = await _adminService
          .fetchAdminRevenues(from: _operationsStartDate)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _adminRevenues = rows;
        _revenueDataVersion++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _revenueDataError = _formatRevenueLoadError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingRevenueData = false);
      }
    }
  }

  Future<void> _saveAdminExpense(AdminExpenseDraft draft) async {
    try {
      await _adminService.logFinanceExpenseAccessDebug();
      if (draft.id == null || draft.id!.isEmpty) {
        await _adminService.createAdminExpense(
          title: draft.title,
          category: draft.category,
          amount: draft.amount,
          expenseDate: draft.expenseDate,
          type: draft.type,
          recurrence: draft.recurrence,
          status: draft.status,
          paymentMethod: draft.paymentMethod,
          vendor: draft.vendor,
          invoiceUrl: draft.invoiceUrl,
          note: draft.note,
        );
      } else {
        await _adminService.updateAdminExpense(
          id: draft.id!,
          title: draft.title,
          category: draft.category,
          amount: draft.amount,
          expenseDate: draft.expenseDate,
          type: draft.type,
          recurrence: draft.recurrence,
          status: draft.status,
          paymentMethod: draft.paymentMethod,
          vendor: draft.vendor,
          invoiceUrl: draft.invoiceUrl,
          note: draft.note,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gider kaydedildi.')),
      );
      await _loadExpenseData();
    } catch (error) {
      debugPrint('[FinanceExpense] save failed: $error');
      rethrow;
    }
  }

  Future<void> _saveAdminRevenue(AdminRevenueDraft draft) async {
    try {
      if (draft.id == null || draft.id!.isEmpty) {
        await _adminService.createAdminRevenue(
          title: draft.title,
          category: draft.category,
          amount: draft.amount,
          revenueDate: draft.revenueDate,
          type: draft.type,
          recurrence: draft.recurrence,
          status: draft.status,
          source: draft.source,
          paymentMethod: draft.paymentMethod,
          referenceNo: draft.referenceNo,
          note: draft.note,
        );
      } else {
        await _adminService.updateAdminRevenue(
          id: draft.id!,
          title: draft.title,
          category: draft.category,
          amount: draft.amount,
          revenueDate: draft.revenueDate,
          type: draft.type,
          recurrence: draft.recurrence,
          status: draft.status,
          source: draft.source,
          paymentMethod: draft.paymentMethod,
          referenceNo: draft.referenceNo,
          note: draft.note,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gelir kaydedildi.')),
      );
      await _loadRevenueData();
    } catch (error) {
      debugPrint('[FinanceRevenue] save failed: $error');
      rethrow;
    }
  }

  Future<void> _cancelAdminRevenue(AdminRevenue revenue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geliri iptal et'),
        content: Text('"${revenue.title}" kaydını iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _adminService.cancelAdminRevenue(revenue.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gelir iptal edildi.')),
      );
      await _loadRevenueData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _cancelAdminExpense(AdminExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gideri iptal et'),
        content: Text('"${expense.title}" kaydını iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _adminService.cancelAdminExpense(expense.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gider iptal edildi.')),
      );
      await _loadExpenseData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> _loadOperationsData() async {
    setState(() {
      _isLoadingOperationsData = true;
      _operationsDataError = null;
    });

    final warnings = <String>[];
    var orderItems = const <AdminFinanceOrderItem>[];
    var orders = const <AdminFinanceOrder>[];
    var openStoreCount = 0;
    var campaigns = const <AdCampaign>[];
    var adMetrics = const <AdMetrics>[];
    var adRevenueRecords = const <AdRevenueRecord>[];
    var adWalletTransactions = const <AdWalletTransaction>[];
    var financeStores = const <AdminFinanceStoreEntry>[];

    try {
      orderItems = await _adminService.getFinanceOrderItems(
        from: _operationsStartDate,
      );
    } catch (error) {
      warnings.add('Sipariş kalemleri alınamadı.');
      debugPrint('Finance order_items load failed: $error');
    }

    try {
      orders = await _adminService.getFinanceOrders(from: _operationsStartDate);
    } catch (error) {
      warnings.add('Siparişler alınamadı.');
      debugPrint('Finance orders load failed: $error');
    }

    try {
      openStoreCount = await _adminService.getOpenStoreCount();
    } catch (error) {
      debugPrint('Finance open store count failed: $error');
    }

    try {
      financeStores = await _adminService.getFinanceStoreDirectory();
    } catch (error) {
      debugPrint('Finance store directory load failed: $error');
    }

    try {
      final rows = await _adminService.getFinanceAdCampaignRows(
        from: _operationsStartDate,
      );
      campaigns = rows.map(AdCampaign.fromJson).toList(growable: false);
    } catch (error) {
      warnings.add('Reklam kampanyaları alınamadı.');
      debugPrint('Finance campaigns load failed: $error');
    }

    try {
      final rows = await _adminService.getFinanceAdMetricsRows(
        from: _operationsStartDate,
      );
      adMetrics = rows.map(AdMetrics.fromJson).toList(growable: false);
    } catch (error) {
      warnings.add('Reklam metrikleri alınamadı.');
      debugPrint('Finance ad metrics load failed: $error');
    }

    try {
      final rows = await _adminService.getFinanceAdRevenueLogRows(
        from: _operationsStartDate,
      );
      adRevenueRecords =
          rows.map(AdRevenueRecord.fromJson).toList(growable: false);
    } catch (error) {
      warnings.add('Reklam gelir kayıtları alınamadı.');
      debugPrint('Finance ad revenue logs load failed: $error');
    }

    try {
      final rows = await _adminService.getFinanceAdWalletTransactionRows(
        from: _operationsStartDate,
      );
      adWalletTransactions =
          rows.map(AdWalletTransaction.fromJson).toList(growable: false);
    } catch (error) {
      warnings.add('Reklam cüzdan hareketleri alınamadı.');
      debugPrint('Finance ad wallet tx load failed: $error');
    }

    if (!mounted) return;
    setState(() {
      _financeOrderItems = orderItems;
      _financeOrders = orders;
      _financeStores = financeStores;
      _openStoreCount = openStoreCount;
      _financeCampaigns = campaigns;
      _financeAdMetrics = adMetrics;
      _financeAdRevenueRecords = adRevenueRecords;
      _financeAdWalletTransactions = adWalletTransactions;
      _operationsDataVersion++;
      _operationsDataWarnings = warnings;
      _operationsDataError = orderItems.isEmpty &&
              orders.isEmpty &&
              campaigns.isEmpty &&
              warnings.isNotEmpty
          ? warnings.join(' ')
          : null;
    });
    if (mounted) {
      setState(() => _isLoadingOperationsData = false);
    }
  }

  Future<void> _loadInvestmentData() async {
    setState(() {
      _isLoadingInvestmentData = true;
      _investmentDataError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getInvestmentEntries(),
        _adminService.getInvestmentAllocations(),
      ]);
      if (!mounted) return;
      setState(() {
        _investmentEntries = results[0] as List<AdminInvestmentEntry>;
        _investmentAllocations = results[1] as List<AdminInvestmentAllocation>;
        _investmentDataVersion++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _investmentDataError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingInvestmentData = false);
      }
    }
  }

  Future<void> _pickInvestmentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedInvestmentDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
      locale: const Locale('tr', 'TR'),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedInvestmentDate = picked);
  }

  Future<void> _pickAllocationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedAllocationDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
      locale: const Locale('tr', 'TR'),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedAllocationDate = picked);
  }

  Future<void> _addInvestmentEntry() async {
    final source = _investmentSourceController.text.trim();
    final amount = _parseCurrencyInput(_investmentAmountController.text);
    if (source.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yatırım kaynağı ve tutarı girin.')),
      );
      return;
    }
    setState(() => _isSavingInvestment = true);
    try {
      await _adminService.upsertInvestmentEntry(
        id: _editingInvestmentId,
        source: source,
        amount: amount,
        investmentDate: _selectedInvestmentDate,
      );
      _clearInvestmentForm();
      await _loadInvestmentData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingInvestmentId == null
                ? 'Yatırım kaydedildi.'
                : 'Yatırım güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _isSavingInvestment = false);
      }
    }
  }

  void _startEditingInvestment(AdminInvestmentEntry entry) {
    setState(() {
      _editingInvestmentId = entry.id;
      _investmentSourceController.text = entry.source;
      _investmentAmountController.text = entry.amount.toStringAsFixed(0);
      _selectedInvestmentDate = entry.investmentDate;
    });
  }

  void _clearInvestmentForm() {
    setState(() {
      _editingInvestmentId = null;
      _investmentSourceController.clear();
      _investmentAmountController.clear();
      _selectedInvestmentDate = DateTime.now();
    });
  }

  Future<void> _addAllocationEntry() async {
    final category = _allocationCategoryController.text.trim();
    final amount = _parseCurrencyInput(_allocationAmountController.text);
    final note = _allocationNoteController.text.trim();
    if (category.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harcama alanı ve tutarı girin.')),
      );
      return;
    }
    setState(() => _isSavingAllocation = true);
    try {
      await _adminService.upsertInvestmentAllocation(
        id: _editingAllocationId,
        category: category,
        amount: amount,
        spentAt: _selectedAllocationDate,
        note: note,
      );
      _clearAllocationForm();
      await _loadInvestmentData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editingAllocationId == null
                ? 'Harcama kaydedildi.'
                : 'Harcama güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) {
        setState(() => _isSavingAllocation = false);
      }
    }
  }

  void _startEditingAllocation(AdminInvestmentAllocation allocation) {
    setState(() {
      _editingAllocationId = allocation.id;
      _allocationCategoryController.text = allocation.category;
      _allocationAmountController.text = allocation.amount.toStringAsFixed(0);
      _allocationNoteController.text = allocation.note;
      _selectedAllocationDate = allocation.spentAt;
    });
  }

  void _clearAllocationForm() {
    setState(() {
      _editingAllocationId = null;
      _allocationCategoryController.clear();
      _allocationAmountController.clear();
      _allocationNoteController.clear();
      _selectedAllocationDate = DateTime.now();
    });
  }

  Future<void> _deleteAllocation(AdminInvestmentAllocation allocation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Harcama kalemi silinsin mi?'),
          content: Text(
            '${allocation.category} için girilen ${_formatCurrency(allocation.amount)} kaydı silinecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await _adminService.deleteInvestmentAllocation(allocation.id);
      if (_editingAllocationId == allocation.id) {
        _clearAllocationForm();
      }
      await _loadInvestmentData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Harcama kalemi silindi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _exportFinanceReportCsv() async {
    final bundle = _analyticsBundle;
    final buffer = StringBuffer()
      ..writeln('metrik,bu_donem,onceki_donem,degisim_yuzde,durum');
    for (final row in bundle.summaryRows) {
      buffer.writeln(
        '"${row.label.replaceAll('"', '""')}",'
        '${row.current.toStringAsFixed(2)},'
        '${row.previous.toStringAsFixed(2)},'
        '${row.changePercent?.toStringAsFixed(1) ?? ''},'
        '"${row.status.replaceAll('"', '""')}"',
      );
    }
    BrowserFileDownload.saveBytes(
      bytes: utf8.encode(buffer.toString()),
      fileName: 'finans-ozet-${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Finans özeti CSV dosyası indiriliyor.')),
    );
  }

  Future<void> _exportInvestmentCsv() async {
    final buffer = StringBuffer()
      ..writeln('tip,kaynak_kategori,tutar,tarih,not');
    for (final entry in _investmentEntries) {
      buffer.writeln(
        'yatirim,"${entry.source.replaceAll('"', '""')}",${entry.amount.toStringAsFixed(2)},${entry.investmentDate.toIso8601String()},""',
      );
    }
    for (final allocation in _investmentAllocations) {
      buffer.writeln(
        'harcama,"${allocation.category.replaceAll('"', '""')}",${allocation.amount.toStringAsFixed(2)},${allocation.spentAt.toIso8601String()},"${allocation.note.replaceAll('"', '""')}"',
      );
    }
    BrowserFileDownload.saveBytes(
      bytes: utf8.encode(buffer.toString()),
      fileName: 'yatirim-finans-${DateTime.now().millisecondsSinceEpoch}.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV dosyası indiriliyor.')));
  }

  Future<void> _deleteInvestmentEntry(AdminInvestmentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yatırım girişi silinsin mi?'),
          content: Text(
            '${entry.source} için girilen ${_formatCurrency(entry.amount)} kaydı silinecek.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await _adminService.deleteInvestmentEntry(entry.id);
      if (_editingInvestmentId == entry.id) {
        _clearInvestmentForm();
      }
      await _loadInvestmentData();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yatırım girişi silindi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  List<AdminFinanceReportHeroMetric> _buildReportHeroMetrics() {
    final metrics = _periodMetrics;
    return [
      AdminFinanceReportHeroMetric(
        label: 'GMV',
        value: _formatCompactCurrency(metrics.gmv),
        accent: const Color(0xFF2563EB),
        subtitle: '${metrics.completedOrders} teslim',
        icon: Icons.storefront_outlined,
      ),
      AdminFinanceReportHeroMetric(
        label: 'Komisyon',
        value: _formatCompactCurrency(metrics.commission),
        accent: const Color(0xFF7C3AED),
        subtitle: 'Varsayılan %${_commissionConfig.defaultPercent.toStringAsFixed(0)}',
        icon: Icons.percent,
      ),
      AdminFinanceReportHeroMetric(
        label: 'Reklam Geliri',
        value: _formatCompactCurrency(metrics.adRevenue),
        accent: const Color(0xFFDB2777),
        icon: Icons.campaign_outlined,
      ),
      AdminFinanceReportHeroMetric(
        label: 'Net Kâr',
        value: _formatCompactCurrency(metrics.netProfit),
        accent: metrics.netProfit >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
        subtitle: 'Vergi sonrası ${_formatCompactCurrency(metrics.netAfterTax)}',
        icon: Icons.insights_outlined,
      ),
    ];
  }

  List<_FinanceSummaryCard> _buildOperationCards() {
    final cacheKey =
        '$_periodCacheKey|$_openStoreCount|$_commissionConfigVersion';
    if (_operationCardsCacheKey == cacheKey && _operationCardsCache != null) {
      return _operationCardsCache!;
    }

    final metrics = _periodMetrics;
    final previous = _previousPeriodMetrics;

    String trendFor(double current, double prev) =>
        _formatPercent(_growthPercent(current, prev));

    final resolved = [
      _FinanceSummaryCard(
        title: 'Toplam GMV',
        value: _formatCompactCurrency(metrics.gmv),
        subtitle: 'Platformda dönen toplam sipariş hacmi',
        trend: trendFor(metrics.gmv, previous.gmv),
        trendColor: _trendColor(_growthPercent(metrics.gmv, previous.gmv)),
        icon: Icons.storefront_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _FinanceSummaryCard(
        title: 'Kasaya Giren Toplam',
        value: _formatCompactCurrency(metrics.cashIn),
        subtitle: 'Gerçek tahsilat',
        trend: trendFor(metrics.cashIn, previous.cashIn),
        trendColor: _trendColor(_growthPercent(metrics.cashIn, previous.cashIn)),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _FinanceSummaryCard(
        title: 'İBUL Net Geliri',
        value: _formatCompactCurrency(metrics.ibulNetRevenue),
        subtitle: 'Komisyon + reklam + kargo − gider − iade',
        trend: trendFor(metrics.ibulNetRevenue, previous.ibulNetRevenue),
        trendColor: _trendColor(
          _growthPercent(metrics.ibulNetRevenue, previous.ibulNetRevenue),
        ),
        icon: Icons.payments_outlined,
        accent: const Color(0xFF16A34A),
      ),
      _FinanceSummaryCard(
        title: 'Platform Komisyonu',
        value: _formatCompactCurrency(metrics.commission),
        subtitle: 'Teslim edilen siparişlerden alınan komisyon',
        trend: trendFor(metrics.commission, previous.commission),
        trendColor: _trendColor(
          _growthPercent(metrics.commission, previous.commission),
        ),
        icon: Icons.show_chart_rounded,
        accent: const Color(0xFF7C3AED),
      ),
      _FinanceSummaryCard(
        title: 'Reklam Geliri',
        value: _formatCompactCurrency(metrics.adRevenue),
        subtitle: metrics.adRevenue > 0
            ? (_financeSnapshot.adBreakdown.usesPlannedBudgetLabel
                ? 'Planlanan / tahsil edilen gelir'
                : 'Kampanya ödemelerinden gelen gelir')
            : 'Kayıt yok',
        trend: metrics.adRevenue > 0
            ? (_financeSnapshot.adBreakdown.usesPlannedBudgetLabel
                ? 'Planlanan'
                : 'Gerçek veri')
            : '₺0',
        trendColor: const Color(0xFF6B7280),
        icon: Icons.campaign_outlined,
        accent: const Color(0xFFDB2777),
      ),
      _FinanceSummaryCard(
        title: 'Kargo Geliri',
        value: _formatCompactCurrency(metrics.courierRevenue),
        subtitle: metrics.courierRevenue > 0
            ? 'Net kargo geliri (tahsilat − maliyet − sübvansiyon)'
            : 'Kayıt yok',
        trend: trendFor(metrics.courierRevenue, previous.courierRevenue),
        trendColor: _trendColor(
          _growthPercent(metrics.courierRevenue, previous.courierRevenue),
        ),
        icon: Icons.local_shipping_outlined,
        accent: const Color(0xFF0284C7),
      ),
      _FinanceSummaryCard(
        title: 'Satıcı Hakedişi',
        value: _formatCompactCurrency(metrics.sellerPayouts),
        subtitle: metrics.sellerPayouts > 0
            ? 'Dönem net hakediş (GMV − komisyon − iade)'
            : 'Kayıt yok',
        trend: '${_payoutSnapshot.rows.length} satıcı',
        trendColor: const Color(0xFF6D28D9),
        icon: Icons.payments_outlined,
        accent: const Color(0xFF7C3AED),
      ),
      _FinanceSummaryCard(
        title: 'Toplam Gider',
        value: _formatCompactCurrency(metrics.expenses),
        subtitle: metrics.expenses > 0
            ? 'Kayıtlı operasyon giderleri (ödendi)'
            : 'Kayıt yok',
        trend: trendFor(metrics.expenses, previous.expenses),
        trendColor: _trendColor(_growthPercent(metrics.expenses, previous.expenses)),
        icon: Icons.receipt_long_outlined,
        accent: const Color(0xFFEA580C),
      ),
      _FinanceSummaryCard(
        title: 'Net Kâr / Zarar',
        value: _formatCompactCurrency(metrics.netProfit),
        subtitle: 'Platform geliri − giderler',
        trend: metrics.netProfit >= 0 ? 'Pozitif' : 'Zarar',
        trendColor: _trendColor(metrics.netProfit),
        icon: Icons.insights_outlined,
        accent: metrics.netProfit >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
      ),
      _FinanceSummaryCard(
        title: 'İade / İptal Tutarı',
        value: _formatCompactCurrency(metrics.refundAmount),
        subtitle: metrics.refundCount > 0
            ? '${metrics.refundCount} kayıt'
            : 'Kayıt yok',
        trend: metrics.refundCount > 0 ? '${metrics.refundCount} adet' : '₺0',
        trendColor: const Color(0xFFDC2626),
        icon: Icons.undo_outlined,
        accent: const Color(0xFFDC2626),
      ),
      _FinanceSummaryCard(
        title: 'Bekleyen Hakediş',
        value: _formatCompactCurrency(metrics.pendingPayout),
        subtitle: metrics.pendingPayout > 0
            ? 'Henüz ödenmemiş satıcı hakedişi'
            : 'Kayıt yok',
        trend: metrics.pendingPayout > 0 ? 'Bekliyor' : '₺0',
        trendColor: const Color(0xFF6B7280),
        icon: Icons.hourglass_empty_outlined,
        accent: const Color(0xFFF97316),
      ),
      _FinanceSummaryCard(
        title: 'Ortalama Sepet',
        value: _formatCompactCurrency(metrics.averageBasket),
        subtitle: 'Teslim edilen sipariş başına ortalama ciro',
        trend: '${metrics.completedOrders} sipariş',
        trendColor: const Color(0xFF2563EB),
        icon: Icons.shopping_bag_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _FinanceSummaryCard(
        title: 'Tahmini KDV',
        value: _formatCompactCurrency(metrics.estimatedKdv),
        subtitle: 'Platform geliri üzerinden tahmini KDV yükü',
        trend: '%${_commissionConfig.kdvPercent.toStringAsFixed(0)}',
        trendColor: const Color(0xFF6B7280),
        icon: Icons.account_balance_outlined,
        accent: const Color(0xFF0F766E),
      ),
      _FinanceSummaryCard(
        title: 'Devlete Ödenecek',
        value: _formatCompactCurrency(metrics.governmentExpenses),
        subtitle: 'Tahmini vergiler + kayıtlı devlet giderleri',
        trend: trendFor(metrics.governmentExpenses, previous.governmentExpenses),
        trendColor: _trendColor(
          _growthPercent(metrics.governmentExpenses, previous.governmentExpenses),
        ),
        icon: Icons.gavel_outlined,
        accent: const Color(0xFFB45309),
      ),
      _FinanceSummaryCard(
        title: 'Vergi Sonrası Net',
        value: _formatCompactCurrency(metrics.netAfterTax),
        subtitle: 'Net kâr − devlet yükümlülükleri',
        trend: metrics.netAfterTax >= 0 ? 'Pozitif' : 'Zarar',
        trendColor: _trendColor(metrics.netAfterTax),
        icon: Icons.savings_outlined,
        accent: metrics.netAfterTax >= 0
            ? const Color(0xFF15803D)
            : const Color(0xFFDC2626),
      ),
    ];
    _operationCardsCacheKey = cacheKey;
    _operationCardsCache = resolved;
    return resolved;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _localeReadyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_busy_outlined,
                        color: Color(0xFFDC2626),
                        size: 52,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Finans locale verisi yüklenemedi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final density = AdminPanelDensity.fromWidth(constraints.maxWidth);
            return Column(
              children: [
                _buildHeader(density: density),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(density.pagePadding),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _segment == _FinanceSegment.investment
                          ? _buildInvestorDashboard(density: density)
                          : _buildOperationsDashboard(density: density),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader({required AdminPanelDensity density}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        density.pagePadding,
        density.pagePadding,
        density.pagePadding,
        density.isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = density.isCompact || constraints.maxWidth < 900;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                _buildTitleBlock(density: density),
                SizedBox(height: density.sectionGap),
                _buildPeriodSwitch(density: density),
                SizedBox(height: density.gridSpacing),
                _buildSegmentSwitch(density: density),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTitleBlock(density: density)),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildPeriodSwitch(density: density),
                          SizedBox(height: density.gridSpacing),
                          _buildSegmentSwitch(density: density),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBlock({required AdminPanelDensity density}) {
    final metrics = _periodMetrics;
    final statusColor = metrics.ibulNetRevenue >= 0
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Finans',
          style: TextStyle(
            fontSize: density.financeHeaderTitleFontSize,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF111827),
          ),
        ),
        Text(
          'Platform ciroyu, İBUL gelirini, hakedişleri, giderleri ve net nakit etkisini tek ekranda takip edin.',
          maxLines: density.financeHeaderSubtitleMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: density.financeHeaderSubtitleFontSize,
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
        SizedBox(height: density.isCompact ? 6 : 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: density.isCompact ? 8 : 10,
            vertical: density.isCompact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, size: 8, color: statusColor),
              const SizedBox(width: 6),
              Text(
                _segment == _FinanceSegment.investment
                    ? 'Yatırım takibi açık'
                    : 'Finans operasyonu açık',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: density.financeChipFontSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickCustomPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _customPeriodStart ?? DateTime(now.year, now.month - 5, 1),
        end: _customPeriodEnd ?? now,
      ),
      locale: const Locale('tr', 'TR'),
    );
    if (!mounted || range == null) return;
    setState(() {
      _selectedPeriod = _FinancePeriodPreset.custom;
      _customPeriodStart = range.start;
      _customPeriodEnd = range.end;
    });
  }

  Widget _buildPeriodChip({
    required AdminPanelDensity density,
    required String label,
    required _FinancePeriodPreset preset,
    IconData? icon,
  }) {
    final isActive = _selectedPeriod == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(density.financeChipRadius),
      onTap: () async {
        if (preset == _FinancePeriodPreset.custom) {
          await _pickCustomPeriod();
          return;
        }
        if (_selectedPeriod == preset) return;
        setState(() => _selectedPeriod = preset);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: density.financeChipPaddingH,
          vertical: density.financeChipPaddingV,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(density.financeChipRadius),
          border: Border.all(
            color: isActive ? const Color(0xFF111827) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: density.financeSegmentIconSize,
                color: isActive ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w700,
                fontSize: density.financeChipFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSwitch({required AdminPanelDensity density}) {
    final chips = [
      _buildPeriodChip(
        density: density,
        label: '7 Gün',
        preset: _FinancePeriodPreset.days7,
      ),
      _buildPeriodChip(
        density: density,
        label: '30 Gün',
        preset: _FinancePeriodPreset.days30,
      ),
      _buildPeriodChip(
        density: density,
        label: '3 Ay',
        preset: _FinancePeriodPreset.months3,
      ),
      _buildPeriodChip(
        density: density,
        label: '6 Ay',
        preset: _FinancePeriodPreset.months6,
      ),
      _buildPeriodChip(
        density: density,
        label: '12 Ay',
        preset: _FinancePeriodPreset.months12,
      ),
      _buildPeriodChip(
        density: density,
        label: 'Özel Tarih',
        preset: _FinancePeriodPreset.custom,
        icon: Icons.calendar_month_outlined,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: () => _openCommissionSettings(density),
            icon: const Icon(Icons.percent, size: 16),
            label: const Text('Komisyon'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: EdgeInsets.symmetric(
                horizontal: density.financeChipPaddingH + 2,
                vertical: density.financeChipPaddingV,
              ),
            ),
          ),
          SizedBox(width: density.gridSpacing),
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) SizedBox(width: density.gridSpacing),
            chips[i],
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentSwitch({required AdminPanelDensity density}) {
    const segments = <(_FinanceSegment, String, IconData)>[
      (_FinanceSegment.summary, 'Özet', Icons.dashboard_outlined),
      (_FinanceSegment.revenue, 'Gelir', Icons.trending_up_outlined),
      (_FinanceSegment.expense, 'Gider', Icons.receipt_long_outlined),
      (_FinanceSegment.reports, 'Raporlar', Icons.assessment_outlined),
      (_FinanceSegment.investment, 'Yatırım', Icons.insights_outlined),
    ];

    return Container(
      padding: EdgeInsets.all(density.financeSegmentPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: segments.map((entry) {
            final (segment, label, icon) = entry;
            final isActive = _segment == segment;
            return InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (_segment == segment) return;
                setState(() => _segment = segment);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(
                  horizontal: density.financeSegmentButtonPaddingH,
                  vertical: density.financeSegmentButtonPaddingV,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: density.financeSegmentIconSize,
                      color: isActive
                          ? const Color(0xFF111827)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF111827)
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                        fontSize: density.financeSegmentFontSize,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOperationsDashboard({required AdminPanelDensity density}) {
    final metrics = _periodMetrics;
    final segmentKey = 'operations_${_segment.name}';

    if (_segment == _FinanceSegment.expense) {
      return Column(
        key: ValueKey(segmentKey),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFinanceSegmentHeader(
            density: density,
            title: 'Gider Yönetimi',
            subtitle: 'Operasyon giderlerini kaydedin, filtreleyin ve takip edin.',
            periodLabel: _selectedPeriodLabel,
            icon: Icons.receipt_long_outlined,
            accent: const Color(0xFFEA580C),
          ),
          SizedBox(height: density.sectionGap),
          AdminFinanceExpensePanel(
            density: density,
            summary: _expenseSummary,
            expenses: _filteredExpenses,
            isLoading: _isLoadingExpenseData,
            error: _expenseDataError,
            periodLabel: _selectedPeriodLabel,
            categoryFilter: _expenseCategoryFilter,
            statusFilter: _expenseStatusFilter,
            typeFilter: _expenseTypeFilter,
            onCategoryFilterChanged: (value) =>
                setState(() => _expenseCategoryFilter = value),
            onStatusFilterChanged: (value) =>
                setState(() => _expenseStatusFilter = value),
            onTypeFilterChanged: (value) =>
                setState(() => _expenseTypeFilter = value),
            onSaveExpense: _saveAdminExpense,
            onCancelExpense: _cancelAdminExpense,
            formatCurrency: _formatCurrency,
            formatCompactCurrency: _formatCompactCurrency,
            onRetry: _loadExpenseData,
          ),
        ],
      );
    }

    if (_segment == _FinanceSegment.revenue) {
      return Column(
        key: ValueKey(segmentKey),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminFinanceRevenuePanel(
            density: density,
            periodLabel: _selectedPeriodLabel,
            snapshot: _financeSnapshot,
            cargo: _cargoBreakdown,
            payoutSnapshot: _payoutSnapshot,
            revenueSeries: _analyticsBundle.revenueSeries,
            isAutoLoading: _isLoadingOperationsData,
            isPayoutLoading: _isLoadingPayoutData,
            payoutError: _payoutDataError,
            manualSummary: _manualRevenueSummary,
            manualRevenues: _filteredRevenues,
            isManualLoading: _isLoadingRevenueData,
            manualError: _revenueDataError,
            manualCategoryFilter: _revenueCategoryFilter,
            manualStatusFilter: _revenueStatusFilter,
            manualTypeFilter: _revenueTypeFilter,
            onManualCategoryFilterChanged: (value) =>
                setState(() => _revenueCategoryFilter = value),
            onManualStatusFilterChanged: (value) =>
                setState(() => _revenueStatusFilter = value),
            onManualTypeFilterChanged: (value) =>
                setState(() => _revenueTypeFilter = value),
            onSaveRevenue: _saveAdminRevenue,
            onCancelRevenue: _cancelAdminRevenue,
            onManualRetry: _loadRevenueData,
            payoutStatusFilter: _payoutStatusFilter,
            searchQuery: _payoutSearchQuery,
            onPayoutStatusFilterChanged: (value) =>
                setState(() => _payoutStatusFilter = value),
            onSearchChanged: (value) =>
                setState(() => _payoutSearchQuery = value),
            onApprove: _approveSellerPayout,
            onMarkPaid: _markSellerPayoutPaid,
            onDispute: _disputeSellerPayout,
            onCancel: _cancelSellerPayout,
            onPayoutRetry: () async {
              await _loadOperationsData();
              await _loadPayoutData();
            },
            formatCurrency: _formatCurrency,
            formatCompactCurrency: _formatCompactCurrency,
            formatPercent: _formatChangePercent,
          ),
        ],
      );
    }

    if (_segment == _FinanceSegment.summary && _isLoadingOperationsData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_segment == _FinanceSegment.summary &&
        _operationsDataError != null &&
        !_hasAnyFinanceData) {
      return _buildOperationsErrorState();
    }

    if (_segment == _FinanceSegment.reports && _isLoadingOperationsData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      key: ValueKey(segmentKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_segment == _FinanceSegment.summary) ...[
          if (_operationsDataWarnings.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: density.gridSpacing),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Text(
                  _operationsDataWarnings.join(' '),
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          _buildCompactSummaryBand(
            density: density,
            stats: [
              _FinanceHeroStat(label: 'Dönem', value: _selectedPeriodLabel),
              _FinanceHeroStat(
                label: 'Kasaya giriş',
                value: _formatCompactCurrency(metrics.cashIn),
              ),
              _FinanceHeroStat(
                label: 'Net nakit etkisi',
                value: _formatCompactCurrency(metrics.ibulNetRevenue),
              ),
              _FinanceHeroStat(
                label: 'Ortalama sipariş',
                value: _formatCompactCurrency(metrics.averageBasket),
              ),
            ],
          ),
          SizedBox(height: density.sectionGap),
          _buildSummaryGrid(_buildOperationCards(), density: density),
          SizedBox(height: density.sectionGap),
          AdminFinanceAlertsPanel(
            density: density,
            alerts: _analyticsBundle.alerts,
          ),
          SizedBox(height: density.sectionGap),
          AdminFinanceChartsPanel(
            density: density,
            periodLabel: _selectedPeriodLabel,
            cashFlowSeries: _analyticsBundle.cashFlowSeries,
            revenueSeries: _analyticsBundle.revenueSeries,
            expenseSeries: _analyticsBundle.expenseSeries,
            formatCurrency: _formatCurrency,
          ),
          SizedBox(height: density.sectionGap),
          AdminFinanceSummaryTablePanel(
            density: density,
            rows: _analyticsBundle.summaryRows,
            periodLabel: _selectedPeriodLabel,
            formatCurrency: _formatCurrency,
            formatPercent: _formatChangePercent,
          ),
          SizedBox(height: density.sectionGap),
          AdminFinanceCalculatorPanel(
            density: density,
            defaultCommissionPercent: _commissionConfig.defaultPercent,
            defaultKdvPercent: _commissionConfig.kdvPercent,
            formatCurrency: _formatCurrency,
          ),
        ] else if (_segment == _FinanceSegment.reports) ...[
          AdminFinanceReportsPanel(
            density: density,
            bundle: _analyticsBundle,
            periodLabel: _selectedPeriodLabel,
            payoutSnapshot: _payoutSnapshot,
            formatCurrency: _formatCurrency,
            formatPercent: _formatChangePercent,
            onExportCsv: _exportFinanceReportCsv,
            heroMetrics: _buildReportHeroMetrics(),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactSummaryBand({
    required AdminPanelDensity density,
    required List<_FinanceHeroStat> stats,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(density.financeSummaryBandPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(density.financeSummaryBandRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wrap = constraints.maxWidth < 720;
          if (wrap) {
            return Wrap(
              spacing: density.gridSpacing,
              runSpacing: density.gridSpacing,
              children: stats
                  .map((item) => _buildSummaryBandStat(item, density))
                  .toList(),
            );
          }
          return Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0)
                  Container(
                    width: 1,
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: const Color(0xFFE5E7EB),
                  ),
                Expanded(child: _buildSummaryBandStat(stats[i], density)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBandStat(
    _FinanceHeroStat item,
    AdminPanelDensity density,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF6B7280),
            fontSize: density.financeKpiSubtitleFontSize + 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          item.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF111827),
            fontSize: density.financeKpiValueFontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }


  Widget _buildInvestorDashboard({required AdminPanelDensity density}) {
    final remainingBalance = _remainingInvestmentBalance;

    return Column(
      key: const ValueKey('investor_dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminFinanceSegmentHeader(
          density: density,
          title: 'Yatırım Takibi',
          subtitle: 'Yatırım girişleri, harcama kalemleri ve bakiye durumu.',
          icon: Icons.insights_outlined,
          accent: const Color(0xFF6366F1),
        ),
        SizedBox(height: density.sectionGap),
        _buildCompactSummaryBand(
          density: density,
          stats: [
            _FinanceHeroStat(
              label: 'Toplam yatırım',
              value: _formatCompactCurrency(_totalInvestmentReceived),
            ),
            _FinanceHeroStat(
              label: 'Harcanan',
              value: _formatCompactCurrency(_totalInvestmentSpent),
            ),
            _FinanceHeroStat(
              label: 'Kalan bakiye',
              value: _formatCompactCurrency(remainingBalance),
            ),
            _FinanceHeroStat(
              label: 'Giriş sayısı',
              value: '${_investmentEntries.length}',
            ),
          ],
        ),
        SizedBox(height: density.sectionGap),
        if (_isLoadingInvestmentData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_investmentDataError != null)
          _buildInvestmentErrorState()
        else ...[
          _buildSummaryGrid(_buildInvestmentOverviewCards(), density: density),
          SizedBox(height: density.sectionGap),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1220;
              final cardWidth = wide
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildInvestmentEntryCard(),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildInvestmentAllocationEntryCard(),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildInvestmentTimelineCard(),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildInvestmentAllocationChartCard(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1220;
              final cardWidth = wide
                  ? (constraints.maxWidth - 20) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildInvestmentHistoryCard(),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildAllocationHistoryCard(),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildInvestmentErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _investmentDataError ?? 'Yatırım verileri yüklenemedi.',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadInvestmentData,
            child: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationsErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _operationsDataError ?? 'Finans verileri yüklenemedi.',
              style: const TextStyle(
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _loadOperationsData,
            child: const Text('Yeniden Dene'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(
    List<_FinanceSummaryCard> cards, {
    required AdminPanelDensity density,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final localDensity =
            AdminPanelDensity.fromWidth(constraints.maxWidth);
        final columns = localDensity.financeKpiColumns;
        final spacing = localDensity.gridSpacing;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: itemWidth,
                  child: _buildSummaryCard(card, density: localDensity),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard(
    _FinanceSummaryCard card, {
    required AdminPanelDensity density,
  }) {
    return Container(
      padding: EdgeInsets.all(density.financeKpiCardPadding),
      constraints: BoxConstraints(
        minHeight: density.financeKpiMinHeight,
        maxHeight: density.financeKpiMaxHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(density.financeKpiIconPadding),
            decoration: BoxDecoration(
              color: card.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              card.icon,
              color: card.accent,
              size: density.financeKpiIconSize,
            ),
          ),
          SizedBox(width: density.isCompact ? 7 : 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        card.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: density.financeKpiTitleFontSize,
                          color: const Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      card.trend,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: card.trendColor,
                        fontWeight: FontWeight.w700,
                        fontSize: density.financeKpiTrendFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  card.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: density.financeKpiValueFontSize,
                    color: const Color(0xFF111827),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  card.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF4B5563),
                    fontSize: density.financeKpiSubtitleFontSize,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Legacy chart card kept for reference; replaced by AdminFinanceChartsPanel.
  // ignore: unused_element
  Widget _buildCashFlowCard({required AdminPanelDensity density}) {
    final points = _selectedChartPoints;
    final grossRevenue = points.fold<double>(
      0,
      (sum, item) => sum + item.grossRevenue,
    );
    final netRevenue = points.fold<double>(
      0,
      (sum, item) => sum + item.netRevenue,
    );
    final totalExpense = points.fold<double>(
      0,
      (sum, item) => sum + item.expense,
    );
    final courierEarnings = points.fold<double>(
      0,
      (sum, item) => sum + item.courierEarnings,
    );
    final maxValue = points.fold<double>(
      1,
      (currentMax, item) =>
          item.netRevenue > currentMax ? item.netRevenue : currentMax,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              density.financeSectionPadding,
              density.financeSectionPadding,
              density.financeSectionPadding,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kazanç Performansı',
                        style: TextStyle(
                          color: const Color(0xFF1F2937),
                          fontSize: density.financeSectionTitleFontSize,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatChartRangeCaption(points),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: density.financeSectionSubtitleFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildChartRangeChip(
                      density: density,
                      label: '7 Gün',
                      preset: _FinanceChartRange.last7Days,
                    ),
                    _buildChartRangeChip(
                      density: density,
                      label: '30 Gün',
                      preset: _FinanceChartRange.last30Days,
                    ),
                    _buildChartRangeChip(
                      density: density,
                      label: '3 Ay',
                      preset: _FinanceChartRange.last3Months,
                    ),
                    _buildChartRangeChip(
                      density: density,
                      label: '6 Ay',
                      preset: _FinanceChartRange.last6Months,
                    ),
                    _buildChartRangeChip(
                      density: density,
                      label: 'Tarih',
                      preset: _FinanceChartRange.custom,
                      icon: Icons.calendar_month_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              density.financeSectionPadding,
              12,
              density.financeSectionPadding,
              12,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final metrics = [
                  _buildPerformanceMetricInline(
                    'Brüt Gelir',
                    _formatCurrency(grossRevenue),
                    const Color(0xFF7C3AED),
                    density,
                  ),
                  _buildPerformanceMetricInline(
                    'Net Kazanç',
                    _formatCurrency(netRevenue),
                    const Color(0xFF10B981),
                    density,
                  ),
                  _buildPerformanceMetricInline(
                    'Gider',
                    _formatCurrency(totalExpense),
                    const Color(0xFFEF4444),
                    density,
                  ),
                  _buildPerformanceMetricInline(
                    'Kurye Kazancı',
                    _formatCurrency(courierEarnings),
                    const Color(0xFF2563EB),
                    density,
                  ),
                ];

                if (compact) {
                  return Wrap(spacing: 12, runSpacing: 10, children: metrics);
                }

                return Row(
                  children: [
                    metrics[0],
                    _buildPerformanceMetricDivider(),
                    metrics[1],
                    _buildPerformanceMetricDivider(),
                    metrics[2],
                    _buildPerformanceMetricDivider(),
                    metrics[3],
                  ],
                );
              },
            ),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              density.financeSectionPadding,
              14,
              density.financeSectionPadding,
              14,
            ),
            child: Column(
              children: [
                SizedBox(
                  height: density.financeChartHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 52,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildPerformanceYAxisLabels(maxValue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _FinanceAreaChartPainter(
                                  points: points,
                                  lineColor: const Color(0xFF7C3AED),
                                  maxValue: maxValue,
                                ),
                              ),
                            ),
                            if (points.isEmpty)
                              const Center(
                                child: Text(
                                  'Bu dönem için gösterilecek veri yok.',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _buildXAxisIndices(points).map((index) {
                    return Expanded(
                      child: Text(
                        points[index].axisLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: index == _buildXAxisIndices(points).first
                            ? TextAlign.left
                            : index == _buildXAxisIndices(points).last
                            ? TextAlign.right
                            : TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7A7A7A),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartRangeChip({
    required AdminPanelDensity density,
    required String label,
    required _FinanceChartRange preset,
    IconData? icon,
  }) {
    final isSelected = _selectedChartRange == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(density.financeChipRadius),
      onTap: () {
        if (_selectedChartRange == preset) return;
        setState(() => _selectedChartRange = preset);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: density.financeChipPaddingH,
          vertical: density.financeChipPaddingV,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(density.financeChipRadius),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD7DEE8)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: density.financeSegmentIconSize,
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF475569),
                fontSize: density.financeChipFontSize,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetricInline(
    String label,
    String value,
    Color valueColor,
    AdminPanelDensity density,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: density.financeKpiSubtitleFontSize + 2,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: density.financeKpiValueFontSize - 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricDivider() {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: const Color(0xFFE5E7EB),
    );
  }

  List<_FinanceSummaryCard> _buildInvestmentOverviewCards() {
    final invested = _totalInvestmentReceived;
    final spent = _totalInvestmentSpent;
    final remaining = _remainingInvestmentBalance;
    final deploymentRate = invested == 0 ? 0.0 : (spent / invested) * 100;
    final allocationCount = _investmentAllocations.length;

    return [
      _FinanceSummaryCard(
        title: 'Toplam Gelen Yatırım',
        value: _formatCompactCurrency(invested),
        subtitle: 'Yatırım turlarından ve ek girişlerden gelen toplam tutar',
        trend: '${_investmentEntries.length} giriş',
        trendColor: const Color(0xFF2563EB),
        icon: Icons.savings_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _FinanceSummaryCard(
        title: 'Toplam Harcama',
        value: _formatCompactCurrency(spent),
        subtitle: 'Yatırım fonundan yapılan toplam kullanım',
        trend: _formatPercent(deploymentRate),
        trendColor: const Color(0xFFEA580C),
        icon: Icons.account_balance_outlined,
        accent: const Color(0xFFEA580C),
      ),
      _FinanceSummaryCard(
        title: 'Kalan Yatırım Bakiyesi',
        value: _formatCompactCurrency(remaining),
        subtitle: 'Henüz tahsis edilmemiş veya harcanmamış bakiye',
        trend: remaining >= 0 ? 'Bakiye pozitif' : 'Aşım var',
        trendColor: remaining >= 0
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF16A34A),
      ),
      _FinanceSummaryCard(
        title: 'Harcama Kalemi',
        value: '$allocationCount',
        subtitle: 'Yatırımın dağıtıldığı toplam harcama satırı',
        trend: _investmentAllocationBreakdown.isEmpty
            ? 'Veri yok'
            : _investmentAllocationBreakdown.first.label,
        trendColor: const Color(0xFF7C3AED),
        icon: Icons.pie_chart_outline,
        accent: const Color(0xFF7C3AED),
      ),
    ];
  }

  Widget _buildInvestmentEntryCard() {
    return _buildPanel(
      title: _editingInvestmentId == null
          ? 'Gelen yatırımı ekle'
          : 'Yatırım girişini düzenle',
      subtitle:
          'Yeni yatırım, köprü turu veya melek yatırım girişini buradan yaz.',
      child: Column(
        children: [
          _buildLabeledField(
            label: 'Yatırım kaynağı',
            child: TextField(
              controller: _investmentSourceController,
              decoration: _inputDecoration('Örn. Pre-seed turu'),
            ),
          ),
          const SizedBox(height: 14),
          _buildLabeledField(
            label: 'Yatırım tutarı',
            child: TextField(
              controller: _investmentAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration('Örn. 2500000'),
            ),
          ),
          const SizedBox(height: 14),
          _buildDateSelector(
            label: 'Yatırım tarihi',
            value: _selectedInvestmentDate,
            onTap: _pickInvestmentDate,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingInvestment ? null : _addInvestmentEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isSavingInvestment
                    ? 'Kaydediliyor...'
                    : _editingInvestmentId == null
                    ? 'Yatırımı Kaydet'
                    : 'Güncellemeyi Kaydet',
              ),
            ),
          ),
          if (_editingInvestmentId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearInvestmentForm,
                child: const Text('Düzenlemeyi İptal Et'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestmentAllocationEntryCard() {
    return _buildPanel(
      title: _editingAllocationId == null
          ? 'Yatırım harcamasını ekle'
          : 'Harcama kalemini düzenle',
      subtitle:
          'Gelen yatırımın hangi alana harcandığını kategori bazında işle.',
      child: Column(
        children: [
          _buildLabeledField(
            label: 'Harcama alanı',
            child: TextField(
              controller: _allocationCategoryController,
              decoration: _inputDecoration('Örn. Pazarlama'),
            ),
          ),
          const SizedBox(height: 14),
          _buildLabeledField(
            label: 'Harcama tutarı',
            child: TextField(
              controller: _allocationAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _inputDecoration('Örn. 480000'),
            ),
          ),
          const SizedBox(height: 14),
          _buildLabeledField(
            label: 'Not',
            child: TextField(
              controller: _allocationNoteController,
              maxLines: 2,
              decoration: _inputDecoration(
                'Örn. Influencer ve lansman bütçesi',
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildDateSelector(
            label: 'Harcama tarihi',
            value: _selectedAllocationDate,
            onTap: _pickAllocationDate,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingAllocation ? null : _addAllocationEntry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _isSavingAllocation
                    ? 'Kaydediliyor...'
                    : _editingAllocationId == null
                    ? 'Harcamayı Kaydet'
                    : 'Güncellemeyi Kaydet',
              ),
            ),
          ),
          if (_editingAllocationId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _clearAllocationForm,
                child: const Text('Düzenlemeyi İptal Et'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvestmentTimelineCard() {
    final points = _investmentTimelinePoints;
    final maxValue = points.fold<double>(
      1,
      (currentMax, item) => item.value > currentMax ? item.value : currentMax,
    );
    return _buildPanel(
      title: 'Yatırım girişi grafiği',
      subtitle:
          'Gelen yatırım girişleri birikimli olarak çizilir; yeni yatırım eklendikçe grafik güncellenir.',
      child: Column(
        children: [
          Row(
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _investmentFilterOptions.map((months) {
                  final isSelected = _selectedInvestmentFilterMonths == months;
                  final label = months == 0 ? 'Tümü' : '$months Ay';
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      if (_selectedInvestmentFilterMonths == months) return;
                      setState(() => _selectedInvestmentFilterMonths = months);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF111827)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF111827)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _exportInvestmentCsv,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('CSV Dışa Aktar'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 260,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(5, (index) {
                      final step = 4 - index;
                      final value = (maxValue / 4) * step;
                      return Text(
                        _formatChartAxisValue(value),
                        style: const TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 12,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: points.isEmpty
                      ? const Center(
                          child: Text(
                            'Seçili ay filtresinde yatırım verisi yok',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : CustomPaint(
                          painter: _InvestmentLineChartPainter(
                            points: points,
                            lineColor: const Color(0xFF2563EB),
                            maxValue: maxValue,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: points
                .map(
                  (point) => Expanded(
                    child: Text(
                      point.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7A7A7A),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentAllocationChartCard() {
    final rows = _investmentAllocationBreakdown;
    return _buildPanel(
      title: 'Yatırım nerelere harcandı?',
      subtitle:
          'Harcama kategorileri toplam yatırım kullanımına göre otomatik dağıtılır.',
      child: Column(
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.label,
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(row.amount),
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: row.share,
                        minHeight: 12,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation<Color>(row.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '%${(row.share * 100).toStringAsFixed(1)} pay',
                      style: TextStyle(
                        color: row.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInvestmentHistoryCard() {
    final entries = [..._investmentEntries]
      ..sort((a, b) => b.investmentDate.compareTo(a.investmentDate));
    final formatter = DateFormat('d MMM yyyy', 'tr_TR');
    return _buildPanel(
      title: 'Yatırım geçmişi',
      subtitle:
          'Eklenen yatırım girişleri burada kronolojik olarak tutulur. Düzenle veya sil.',
      child: Column(
        children: entries
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.source,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatter.format(entry.investmentDate),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCurrency(entry.amount),
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _startEditingInvestment(entry),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Düzenle',
                        ),
                        IconButton(
                          onPressed: () => _deleteInvestmentEntry(entry),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Sil',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildAllocationHistoryCard() {
    final entries = [..._investmentAllocations]
      ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
    final formatter = DateFormat('d MMM yyyy', 'tr_TR');
    return _buildPanel(
      title: 'Harcama geçmişi',
      subtitle:
          'Yatırım fonundan yapılan harcamalar açıklamalarıyla görünür. Düzenle veya sil.',
      child: Column(
        children: entries
            .map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDD5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.outbox_outlined,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.category,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${formatter.format(entry.spentAt)}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatCurrency(entry.amount),
                            style: const TextStyle(
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          onPressed: () => _startEditingAllocation(entry),
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Düzenle',
                        ),
                        IconButton(
                          onPressed: () => _deleteAllocation(entry),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFDC2626),
                          ),
                          tooltip: 'Sil',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB)),
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return _buildLabeledField(
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF64748B),
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('d MMM yyyy', 'tr_TR').format(value),
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

enum _FinanceSegment { summary, revenue, expense, reports, investment }

enum _FinancePeriodPreset {
  days7,
  days30,
  months3,
  months6,
  months12,
  custom,
}

enum _FinanceChartRange {
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  custom,
}

class _PeriodFinanceMetrics {
  const _PeriodFinanceMetrics({
    required this.gmv,
    required this.cashIn,
    required this.ibulNetRevenue,
    required this.commission,
    required this.adRevenue,
    required this.courierRevenue,
    required this.sellerPayouts,
    required this.expenses,
    required this.netProfit,
    required this.refundAmount,
    required this.refundCount,
    required this.pendingPayout,
    required this.averageBasket,
    required this.completedOrders,
    required this.estimatedKdv,
    required this.governmentExpenses,
    required this.netAfterTax,
  });

  final double gmv;
  final double cashIn;
  final double ibulNetRevenue;
  final double commission;
  final double adRevenue;
  final double courierRevenue;
  final double sellerPayouts;
  final double expenses;
  final double netProfit;
  final double refundAmount;
  final int refundCount;
  final double pendingPayout;
  final double averageBasket;
  final int completedOrders;
  final double estimatedKdv;
  final double governmentExpenses;
  final double netAfterTax;
}

class _FinanceMonthData {
  const _FinanceMonthData({
    required this.periodStart,
    required this.label,
    required this.gmvCollected,
    required this.commissionRevenue,
    required this.courierRevenue,
    required this.sellerPayouts,
    required this.totalExpenses,
    required this.completedOrders,
    required this.activeStores,
  });

  final DateTime periodStart;
  final String label;
  final double gmvCollected;
  final double commissionRevenue;
  final double courierRevenue;
  final double sellerPayouts;
  final double totalExpenses;
  final int completedOrders;
  final int activeStores;

  double get platformRevenue => commissionRevenue + courierRevenue;
  double get cashIn => gmvCollected + courierRevenue;
  double get cashOut => sellerPayouts + totalExpenses;
  double get netCashflow => cashIn - cashOut;
  double get netProfit => platformRevenue - totalExpenses;
}

class _FinanceSummaryCard {
  const _FinanceSummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.trend,
    required this.trendColor,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final String trend;
  final Color trendColor;
  final IconData icon;
  final Color accent;
}

class _FinanceHeroStat {
  const _FinanceHeroStat({required this.label, required this.value});

  final String label;
  final String value;
}

class _FinanceChartPoint {
  const _FinanceChartPoint({
    required this.date,
    required this.axisLabel,
    required this.grossRevenue,
    required this.netRevenue,
    required this.expense,
    required this.courierEarnings,
  });

  final DateTime date;
  final String axisLabel;
  final double grossRevenue;
  final double netRevenue;
  final double expense;
  final double courierEarnings;
}

class _InvestmentTimelinePoint {
  const _InvestmentTimelinePoint({required this.label, required this.value});

  final String label;
  final double value;
}

class _InvestmentBreakdownRow {
  const _InvestmentBreakdownRow({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
  });

  final String label;
  final double amount;
  final double share;
  final Color color;
}

class _FinanceAreaChartPainter extends CustomPainter {
  const _FinanceAreaChartPainter({
    required this.points,
    required this.lineColor,
    required this.maxValue,
  });

  final List<_FinanceChartPoint> points;
  final Color lineColor;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = points.length == 1
        ? size.width
        : size.width / (points.length - 1);
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = points.length == 1 ? size.width / 2 : stepX * i;
      final y =
          size.height -
          ((point.netRevenue / safeMax).clamp(0.0, 1.0) * (size.height - 20)) -
          10;
      offsets.add(Offset(x, y));
    }

    final linePath = ui.Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = ui.Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.18),
          lineColor.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, strokePaint);

    final pointPaint = Paint()..color = lineColor;
    for (final offset in offsets) {
      canvas.drawCircle(
        offset,
        7,
        Paint()..color = lineColor.withValues(alpha: 0.12),
      );
      canvas.drawCircle(offset, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceAreaChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.maxValue != maxValue;
  }
}

class _InvestmentLineChartPainter extends CustomPainter {
  const _InvestmentLineChartPainter({
    required this.points,
    required this.lineColor,
    required this.maxValue,
  });

  final List<_InvestmentTimelinePoint> points;
  final Color lineColor;
  final double maxValue;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = size.height * (i / gridLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (points.isEmpty) return;

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = points.length == 1
        ? size.width
        : size.width / (points.length - 1);
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = points.length == 1 ? size.width / 2 : stepX * i;
      final y =
          size.height -
          ((point.value / safeMax).clamp(0.0, 1.0) * (size.height - 20)) -
          10;
      offsets.add(Offset(x, y));
    }

    final linePath = ui.Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final fillPath = ui.Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: 0.18),
          lineColor.withValues(alpha: 0.03),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, strokePaint);

    final pointPaint = Paint()..color = lineColor;
    for (final offset in offsets) {
      canvas.drawCircle(
        offset,
        7,
        Paint()..color = lineColor.withValues(alpha: 0.12),
      );
      canvas.drawCircle(offset, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InvestmentLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.maxValue != maxValue;
  }
}
