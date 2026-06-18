import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/seller_badge_models.dart';
import 'seller_badge_widgets.dart';

Future<void> showSellerBadgeDetailSheet({
  required BuildContext context,
  required SellerBadgeProgress progress,
  void Function(SellerStoreProfileFocus focus)? onNavigateToStoreProfile,
  VoidCallback? onRetry,
}) {
  final isWide = MediaQuery.sizeOf(context).width >= 720;
  if (isWide) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SellerBadgeDetailPanel(
            progress: progress,
            onNavigateToStoreProfile: onNavigateToStoreProfile,
            onRetry: onRetry,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SellerBadgeDetailPanel(
            progress: progress,
            onNavigateToStoreProfile: onNavigateToStoreProfile,
            onRetry: onRetry,
            onClose: () => Navigator.of(context).pop(),
            scrollController: scrollController,
          ),
        );
      },
    ),
  );
}

class SellerBadgeDetailPanel extends StatelessWidget {
  const SellerBadgeDetailPanel({
    super.key,
    required this.progress,
    this.onNavigateToStoreProfile,
    this.onRetry,
    this.onClose,
    this.scrollController,
  });

  final SellerBadgeProgress progress;
  final void Function(SellerStoreProfileFocus focus)? onNavigateToStoreProfile;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final definition = progress.definition;
    final style = SellerBadgeLevelStyle.forLevel(definition.level);
    final canFeature = progress.status == SellerBadgeStatus.earned;
    final canMapPopup = canFeature && definition.publiclyVerifiable;

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SellerBadgeIcon(progress: progress, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      definition.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sellerBadgeStatusLabel(progress.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle('Görev nedir?'),
          _sectionBody(definition.description),
          const SizedBox(height: 14),
          _sectionTitle('Nasıl tamamlanır?'),
          _sectionBody(
            definition.howToComplete ?? definition.requirementLabel,
          ),
          const SizedBox(height: 14),
          _sectionTitle('Hangi veriyle hesaplanır?'),
          _sectionBody(
            definition.dataSourceLabel ?? 'Mağaza performans verileri',
          ),
          const SizedBox(height: 14),
          _sectionTitle('Mevcut ilerleme'),
          _sectionBody(sellerBadgeProgressLabel(progress)),
          if (progress.statusDetail != null &&
              progress.statusDetail!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              progress.statusDetail!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (progress.checklistItems.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Profil kontrol listesi'),
            const SizedBox(height: 8),
            ...progress.checklistItems.map(
              (item) => _checklistRow(context, item),
            ),
          ] else if (progress.incompleteChecklistItems.isEmpty &&
              progress.status == SellerBadgeStatus.inProgress) ...[
            const SizedBox(height: 14),
            _sectionTitle('Eksik adımlar'),
            _sectionBody('Hedefe ulaşmak için ilerlemeye devam et.'),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Rozet kazanılınca nerede görünür?'),
          _sectionBody(
            canFeature
                ? 'Başarılarım vitrininden profilinde (en fazla 4) ve uygunsa harita popup\'ında (en fazla 2) gösterebilirsin.'
                : 'Rozet kazanıldığında Başarılarım vitrininden profil ve harita görünürlüğüne eklenebilir.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _visibilityChip(
                'Profil vitrini',
                canFeature,
                Icons.storefront_outlined,
              ),
              _visibilityChip(
                'Harita popup',
                canMapPopup,
                Icons.map_outlined,
              ),
            ],
          ),
          if (progress.canRetry && onRetry != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Yenile'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }

  Widget _sectionBody(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade700,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _checklistRow(BuildContext context, SellerBadgeChecklistItem item) {
    final color = item.completed ? const Color(0xFF059669) : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: item.completed ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.completed
              ? const Color(0xFFBBF7D0)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: item.completed
                    ? const Color(0xFF166534)
                    : const Color(0xFF334155),
              ),
            ),
          ),
          if (!item.completed &&
              item.focus != null &&
              onNavigateToStoreProfile != null)
            TextButton(
              onPressed: () {
                onNavigateToStoreProfile!(item.focus!);
                onClose?.call();
              },
              child: const Text('Tamamla'),
            ),
        ],
      ),
    );
  }

  Widget _visibilityChip(String label, bool enabled, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.1)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.25)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: enabled ? AppColors.primary : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.primary : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}
