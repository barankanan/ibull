import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../panel/helpers/seller_panel_module_helpers.dart';
import '../panel/models/seller_panel_types.dart';
import 'staff_permission_summary.dart';

const _mutedText = Color(0xFF6B7280);

/// Sayfaların görsel kategorisi (yalnız gösterim; izin anlamı taşımaz).
class StaffPageCategory {
  const StaffPageCategory(this.title, this.modules);

  final String title;
  final List<SellerModule> modules;
}

List<StaffPageCategory> staffPageCategories(List<SellerModule> choices) {
  const layout = <String, List<SellerModule>>{
    'Operasyon': [
      SellerModule.dashboard,
      SellerModule.garson,
      SellerModule.orders,
    ],
    'Katalog ve reklam': [
      SellerModule.products,
      SellerModule.collections,
      SellerModule.campaigns,
    ],
    'Finans ve destek': [
      SellerModule.finance,
      SellerModule.support,
      SellerModule.reviews,
    ],
  };
  final used = <SellerModule>{};
  final result = <StaffPageCategory>[];
  layout.forEach((title, modules) {
    final present = modules.where(choices.contains).toList(growable: false);
    used.addAll(present);
    if (present.isNotEmpty) result.add(StaffPageCategory(title, present));
  });
  final rest = choices.where((m) => !used.contains(m)).toList(growable: false);
  if (rest.isNotEmpty) result.add(StaffPageCategory('İşletme ve sistem', rest));
  return result;
}

String staffPageDescription(SellerModule module) {
  switch (module) {
    case SellerModule.dashboard:
      return 'Satış ve sipariş özeti.';
    case SellerModule.garson:
      return 'Masa, adisyon ve mutfak siparişi.';
    case SellerModule.orders:
      return 'Siparişleri görür ve yönetir.';
    case SellerModule.products:
      return 'Ürün ekler ve düzenler. Görüntüle seçeneği yok.';
    case SellerModule.collections:
      return 'Ürün listeleri. Görüntüle seçeneği yok.';
    case SellerModule.campaigns:
      return 'Reklam ve kampanyalar. Görüntüle seçeneği yok.';
    case SellerModule.finance:
      return 'Finans özetini görür.';
    case SellerModule.support:
      return 'Destek kayıtları. Görüntüle seçeneği yok.';
    case SellerModule.reviews:
      return 'Yorum ve şikayetleri görür.';
    case SellerModule.system:
      return 'Yazıcı, alan ve masa ayarları.';
    case SellerModule.store:
      return 'Sayfa görünür. Mağaza profili bu seçimle açılmaz.';
    case SellerModule.team:
      return 'Sayfa görünür. Personel yönetimi bu seçimle açılmaz.';
    case SellerModule.mallRequests:
      return 'AVM taleplerini listeler.';
    case SellerModule.achievements:
      return 'Başarı rozetleri.';
    case SellerModule.vehicles:
      return 'Araç ilanları.';
    case SellerModule.contracts:
      return 'Sözleşmeler.';
    case SellerModule.downloadApp:
      return 'Uygulama indirme.';
  }
}

/// Erişim yok / Görüntüle / Tam yönetim. Üç seçenek hep görünür; sayfada
/// karşılığı olmayan seçenek pasif kalır (StaffPageLevelPlan.levels belirler).
class StaffLevelSegments extends StatelessWidget {
  const StaffLevelSegments({
    super.key,
    required this.keyPrefix,
    required this.title,
    required this.plan,
    required this.current,
    required this.enabled,
    required this.onChanged,
  });

  final String keyPrefix;
  final String title;
  final StaffPageLevelPlan plan;
  final StaffPageLevel current;
  final bool enabled;
  final ValueChanged<StaffPageLevel> onChanged;

  static const _options = <StaffPageLevel>[
    StaffPageLevel.none,
    StaffPageLevel.view,
    StaffPageLevel.full,
  ];

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderStrong),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final level in _options)
              Expanded(child: _segment(context, level)),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, StaffPageLevel level) {
    final available = plan.levels.contains(level);
    final selected = current == level;
    final active = enabled && available;
    final label = staffPageLevelLabel(level);
    final fill = level == StaffPageLevel.none
        ? const Color(0xFF4B5563)
        : AppColors.primary;
    final radius = BorderRadius.circular(9);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: active,
      label: available
          ? '$title: $label'
          : '$title: $label, bu sayfada kullanılamaz',
      onTap: active ? () => onChanged(level) : null,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? fill : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            key: ValueKey('page-level-$keyPrefix-${level.name}'),
            borderRadius: radius,
            focusColor: AppColors.primary.withValues(alpha: 0.22),
            onTap: active ? () => onChanged(level) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : available
                              ? AppColors.textDark
                              : const Color(0xFFB0B0B0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bir sayfa satırı: ikon + ad + tek satır açıklama + düzey seçici.
class StaffPageAccessRow extends StatelessWidget {
  const StaffPageAccessRow({
    super.key,
    required this.module,
    required this.plan,
    required this.current,
    required this.enabled,
    required this.onChanged,
  });

  final SellerModule module;
  final StaffPageLevelPlan plan;
  final StaffPageLevel current;
  final bool enabled;
  final ValueChanged<StaffPageLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    final title = sellerModuleLabel(module);
    final accessible = current != StaffPageLevel.none;
    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accessible
                ? AppColors.primary.withValues(alpha: 0.12)
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            sellerModuleIcon(module),
            size: 22,
            color: accessible ? AppColors.primary : const Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if (current == StaffPageLevel.custom)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Özel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                staffPageDescription(module),
                style: const TextStyle(fontSize: 13, color: _mutedText),
              ),
            ],
          ),
        ),
      ],
    );
    final segments = StaffLevelSegments(
      keyPrefix: module.name,
      title: title,
      plan: plan,
      current: current,
      enabled: enabled,
      onChanged: onChanged,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: info),
                    const SizedBox(width: 16),
                    SizedBox(width: 330, child: segments),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [info, const SizedBox(height: 10), segments],
                ),
        );
      },
    );
  }
}
