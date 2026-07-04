import 'package:flutter/material.dart';

import '../helpers/finance_chart_helpers.dart';
import '../helpers/seller_finance_density.dart';
import '../models/finance_models.dart';
import 'dashboard/chart/finance_performance_line_chart.dart';
import 'dashboard/chart/finance_range_selector.dart';
import 'finance_widgets.dart';

class FinancePerformanceSection extends StatefulWidget {
  const FinancePerformanceSection({
    super.key,
    required this.loadTrend,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthSalaryLoad,
    required this.totalLiquidity,
    this.density,
  });

  final Future<List<DailyFinanceTrendPoint>> Function(DateTime from, DateTime to)
      loadTrend;
  final double monthIncome;
  final double monthExpense;
  final double monthSalaryLoad;
  final double totalLiquidity;
  final SellerFinanceDensity? density;

  @override
  State<FinancePerformanceSection> createState() =>
      _FinancePerformanceSectionState();
}

class _FinancePerformanceSectionState extends State<FinancePerformanceSection> {
  FinancePerformanceRange _range = FinancePerformanceRange.days30;
  DateTime? _customFrom;
  DateTime? _customTo;
  late Future<List<DailyFinanceTrendPoint>> _trendFuture;
  Set<FinanceChartSeriesId> _enabledSeries = FinanceChartSeriesId.values.toSet();
  final _allSeries = defaultFinanceChartSeries();

  @override
  void initState() {
    super.initState();
    _reloadTrend();
  }

  void _reloadTrend() {
    final bounds = resolveFinancePerformanceRange(
      range: _range,
      customFrom: _customFrom,
      customTo: _customTo,
    );
    _trendFuture = widget.loadTrend(bounds.from, bounds.to);
  }

  void _setRange(FinancePerformanceRange next) {
    if (_range == next && next != FinancePerformanceRange.custom) return;
    setState(() {
      _range = next;
      _reloadTrend();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: _customFrom ?? now.subtract(const Duration(days: 29)),
      end: _customTo ?? now,
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: initialRange,
      helpText: 'Özel tarih aralığı',
      saveText: 'Uygula',
      cancelText: 'İptal',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = FinancePerformanceRange.custom;
      _customFrom = picked.start;
      _customTo = picked.end;
      _reloadTrend();
    });
  }

  void _toggleSeries(FinanceChartSeriesId id) {
    setState(() {
      _enabledSeries = toggleFinanceChartSeries(
        enabled: _enabledSeries,
        id: id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.density ??
        SellerFinanceDensity.fromWidth(MediaQuery.sizeOf(context).width);
    final chartHeight = d.isWide ? 320.0 : d.chartHeight;

    return FinSurfaceCard(
      padding: EdgeInsets.all(d.isCompact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              final header = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Finansal Performans',
                    style: TextStyle(
                      fontSize: d.sectionTitleFontSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gelir, gider, maaş yükü ve likidite karşılaştırması',
                    style: TextStyle(
                      fontSize: d.sectionSubtitleFontSize,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: 10),
                    FinanceRangeSelector(
                      selected: _range,
                      onSelected: _setRange,
                      customFrom: _customFrom,
                      customTo: _customTo,
                      onCustomRangeTap: _pickCustomRange,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: header),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FinanceRangeSelector(
                      selected: _range,
                      onSelected: _setRange,
                      customFrom: _customFrom,
                      customTo: _customTo,
                      onCustomRangeTap: _pickCustomRange,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          FinanceSeriesLegend(
            series: _allSeries,
            enabled: _enabledSeries,
            onToggle: _toggleSeries,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DailyFinanceTrendPoint>>(
            future: _trendFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _ChartSkeleton(height: chartHeight);
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: chartHeight,
                  child: FinErrorCard(
                    message: 'Finansal grafik verileri yüklenemedi.',
                    onRetry: () => setState(_reloadTrend),
                  ),
                );
              }

              final chartPoints = buildFinancePerformanceChartPoints(
                dailyPoints: snapshot.data ?? const [],
                range: _range,
                monthSalaryLoad: widget.monthSalaryLoad,
              );

              if (!financeChartHasVisibleData(chartPoints)) {
                return _ChartEmptyState(height: chartHeight);
              }

              final activeSeries = filterFinanceChartSeries(
                all: _allSeries,
                enabled: _enabledSeries,
              );

              return FinancePerformanceLineChart(
                points: chartPoints,
                series: activeSeries,
                formatCurrency: fmtCurrency,
                height: chartHeight,
              );
            },
          ),
          const SizedBox(height: 12),
          _buildSummaryStrip(),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryChip(
          'Toplam Gelir',
          fmtCurrency(widget.monthIncome),
          financeChartIncomeColor,
        ),
        _summaryChip(
          'Toplam Gider',
          fmtCurrency(widget.monthExpense),
          financeChartExpenseColor,
        ),
        _summaryChip(
          'Maaş Yükü',
          fmtCurrency(widget.monthSalaryLoad),
          financeChartSalaryColor,
        ),
        _summaryChip(
          'Net Likidite',
          fmtCurrency(widget.totalLiquidity),
          financeChartLiquidityColor,
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: kFinancePrimary,
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_outlined, size: 32, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Bu tarih aralığında finansal veri bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Farklı bir tarih aralığı seçerek tekrar deneyin.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
