import 'package:flutter/material.dart';

import '../helpers/admin_panel_density.dart';

class AdminFinanceSegmentHeader extends StatelessWidget {
  const AdminFinanceSegmentHeader({
    super.key,
    required this.density,
    required this.title,
    required this.subtitle,
    this.periodLabel,
    this.icon = Icons.insights_outlined,
    this.accent = const Color(0xFF111827),
    this.trailing,
  });

  final AdminPanelDensity density;
  final String title;
  final String subtitle;
  final String? periodLabel;
  final IconData icon;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(density.financeSectionPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.08), const Color(0xFFF8FAFC)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: density.financeSectionTitleFontSize + 1,
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
                    height: 1.35,
                  ),
                ),
                if (periodLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Dönem: $periodLabel',
                    style: TextStyle(
                      fontSize: density.financeKpiSubtitleFontSize,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
