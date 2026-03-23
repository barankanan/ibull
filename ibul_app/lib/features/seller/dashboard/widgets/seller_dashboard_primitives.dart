import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../services/seller_dashboard_service.dart';

class SellerDashboardSectionLabel extends StatelessWidget {
  const SellerDashboardSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }
}

class SellerDashboardGrid extends StatelessWidget {
  const SellerDashboardGrid({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          1,
          ((constraints.maxWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final width =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class SellerDashboardLineChartPainter extends CustomPainter {
  const SellerDashboardLineChartPainter({
    required this.points,
    required this.lineColor,
    required this.maxValue,
    required this.showFullYearMarkers,
  });

  final List<SellerDashboardSeriesPoint> points;
  final Color lineColor;
  final double maxValue;
  final bool showFullYearMarkers;

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

    if (points.isEmpty) {
      return;
    }

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
          ((point.revenue / safeMax).clamp(0.0, 1.0) * (size.height - 16)) -
          8;
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
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, strokePaint);

    final pointPaint = Paint()..color = lineColor;
    for (final offset in offsets) {
      canvas.drawCircle(offset, 3.5, pointPaint);
      canvas.drawCircle(
        offset,
        7,
        Paint()..color = lineColor.withValues(alpha: 0.12),
      );
    }

    if (showFullYearMarkers && offsets.length >= 6) {
      final selected = offsets[(offsets.length / 2).floor()];
      final dashedPaint = Paint()
        ..color = const Color(0xFF6B7280)
        ..strokeWidth = 1.5;
      var startY = 0.0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(selected.dx, startY),
          Offset(selected.dx, math.min(startY + 7, size.height)),
          dashedPaint,
        );
        startY += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant SellerDashboardLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.showFullYearMarkers != showFullYearMarkers;
  }
}
