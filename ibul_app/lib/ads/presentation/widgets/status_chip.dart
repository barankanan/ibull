import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  factory StatusChip.fromStatus(String rawStatus, {Key? key}) {
    final normalized = rawStatus.trim().toLowerCase();
    Color bg;
    Color fg;
    IconData icon;
    String label;
    switch (normalized) {
      case 'active':
      case 'approved': // CampaignStatus.approved.dbValue
      case 'succeeded':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        icon = Icons.check_circle_outline;
        label = normalized == 'approved' ? 'Onaylandi' : 'Aktif';
        break;
      case 'pending': // CampaignStatus.pendingReview.dbValue
      case 'pending_review':
      case 'scheduled':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFFEA580C);
        icon = Icons.hourglass_top_rounded;
        label = switch (normalized) {
          'scheduled' => 'Planlandi',
          _ => 'Bekleniliyor',
        };
        break;
      case 'paused':
      case 'stopped':
      case 'draft':
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.pause_circle_outline;
        label = switch (normalized) {
          'stopped' => 'Durduruldu',
          'draft' => 'Taslak',
          _ => 'Duraklatildi',
        };
        break;
      case 'rejected': // CampaignStatus.rejected.dbValue
      case 'failed':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        label = 'Reddedildi';
        break;
      default:
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        icon = Icons.info_outline_rounded;
        label = rawStatus;
    }
    return StatusChip(
      key: key,
      label: label,
      backgroundColor: bg,
      foregroundColor: fg,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
