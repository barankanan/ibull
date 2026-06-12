import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../services/admin_service.dart';
import '../../utils/browser_file_download.dart';

class FinanceAdminPage extends StatefulWidget {
  const FinanceAdminPage({super.key});

  @override
  State<FinanceAdminPage> createState() => _FinanceAdminPageState();
}

class _FinanceAdminPageState extends State<FinanceAdminPage> {
  static const double _commissionRate = 0.15;
  static const List<int> _periodOptions = [3, 6, 12];
  static const List<int> _investmentFilterOptions = [3, 6, 12, 0];
  static const String _financeLocale = 'tr_TR';

  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: _financeLocale,
    symbol: '₺',
    decimalDigits: 0,
  );
  final AdminService _adminService = AdminService();
  late final Future<void> _localeReadyFuture;

  _FinanceViewMode _viewMode = _FinanceViewMode.operations;
  int _selectedPeriodMonths = 6;
  _FinanceChartRange _selectedChartRange = _FinanceChartRange.last30Days;
  int _selectedInvestmentFilterMonths = 12;
  List<AdminFinanceOrderItem> _financeOrderItems = const [];
  List<AdminFinanceOrder> _financeOrders = const [];
  int _openStoreCount = 0;
  bool _isLoadingOperationsData = true;
  String? _operationsDataError;
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
  bool _isLoadingInvestmentData = true;
  bool _isSavingInvestment = false;
  bool _isSavingAllocation = false;
  String? _investmentDataError;
  String? _editingInvestmentId;
  String? _editingAllocationId;
  int _operationsDataVersion = 0;
  int _investmentDataVersion = 0;
  String? _allFinanceDataCacheKey;
  List<_FinanceMonthData>? _allFinanceDataCache;
  String? _dailyFinanceSeriesCacheKey;
  List<_FinanceChartPoint>? _dailyFinanceSeriesCache;
  String? _visibleMonthsCacheKey;
  List<_FinanceMonthData>? _visibleMonthsCache;
  String? _previousVisibleMonthsCacheKey;
  List<_FinanceMonthData>? _previousVisibleMonthsCache;
  String? _visibleAllocationsCacheKey;
  List<AdminInvestmentAllocation>? _visibleAllocationsCache;
  String? _investmentTimelinePointsCacheKey;
  List<_InvestmentTimelinePoint>? _investmentTimelinePointsCache;
  String? _investmentAllocationBreakdownCacheKey;
  List<_InvestmentBreakdownRow>? _investmentAllocationBreakdownCache;
  String? _operationCardsCacheKey;
  List<_FinanceSummaryCard>? _operationCardsCache;
  String? _revenueSourcesCacheKey;
  List<_FinanceBreakdownRow>? _revenueSourcesCache;
  String? _expenseSourcesCacheKey;
  List<_FinanceBreakdownRow>? _expenseSourcesCache;
  String? _payoutTimelineCacheKey;
  List<_FinanceTimelineItem>? _payoutTimelineCache;
  String? _operationalInsightsCacheKey;
  List<_FinanceInsightItem>? _operationalInsightsCache;

  @override
  void initState() {
    super.initState();
    _localeReadyFuture = initializeDateFormatting(_financeLocale);
    _loadOperationsData();
    _loadInvestmentData();
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

  List<_FinanceMonthData> get _visibleMonths {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths';
    if (_visibleMonthsCacheKey == cacheKey && _visibleMonthsCache != null) {
      return _visibleMonthsCache!;
    }

    final allFinanceData = _allFinanceData;
    final startIndex = math.max(
      0,
      allFinanceData.length - _selectedPeriodMonths,
    );
    final resolved = allFinanceData.sublist(startIndex);
    _visibleMonthsCacheKey = cacheKey;
    _visibleMonthsCache = resolved;
    return resolved;
  }

  List<_FinanceMonthData> get _previousVisibleMonths {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths';
    if (_previousVisibleMonthsCacheKey == cacheKey &&
        _previousVisibleMonthsCache != null) {
      return _previousVisibleMonthsCache!;
    }

    final allFinanceData = _allFinanceData;
    final currentStartIndex = math.max(
      0,
      allFinanceData.length - _selectedPeriodMonths,
    );
    final previousStartIndex = math.max(
      0,
      currentStartIndex - _selectedPeriodMonths,
    );
    final resolved = allFinanceData.sublist(
      previousStartIndex,
      currentStartIndex,
    );
    _previousVisibleMonthsCacheKey = cacheKey;
    _previousVisibleMonthsCache = resolved;
    return resolved;
  }

  double _sumBy(double Function(_FinanceMonthData item) selector) {
    return _visibleMonths.fold(0, (sum, item) => sum + selector(item));
  }

  int _sumIntBy(int Function(_FinanceMonthData item) selector) {
    return _visibleMonths.fold(0, (sum, item) => sum + selector(item));
  }

  double _previousSumBy(double Function(_FinanceMonthData item) selector) {
    return _previousVisibleMonths.fold(0, (sum, item) => sum + selector(item));
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
    final cacheKey = '$_operationsDataVersion|$_investmentDataVersion';
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
    for (final allocation in _investmentAllocations) {
      final key = _bucketKey(allocation.spentAt);
      expensesByMonth.update(
        key,
        (value) => value + allocation.amount,
        ifAbsent: () => allocation.amount,
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
          final commission = gross * _commissionRate;
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
    final cacheKey = '$_operationsDataVersion|$_investmentDataVersion';
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
    for (final allocation in _investmentAllocations) {
      final day = _dayStart(allocation.spentAt);
      if (day.isBefore(startDate)) continue;
      final key = _dayBucketKey(day);
      expenseByDay.update(
        key,
        (value) => value + allocation.amount,
        ifAbsent: () => allocation.amount,
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
      final commissionRevenue = grossOrderFlow * _commissionRate;
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

  List<AdminInvestmentAllocation> get _visibleAllocations {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths';
    if (_visibleAllocationsCacheKey == cacheKey &&
        _visibleAllocationsCache != null) {
      return _visibleAllocationsCache!;
    }

    final visibleKeys = _visibleMonths
        .map((item) => _bucketKey(item.periodStart))
        .toSet();
    final resolved = _investmentAllocations
        .where((allocation) {
          return visibleKeys.contains(_bucketKey(allocation.spentAt));
        })
        .toList(growable: false);
    _visibleAllocationsCacheKey = cacheKey;
    _visibleAllocationsCache = resolved;
    return resolved;
  }

  Future<void> _loadOperationsData() async {
    setState(() {
      _isLoadingOperationsData = true;
      _operationsDataError = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _adminService.getFinanceOrderItems(from: _operationsStartDate),
        _adminService.getFinanceOrders(from: _operationsStartDate),
        _adminService.getOpenStoreCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _financeOrderItems = results[0] as List<AdminFinanceOrderItem>;
        _financeOrders = results[1] as List<AdminFinanceOrder>;
        _openStoreCount = results[2] as int;
        _operationsDataVersion++;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _operationsDataError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingOperationsData = false);
      }
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

  List<_FinanceSummaryCard> _buildOperationCards() {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths|$_openStoreCount';
    if (_operationCardsCacheKey == cacheKey && _operationCardsCache != null) {
      return _operationCardsCache!;
    }

    final cashIn = _sumBy((item) => item.cashIn);
    final platformRevenue = _sumBy((item) => item.platformRevenue);
    final sellerPayouts = _sumBy((item) => item.sellerPayouts);
    final expenses = _sumBy((item) => item.totalExpenses);
    final netCashflow = _sumBy((item) => item.netCashflow);
    final courierRevenue = _sumBy((item) => item.courierRevenue);
    final previousRevenue = _previousSumBy((item) => item.platformRevenue);
    final previousExpenses = _previousSumBy((item) => item.totalExpenses);
    final previousCourierRevenue = _previousSumBy(
      (item) => item.courierRevenue,
    );

    final resolved = [
      _FinanceSummaryCard(
        title: 'Kasaya Giren Toplam',
        value: _formatCompactCurrency(cashIn),
        subtitle: 'Sipariş tahsilatı ve kargo/kurye gelirinin toplamı',
        trend: _formatPercent(
          _growthPercent(cashIn, _previousSumBy((item) => item.cashIn)),
        ),
        trendColor: _trendColor(
          _growthPercent(cashIn, _previousSumBy((item) => item.cashIn)),
        ),
        icon: Icons.account_balance_wallet_outlined,
        accent: const Color(0xFF2563EB),
      ),
      _FinanceSummaryCard(
        title: 'Platform Geliri',
        value: _formatCompactCurrency(platformRevenue),
        subtitle: 'Sipariş komisyonu ve kargo/kurye tahsilatı',
        trend: _formatPercent(_growthPercent(platformRevenue, previousRevenue)),
        trendColor: _trendColor(
          _growthPercent(platformRevenue, previousRevenue),
        ),
        icon: Icons.show_chart_rounded,
        accent: const Color(0xFF0F766E),
      ),
      _FinanceSummaryCard(
        title: 'Satıcı Hakedişi',
        value: _formatCompactCurrency(sellerPayouts),
        subtitle: 'Teslim edilen siparişlerden satıcıya kalan toplam pay',
        trend: '$_openStoreCount açık mağaza',
        trendColor: const Color(0xFF6D28D9),
        icon: Icons.payments_outlined,
        accent: const Color(0xFF7C3AED),
      ),
      _FinanceSummaryCard(
        title: 'Toplam Gider',
        value: _formatCompactCurrency(expenses),
        subtitle: 'Kayıt altına alınan yatırım ve operasyon giderleri',
        trend: _formatPercent(_growthPercent(expenses, previousExpenses)),
        trendColor: _trendColor(_growthPercent(expenses, previousExpenses)),
        icon: Icons.receipt_long_outlined,
        accent: const Color(0xFFEA580C),
      ),
      _FinanceSummaryCard(
        title: 'Net Nakit Etkisi',
        value: _formatCompactCurrency(netCashflow),
        subtitle: 'Kasaya girişler eksi hakediş ve giderler',
        trend: netCashflow >= 0 ? 'Pozitif nakit' : 'Denge dışı',
        trendColor: _trendColor(netCashflow),
        icon: Icons.insights_outlined,
        accent: const Color(0xFF16A34A),
      ),
      _FinanceSummaryCard(
        title: 'Kurye / Kargo Geliri',
        value: _formatCompactCurrency(courierRevenue),
        subtitle: 'Teslimat akışında tahsil edilen kargo veya kurye tutarı',
        trend: _formatPercent(
          _growthPercent(courierRevenue, previousCourierRevenue),
        ),
        trendColor: _trendColor(
          _growthPercent(courierRevenue, previousCourierRevenue),
        ),
        icon: Icons.local_shipping_outlined,
        accent: const Color(0xFF2563EB),
      ),
    ];
    _operationCardsCacheKey = cacheKey;
    _operationCardsCache = resolved;
    return resolved;
  }

  List<_FinanceBreakdownRow> _buildRevenueSources() {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths';
    if (_revenueSourcesCacheKey == cacheKey && _revenueSourcesCache != null) {
      return _revenueSourcesCache!;
    }
    if (_visibleMonths.isEmpty) return const [];
    final start = _visibleMonths.first.periodStart;
    final end = DateTime(
      _visibleMonths.last.periodStart.year,
      _visibleMonths.last.periodStart.month + 1,
      1,
    );
    final totals = <String, double>{};
    final counts = <String, int>{};
    for (final item in _financeOrderItems) {
      if (!_isDeliveredStatus(item.status)) continue;
      if (item.createdAt.isBefore(start) || !item.createdAt.isBefore(end)) {
        continue;
      }
      final label = item.storeName.trim().isNotEmpty
          ? item.storeName.trim()
          : 'Bilinmeyen mağaza';
      totals.update(
        label,
        (value) => value + item.totalPrice,
        ifAbsent: () => item.totalPrice,
      );
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }
    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    final colors = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF0F766E),
      const Color(0xFFEA580C),
      const Color(0xFFDB2777),
    ];
    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final resolved = List.generate(math.min(rows.length, 5), (index) {
      final row = rows[index];
      final orderCount = counts[row.key] ?? 0;
      return _FinanceBreakdownRow(
        label: row.key,
        amount: row.value,
        share: total == 0 ? 0 : row.value / total,
        note: '$orderCount teslim sipariş kalemi',
        color: colors[index % colors.length],
      );
    });
    _revenueSourcesCacheKey = cacheKey;
    _revenueSourcesCache = resolved;
    return resolved;
  }

  List<_FinanceBreakdownRow> _buildExpenseSources() {
    final cacheKey =
        '$_investmentDataVersion|$_selectedPeriodMonths|${_visibleAllocations.length}';
    if (_expenseSourcesCacheKey == cacheKey && _expenseSourcesCache != null) {
      return _expenseSourcesCache!;
    }
    final totals = <String, double>{};
    for (final allocation in _visibleAllocations) {
      final label = allocation.category.trim().isEmpty
          ? 'Kategori girilmemiş'
          : allocation.category.trim();
      totals.update(
        label,
        (value) => value + allocation.amount,
        ifAbsent: () => allocation.amount,
      );
    }
    final total = totals.values.fold<double>(0, (sum, value) => sum + value);
    final colors = <Color>[
      const Color(0xFFEA580C),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
      const Color(0xFF4F46E5),
      const Color(0xFF0F766E),
      const Color(0xFF2563EB),
    ];
    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final resolved = List.generate(rows.length, (index) {
      final row = rows[index];
      return _FinanceBreakdownRow(
        label: row.key,
        amount: row.value,
        share: total == 0 ? 0 : row.value / total,
        note: 'Admin tarafinda kaydedilen gider kategorisi',
        color: colors[index % colors.length],
      );
    });
    _expenseSourcesCacheKey = cacheKey;
    _expenseSourcesCache = resolved;
    return resolved;
  }

  List<_FinanceTimelineItem> _buildPayoutTimeline() {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths';
    if (_payoutTimelineCacheKey == cacheKey && _payoutTimelineCache != null) {
      return _payoutTimelineCache!;
    }
    final totalCommission = _sumBy((item) => item.commissionRevenue);
    final totalPayout = _sumBy((item) => item.sellerPayouts);
    final totalExpenses = _sumBy((item) => item.totalExpenses);
    final courierRevenue = _sumBy((item) => item.courierRevenue);
    final deliveredOrders = _sumIntBy((item) => item.completedOrders);
    final resolved = [
      _FinanceTimelineItem(
        title: 'Gerçekleşen satıcı hakedişi',
        subtitle: '$deliveredOrders teslim siparişten hesaplandı',
        amount: totalPayout,
        status: 'Gerçek veri',
        color: const Color(0xFF7C3AED),
        icon: Icons.payments_outlined,
      ),
      _FinanceTimelineItem(
        title: 'Platform komisyonu',
        subtitle: 'Teslim edilen siparişlerin %15 komisyonu',
        amount: totalCommission,
        status: 'Gerçek veri',
        color: const Color(0xFF16A34A),
        icon: Icons.show_chart_rounded,
      ),
      _FinanceTimelineItem(
        title: 'Kayıtlı gider',
        subtitle: 'Yatırım ve operasyon harcamalarından çekildi',
        amount: totalExpenses,
        status: 'Gerçek veri',
        color: const Color(0xFFEA580C),
        icon: Icons.receipt_long_outlined,
      ),
      _FinanceTimelineItem(
        title: 'Kurye / kargo tahsilatı',
        subtitle: 'Siparişlerde kayda geçen taşıma geliri',
        amount: courierRevenue,
        status: courierRevenue > 0 ? 'Gerçek veri' : 'Kayıt yok',
        color: const Color(0xFF2563EB),
        icon: Icons.local_shipping_outlined,
      ),
    ];
    _payoutTimelineCacheKey = cacheKey;
    _payoutTimelineCache = resolved;
    return resolved;
  }

  List<_FinanceInsightItem> _buildOperationalInsights() {
    final cacheKey =
        '$_operationsDataVersion|$_investmentDataVersion|$_selectedPeriodMonths|$_openStoreCount';
    if (_operationalInsightsCacheKey == cacheKey &&
        _operationalInsightsCache != null) {
      return _operationalInsightsCache!;
    }
    final totalOrders = _sumIntBy((item) => item.completedOrders);
    final totalGmv = _sumBy((item) => item.gmvCollected);
    final averageOrder = totalOrders == 0 ? 0.0 : totalGmv / totalOrders;
    final courierRevenue = _sumBy((item) => item.courierRevenue);
    final start = _visibleMonths.first.periodStart;
    final end = DateTime(
      _visibleMonths.last.periodStart.year,
      _visibleMonths.last.periodStart.month + 1,
      1,
    );
    final refundCount = _financeOrderItems
        .where(
          (item) =>
              _isRefundStatus(item.status) &&
              !item.createdAt.isBefore(start) &&
              item.createdAt.isBefore(end),
        )
        .length;

    final resolved = [
      _FinanceInsightItem(
        title: 'Açık mağaza',
        value: '$_openStoreCount',
        note: 'Şu anda siparişe açık mağaza sayısı',
      ),
      _FinanceInsightItem(
        title: 'Gerçekleşen sipariş',
        value: '$totalOrders',
        note: 'Seçili dönemde teslim edilen toplam sipariş',
      ),
      _FinanceInsightItem(
        title: 'Ortalama sipariş',
        value: _formatCompactCurrency(averageOrder),
        note: 'Teslim edilen sipariş başına ortalama ciro',
      ),
      _FinanceInsightItem(
        title: 'İade / iptal kaydı',
        value: '$refundCount',
        note: 'Order item durumlarından yakalanan iade veya iptal adedi',
      ),
      _FinanceInsightItem(
        title: 'Kurye / kargo tahsilatı',
        value: _formatCompactCurrency(courierRevenue),
        note: 'Sipariş kayıtlarındaki shipping amount toplamı',
      ),
    ];
    _operationalInsightsCacheKey = cacheKey;
    _operationalInsightsCache = resolved;
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

        return Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _viewMode == _FinanceViewMode.operations
                      ? _buildOperationsDashboard()
                      : _buildInvestorDashboard(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact)
                const SizedBox.shrink()
              else
                Row(
                  children: [
                    Expanded(child: _buildTitleBlock()),
                    const SizedBox(width: 16),
                    _buildPeriodSwitch(),
                    const SizedBox(width: 12),
                    _buildViewSwitch(),
                  ],
                ),
              if (compact) ...[
                _buildTitleBlock(),
                const SizedBox(height: 18),
                _buildPeriodSwitch(),
                const SizedBox(height: 12),
                _buildViewSwitch(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildTitleBlock() {
    final totalRevenue = _sumBy((item) => item.platformRevenue);
    final totalExpenses = _sumBy((item) => item.totalExpenses);
    final statusColor = totalRevenue >= totalExpenses
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Finans akışı, hakediş ve yatırımcı görünümü',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sipariş ciroyu, platform gelirini, satıcı hakedişini, kayıtlı giderleri ve yatırım hareketlerini tek ekranda izle.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: statusColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, size: 10, color: statusColor),
              const SizedBox(width: 8),
              Text(
                _viewMode == _FinanceViewMode.operations
                    ? 'Finans operasyonu açık'
                    : 'Yatırım takibi açık',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSwitch() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _periodOptions.map((months) {
        final isActive = _selectedPeriodMonths == months;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () {
            if (_selectedPeriodMonths == months) return;
            setState(() => _selectedPeriodMonths = months);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF111827) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF111827)
                    : Colors.grey.shade300,
              ),
            ),
            child: Text(
              '$months Ay',
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildViewSwitch() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewButton(
            label: 'Finans',
            mode: _FinanceViewMode.operations,
            icon: Icons.account_balance_wallet_outlined,
          ),
          _buildViewButton(
            label: 'Yatırım',
            mode: _FinanceViewMode.investor,
            icon: Icons.insights_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildViewButton({
    required String label,
    required _FinanceViewMode mode,
    required IconData icon,
  }) {
    final isActive = _viewMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        if (_viewMode == mode) return;
        setState(() => _viewMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF111827) : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF111827)
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationsDashboard() {
    final totalCashIn = _sumBy((item) => item.cashIn);
    final totalNetCashflow = _sumBy((item) => item.netCashflow);
    final totalOrders = _sumIntBy((item) => item.completedOrders);
    final averageOrder = totalOrders == 0 ? 0.0 : totalCashIn / totalOrders;

    if (_isLoadingOperationsData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_operationsDataError != null) {
      return _buildOperationsErrorState();
    }

    return Column(
      key: const ValueKey('operations_dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Finans akışını canlı veriden izle',
          subtitle:
              'Sipariş, mağaza ve kayıtlı gider verileri Supabase üzerinden okunur; bu ekran artık demo sayı kullanmaz.',
          badge: 'Son $_selectedPeriodMonths ay özeti',
          stats: [
            _FinanceHeroStat(
              label: 'Kasaya giriş',
              value: _formatCompactCurrency(totalCashIn),
            ),
            _FinanceHeroStat(
              label: 'Net nakit etkisi',
              value: _formatCompactCurrency(totalNetCashflow),
            ),
            _FinanceHeroStat(
              label: 'Ortalama sipariş',
              value: _formatCompactCurrency(averageOrder),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildSummaryGrid(_buildOperationCards()),
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
                SizedBox(width: cardWidth, child: _buildCashFlowCard()),
                SizedBox(
                  width: cardWidth,
                  child: _buildBreakdownCard(
                    title: 'Nereden ne kadar gelmiş?',
                    subtitle:
                        'Teslim edilen sipariş cirosunda en fazla payı üreten mağazalar.',
                    rows: _buildRevenueSources(),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _buildBreakdownCard(
                    title: 'Gider kompozisyonu',
                    subtitle:
                        'Admin tarafından girilen gerçek gider kategorileri.',
                    rows: _buildExpenseSources(),
                  ),
                ),
                SizedBox(width: cardWidth, child: _buildPayoutCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1220;
            final leftWidth = wide
                ? constraints.maxWidth * 0.62
                : constraints.maxWidth;
            final rightWidth = wide
                ? constraints.maxWidth * 0.38 - 20
                : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                SizedBox(width: leftWidth, child: _buildMonthlyTable()),
                SizedBox(width: rightWidth, child: _buildInsightsCard()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildInvestorDashboard() {
    final remainingBalance = _remainingInvestmentBalance;

    return Column(
      key: const ValueKey('investor_dashboard'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeroCard(
          title: 'Yatırım yönetimi',
          subtitle:
              'Gelen yatırımı gir, yatırımın hangi alanlara harcandığını yaz ve ekranın bu hareketlerden otomatik grafik üretmesini sağla.',
          badge: 'Yatırım takibi',
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
          ],
        ),
        const SizedBox(height: 20),
        if (_isLoadingInvestmentData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_investmentDataError != null)
          _buildInvestmentErrorState()
        else ...[
          _buildSummaryGrid(_buildInvestmentOverviewCards()),
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

  Widget _buildHeroCard({
    required String title,
    required String subtitle,
    required String badge,
    required List<_FinanceHeroStat> stats,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 920;
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.spaceBetween,
            children: [
              SizedBox(
                width: compact
                    ? constraints.maxWidth
                    : constraints.maxWidth * 0.52,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: compact
                    ? constraints.maxWidth
                    : constraints.maxWidth * 0.36,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: stats
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.68),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryGrid(List<_FinanceSummaryCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1460
            ? 3
            : constraints.maxWidth >= 980
            ? 2
            : 1;
        final itemWidth =
            (constraints.maxWidth - (20 * (columns - 1))) / columns;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: cards
              .map(
                (card) =>
                    SizedBox(width: itemWidth, child: _buildSummaryCard(card)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard(_FinanceSummaryCard card) {
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: card.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(card.icon, color: card.accent, size: 20),
              ),
              const Spacer(),
              Text(
                card.trend,
                style: TextStyle(
                  color: card.trendColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            card.title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.value,
            style: const TextStyle(
              fontSize: 28,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            card.subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowCard() {
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kazanç Performansı',
                        style: TextStyle(
                          color: Color(0xFF1F2937),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatChartRangeCaption(points),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildChartRangeChip(
                      label: '7 Gün',
                      preset: _FinanceChartRange.last7Days,
                    ),
                    _buildChartRangeChip(
                      label: '30 Gün',
                      preset: _FinanceChartRange.last30Days,
                    ),
                    _buildChartRangeChip(
                      label: '3 Ay',
                      preset: _FinanceChartRange.last3Months,
                    ),
                    _buildChartRangeChip(
                      label: '6 Ay',
                      preset: _FinanceChartRange.last6Months,
                    ),
                    _buildChartRangeChip(
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
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final metrics = [
                  _buildPerformanceMetricInline(
                    'Brüt Gelir',
                    _formatCurrency(grossRevenue),
                    const Color(0xFF7C3AED),
                  ),
                  _buildPerformanceMetricInline(
                    'Net Kazanç',
                    _formatCurrency(netRevenue),
                    const Color(0xFF10B981),
                  ),
                  _buildPerformanceMetricInline(
                    'Gider',
                    _formatCurrency(totalExpense),
                    const Color(0xFFEF4444),
                  ),
                  _buildPerformanceMetricInline(
                    'Kurye Kazancı',
                    _formatCurrency(courierEarnings),
                    const Color(0xFF2563EB),
                  ),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(spacing: 18, runSpacing: 14, children: metrics),
                      const SizedBox(height: 16),
                      _buildChartLegendPill(),
                    ],
                  );
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
                    const Spacer(),
                    _buildChartLegendPill(),
                  ],
                );
              },
            ),
          ),
          Container(height: 1, color: const Color(0xFFE5E7EB)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildPerformanceYAxisLabels(maxValue),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                                  'Grafik verisi bulunamadı',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _buildXAxisIndices(points).map((index) {
                    return Expanded(
                      child: Text(
                        points[index].axisLabel,
                        textAlign: index == _buildXAxisIndices(points).first
                            ? TextAlign.left
                            : index == _buildXAxisIndices(points).last
                            ? TextAlign.right
                            : TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7A7A7A),
                          fontSize: 12,
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
    required String label,
    required _FinanceChartRange preset,
    IconData? icon,
  }) {
    final isSelected = _selectedChartRange == preset;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        if (_selectedChartRange == preset) return;
        setState(() => _selectedChartRange = preset);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
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
              Icon(icon, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF475569),
                fontSize: 14,
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
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 130),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 16,
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

  Widget _buildChartLegendPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8B4FE)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 14, color: Color(0xFF7C3AED)),
          SizedBox(width: 10),
          Text(
            'Net Kazanç',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard({
    required String title,
    required String subtitle,
    required List<_FinanceBreakdownRow> rows,
  }) {
    return _buildPanel(
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? Text(
              'Bu dönem için gösterilecek kırılım verisi yok.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            )
          : Column(
              children: rows.map((row) {
                return Padding(
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
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Text(
                            _formatCurrency(row.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: row.share,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFF3F4F6),
                          valueColor: AlwaysStoppedAnimation<Color>(row.color),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '%${(row.share * 100).toStringAsFixed(1)}',
                            style: TextStyle(
                              color: row.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              row.note,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPayoutCard() {
    final payoutTimeline = _buildPayoutTimeline();
    return _buildPanel(
      title: 'Gerçek finans özeti',
      subtitle:
          'Seçili dönemde hesaplanan komisyon, hakediş, gider ve kurye tahsilatı.',
      child: Column(
        children: payoutTimeline.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: item.color.withValues(alpha: 0.16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: item.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(item.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.status,
                      style: TextStyle(
                        color: item.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyTable() {
    return _buildPanel(
      title: 'Aylık finans çizgisi',
      subtitle:
          'Hangi ay ne kadar tahsilat, gelir, gider ve net katkı oluştuğunu gör.',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 44,
          columns: const [
            DataColumn(label: Text('Dönem')),
            DataColumn(label: Text('GMV')),
            DataColumn(label: Text('Platform Geliri')),
            DataColumn(label: Text('Gider')),
            DataColumn(label: Text('Hakediş')),
            DataColumn(label: Text('Net Etki')),
          ],
          rows: _visibleMonths.map((item) {
            final netColor = item.netCashflow >= 0
                ? const Color(0xFF15803D)
                : const Color(0xFFDC2626);
            return DataRow(
              cells: [
                DataCell(Text(item.label)),
                DataCell(Text(_formatCompactCurrency(item.gmvCollected))),
                DataCell(Text(_formatCompactCurrency(item.platformRevenue))),
                DataCell(Text(_formatCompactCurrency(item.totalExpenses))),
                DataCell(Text(_formatCompactCurrency(item.sellerPayouts))),
                DataCell(
                  Text(
                    _formatCompactCurrency(item.netCashflow),
                    style: TextStyle(
                      color: netColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInsightsCard() {
    final insights = _buildOperationalInsights();
    return _buildPanel(
      title: 'Canlı finans sinyalleri',
      subtitle:
          'Sipariş, mağaza ve iade kayıtlarından türetilen kontrol metrikleri.',
      child: Column(
        children: insights
            .map(
              (item) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.value,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.note,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        height: 1.45,
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

enum _FinanceViewMode { operations, investor }

enum _FinanceChartRange {
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  custom,
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

class _FinanceBreakdownRow {
  const _FinanceBreakdownRow({
    required this.label,
    required this.amount,
    required this.share,
    required this.note,
    required this.color,
  });

  final String label;
  final double amount;
  final double share;
  final String note;
  final Color color;
}

class _FinanceTimelineItem {
  const _FinanceTimelineItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    required this.color,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final Color color;
  final IconData icon;
}

class _FinanceInsightItem {
  const _FinanceInsightItem({
    required this.title,
    required this.value,
    required this.note,
  });

  final String title;
  final String value;
  final String note;
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
