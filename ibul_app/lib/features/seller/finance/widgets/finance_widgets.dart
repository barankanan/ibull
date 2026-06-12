import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import '../models/finance_models.dart';

// ─────────────────────────────────────────
// Ortak renk & sabit tanımlar
// ─────────────────────────────────────────

const kFinancePrimary = Color(0xFF065F46);
const kFinanceAccent = Color(0xFF10B981);
const kFinanceSurface = Color(0xFFF8FAFC);
const kFinanceDivider = Color(0xFFE2E8F0);
final _currFmt = NumberFormat('#,##0.00', 'tr_TR');

String fmtCurrency(double v) => '₺${_currFmt.format(v)}';
String fmtDate(DateTime d) => DateFormat('dd.MM.yyyy', 'tr_TR').format(d);
String fmtMonth(int m, int y) => DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(y, m));

class FinSurfaceCard extends StatelessWidget {
  const FinSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class FinMetricRow extends StatelessWidget {
  const FinMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF0F172A),
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class FinSectionSwitchChip extends StatelessWidget {
  const FinSectionSwitchChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? kFinancePrimary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kFinancePrimary : const Color(0xFFE2E8F0),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: kFinancePrimary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FinMiniToolbar extends StatelessWidget {
  const FinMiniToolbar({
    super.key,
    required this.children,
    this.embedded = false,
  });

  final List<Widget> children;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: embedded ? null : const Border(bottom: BorderSide(color: kFinanceDivider)),
        borderRadius: embedded ? BorderRadius.circular(12) : null,
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: children,
      ),
    );
  }
}

class FinToolbarAction extends StatelessWidget {
  const FinToolbarAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kFinancePrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        icon: Icon(icon, size: 14),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF334155),
        side: const BorderSide(color: kFinanceDivider),
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label),
    );
  }
}

// ─────────────────────────────────────────
// KPI Card
// ─────────────────────────────────────────

class FinKpiCard extends StatelessWidget {
  const FinKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.icon,
    this.color = kFinanceAccent,
    this.onTap,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? color.withValues(alpha: 0.35) : kFinanceDivider,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────

class FinSectionHeader extends StatelessWidget {
  const FinSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.actionLabel,
  });

  final String title;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (action != null && actionLabel != null)
            GestureDetector(
              onTap: action,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kFinancePrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Status Badge
// ─────────────────────────────────────────

class FinStatusBadge extends StatelessWidget {
  const FinStatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────

class FinEmptyState extends StatelessWidget {
  const FinEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    this.actionLabel,
  });

  final String message;
  final IconData icon;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add, size: 16),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: kFinancePrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Add Button (FAB-style for tab content)
// ─────────────────────────────────────────

