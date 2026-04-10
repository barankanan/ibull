import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../models/product_pricing.dart';

class WeightSelector extends StatelessWidget {
  const WeightSelector({
    super.key,
    required this.selectedGrams,
    required this.minWeightGrams,
    required this.weightStepGrams,
    required this.presetOptions,
    required this.onChanged,
    this.maxWeightGrams,
  });

  final int selectedGrams;
  final int minWeightGrams;
  final int weightStepGrams;
  final int? maxWeightGrams;
  final List<int> presetOptions;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canDecrease = selectedGrams > minWeightGrams;
    final canIncrease =
        maxWeightGrams == null || selectedGrams < maxWeightGrams!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gramaj',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              _StepperButton(
                icon: Icons.remove_rounded,
                enabled: canDecrease,
                onTap: () => onChanged(
                  ProductPriceCalculator.clampWeightSelection(
                    selectedGrams - weightStepGrams,
                    minWeightGrams: minWeightGrams,
                    weightStepGrams: weightStepGrams,
                    maxWeightGrams: maxWeightGrams,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      ProductPriceCalculator.formatWeight(selectedGrams),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ProductPriceCalculator.formatWeight(weightStepGrams)} artış',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _StepperButton(
                icon: Icons.add_rounded,
                enabled: canIncrease,
                onTap: () => onChanged(
                  ProductPriceCalculator.clampWeightSelection(
                    selectedGrams + weightStepGrams,
                    minWeightGrams: minWeightGrams,
                    weightStepGrams: weightStepGrams,
                    maxWeightGrams: maxWeightGrams,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presetOptions.map((grams) {
              final selected = grams == selectedGrams;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(ProductPriceCalculator.formatWeight(grams)),
                  selected: selected,
                  onSelected: (_) => onChanged(grams),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF374151),
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFE5E7EB),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : Colors.grey.shade400,
        ),
      ),
    );
  }
}
