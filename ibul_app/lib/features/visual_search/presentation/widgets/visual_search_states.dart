import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../domain/visual_search_models.dart';

class VisualSearchStatusChip extends StatelessWidget {
  const VisualSearchStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  final String label;
  final Color color;
  final Color? background;

  factory VisualSearchStatusChip.forStatus(VisualSearchJobStatus status) {
    switch (status) {
      case VisualSearchJobStatus.completed:
        return const VisualSearchStatusChip(
          label: 'Tamamlandı',
          color: AppColors.success,
          background: AppColors.successSoft,
        );
      case VisualSearchJobStatus.failed:
        return const VisualSearchStatusChip(
          label: 'Başarısız',
          color: AppColors.danger,
          background: AppColors.dangerSoft,
        );
      case VisualSearchJobStatus.processing:
        return const VisualSearchStatusChip(
          label: 'İşleniyor',
          color: AppColors.warning,
          background: AppColors.warningSoft,
        );
      case VisualSearchJobStatus.pending:
        return const VisualSearchStatusChip(
          label: 'Sırada',
          color: AppColors.primary,
          background: AppColors.softPurple,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class VisualSearchStatePanel extends StatelessWidget {
  const VisualSearchStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.softPurple,
                minHeight: 4,
              ),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.softPurple,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textGrey,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
