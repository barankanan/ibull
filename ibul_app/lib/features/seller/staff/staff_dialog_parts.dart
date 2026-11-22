import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/sub_admin.dart';

const _mutedText = Color(0xFF6B7280);

/// Bölüm kartı: başlık + isteğe bağlı açıklama + içerik.
class StaffSectionCard extends StatelessWidget {
  const StaffSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 13, color: _mutedText),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class StaffNote extends StatelessWidget {
  const StaffNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration staffInputDecoration({
  required String label,
  String? helper,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    helperText: helper,
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AppColors.borderStrong),
    enabledBorder: border(AppColors.borderStrong),
    focusedBorder: border(AppColors.primary, 2),
    disabledBorder: border(AppColors.border),
  );
}

/// Geniş alanda yan yana, dar alanda alt alta alan ızgarası.
class StaffFieldGrid extends StatelessWidget {
  const StaffFieldGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 || children.length < 2) {
          return Column(
            children: [
              for (final child in children)
                Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Önerilen kısa işlem adları; kayıtlı olmayanlar katalog etiketine düşer.
String staffActionLabel(SellerPermission permission) {
  switch (permission) {
    case SellerPermission.manageOrders:
      return 'Sipariş gönder';
    case SellerPermission.transferTable:
      return 'Masa aktar';
    case SellerPermission.closeBill:
      return 'Masa kapat';
    case SellerPermission.splitBill:
      return 'Hesap böl';
    case SellerPermission.takePartialPayment:
      return 'Ara ödeme';
    case SellerPermission.managePrintSettings:
      return 'Yazıcı yönet';
    case SellerPermission.manageStaff:
      return 'Personel yönet';
    default:
      return sellerPermissionLabel(permission);
  }
}

const staffSensitivePermissions = <SellerPermission>{
  SellerPermission.manageStaff,
  SellerPermission.closeBill,
  SellerPermission.takePartialPayment,
  SellerPermission.managePrintSettings,
};

/// Tek bir özel işlem izni için anahtar satırı.
class StaffPermissionSwitchRow extends StatelessWidget {
  const StaffPermissionSwitchRow({
    super.key,
    required this.permission,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final SellerPermission permission;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: ValueKey('perm-${permission.name}'),
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      activeTrackColor: AppColors.primary,
      activeThumbColor: Colors.white,
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            staffActionLabel(permission),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (staffSensitivePermissions.contains(permission))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Hassas',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
      subtitle: Text(
        description,
        style: const TextStyle(fontSize: 13, color: _mutedText),
      ),
    );
  }
}
