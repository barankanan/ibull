import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/finance_models.dart';
import 'finance_widgets.dart';

enum FinanceTrendRange { days7, days30, days90 }

class FinancePerformanceSection extends StatefulWidget {
  const FinancePerformanceSection({
    super.key,
    required this.loadTrend,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthSalaryLoad,
    required this.totalLiquidity,
  });

  final Future<List<DailyFinanceTrendPoint>> Function(DateTime from, DateTime to)
      loadTrend;
  final double monthIncome;
  final double monthExpense;
  final double monthSalaryLoad;
  final double totalLiquidity;

  @override
  State<FinancePerformanceSection> createState() =>
      _FinancePerformanceSectionState();
}

class _FinancePerformanceSectionState extends State<FinancePerformanceSection> {
  FinanceTrendRange _range = FinanceTrendRange.days30;
  late Future<List<DailyFinanceTrendPoint>> _trendFuture;

  @override
  void initState() {
    super.initState();
    _trendFuture = widget.loadTrend(_rangeFrom(), _rangeTo());
  }

  DateTime _rangeTo() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  DateTime _rangeFrom() {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    return switch (_range) {
      FinanceTrendRange.days7 => dayStart.subtract(const Duration(days: 6)),
      FinanceTrendRange.days30 => dayStart.subtract(const Duration(days: 29)),
      FinanceTrendRange.days90 => dayStart.subtract(const Duration(days: 89)),
    };
  }

  void _setRange(FinanceTrendRange next) {
    if (_range == next) return;
    setState(() {
      _range = next;
      _trendFuture = widget.loadTrend(_rangeFrom(), _rangeTo());
    });
  }

  @override
  Widget build(BuildContext context) {
    return FinSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finansal Performans',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Gelir ve gider trendi — seçilen döneme göre günlük akış.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              _rangeChip('7 Gün', FinanceTrendRange.days7),
              const SizedBox(width: 6),
              _rangeChip('30 Gün', FinanceTrendRange.days30),
              const SizedBox(width: 6),
              _rangeChip('3 Ay', FinanceTrendRange.days90),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<DailyFinanceTrendPoint>>(
            future: _trendFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final points = snapshot.data ?? const [];
              final hasData = points.any((p) => p.income > 0 || p.expense > 0);
              if (!hasData) {
                return Container(
                  height: 260,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Seçilen dönemde gelir veya gider hareketi yok. '
                    'Masa kapanışları ve gider kayıtları geldikçe grafik dolacak.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                );
              }
              final chartPoints = _downsample(points);
              return Column(
                children: [
                  FinTrendChart(
                    points: chartPoints
                        .map(
                          (p) => (
                            label: _labelFor(p.date),
                            income: p.income,
                            expense: p.expense,
                          ),
                        )
                        .toList(growable: false),
                    height: 260,
                  ),
                  const SizedBox(height: 8),
                  if (chartPoints.isNotEmpty)
                    Text(
                      'Son gün: ${fmtCurrency(chartPoints.last.income)} gelir · '
                      '${fmtCurrency(chartPoints.last.expense)} gider',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniStat(
                'Bu Ay Gelir',
                fmtCurrency(widget.monthIncome),
                const Color(0xFF10B981),
              ),
              _miniStat(
                'Bu Ay Gider',
                fmtCurrency(widget.monthExpense),
                const Color(0xFFEF4444),
              ),
              _miniStat(
                'Maaş Yükü',
                fmtCurrency(widget.monthSalaryLoad),
                const Color(0xFF8B5CF6),
              ),
              _miniStat(
                'Toplam Likidite',
                fmtCurrency(widget.totalLiquidity),
                kFinancePrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<DailyFinanceTrendPoint> _downsample(List<DailyFinanceTrendPoint> points) {
    if (points.length <= 14) return points;
    final step = (points.length / 14).ceil();
    final sampled = <DailyFinanceTrendPoint>[];
    for (var i = 0; i < points.length; i += step) {
      sampled.add(points[i]);
    }
    if (sampled.last.date != points.last.date) {
      sampled.add(points.last);
    }
    return sampled;
  }

  String _labelFor(DateTime date) {
    if (_range == FinanceTrendRange.days7) {
      return DateFormat('E', 'tr_TR').format(date).substring(0, 2);
    }
    return DateFormat('d MMM', 'tr_TR').format(date);
  }

  Widget _rangeChip(String label, FinanceTrendRange value) {
    final selected = _range == value;
    return FinSectionSwitchChip(
      label: label,
      icon: Icons.calendar_today_rounded,
      selected: selected,
      onTap: () => _setRange(value),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
