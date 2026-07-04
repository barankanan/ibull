import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../helpers/admin_finance_analytics_helper.dart';
import '../helpers/admin_panel_density.dart';

class FinanceChartSeriesConfig {
  const FinanceChartSeriesConfig({
    required this.label,
    required this.color,
    required this.extractor,
    this.showArea = false,
  });

  final String label;
  final Color color;
  final double Function(AdminFinanceChartPoint point) extractor;
  final bool showArea;
}

class AdminFinanceChartsPanel extends StatelessWidget {
  const AdminFinanceChartsPanel({
    super.key,
    required this.density,
    required this.periodLabel,
    required this.cashFlowSeries,
    required this.revenueSeries,
    required this.expenseSeries,
    required this.formatCurrency,
    this.revenueOnly = false,
    this.expenseOnly = false,
  });

  final AdminPanelDensity density;
  final String periodLabel;
  final List<AdminFinanceChartPoint> cashFlowSeries;
  final List<AdminFinanceChartPoint> revenueSeries;
  final List<AdminFinanceChartPoint> expenseSeries;
  final String Function(double) formatCurrency;
  final bool revenueOnly;
  final bool expenseOnly;

  double get _chartHeight => density.isCompact ? 240 : 280;

  @override
  Widget build(BuildContext context) {
    if (revenueOnly) {
      return _chartCard(
        title: 'Gelir Kaynakları Trendi',
        subtitle: 'Haftalık/ günlük kırılım · $periodLabel',
        series: _revenueSeriesConfig(),
        points: revenueSeries,
      );
    }
    if (expenseOnly) {
      return _chartCard(
        title: 'Gider Trendi',
        subtitle: 'Ödenen, tekrarlayan ve bekleyen · $periodLabel',
        series: _expenseSeriesConfig(),
        points: expenseSeries,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _chartCard(
          title: 'Para Akışı',
          subtitle: 'GMV, İBUL geliri, gider ve net kâr · $periodLabel',
          series: [
            FinanceChartSeriesConfig(
              label: 'GMV / Ciro',
              color: const Color(0xFF6366F1),
              extractor: (p) => p.gmv,
              showArea: true,
            ),
            FinanceChartSeriesConfig(
              label: 'İBUL Geliri',
              color: const Color(0xFF0F766E),
              extractor: (p) => p.ibulRevenue,
            ),
            FinanceChartSeriesConfig(
              label: 'Toplam Gider',
              color: const Color(0xFFEA580C),
              extractor: (p) => p.totalExpense,
            ),
            FinanceChartSeriesConfig(
              label: 'Net Kâr / Zarar',
              color: const Color(0xFF16A34A),
              extractor: (p) => p.netProfit,
              showArea: true,
            ),
          ],
          points: cashFlowSeries,
        ),
        SizedBox(height: density.gridSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 900;
            final chart = _chartCard(
              title: 'Gelir Kaynakları Trendi',
              subtitle: 'Komisyon, reklam, kargo · $periodLabel',
              series: _revenueSeriesConfig(),
              points: revenueSeries,
            );
            final expenseChart = _chartCard(
              title: 'Gider Trendi',
              subtitle: 'Ödenen, tekrarlayan ve bekleyen · $periodLabel',
              series: _expenseSeriesConfig(),
              points: expenseSeries,
            );
            if (stacked) {
              return Column(
                children: [
                  chart,
                  SizedBox(height: density.gridSpacing),
                  expenseChart,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: chart),
                SizedBox(width: density.gridSpacing),
                Expanded(child: expenseChart),
              ],
            );
          },
        ),
      ],
    );
  }

  List<FinanceChartSeriesConfig> _revenueSeriesConfig() => [
        FinanceChartSeriesConfig(
          label: 'Sipariş Komisyonu',
          color: const Color(0xFF2563EB),
          extractor: (p) => p.commission,
          showArea: true,
        ),
        FinanceChartSeriesConfig(
          label: 'Reklam Geliri',
          color: const Color(0xFFDB2777),
          extractor: (p) => p.adRevenue,
        ),
        FinanceChartSeriesConfig(
          label: 'Kargo Geliri',
          color: const Color(0xFF0284C7),
          extractor: (p) => p.cargoRevenue,
        ),
        FinanceChartSeriesConfig(
          label: 'Emlak / Kira',
          color: const Color(0xFF9CA3AF),
          extractor: (p) => p.propertyRevenue,
        ),
      ];

  List<FinanceChartSeriesConfig> _expenseSeriesConfig() => [
        FinanceChartSeriesConfig(
          label: 'Toplam Gider',
          color: const Color(0xFFEA580C),
          extractor: (p) => p.totalExpense,
          showArea: true,
        ),
        FinanceChartSeriesConfig(
          label: 'Tekrarlayan',
          color: const Color(0xFF7C3AED),
          extractor: (p) => p.recurringExpense,
        ),
        FinanceChartSeriesConfig(
          label: 'Bekleyen',
          color: const Color(0xFFF97316),
          extractor: (p) => p.pendingExpense,
        ),
      ];

  Widget _chartCard({
    required String title,
    required String subtitle,
    required List<FinanceChartSeriesConfig> series,
    required List<AdminFinanceChartPoint> points,
  }) {
    final hasData = points.any((p) => p.hasData);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: EdgeInsets.all(density.financeSectionPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: density.financeSectionTitleFontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: density.financeSectionSubtitleFontSize,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: series
                .map(
                  (s) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        s.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _chartHeight,
            child: hasData
                ? _InteractiveFinanceChart(
                    points: points,
                    series: series,
                    formatCurrency: formatCurrency,
                  )
                : Center(
                    child: Text(
                      'Bu dönem için grafik verisi yok.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveFinanceChart extends StatefulWidget {
  const _InteractiveFinanceChart({
    required this.points,
    required this.series,
    required this.formatCurrency,
  });

  final List<AdminFinanceChartPoint> points;
  final List<FinanceChartSeriesConfig> series;
  final String Function(double) formatCurrency;

  @override
  State<_InteractiveFinanceChart> createState() =>
      _InteractiveFinanceChartState();
}

class _InteractiveFinanceChartState extends State<_InteractiveFinanceChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxValue = widget.series.fold<double>(1, (max, config) {
      for (final point in points) {
        final value = config.extractor(point).abs();
        if (value > max) return value;
      }
      return max;
    });

    final labelIndexes = _labelIndexes(points.length);
    final selected = _selectedIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null && selected >= 0 && selected < points.length)
          _tooltip(points[selected])
        else
          const SizedBox(height: 28),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _axisLabel(maxValue),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      _axisLabel(maxValue / 2),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const Text(
                      '0',
                      style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onTapDown: (details) {
                        final index = _indexAt(
                          details.localPosition.dx,
                          constraints.maxWidth,
                          points.length,
                        );
                        setState(
                          () => _selectedIndex =
                              _selectedIndex == index ? null : index,
                        );
                      },
                      child: CustomPaint(
                        painter: _SmoothMultiSeriesChartPainter(
                          points: points,
                          series: widget.series,
                          maxValue: maxValue,
                          selectedIndex: selected,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: labelIndexes.map((index) {
            return Expanded(
              child: Text(
                points[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: selected == index
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: selected == index
                      ? const Color(0xFF111827)
                      : const Color(0xFF94A3B8),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _tooltip(AdminFinanceChartPoint point) {
    final chips = widget.series
        .map((config) {
          final value = config.extractor(point);
          if (value == 0) return null;
          return Container(
            margin: const EdgeInsets.only(right: 6, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: config.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: config.color.withValues(alpha: 0.25)),
            ),
            child: Text(
              '${config.label}: ${widget.formatCurrency(value)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: config.color,
              ),
            ),
          );
        })
        .whereType<Widget>()
        .toList();

    return Container(
      height: 28,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: chips),
      ),
    );
  }

  List<int> _labelIndexes(int length) {
    if (length <= 1) return [0];
    if (length <= 6) return List.generate(length, (i) => i);
    if (length <= 12) {
      return List.generate(6, (i) => (i * (length - 1) ~/ 5));
    }
    return List.generate(8, (i) => (i * (length - 1) ~/ 7));
  }

  int _indexAt(double x, double width, int length) {
    if (length <= 1) return 0;
    final step = width / (length - 1);
    return (x / step).round().clamp(0, length - 1);
  }

  String _axisLabel(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

class _SmoothMultiSeriesChartPainter extends CustomPainter {
  _SmoothMultiSeriesChartPainter({
    required this.points,
    required this.series,
    required this.maxValue,
    this.selectedIndex,
  });

  final List<AdminFinanceChartPoint> points;
  final List<FinanceChartSeriesConfig> series;
  final double maxValue;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    final stepX = size.width / (points.length - 1);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < points.length) {
      final x = selectedIndex! * stepX;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 1,
      );
    }

    for (final config in series) {
      final offsets = _seriesOffsets(config, size, safeMax, stepX);
      if (offsets.length < 2) continue;

      if (config.showArea) {
        final areaPath = _smoothPath(offsets, closeBottom: size.height);
        canvas.drawPath(
          areaPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, 0),
              Offset(0, size.height),
              [
                config.color.withValues(alpha: 0.22),
                config.color.withValues(alpha: 0.02),
              ],
            ),
        );
      }

      canvas.drawPath(
        _smoothPath(offsets),
        Paint()
          ..color = config.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var i = 0; i < offsets.length; i++) {
        final selected = selectedIndex == i;
        canvas.drawCircle(
          offsets[i],
          selected ? 5 : 3,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          offsets[i],
          selected ? 5 : 3,
          Paint()
            ..color = config.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 2.5 : 1.5,
        );
        if (selected) {
          canvas.drawCircle(offsets[i], 2.5, Paint()..color = config.color);
        }
      }
    }
  }

  List<Offset> _seriesOffsets(
    FinanceChartSeriesConfig config,
    Size size,
    double safeMax,
    double stepX,
  ) {
    final offsets = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final value = config.extractor(points[i]);
      final x = i * stepX;
      final y = size.height -
          ((value / safeMax).clamp(0.0, 1.0) * (size.height - 16)) -
          8;
      offsets.add(Offset(x, y));
    }
    return offsets;
  }

  Path _smoothPath(List<Offset> offsets, {double? closeBottom}) {
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      final previous = offsets[i - 1];
      final current = offsets[i];
      final controlX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    if (closeBottom != null) {
      path
        ..lineTo(offsets.last.dx, closeBottom)
        ..lineTo(offsets.first.dx, closeBottom)
        ..close();
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _SmoothMultiSeriesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.series != series ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
