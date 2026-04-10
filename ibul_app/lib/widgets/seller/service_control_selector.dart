import 'package:flutter/material.dart';

import '../../models/product_pricing.dart';

class ServiceControlSelector extends StatelessWidget {
  const ServiceControlSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = ProductServiceControlType.values,
    this.title = 'Servis Kontrolu',
  });

  final ProductServiceControlType value;
  final ValueChanged<ProductServiceControlType> onChanged;
  final Iterable<ProductServiceControlType> options;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((type) {
            final selected = type == value;
            return ChoiceChip(
              label: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(type.sellerLabelTr),
              ),
              selected: selected,
              onSelected: (_) => onChanged(type),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF6B21A8),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF6B21A8)
                    : const Color(0xFFE5E7EB),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ],
    );
  }
}
