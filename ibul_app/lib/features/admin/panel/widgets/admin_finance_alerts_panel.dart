import 'package:flutter/material.dart';

import '../helpers/admin_finance_analytics_helper.dart';
import '../helpers/admin_panel_density.dart';

class AdminFinanceAlertsPanel extends StatelessWidget {
  const AdminFinanceAlertsPanel({
    super.key,
    required this.density,
    required this.alerts,
  });

  final AdminPanelDensity density;
  final List<AdminFinanceAlert> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(density.financeSectionPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(density.financeSectionRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Finans Uyarıları',
            style: TextStyle(
              fontSize: density.financeSectionTitleFontSize,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          if (alerts.isEmpty)
            Text(
              'Kritik finans uyarısı yok.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: alerts.map(_alertChip).toList(),
            ),
        ],
      ),
    );
  }

  Widget _alertChip(AdminFinanceAlert alert) {
    final (color, label) = switch (alert.severity) {
      AdminFinanceAlertSeverity.critical => (const Color(0xFFDC2626), 'Kritik'),
      AdminFinanceAlertSeverity.warning => (const Color(0xFFF97316), 'Uyarı'),
      AdminFinanceAlertSeverity.info => (const Color(0xFF2563EB), 'Bilgi'),
    };
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  alert.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700, height: 1.3),
          ),
        ],
      ),
    );
  }
}
