import 'package:flutter/material.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    required this.spent,
    required this.total,
    required this.currency,
    this.height = 10,
    super.key,
  });

  final double spent;
  final double total;
  final String currency;
  final double height;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (spent / total).clamp(0.0, 1.0);
    final remaining = (total - spent).clamp(0.0, total);
    final color = progress >= 0.9
        ? const Color(0xFFDC2626)
        : progress >= 0.7
        ? const Color(0xFFF59E0B)
        : const Color(0xFF16A34A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: height,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${spent.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} $currency',
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Kalan ${remaining.toStringAsFixed(0)} $currency',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
