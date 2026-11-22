import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/sub_admin.dart';
import 'staff_permission_summary.dart';

const _muted = Color(0xFF6B7280);

class StaffSummaryPage {
  const StaffSummaryPage(this.label, this.level);

  final String label;
  final String level;
}

/// Seçili izinlerden hesaplanan güvenlik uyarıları (yalnız bilgi; kaydı engellemez).
List<String> staffSecurityWarnings({
  required Set<SellerPermission> selected,
  required bool hasPages,
}) {
  return <String>[
    if (!hasPages) 'Hiçbir sayfaya erişemeyecek. Bu hâliyle kaydedilemez.',
    if (selected.contains(SellerPermission.manageStaff))
      'Personel yönetimi açık: başka personel ekleyebilir ve yetkilerini değiştirebilir.',
    if (selected.contains(SellerPermission.closeBill))
      'Masa kapatma açık: hesabı kapatabilir.',
    if (selected.contains(SellerPermission.takePartialPayment))
      'Ara ödeme açık: ödeme kaydı alabilir.',
    if (selected.contains(SellerPermission.managePrintSettings))
      'Yazıcı yönetimi açık: yazıcı ayarlarını değiştirebilir.',
  ];
}

/// Canlı yetki özeti. Satırlar staffPermissionSummary ile gerçek izinlerden gelir.
class StaffLiveSummary extends StatelessWidget {
  const StaffLiveSummary({
    super.key,
    required this.who,
    required this.pages,
    required this.lines,
    required this.warnings,
    required this.permissionNames,
  });

  final String who;
  final List<StaffSummaryPage> pages;
  final List<StaffSummaryLine> lines;
  final List<String> warnings;
  final List<String> permissionNames;

  @override
  Widget build(BuildContext context) {
    final allowed = lines.where((l) => l.allowed).toList(growable: false);
    final denied = lines.where((l) => !l.allowed).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: const Text(
            'Canlı yetki özeti',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(who, style: const TextStyle(fontSize: 13, color: _muted)),
        const SizedBox(height: 16),
        _block(
          'Kullanabileceği sayfalar',
          pages.isEmpty
              ? [const _Line('Hiçbir sayfaya erişemez.', null)]
              : [
                  for (final page in pages)
                    _Line(page.label, true, trailing: page.level),
                ],
        ),
        _block(
          'Yapabileceği işlemler',
          allowed.isEmpty
              ? [const _Line('Yapabileceği işlem yok.', null)]
              : [for (final l in allowed) _Line(l.text, true)],
        ),
        _block(
          'Kullanamayacağı işlemler',
          denied.isEmpty
              ? [const _Line('Kısıtlı işlem yok.', null)]
              : [for (final l in denied) _Line(l.text, false)],
        ),
        _warnings(),
        const SizedBox(height: 4),
        const Text(
          'Sunucuya kaydedilecek yetkiler',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          permissionNames.isEmpty ? 'Yetki yok' : permissionNames.join(', '),
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
      ],
    );
  }

  Widget _block(String title, List<Widget> rows) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }

  Widget _warnings() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warnings.isEmpty
            ? AppColors.success.withValues(alpha: 0.08)
            : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warnings.isEmpty
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Önemli güvenlik uyarıları',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (warnings.isEmpty)
            const Text(
              'Öne çıkan bir uyarı yok.',
              style: TextStyle(fontSize: 13),
            )
          else
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(warning, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, this.allowed, {this.trailing});

  final String text;

  /// true: yapabilir, false: yapamaz, null: nötr bilgi.
  final bool? allowed;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final icon = allowed == null
        ? null
        : allowed!
            ? Icons.check_circle_rounded
            : Icons.remove_circle_outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 18,
              color: allowed! ? AppColors.success : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: allowed == false ? _muted : AppColors.ink,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dar ekranda özet, alttan açılan sayfada gösterilir.
Future<void> showStaffSummarySheet(BuildContext context, Widget summary) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Kapat',
              onPressed: () => Navigator.pop(sheetContext),
              icon: const Icon(Icons.close),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: summary,
            ),
          ),
        ],
      ),
    ),
  );
}