class FinAddButton extends StatelessWidget {
  const FinAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: kFinancePrimary,
          minimumSize: const Size(double.infinity, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Loading Overlay
// ─────────────────────────────────────────

class FinLoadingOverlay extends StatelessWidget {
  const FinLoadingOverlay({super.key, this.message = 'Yükleniyor...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: kFinancePrimary,
            strokeWidth: 2,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Error Card
// ─────────────────────────────────────────

class FinErrorCard extends StatelessWidget {
  const FinErrorCard({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRetry,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Form helpers
// ─────────────────────────────────────────

class FinTextField extends StatelessWidget {
  const FinTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.prefixText,
    this.suffixText,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final String? prefixText;
  final String? suffixText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        suffixText: suffixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kFinanceDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kFinanceDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kFinancePrimary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}

// ─────────────────────────────────────────
// Mini trend bar chart (for overview)
// ─────────────────────────────────────────

class FinTrendChart extends StatelessWidget {
  const FinTrendChart({super.key, required this.points, this.height = 120});

  final List<({String label, double income, double expense})> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Veri yok', style: TextStyle(color: Color(0xFF94A3B8))),
        ),
      );
    }
    final maxVal = points.fold<double>(
        1,
        (m, p) => [m, p.income, p.expense].reduce((a, b) => a > b ? a : b));

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TrendPainter(points: points, maxVal: maxVal),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.points, required this.maxVal});

  final List<({String label, double income, double expense})> points;
  final double maxVal;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final n = points.length;
    final w = size.width;
    final h = size.height - 20; // bottom margin for labels

    double x(int i) => n == 1 ? w / 2 : i * (w / (n - 1));
    double y(double v) => h - (v / maxVal * h).clamp(0, h);

    final incomePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final expensePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final incPath = Path();
    final expPath = Path();

    for (int i = 0; i < n; i++) {
      final px = x(i);
      final iy = y(points[i].income);
      final ey = y(points[i].expense);
      if (i == 0) {
        incPath.moveTo(px, iy);
        expPath.moveTo(px, ey);
      } else {
        incPath.lineTo(px, iy);
        expPath.lineTo(px, ey);
      }
      // Label
      if (n <= 6) {
        final tp = TextPainter(
          text: TextSpan(
            text: points[i].label,
            style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(px - tp.width / 2, h + 4));
      }
    }

    canvas.drawPath(incPath, incomePaint);
    canvas.drawPath(expPath, expensePaint);
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points || old.maxVal != maxVal;
}

// ─────────────────────────────────────────
// Gelir & Sipariş Grafiği (günlük ciro barları + sipariş adedi çizgisi)
// Genel Bakış'taki grafiğin finans karşılığı.
// ─────────────────────────────────────────

class FinSalesChart extends StatelessWidget {
  const FinSalesChart({
    super.key,
    required this.points,
    this.height = 200,
    this.embedded = false,
  });

  final List<DailySalesPoint> points;
  final double height;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final totalRevenue =
        points.fold<double>(0, (s, p) => s + p.revenue);
    final totalOrders = points.fold<int>(0, (s, p) => s + p.orderCount);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          Row(
            children: [
              const Icon(Icons.show_chart_rounded,
                  size: 16, color: kFinancePrimary),
              const SizedBox(width: 6),
              const Text(
                'Gelir & Sipariş Grafiği',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              _legendDot(kFinanceAccent, 'Gelir'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFF3B82F6), 'Sipariş'),
            ],
          ),
          const SizedBox(height: 6),
        ] else ...[
          Row(
            children: [
              _legendDot(kFinanceAccent, 'Gelir'),
              const SizedBox(width: 10),
              _legendDot(const Color(0xFF3B82F6), 'Sipariş'),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            _miniStat('Toplam Ciro', fmtCurrency(totalRevenue),
                kFinanceAccent),
            const SizedBox(width: 16),
            _miniStat('Sipariş', '$totalOrders adet',
                const Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: totalRevenue <= 0 && totalOrders <= 0
              ? const Center(
                  child: Text(
                    'Bu dönemde kapatılmış masa veya online satış yok.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                )
              : CustomPaint(
                  painter: _SalesChartPainter(points: points),
                  child: const SizedBox.expand(),
                ),
        ),
      ],
    );

    if (embedded) return content;

    return FinSurfaceCard(
      padding: const EdgeInsets.all(14),
      child: content,
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  _SalesChartPainter({required this.points});

  final List<DailySalesPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final n = points.length;
    const bottomMargin = 18.0;
    final h = size.height - bottomMargin;
    final w = size.width;

    final maxRevenue = points.fold<double>(
        1, (m, p) => p.revenue > m ? p.revenue : m);
    final maxOrders = points.fold<int>(
        1, (m, p) => p.orderCount > m ? p.orderCount : m);

    // ── Günlük ciro barları ──
    final slot = w / n;
    final barWidth = (slot * 0.55).clamp(2.0, 22.0);
    final barPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final p = points[i];
      final barH = (p.revenue / maxRevenue).clamp(0.0, 1.0) * (h - 4);
      final cx = slot * i + slot / 2;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barWidth / 2, h - barH, barWidth, barH),
        const Radius.circular(3),
      );
      barPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF34D399), Color(0xFF059669)],
      ).createShader(Rect.fromLTWH(cx - barWidth / 2, h - barH, barWidth, barH));
      canvas.drawRRect(rect, barPaint);
    }

    // ── Sipariş adedi çizgisi ──
    final linePaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = const Color(0xFF3B82F6);
    final path = Path();
    double xAt(int i) => slot * i + slot / 2;
    double yAt(int orders) =>
        h - (orders / maxOrders).clamp(0.0, 1.0) * (h - 6);
    for (var i = 0; i < n; i++) {
      final px = xAt(i);
      final py = yAt(points[i].orderCount);
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
          Offset(xAt(i), yAt(points[i].orderCount)), 2.4, dotPaint);
    }

    // ── X ekseni etiketleri (yer varsa) ──
    final maxLabels = (w / 28).floor().clamp(1, n);
    final step = (n / maxLabels).ceil();
    for (var i = 0; i < n; i += step) {
      final label = '${points[i].date.day}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xAt(i) - tp.width / 2, h + 4));
    }
  }

  @override
  bool shouldRepaint(_SalesChartPainter old) => old.points != points;
}

// ─────────────────────────────────────────
// Health Score Gauge
// ─────────────────────────────────────────

class FinHealthGauge extends StatelessWidget {
  const FinHealthGauge({super.key, required this.score, required this.color, required this.label});

  final int score;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const Text(
                    '/100',
                    style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
