import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/product_pricing.dart';

class ServiceStepperFields extends StatelessWidget {
  const ServiceStepperFields({
    super.key,
    required this.serviceControlType,
    required this.minController,
    required this.maxController,
    required this.stepController,
    this.onChanged,
  });

  final ProductServiceControlType serviceControlType;
  final TextEditingController minController;
  final TextEditingController maxController;
  final TextEditingController stepController;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = switch (serviceControlType) {
      ProductServiceControlType.portionStepper => _FieldLabels(
        title: 'Porsiyon Ayarları',
        description:
            'Yarım, 1, 1.5 ve 2 porsiyon gibi seçenekleri sistem otomatik üretir.',
        minLabel: 'Minimum Porsiyon',
        maxLabel: 'Maksimum Porsiyon',
        stepLabel: 'Artis Adimi',
      ),
      ProductServiceControlType.skewerStepper => _FieldLabels(
        title: 'Şiş Ayarları',
        description: 'Tek, çift ve devam eden şiş seçimlerini tanımlayın.',
        minLabel: 'Minimum Sis',
        maxLabel: 'Maksimum Sis',
        stepLabel: 'Artis Adimi',
      ),
      _ => const _FieldLabels(
        title: '',
        description: '',
        minLabel: '',
        maxLabel: '',
        stepLabel: '',
      ),
    };

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
          Text(
            labels.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            labels.description,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StepperField(
                controller: minController,
                label: labels.minLabel,
                hint:
                    serviceControlType ==
                        ProductServiceControlType.portionStepper
                    ? '0.5'
                    : '1',
                onChanged: onChanged,
              ),
              _StepperField(
                controller: maxController,
                label: labels.maxLabel,
                hint:
                    serviceControlType ==
                        ProductServiceControlType.portionStepper
                    ? '2.0'
                    : '3',
                onChanged: onChanged,
              ),
              _StepperField(
                controller: stepController,
                label: labels.stepLabel,
                hint:
                    serviceControlType ==
                        ProductServiceControlType.portionStepper
                    ? '0.5'
                    : '1',
                helperText:
                    serviceControlType ==
                        ProductServiceControlType.portionStepper
                    ? 'Ondalik desteklenir'
                    : null,
                onChanged: onChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.controller,
    required this.label,
    required this.hint,
    this.helperText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? helperText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]\d{0,2})?$')),
        ],
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
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

class _FieldLabels {
  const _FieldLabels({
    required this.title,
    required this.description,
    required this.minLabel,
    required this.maxLabel,
    required this.stepLabel,
  });

  final String title;
  final String description;
  final String minLabel;
  final String maxLabel;
  final String stepLabel;
}
