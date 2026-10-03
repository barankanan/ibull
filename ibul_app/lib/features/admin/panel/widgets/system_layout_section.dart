import 'package:flutter/material.dart';

/// Sistem Düzeni ortak görünümü: beyaz yüzey, açık gri ayırıcı, mor vurgu.
abstract final class SystemLayoutColors {
  static const background = Color(0xFFF7F7FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE7E5EE);
  static const accent = Color(0xFF8B5CF6);
  static const accentSoft = Color(0xFFF3F0FF);
  static const title = Color(0xFF1F1035);
  static const muted = Color(0xFF6B7280);
}

const double kSystemLayoutButtonHeight = 40;

ButtonStyle systemLayoutPrimaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: SystemLayoutColors.accent,
  foregroundColor: Colors.white,
  minimumSize: const Size(0, kSystemLayoutButtonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 18),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

ButtonStyle systemLayoutSecondaryButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: SystemLayoutColors.accent,
  side: const BorderSide(color: SystemLayoutColors.border),
  minimumSize: const Size(0, kSystemLayoutButtonHeight),
  padding: const EdgeInsets.symmetric(horizontal: 14),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
);

/// Bölüm başlığı: solda başlık/açıklama, sağda ikincil işlemler ve en sağda
/// ana işlem. Dar pencerede işlemler alt satıra iner.
class SystemLayoutSectionHeader extends StatelessWidget {
  const SystemLayoutSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.liveNote,
    this.secondaryActions = const [],
    this.primaryAction,
  });

  final String title;
  final String? subtitle;

  /// Kaydetmenin müşteri tarafına nasıl yansıdığını açıklar.
  final String? liveNote;
  final List<Widget> secondaryActions;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final actions = [...secondaryActions, ?primaryAction];
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: SystemLayoutColors.title,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: SystemLayoutColors.muted,
            ),
          ),
        ],
        if (liveNote != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.public_rounded,
                size: 14,
                color: SystemLayoutColors.accent,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  liveNote!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: SystemLayoutColors.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        color: SystemLayoutColors.surface,
        border: Border(bottom: BorderSide(color: SystemLayoutColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          final actionRow = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: actions,
          );
          if (narrow || actions.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actionRow),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              actionRow,
            ],
          );
        },
      ),
    );
  }
}

/// Boş / hata durumları için ortalanmış bilgi kutusu.
class SystemLayoutEmptyState extends StatelessWidget {
  const SystemLayoutEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: SystemLayoutColors.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: SystemLayoutColors.accent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SystemLayoutColors.title,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: SystemLayoutColors.muted,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
