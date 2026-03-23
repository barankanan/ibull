import 'package:flutter/material.dart';

class BudgetPlanner extends StatelessWidget {
  const BudgetPlanner({
    required this.dailyBudgetController,
    required this.totalBudgetController,
    required this.durationController,
    required this.onDailyBudgetChanged,
    required this.onTotalBudgetChanged,
    required this.onDurationChanged,
    required this.estimatedConversions,
    required this.suggestedDailyBudget,
    required this.suggestedTotalBudget,
    required this.budgetConfigured,
    required this.onApplySuggestedBudget,
    super.key,
  });

  final TextEditingController dailyBudgetController;
  final TextEditingController totalBudgetController;
  final TextEditingController durationController;
  final ValueChanged<String> onDailyBudgetChanged;
  final ValueChanged<String> onTotalBudgetChanged;
  final ValueChanged<String> onDurationChanged;
  final int estimatedConversions;
  final double suggestedDailyBudget;
  final double suggestedTotalBudget;
  final bool budgetConfigured;
  final VoidCallback onApplySuggestedBudget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Butceyi siz belirleyin',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budgetConfigured
                          ? 'Mevcut plani duzenleyebilir veya alanlari degistirerek yeni butce olusturabilirsiniz.'
                          : 'Alanlar varsayilan olarak bos gelir. Isterseniz sistemin onerilen butcesini tek tikla uygulayabilirsiniz.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Oneri: ${suggestedDailyBudget.toStringAsFixed(0)} TRY / gun • ${suggestedTotalBudget.toStringAsFixed(0)} TRY toplam',
                          style: const TextStyle(
                            color: Color(0xFF1E3A8A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: onApplySuggestedBudget,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Onerilen butceyi uygula'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _BudgetField(
                controller: dailyBudgetController,
                label: 'Gunluk butce',
                suffix: 'TRY',
                icon: Icons.payments_outlined,
                onChanged: onDailyBudgetChanged,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _BudgetField(
                controller: totalBudgetController,
                label: 'Toplam butce',
                suffix: 'TRY',
                icon: Icons.account_balance_wallet_outlined,
                onChanged: onTotalBudgetChanged,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _BudgetField(
                controller: durationController,
                label: 'Kampanya suresi',
                suffix: 'Gun',
                icon: Icons.calendar_month_outlined,
                onChanged: onDurationChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: Color(0xFF0369A1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tahmini donusum',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$estimatedConversions tahmini aksiyon bu plan icin uygun gorunuyor.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetField extends StatelessWidget {
  const _BudgetField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: suffix,
      ),
    );
  }
}
