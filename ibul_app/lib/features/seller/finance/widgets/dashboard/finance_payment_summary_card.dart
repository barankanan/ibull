import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';
import '../finance_widgets.dart';

class FinancePaymentSummaryRow {
  const FinancePaymentSummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.isCritical = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isCritical;
}

class FinancePaymentSummaryCard extends StatelessWidget {
  const FinancePaymentSummaryCard({
    super.key,
    required this.density,
    required this.rows,
    this.onViewDetails,
  });

  final SellerFinanceDensity density;
  final List<FinancePaymentSummaryRow> rows;
  final VoidCallback? onViewDetails;

  @override
  Widget build(BuildContext context) {
    return FinSurfaceCard(
      padding: EdgeInsets.all(density.isCompact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: Color(0xFFD97706),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ödeme Özeti',
                  style: TextStyle(
                    fontSize: density.sectionTitleFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Bekleyen, gecikmiş ve yaklaşan ödemeler',
            style: TextStyle(
              fontSize: density.sectionSubtitleFontSize,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(_row),
          if (onViewDetails != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                label: const Text('Detayları Gör'),
                style: TextButton.styleFrom(
                  foregroundColor: kFinancePrimary,
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(FinancePaymentSummaryRow row) {
    final valueColor = row.isCritical
        ? row.accent
        : (row.value == '0' || row.value == '0 kayıt' || row.value == '₺0,00'
              ? const Color(0xFF64748B)
              : const Color(0xFF111827));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: row.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(row.icon, size: 14, color: row.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Text(
            row.value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
