import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class SavedPaymentCardsEmptyState extends StatelessWidget {
  const SavedPaymentCardsEmptyState({
    super.key,
    required this.onAddCard,
  });

  final VoidCallback onAddCard;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.credit_card_off_outlined,
                size: 36,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Kayıtlı kartın yok',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sipariş verirken kartını kaydedebilir veya buradan yeni kart ekleyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddCard,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Kart Ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
