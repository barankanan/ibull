import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/seller_badge_models.dart';
import 'seller_badge_widgets.dart';

abstract final class AchievementDashboardTokens {
  static const cardRadius = 14.0;
  static const cardBorder = Color(0xFFE5E7EB);
  static const cardShadow = Color(0x08000000);
  static const pageGap = 14.0;
}

class AchievementMetricItem {
  const AchievementMetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;
}

class SellerAchievementsDashboardHeader extends StatelessWidget {
  const SellerAchievementsDashboardHeader({
    super.key,
    required this.earnedCount,
    required this.inProgressCount,
    this.onRefresh,
  });

  final int earnedCount;
  final int inProgressCount;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AchievementDashboardTokens.cardRadius),
        border: Border.all(color: AchievementDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AchievementDashboardTokens.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Başarılarım',
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Görevleri tamamla, rozet kazan ve mağaza profilinde en güçlü başarılarını sergile.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          );
          final actions = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$earnedCount rozet · $inProgressCount görev',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              if (onRefresh != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Yenile',
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF8FAFC),
                    foregroundColor: const Color(0xFF475569),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ],
            ],
          );

          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleBlock, const SizedBox(height: 12), actions],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
        },
      ),
    );
  }
}

class AchievementMetricCard extends StatelessWidget {
  const AchievementMetricCard({super.key, required this.item});

  final AchievementMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AchievementDashboardTokens.cardRadius),
        border: Border.all(color: AchievementDashboardTokens.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AchievementDashboardTokens.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, size: 15, color: item.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ],
      ),
    );
  }
}

class AchievementMetricGrid extends StatelessWidget {
  const AchievementMetricGrid({super.key, required this.metrics});

  final List<AchievementMetricItem> metrics;

