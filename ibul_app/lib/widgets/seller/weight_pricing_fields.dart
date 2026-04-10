import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WeightPricingFields extends StatelessWidget {
  const WeightPricingFields({
    super.key,
    required this.minWeightController,
    required this.weightStepController,
    required this.defaultWeightController,
    required this.maxWeightController,
    this.onChanged,
  });

  final TextEditingController minWeightController;
  final TextEditingController weightStepController;
  final TextEditingController defaultWeightController;
  final TextEditingController maxWeightController;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gramaj Ayarları',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Kiloluk ürün için minimum, varsayılan, artış ve maksimum gramaj seçeneklerini belirleyin.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _WeightField(
                controller: minWeightController,
                label: 'Minimum Gramaj',
                hint: '500',
                suffix: 'g',
                onChanged: onChanged,
              ),
              _WeightField(
                controller: defaultWeightController,
                label: 'Varsayılan Gramaj',
                hint: '500',
                suffix: 'g',
                onChanged: onChanged,
              ),
              _WeightField(
                controller: weightStepController,
                label: 'Artış Adımı',
                hint: '250',
                suffix: 'g',
                onChanged: onChanged,
              ),
              _WeightField(
                controller: maxWeightController,
                label: 'Maksimum Gramaj',
                hint: '1500',
                suffix: 'g',
                helperText: 'Boş bırakılabilir',
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suffix,
    this.helperText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String suffix;
  final String? helperText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          suffixText: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
