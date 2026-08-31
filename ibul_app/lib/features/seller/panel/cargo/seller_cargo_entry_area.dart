import 'package:flutter/material.dart';

import '../../../../core/constants.dart';

class SellerCargoEntryArea extends StatelessWidget {
  const SellerCargoEntryArea({
    super.key,
    required this.walletText,
    required this.walletReady,
    required this.onTopup,
    required this.onAddOrder,
  });

  final String walletText;
  final bool walletReady;
  final VoidCallback onTopup;
  final VoidCallback onAddOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E4FF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kargo Cik Alani',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2A44),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dis kaynakli siparisleri buradan ekleyip dogrudan IHIZ teslimat akisina aktarabilirsiniz.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
                ),
                const SizedBox(height: 8),
                Text(
                  walletText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: walletReady
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFFB42318),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Not: Kargo siparisi acmak icin satıcı cüzdaninda bakiye bulunmasi zorunludur.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onTopup,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Bakiye Yukle'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: const BorderSide(color: Color(0xFFD0DBFF)),
                  foregroundColor: const Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onAddOrder,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Kargo Siparisi Ekle'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
