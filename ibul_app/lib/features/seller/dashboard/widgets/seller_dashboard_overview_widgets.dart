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

/// Tek kartta günlük / aylık kazanç özeti — Genel Bakış ve Finans modülünde ortak.
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
    this.loading = false,
    this.wrapInShell = true,
  });

  final String dailyValue;
  final String monthlyValue;
  final String dayLabel;
  final String monthLabel;
  final List<DateTime> monthOptions;
  final DateTime selectedMonth;
  final String Function(DateTime month) formatMonthOption;
  final VoidCallback onPickDay;
  final ValueChanged<DateTime> onMonthChanged;
  final bool loading;
  final bool wrapInShell;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.payments_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kazanç Özeti',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seçili gün ve ay için satış cirosu',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      height: 1.3,
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
                _FilterPill(
                  icon: Icons.calendar_today_rounded,
                  label: dayLabel,
                  onTap: loading ? null : onPickDay,
                ),
                _MonthFilterPill(
                  value: selectedMonth,
                  options: monthOptions,
                  formatLabel: formatMonthOption,
                  onChanged: loading ? null : onMonthChanged,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: loading
              ? const SizedBox(
                  height: 96,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Günlük Kazanç',
                          value: dailyValue,
                          caption: dayLabel,
                          accent: const Color(0xFF3B82F6),
                          icon: Icons.wb_sunny_outlined,
                        ),
                      ),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Aylık Kazanç',
                          value: monthlyValue,
                          caption: monthLabel,
                          accent: const Color(0xFF10B981),
                          icon: Icons.calendar_month_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );

    if (!wrapInShell) return content;

    return SellerDashboardCardShell(
      padding: const EdgeInsets.all(20),
      child: content,
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthFilterPill extends StatelessWidget {
  const _MonthFilterPill({
    required this.value,
    required this.options,
    required this.formatLabel,
    required this.onChanged,
  });

  final DateTime value;
  final List<DateTime> options;
  final String Function(DateTime month) formatLabel;
  final ValueChanged<DateTime>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime>(
          value: options.firstWhere(
            (m) => m.year == value.year && m.month == value.month,
            orElse: () => options.first,
          ),
          isDense: true,
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
          items: options
              .map(
                (month) => DropdownMenuItem(
                  value: month,
                  child: Text(formatLabel(month)),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged == null
              ? null
              : (selected) {
                  if (selected != null) onChanged!(selected);
                },
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.caption,
    required this.accent,
    required this.icon,
  });

  final String label;
  final String value;
  final String caption;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: accent.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
