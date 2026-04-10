import 'package:flutter/material.dart';

import '../../core/constants.dart';

class ProductQuantityStepper extends StatelessWidget {
  const ProductQuantityStepper({
    super.key,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.addLabel = 'Ekle',
    this.valueLabel,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final String addLabel;
  final String? valueLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 38.0 : 46.0;
    final iconSize = compact ? 18.0 : 20.0;
    final horizontalPadding = compact ? 12.0 : 16.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: quantity <= 0
          ? Material(
              key: const ValueKey('add'),
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onAdd,
                child: Ink(
                  height: height,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        Color.lerp(
                          AppColors.primary,
                          const Color(0xFF5B1FBF),
                          0.45,
                        )!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: iconSize,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        addLabel,
                        style: TextStyle(
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              key: const ValueKey('stepper'),
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StepButton(
                    icon: quantity == 1
                        ? Icons.remove_rounded
                        : Icons.remove_rounded,
                    onTap: onDecrement,
                    compact: compact,
                  ),
                  Container(
                    constraints: BoxConstraints(minWidth: compact ? 52 : 64),
                    alignment: Alignment.center,
                    child: Text(
                      valueLabel ?? '$quantity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add_rounded,
                    onTap: onIncrement,
                    compact: compact,
                  ),
                ],
              ),
            ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 40.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: compact ? 18 : 20, color: AppColors.primary),
        ),
      ),
    );
  }
}
