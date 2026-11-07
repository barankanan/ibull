import 'package:flutter/material.dart';

class SellerDashboardCardShell extends StatelessWidget {
  const SellerDashboardCardShell({
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SellerDashboardStatusCard extends StatelessWidget {
  const SellerDashboardStatusCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: data['iconBackground'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  data['icon'] as IconData,
                  size: 16,
                  color: data['iconColor'] as Color,
                ),
              ),
              const Spacer(),
              Text(
                data['trend'] as String,
                style: TextStyle(
                  color: data['trendColor'] as Color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] as String,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['value'] as String,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['subtitle'] as String,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class EarningsSummaryCard extends StatelessWidget {
  const EarningsSummaryCard({
    super.key,
    required this.dailyValue,
    required this.monthlyValue,
    required this.dayLabel,
    required this.monthLabel,
    required this.monthOptions,
    required this.selectedMonth,
    required this.formatMonthOption,
    required this.onPickDay,
    required this.onMonthChanged,
  });

  final String dailyValue;
  final String monthlyValue;
  final String dayLabel;
  final String monthLabel;
  final List<DateTime> monthOptions;
  final DateTime selectedMonth;
  final String Function(DateTime month) formatMonthOption;
  final Future<void> Function() onPickDay;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanç',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EarningsFigure(
                  label: 'Günlük',
                  value: dailyValue,
                  caption: dayLabel,
                  onTap: onPickDay,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EarningsFigure(
                  label: 'Aylık',
                  value: monthlyValue,
                  caption: monthLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DateTime>(
            key: ValueKey<DateTime>(selectedMonth),
            initialValue: monthOptions.contains(selectedMonth)
                ? selectedMonth
                : null,
            decoration: const InputDecoration(
              labelText: 'Ay',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: monthOptions
                .map(
                  (month) => DropdownMenuItem<DateTime>(
                    value: month,
                    child: Text(formatMonthOption(month)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) onMonthChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

class _EarningsFigure extends StatelessWidget {
  const _EarningsFigure({
    required this.label,
    required this.value,
    required this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class SellerDashboardRevenueCard extends StatelessWidget {
  const SellerDashboardRevenueCard({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: data['iconBackground'] as Color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  data['icon'] as IconData,
                  size: 16,
                  color: data['iconColor'] as Color,
                ),
              ),
              const Spacer(),
              Text(
                data['trend'] as String,
                style: TextStyle(
                  color: data['trendColor'] as Color,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['title'] as String,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data['value'] as String,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data['subtitle'] as String,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerDashboardRangeChip extends StatelessWidget {
  const SellerDashboardRangeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF475569),
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerDashboardMetricInline extends StatelessWidget {
  const SellerDashboardMetricInline({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerDashboardInlineDivider extends StatelessWidget {
  const SellerDashboardInlineDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.only(right: 14),
      color: const Color(0xFFE5E7EB),
    );
  }
}

class SellerDashboardLegendPill extends StatelessWidget {
  const SellerDashboardLegendPill({
    super.key,
    required this.label,
    required this.color,
    this.outlined = false,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: outlined ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SellerDashboardPerformanceCard extends StatelessWidget {
  const SellerDashboardPerformanceCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.valueSuffix,
    required this.progress,
    required this.progressColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String valueSuffix;
  final double progress;
  final Color progressColor;

  @override
  Widget build(BuildContext context) {
    return SellerDashboardCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: valueSuffix,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }
}
