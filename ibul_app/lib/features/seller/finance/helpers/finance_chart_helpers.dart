import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';

/// Dönem seçenekleri — Finansal Performans grafiği.
enum FinancePerformanceRange {
  days7,
  days30,
  days90,
  days180,
  year1,
  custom,
}

enum FinanceChartSeriesId { income, expense, salary, liquidity }

/// Grafikte gösterilen günlük/özet nokta.
class FinancePerformanceChartPoint {
  const FinancePerformanceChartPoint({
    required this.date,
    required this.xLabel,
    required this.income,
    required this.expense,
    required this.salaryLoadDaily,
    required this.liquidityCumulative,
  });

  final DateTime date;
  final String xLabel;
  final double income;
  final double expense;

  /// Aylık maaş yükünün seçilen dönemdeki günlük ortalaması (referans çizgisi).
  /// Günlük maaş ödeme kaynağı yok — yanıltıcı dağıtım yapılmaz.
  final double salaryLoadDaily;

  /// Günlük gelir-gider farkının kümülatif toplamı (net likidite akışı).
  final double liquidityCumulative;
}

class FinanceChartSeriesConfig {
  const FinanceChartSeriesConfig({
    required this.id,
    required this.label,
    required this.color,
    required this.extractor,
  });

  final FinanceChartSeriesId id;
  final String label;
  final Color color;
  final double Function(FinancePerformanceChartPoint point) extractor;
}

const financeChartIncomeColor = Color(0xFF10B981);
const financeChartExpenseColor = Color(0xFFEF4444);
const financeChartSalaryColor = Color(0xFF8B5CF6);
const financeChartLiquidityColor = Color(0xFF0EA5E9);

List<FinanceChartSeriesConfig> defaultFinanceChartSeries() {
  return [
    FinanceChartSeriesConfig(
      id: FinanceChartSeriesId.income,
      label: 'Gelir',
      color: financeChartIncomeColor,
      extractor: (p) => p.income,
    ),
    FinanceChartSeriesConfig(
      id: FinanceChartSeriesId.expense,
      label: 'Gider',
      color: financeChartExpenseColor,
      extractor: (p) => p.expense,
    ),
    FinanceChartSeriesConfig(
      id: FinanceChartSeriesId.salary,
      label: 'Maaş Yükü',
      color: financeChartSalaryColor,
      extractor: (p) => p.salaryLoadDaily,
    ),
    FinanceChartSeriesConfig(
      id: FinanceChartSeriesId.liquidity,
      label: 'Likidite',
      color: financeChartLiquidityColor,
      extractor: (p) => p.liquidityCumulative,
    ),
  ];
}

DateTime financeDayStart(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime financeRangeEnd({DateTime? now}) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month, n.day, 23, 59, 59);
}

/// Seçilen döneme göre başlangıç/bitiş tarihi.
({DateTime from, DateTime to}) resolveFinancePerformanceRange({
  required FinancePerformanceRange range,
  DateTime? customFrom,
  DateTime? customTo,
  DateTime? now,
}) {
  final end = financeRangeEnd(now: now);
  final today = financeDayStart(now ?? DateTime.now());
  switch (range) {
    case FinancePerformanceRange.days7:
      return (from: today.subtract(const Duration(days: 6)), to: end);
    case FinancePerformanceRange.days30:
      return (from: today.subtract(const Duration(days: 29)), to: end);
    case FinancePerformanceRange.days90:
      return (from: today.subtract(const Duration(days: 89)), to: end);
    case FinancePerformanceRange.days180:
      return (from: today.subtract(const Duration(days: 179)), to: end);
    case FinancePerformanceRange.year1:
      return (from: today.subtract(const Duration(days: 364)), to: end);
    case FinancePerformanceRange.custom:
      final from = customFrom != null
          ? financeDayStart(customFrom)
          : today.subtract(const Duration(days: 29));
      final to = customTo != null
          ? DateTime(
              customTo.year,
              customTo.month,
              customTo.day,
              23,
              59,
              59,
            )
          : end;
      if (from.isAfter(to)) {
        return (from: financeDayStart(to), to: to);
      }
      return (from: from, to: to);
  }
}

String formatFinanceAxisLabel(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 1000000000) {
    return '$sign₺${(abs / 1000000000).toStringAsFixed(1)}B';
  }
  if (abs >= 1000000) {
    return '$sign₺${(abs / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return '$sign₺${(abs / 1000).toStringAsFixed(0)}K';
  }
  return '$sign₺${abs.toStringAsFixed(0)}';
}

String formatFinanceChartDateLabel(
  DateTime date,
  FinancePerformanceRange range,
) {
  switch (range) {
    case FinancePerformanceRange.days7:
      return DateFormat('E', 'tr_TR').format(date).substring(0, 2);
    case FinancePerformanceRange.days30:
    case FinancePerformanceRange.days90:
    case FinancePerformanceRange.days180:
    case FinancePerformanceRange.custom:
      return DateFormat('d MMM', 'tr_TR').format(date);
    case FinancePerformanceRange.year1:
      return DateFormat('MMM yy', 'tr_TR').format(date);
  }
}

String formatFinanceTooltipDate(DateTime date) {
  return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
}

