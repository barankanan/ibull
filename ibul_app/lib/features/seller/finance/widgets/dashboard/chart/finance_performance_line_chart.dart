import 'package:flutter/material.dart';

import '../../../helpers/finance_chart_helpers.dart';

class FinancePerformanceLineChart extends StatefulWidget {
  const FinancePerformanceLineChart({
    super.key,
    required this.points,
    required this.series,
    required this.formatCurrency,
    required this.height,
  });

  final List<FinancePerformanceChartPoint> points;
  final List<FinanceChartSeriesConfig> series;
  final String Function(double) formatCurrency;
  final double height;

  @override
  State<FinancePerformanceLineChart> createState() =>
      _FinancePerformanceLineChartState();
}

class _FinancePerformanceLineChartState extends State<FinancePerformanceLineChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty || widget.series.isEmpty) {
      return SizedBox(height: widget.height);
    }

    final maxValue = financeChartMaxValue(
      points: points,
      series: widget.series,
    );
    final labelIndexes = financeChartLabelIndexes(points.length);
    final selected = _selectedIndex;

    return SizedBox(
      height: widget.height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTooltip(selected, points),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 52,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatFinanceAxisLabel(maxValue),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        formatFinanceAxisLabel(maxValue / 2),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Text(
                        '₺0',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return MouseRegion(
                        onHover: (event) {
                          final index = financeChartIndexAt(
                            event.localPosition.dx,
                            constraints.maxWidth,
                            points.length,
                          );
                          if (_selectedIndex != index) {
                            setState(() => _selectedIndex = index);
                          }
                        },
                        child: GestureDetector(
                          onTapDown: (details) {
                            final index = financeChartIndexAt(
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
                            painter: _FinancePerformanceChartPainter(
                              points: points,
                              series: widget.series,
                              maxValue: maxValue,
                              selectedIndex: selected,
                            ),
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Row(
              children: labelIndexes.map((index) {
                return Expanded(
                  child: Text(
                    points[index].xLabel,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(int? selected, List<FinancePerformanceChartPoint> points) {
    if (selected == null || selected < 0 || selected >= points.length) {
      return const SizedBox(height: 72);
    }
    final point = points[selected];
    return Container(
      height: 72,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatFinanceTooltipDate(point.date),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.series.map((config) {
                final value = config.extractor(point);
                return Text(
                  '${config.label}: ${widget.formatCurrency(value)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: config.color,
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancePerformanceChartPainter extends CustomPainter {
  _FinancePerformanceChartPainter({
    required this.points,
    required this.series,
    required this.maxValue,
    this.selectedIndex,
  });

  final List<FinancePerformanceChartPoint> points;
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
    for (var i = 1; i <= 4; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
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

      canvas.drawPath(
        _smoothPath(offsets),
        Paint()
          ..color = config.color
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      for (var i = 0; i < offsets.length; i++) {
        final selected = selectedIndex == i;
        if (!selected && points.length > 20) continue;
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
    return List.generate(points.length, (i) {
      final value = config.extractor(points[i]);
      final x = i * stepX;
      final y = size.height - (value / safeMax * size.height).clamp(0, size.height);
      return Offset(x, y);
    });
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_FinancePerformanceChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.series != series ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
