import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../helpers/finance_chart_helpers.dart';

class FinanceRangeSelector extends StatelessWidget {
  const FinanceRangeSelector({
    super.key,
    required this.selected,
    required this.onSelected,
    this.customFrom,
    this.customTo,
    this.onCustomRangeTap,
  });

  final FinancePerformanceRange selected;
  final ValueChanged<FinancePerformanceRange> onSelected;
  final DateTime? customFrom;
  final DateTime? customTo;
  final VoidCallback? onCustomRangeTap;

  static const _options = <({FinancePerformanceRange range, String label})>[
    (range: FinancePerformanceRange.days7, label: '7 Gün'),
    (range: FinancePerformanceRange.days30, label: '30 Gün'),
    (range: FinancePerformanceRange.days90, label: '3 Ay'),
    (range: FinancePerformanceRange.days180, label: '6 Ay'),
    (range: FinancePerformanceRange.year1, label: '1 Yıl'),
    (range: FinancePerformanceRange.custom, label: 'Özel Tarih'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        ..._options.map((opt) {
          final isSelected = selected == opt.range;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (opt.range == FinancePerformanceRange.custom) {
                  onCustomRangeTap?.call();
                  return;
                }
                onSelected(opt.range);
              },
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF065F46)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF065F46)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        }),
        if (selected == FinancePerformanceRange.custom &&
            customFrom != null &&
            customTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              '${DateFormat('d MMM', 'tr_TR').format(customFrom!)} – '
              '${DateFormat('d MMM yyyy', 'tr_TR').format(customTo!)}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
      ],
    );
  }
}

class FinanceSeriesLegend extends StatelessWidget {
  const FinanceSeriesLegend({
    super.key,
    required this.series,
    required this.enabled,
    required this.onToggle,
  });

  final List<FinanceChartSeriesConfig> series;
  final Set<FinanceChartSeriesId> enabled;
  final ValueChanged<FinanceChartSeriesId> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: series.map((config) {
        final active = enabled.contains(config.id);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onToggle(config.id),
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? config.color.withValues(alpha: 0.12)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: active
                      ? config.color.withValues(alpha: 0.35)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? config.color : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    config.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: active
                          ? const Color(0xFF334155)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}
