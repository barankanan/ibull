import 'package:flutter/material.dart';

import '../../../../../services/printer_print_size_settings.dart';

/// Yazıcı Ayarları — Baskı Boyutu (Küçük / Normal / Büyük / Çok Büyük).
class PrinterPrintSizeSettingsSection extends StatelessWidget {
  const PrinterPrintSizeSettingsSection({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final PrinterPrintSizeSettings settings;
  final ValueChanged<PrinterPrintSizeSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Baskı Boyutu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Yazı Boyutu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        KeyedSubtree(
          key: const Key('print_size_chips'),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PrintSizePreset.values.map((preset) {
              final isSelected = settings.preset == preset;
              return GestureDetector(
                key: Key('print_size_${preset.bridgeValue}'),
                onTap: () => onChanged(
                  settings.copyWith(preset: preset),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 130),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF8B5CF6)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Text(
                    preset.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Baskıdaki yazıların boyutunu ayarlayın. Mutfak, adisyon ve test fişlerinde geçerlidir.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