/// Günlük trend noktalarını grafik serilerine dönüştürür.
/// Maaş yükü: düz referans (aylık / gün sayısı).
/// Likidite: günlük net akışın kümülatif toplamı.
List<FinancePerformanceChartPoint> buildFinancePerformanceChartPoints({
  required List<DailyFinanceTrendPoint> dailyPoints,
  required FinancePerformanceRange range,
  required double monthSalaryLoad,
}) {
  if (dailyPoints.isEmpty) return const [];

  final sorted = List<DailyFinanceTrendPoint>.from(dailyPoints)
    ..sort((a, b) => a.date.compareTo(b.date));

  final aggregated = _aggregateIfNeeded(sorted, range);
  final dayCount = aggregated.length;
  final dailySalaryRef =
      monthSalaryLoad > 0 && dayCount > 0 ? monthSalaryLoad / dayCount : 0.0;

  var cumulative = 0.0;
  return aggregated.map((point) {
    cumulative += point.income - point.expense;
    return FinancePerformanceChartPoint(
      date: point.date,
      xLabel: formatFinanceChartDateLabel(point.date, range),
      income: point.income,
      expense: point.expense,
      salaryLoadDaily: dailySalaryRef,
      liquidityCumulative: cumulative,
    );
  }).toList(growable: false);
}

List<DailyFinanceTrendPoint> _aggregateIfNeeded(
  List<DailyFinanceTrendPoint> points,
  FinancePerformanceRange range,
) {
  final shouldWeekly = range == FinancePerformanceRange.days180;
  final shouldMonthly =
      range == FinancePerformanceRange.year1 ||
      (range == FinancePerformanceRange.custom && points.length > 120);

  if (!shouldWeekly && !shouldMonthly) {
    return _downsamplePoints(points, maxPoints: 45);
  }

  if (shouldMonthly) {
    return _aggregateByMonth(points);
  }
  return _aggregateByWeek(points);
}

List<DailyFinanceTrendPoint> _downsamplePoints(
  List<DailyFinanceTrendPoint> points, {
  required int maxPoints,
}) {
  if (points.length <= maxPoints) return points;
  final step = (points.length / maxPoints).ceil();
  final sampled = <DailyFinanceTrendPoint>[];
  for (var i = 0; i < points.length; i += step) {
    sampled.add(points[i]);
  }
  if (sampled.last.date != points.last.date) {
    sampled.add(points.last);
  }
  return sampled;
}

List<DailyFinanceTrendPoint> _aggregateByWeek(List<DailyFinanceTrendPoint> points) {
  final buckets = <DateTime, ({double income, double expense})>{};
  for (final p in points) {
    final monday = p.date.subtract(Duration(days: p.date.weekday - 1));
    final key = financeDayStart(monday);
    final prev = buckets[key];
    buckets[key] = (
      income: (prev?.income ?? 0) + p.income,
      expense: (prev?.expense ?? 0) + p.expense,
    );
  }
  final keys = buckets.keys.toList()..sort();
  return keys
      .map(
        (k) => DailyFinanceTrendPoint(
          date: k,
          income: buckets[k]!.income,
          expense: buckets[k]!.expense,
        ),
      )
      .toList(growable: false);
}

List<DailyFinanceTrendPoint> _aggregateByMonth(
  List<DailyFinanceTrendPoint> points,
) {
  final buckets = <DateTime, ({double income, double expense})>{};
  for (final p in points) {
    final key = DateTime(p.date.year, p.date.month, 1);
    final prev = buckets[key];
    buckets[key] = (
      income: (prev?.income ?? 0) + p.income,
      expense: (prev?.expense ?? 0) + p.expense,
    );
  }
  final keys = buckets.keys.toList()..sort();
  return keys
      .map(
        (k) => DailyFinanceTrendPoint(
          date: k,
          income: buckets[k]!.income,
          expense: buckets[k]!.expense,
        ),
      )
      .toList(growable: false);
}

bool financeChartHasVisibleData(List<FinancePerformanceChartPoint> points) {
  if (points.isEmpty) return false;
  return points.any(
    (p) =>
        p.income > 0 ||
        p.expense > 0 ||
        p.salaryLoadDaily > 0 ||
        p.liquidityCumulative != 0,
  );
}

List<FinanceChartSeriesConfig> filterFinanceChartSeries({
  required List<FinanceChartSeriesConfig> all,
  required Set<FinanceChartSeriesId> enabled,
}) {
  return all.where((s) => enabled.contains(s.id)).toList(growable: false);
}

Set<FinanceChartSeriesId> toggleFinanceChartSeries({
  required Set<FinanceChartSeriesId> enabled,
  required FinanceChartSeriesId id,
}) {
  final next = Set<FinanceChartSeriesId>.from(enabled);
  if (next.contains(id)) {
    if (next.length <= 1) return enabled;
    next.remove(id);
  } else {
    next.add(id);
  }
  return next;
}

double financeChartMaxValue({
  required List<FinancePerformanceChartPoint> points,
  required List<FinanceChartSeriesConfig> series,
}) {
  var max = 1.0;
  for (final point in points) {
    for (final config in series) {
      final v = config.extractor(point).abs();
      if (v > max) max = v;
    }
  }
  return max;
}

({double income, double expense, double salary, double liquidity}) sumChartTotals(
  List<FinancePerformanceChartPoint> points,
) {
  var income = 0.0;
  var expense = 0.0;
  for (final p in points) {
    income += p.income;
    expense += p.expense;
  }
  final salary = points.isEmpty ? 0.0 : points.first.salaryLoadDaily * points.length;
  final liquidity = points.isEmpty ? 0.0 : points.last.liquidityCumulative;
  return (income: income, expense: expense, salary: salary, liquidity: liquidity);
}

List<int> financeChartLabelIndexes(int length) {
  if (length <= 1) return [0];
  if (length <= 6) return List.generate(length, (i) => i);
  if (length <= 12) {
    return List.generate(6, (i) => (i * (length - 1) ~/ 5));
  }
  return List.generate(8, (i) => (i * (length - 1) ~/ 7));
}

int financeChartIndexAt(double x, double width, int length) {
  if (length <= 1) return 0;
  final step = width / (length - 1);
  return (x / step).round().clamp(0, length - 1);
}
