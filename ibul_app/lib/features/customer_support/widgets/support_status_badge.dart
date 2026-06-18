import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/customer_support_models.dart';

class SupportStatusBadge extends StatelessWidget {
  const SupportStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final CustomerSupportStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: colors.foreground,
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  ({Color background, Color foreground}) _colorsFor(
    CustomerSupportStatus status,
  ) {
    switch (status) {
      case CustomerSupportStatus.open:
        return (background: const Color(0xFFEEF2FF), foreground: AppColors.primary);
      case CustomerSupportStatus.reviewing:
        return (background: const Color(0xFFF3E8FF), foreground: AppColors.primary);
      case CustomerSupportStatus.answered:
        return (background: const Color(0xFFECFDF5), foreground: const Color(0xFF059669));
      case CustomerSupportStatus.waitingUser:
        return (background: const Color(0xFFFEF3C7), foreground: const Color(0xFFD97706));
      case CustomerSupportStatus.resolved:
        return (background: const Color(0xFFF3F4F6), foreground: const Color(0xFF6B7280));
      case CustomerSupportStatus.closed:
        return (background: const Color(0xFFF3F4F6), foreground: const Color(0xFF6B7280));
      case CustomerSupportStatus.rejected:
        return (background: const Color(0xFFFEE2E2), foreground: const Color(0xFFB91C1C));
    }
  }
}

class SupportComingSoonCard extends StatelessWidget {
  const SupportComingSoonCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: null,
            child: const Text('Yakında'),
          ),
        ],
      ),
    );
  }
}
