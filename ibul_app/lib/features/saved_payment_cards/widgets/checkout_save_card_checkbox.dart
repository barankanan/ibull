import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class CheckoutSaveCardCheckbox extends StatelessWidget {
  const CheckoutSaveCardCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Kartımı sonraki alışverişlerim için kaydet',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'CVV kaydedilmez. Kart güvenli ödeme altyapısı ile saklanır.',
          style: TextStyle(fontSize: 12, height: 1.35),
        ),
      ),
    );
  }
}
