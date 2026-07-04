import 'package:flutter/material.dart';

import '../../helpers/seller_finance_density.dart';
import '../finance_widgets.dart';

typedef FinanceScheduleRowBuilder = Widget Function(Map<String, dynamic> item);

class FinancePaymentCalendarCard extends StatelessWidget {
  const FinancePaymentCalendarCard({
    super.key,
    required this.density,
    required this.loading,
    required this.scheduleItems,
    required this.rowBuilder,
  });

  final SellerFinanceDensity density;
  final bool loading;
  final List<Map<String, dynamic>> scheduleItems;
  final FinanceScheduleRowBuilder rowBuilder;

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
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ödeme Takvimi',
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
            'Yaklaşan ve gecikmiş vadeler',
            style: TextStyle(
              fontSize: density.sectionSubtitleFontSize,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          if (loading && scheduleItems.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: kFinancePrimary,
                ),
              ),
            )
          else if (scheduleItems.isEmpty)
            _emptyState()
          else
            ...scheduleItems.map(rowBuilder),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 28,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          const Text(
            'Yakın vade bulunmuyor.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Yaklaşan ödeme kaydı oluşturulduğunda burada görünür.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF94A3B8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
