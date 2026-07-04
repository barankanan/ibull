import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../helpers/seller_finance_density.dart';
import '../finance_widgets.dart';

class SellerFinancePageHeader extends StatelessWidget {
  const SellerFinancePageHeader({
    super.key,
    required this.density,
    required this.onRefresh,
    this.isRefreshing = false,
    this.lastUpdatedAt,
  });

  final SellerFinanceDensity density;
  final VoidCallback onRefresh;
  final bool isRefreshing;
  final DateTime? lastUpdatedAt;

  @override
  Widget build(BuildContext context) {
    final periodLabel = DateFormat('MMMM yyyy', 'tr_TR').format(DateTime.now());
    final lastUpdatedText = lastUpdatedAt == null
        ? null
        : 'Son güncelleme: ${DateFormat('HH:mm', 'tr_TR').format(lastUpdatedAt!)}';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: density.isCompact ? 14 : 18,
        vertical: density.isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kFinancePrimary.withValues(alpha: 0.07),
            const Color(0xFFF8FAFC),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(density.cardRadius),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: kFinancePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: kFinancePrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finans Merkezi',
                  style: TextStyle(
                    fontSize: density.headerTitleFontSize,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gelir, gider, tahsilat ve ödeme durumunu tek ekrandan takip edin.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: density.headerSubtitleFontSize,
                    color: const Color(0xFF6B7280),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _periodChip(periodLabel),
                    if (lastUpdatedText != null)
                      Text(
                        lastUpdatedText,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: isRefreshing ? null : onRefresh,
            style: FilledButton.styleFrom(
              backgroundColor: kFinancePrimary,
              disabledBackgroundColor: kFinancePrimary.withValues(alpha: 0.6),
              padding: EdgeInsets.symmetric(
                horizontal: density.isCompact ? 12 : 14,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: isRefreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              isRefreshing ? 'Yenileniyor' : 'Yenile',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_outlined,
            size: 12,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
