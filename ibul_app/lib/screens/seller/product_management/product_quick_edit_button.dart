import 'package:flutter/material.dart';

import '../../../core/constants.dart';

class ProductQuickEditButton extends StatelessWidget {
  const ProductQuickEditButton({
    super.key,
    required this.isActive,
    required this.onPressed,
  });

  final bool isActive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = isActive
        ? ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          );

    final child = isActive
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Düzenlemeyi Bitir'),
            style: style,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('Hızlı Düzenle'),
            style: style,
          );

    return child;
  }
}
