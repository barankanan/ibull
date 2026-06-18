import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/seller_badge_models.dart';
import 'seller_badge_detail_sheet.dart';
import 'seller_badge_icon_widget.dart';

export 'seller_badge_icon_widget.dart';

class SellerGlowReplayButton extends StatelessWidget {
  const SellerGlowReplayButton({
    super.key,
    required this.onPressed,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Rozet animasyonunu tekrar oynat',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: compact ? 5 : 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0x1A6D28D9),
                  Color(0x1F0EA5E9),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: compact ? 14 : 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'İkonu İzle',
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SellerBadgeRow extends StatelessWidget {
  const SellerBadgeRow({
    super.key,
    required this.badges,
    this.maxVisible = 2,
    this.animateGlow = false,
    this.glowReplayToken = 0,
    this.compact = true,
  });

  final List<SellerBadgeProgress> badges;
  final int maxVisible;
  final bool animateGlow;
  final int glowReplayToken;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    final visible = badges.take(maxVisible).toList(growable: false);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          SellerBadgeIcon(
            progress: visible[i],
            size: compact ? 34 : 42,
            showLabel: !compact,
            animateGlow: animateGlow,
            glowReplayToken: glowReplayToken,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

/// Vitrin rozeti — FilterChip check overlay yerine premium seçim halkası.
class SellerFeaturedBadgeTile extends StatelessWidget {
  const SellerFeaturedBadgeTile({
    super.key,
    required this.progress,
    required this.selected,
    required this.onTap,
    this.animateGlow = false,
    this.glowReplayToken = 0,
    this.onReplayGlow,
  });

  final SellerBadgeProgress progress;
  final bool selected;
  final VoidCallback onTap;
  final bool animateGlow;
  final int glowReplayToken;
  final VoidCallback? onReplayGlow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.07)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SellerBadgeIcon(
                        progress: progress,
                        size: 32,
                        animateGlow: animateGlow,
                        glowReplayToken: glowReplayToken,
                      ),
                      if (selected)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.definition.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'Vitrinde',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (progress.showsGlowReplayButton && onReplayGlow != null) ...[
                const SizedBox(height: 8),
                SellerGlowReplayButton(
                  onPressed: onReplayGlow!,
                  compact: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SellerBadgeTaskCard extends StatelessWidget {
  const SellerBadgeTaskCard({
    super.key,
    required this.progress,
    this.animateGlow = false,
    this.glowReplayToken = 0,
    this.onShowDetail,
    this.onNavigateToStoreProfile,
    this.onRetry,
    this.onReplayGlow,
  });

  final SellerBadgeProgress progress;
  final bool animateGlow;
  final int glowReplayToken;
  final VoidCallback? onShowDetail;
  final void Function(SellerStoreProfileFocus focus)? onNavigateToStoreProfile;
  final VoidCallback? onRetry;
  final VoidCallback? onReplayGlow;

  @override
  Widget build(BuildContext context) {
    final style = SellerBadgeLevelStyle.forLevel(progress.definition.level);
    final statusLabel = sellerBadgeStatusLabel(progress.status);
    final missingItems = progress.incompleteChecklistItems;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SellerBadgeIcon(
                progress: progress,
                size: 44,
                animateGlow: animateGlow,
                glowReplayToken: glowReplayToken,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.definition.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress.definition.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: style.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: _progressValue(progress),
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _metaChip(statusLabel, _statusColor(progress.status)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sellerBadgeProgressLabel(progress),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          if (missingItems.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eksik: ${missingItems.map((e) => e.label).join(', ')}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                  if (missingItems.first.focus != null &&
                      onNavigateToStoreProfile != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => onNavigateToStoreProfile!(
                          missingItems.first.focus!,
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Eksik maddeyi tamamla'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Şart: ${progress.definition.requirementLabel}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (progress.canRetry && onRetry != null)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Yenile'),
                ),
              if (progress.showsGlowReplayButton && onReplayGlow != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SellerGlowReplayButton(
                    onPressed: onReplayGlow!,
                    compact: true,
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: onShowDetail ??
                    () => showSellerBadgeDetailSheet(
                          context: context,
                          progress: progress,
                          onNavigateToStoreProfile: onNavigateToStoreProfile,
                          onRetry: onRetry,
                        ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.04),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.28)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Detay'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static double? _progressValue(SellerBadgeProgress progress) {
    switch (progress.status) {
      case SellerBadgeStatus.unavailable:
      case SellerBadgeStatus.insufficientData:
      case SellerBadgeStatus.error:
      case SellerBadgeStatus.comingSoon:
      case SellerBadgeStatus.locked:
        return 0;
      case SellerBadgeStatus.earned:
        return 1;
      case SellerBadgeStatus.inProgress:
        return progress.progressRatio;
    }
  }

  static Color _statusColor(SellerBadgeStatus status) {
    switch (status) {
      case SellerBadgeStatus.earned:
        return const Color(0xFF059669);
      case SellerBadgeStatus.inProgress:
        return AppColors.primary;
      case SellerBadgeStatus.comingSoon:
        return const Color(0xFF94A3B8);
      case SellerBadgeStatus.unavailable:
      case SellerBadgeStatus.insufficientData:
        return const Color(0xFF64748B);
      case SellerBadgeStatus.error:
        return const Color(0xFFDC2626);
      case SellerBadgeStatus.locked:
        return const Color(0xFFCBD5E1);
    }
  }

  static Widget _metaChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class SellerAchievementsSummaryCard extends StatelessWidget {
  const SellerAchievementsSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class SellerBadgeCategoryChipBar extends StatelessWidget {
  const SellerBadgeCategoryChipBar({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  final SellerBadgeCategory? selectedCategory;
  final ValueChanged<SellerBadgeCategory?> onSelected;

  static const List<(SellerBadgeCategory?, String)> items = [
    (null, 'Tümü'),
    (SellerBadgeCategory.onboarding, 'Başlangıç'),
    (SellerBadgeCategory.followers, 'Takipçi'),
    (SellerBadgeCategory.orders, 'Sipariş'),
    (SellerBadgeCategory.shippingSpeed, 'Kargo'),
    (SellerBadgeCategory.packagingQuality, 'Paketleme'),
    (SellerBadgeCategory.messageResponse, 'Mesaj'),
    (SellerBadgeCategory.reviews, 'Yorum'),
    (SellerBadgeCategory.region, 'Bölgesel'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: selectedCategory == item.$1,
                onSelected: (_) => onSelected(item.$1),
                selectedColor: AppColors.primary.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selectedCategory == item.$1
                      ? AppColors.primary
                      : const Color(0xFF475569),
                ),
                side: BorderSide(
                  color: selectedCategory == item.$1
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : const Color(0xFFE2E8F0),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                backgroundColor: Colors.white,
                showCheckmark: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
