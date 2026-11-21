import 'package:flutter/material.dart';

import 'staff_permission_summary.dart';

const _accent = Color(0xFF6C63FF);

/// Gerçek izinlerden hesaplanan canlı sonuç özeti.
class StaffSummaryCard extends StatelessWidget {
  const StaffSummaryCard({super.key, required this.lines});

  final List<StaffSummaryLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bu kişi şunları yapabilir',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Özet, seçili izinlerden anlık hesaplanır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    line.allowed
                        ? Icons.check_circle_rounded
                        : Icons.remove_circle_outline,
                    size: 16,
                    color: line.allowed
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      line.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: line.allowed
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Bir sayfa için Erişim yok / Görüntüle / Tam yönetim seçimi.
/// Sığmayan seçenekler alt satıra iner; yatay taşma olmaz.
class StaffPageLevelRow extends StatelessWidget {
  const StaffPageLevelRow({
    super.key,
    required this.title,
    required this.plan,
    required this.current,
    required this.enabled,
    required this.onChanged,
    this.hint,
    this.keyPrefix = '',
  });

  final String title;
  final StaffPageLevelPlan plan;
  final StaffPageLevel current;
  final bool enabled;
  final ValueChanged<StaffPageLevel> onChanged;
  final String? hint;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final level in plan.levels)
                ChoiceChip(
                  key: ValueKey('page-level-$keyPrefix-${level.name}'),
                  label: Text(staffPageLevelLabel(level)),
                  selected: current == level,
                  selectedColor: _accent.withValues(alpha: 0.16),
                  onSelected: enabled ? (_) => onChanged(level) : null,
                ),
              if (current == StaffPageLevel.custom)
                const Chip(label: Text('Özel seçim')),
            ],
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                hint!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kaydetmeden önce sonucu gösteren önizleme.
Future<void> showStaffPreviewDialog({
  required BuildContext context,
  required String who,
  required List<StaffSummaryLine> lines,
  required List<String> pages,
  required List<String> permissionNames,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Önizleme: $who'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Görebileceği sayfalar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(pages.isEmpty ? 'Hiç sayfa yok' : pages.join(', ')),
              const SizedBox(height: 12),
              StaffSummaryCard(lines: lines),
              const SizedBox(height: 8),
              const Text(
                'Sunucuya kaydedilecek yetkiler',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                permissionNames.isEmpty ? 'Yetki yok' : permissionNames.join(', '),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}