  int _columnsForWidth(double width) {
    if (width >= 1100) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsForWidth(constraints.maxWidth);
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: columns == 1 ? constraints.maxWidth : itemWidth,
                  child: AchievementMetricCard(item: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

List<AchievementMetricItem> buildAchievementMetrics({
  required int earnedCount,
  required int inProgressCount,
  required int featuredCount,
  required bool loadingFeatured,
  required int maxFeatured,
}) {
  return [
    AchievementMetricItem(
      title: 'Kazanılan Rozetler',
      value: '$earnedCount',
      icon: Icons.emoji_events_outlined,
      accent: AppColors.primary,
      subtitle: 'Gerçek ilerleme',
    ),
    AchievementMetricItem(
      title: 'Devam Eden Görevler',
      value: '$inProgressCount',
      icon: Icons.trending_up_rounded,
      accent: const Color(0xFF0EA5E9),
      subtitle: 'Aktif hedefler',
    ),
    AchievementMetricItem(
      title: 'Vitrindeki Rozetler',
      value: loadingFeatured ? '—' : '$featuredCount / $maxFeatured',
      icon: Icons.star_outline_rounded,
      accent: const Color(0xFFD97706),
      subtitle: 'Profilde gösterilen',
    ),
    const AchievementMetricItem(
      title: 'Bölge Sıralaması',
      value: 'Yakında',
      icon: Icons.map_outlined,
      accent: Color(0xFF64748B),
      subtitle: 'Veri bekleniyor',
    ),
  ];
}

class BadgeShowcaseCard extends StatelessWidget {
  const BadgeShowcaseCard({
    super.key,
    required this.earnedBadges,
    required this.featuredBadgeIds,
    required this.onToggleFeatured,
    this.animateGlowFor,
    this.glowReplayTokenFor,
    this.onReplayGlow,
  });

  final List<SellerBadgeProgress> earnedBadges;
  final List<String> featuredBadgeIds;
  final void Function(SellerBadgeProgress badge) onToggleFeatured;
  final bool Function(SellerBadgeProgress badge)? animateGlowFor;
  final int Function(String badgeId)? glowReplayTokenFor;
  final void Function(String badgeId)? onReplayGlow;

  @override
  Widget build(BuildContext context) {
    final earnedById = {
      for (final badge in earnedBadges) badge.definition.badgeId: badge,
    };

    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rozet Vitrinim',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Profilde en fazla 4 rozet göster. Slotlara dokunarak seç.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (index) {
              final badgeId = index < featuredBadgeIds.length
                  ? featuredBadgeIds[index]
                  : null;
              final badge =
                  badgeId == null ? null : earnedById[badgeId];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                  child: _ShowcaseSlot(
                    badge: badge,
                    selected: badge != null,
                    onTap: badge == null
                        ? null
                        : () => onToggleFeatured(badge),
                    animateGlow: badge != null &&
                        (animateGlowFor?.call(badge) ?? false),
                    glowReplayToken: badge == null
                        ? 0
                        : (glowReplayTokenFor?.call(badge.definition.badgeId) ??
                              0),
                  ),
                ),
              );
            }),
          ),
          if (earnedBadges.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Henüz vitrine ekleyebileceğin kazanılmış rozet yok.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: earnedBadges.map((badge) {
                final selected =
                    featuredBadgeIds.contains(badge.definition.badgeId);
                return SellerFeaturedBadgeTile(
                  progress: badge,
                  selected: selected,
                  onTap: () => onToggleFeatured(badge),
                  animateGlow: animateGlowFor?.call(badge) ?? false,
                  glowReplayToken:
                      glowReplayTokenFor?.call(badge.definition.badgeId) ?? 0,
                  onReplayGlow: onReplayGlow == null
                      ? null
                      : () => onReplayGlow!(badge.definition.badgeId),
                );
              }).toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class AchievementProgressSummaryCard extends StatelessWidget {
  const AchievementProgressSummaryCard({
    super.key,
    required this.earnedCount,
    required this.totalCount,
    required this.inProgressCount,
    required this.featuredCount,
    required this.maxFeatured,
    required this.welcomeActive,
  });

  final int earnedCount;
  final int totalCount;
  final int inProgressCount;
  final int featuredCount;
  final int maxFeatured;
  final bool welcomeActive;

  @override
  Widget build(BuildContext context) {
    final completion = totalCount <= 0 ? 0.0 : earnedCount / totalCount;
    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hızlı Özet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          _summaryRow('Tamamlanma', '%${(completion * 100).round()}'),
          _summaryRow('Sıradaki hedef', inProgressCount > 0 ? '$inProgressCount görev' : 'Tümü tamam'),
          _summaryRow('Vitrin', '$featuredCount / $maxFeatured rozet'),
          _summaryRow(
            'Yeni satıcı desteği',
            welcomeActive ? 'Aktif' : 'Kapalı',
            valueColor: welcomeActive ? const Color(0xFF059669) : null,
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: completion.clamp(0, 1),
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class EarnedBadgesGrid extends StatelessWidget {
  const EarnedBadgesGrid({
    super.key,
    required this.badges,
    required this.featuredBadgeIds,
    required this.onShowDetail,
  });

  final List<SellerBadgeProgress> badges;
  final List<String> featuredBadgeIds;
  final void Function(SellerBadgeProgress badge) onShowDetail;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return _dashboardCard(
        child: AchievementEmptyState(
          title: 'Henüz kazanılmış rozet yok',
          message: 'Görevleri tamamladıkça rozetler burada görünecek.',
          icon: Icons.emoji_events_outlined,
        ),
      );
    }

    return _dashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kazanılan Rozetler',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 4
                  : constraints.maxWidth >= 560
                  ? 2
                  : 1;
              const spacing = 8.0;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: badges
                    .map(
                      (badge) => SizedBox(
                        width: columns == 1 ? constraints.maxWidth : itemWidth,
                        child: SellerEarnedBadgeGridTile(
                          progress: badge,
                          featured: featuredBadgeIds
                              .contains(badge.definition.badgeId),
                          onTap: () => onShowDetail(badge),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class AchievementEmptyState extends StatelessWidget {
  const AchievementEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _ShowcaseSlot extends StatelessWidget {
  const _ShowcaseSlot({
    required this.badge,
    required this.selected,
    this.onTap,
    this.animateGlow = false,
    this.glowReplayToken = 0,
  });

  final SellerBadgeProgress? badge;
  final bool selected;
  final VoidCallback? onTap;
  final bool animateGlow;
  final int glowReplayToken;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : const Color(0xFFE2E8F0),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: badge == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      size: 22,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rozet seç',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SellerBadgeIcon(
                      progress: badge!,
                      size: 30,
                      animateGlow: animateGlow,
                      glowReplayToken: glowReplayToken,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      badge!.definition.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

Widget _dashboardCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AchievementDashboardTokens.cardRadius),
      border: Border.all(color: AchievementDashboardTokens.cardBorder),
      boxShadow: const [
        BoxShadow(
          color: AchievementDashboardTokens.cardShadow,
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
