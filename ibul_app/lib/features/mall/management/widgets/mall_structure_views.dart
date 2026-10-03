import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_floor.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import 'mall_management_dialogs.dart';
import 'mall_panel_kit.dart';

export 'mall_management_dialogs.dart';

String mallFloorLevelLabel(MallFloor floor) {
  final level = floor.levelNumber;
  if (level == null) return 'Seviye belirtilmedi';
  return MallFloorLevels.levelLabel(level);
}

MallTone mallOccupancyTone(String occupancy) => switch (occupancy) {
      'occupied' => MallTone.success,
      'reserved' => MallTone.primary,
      'temporarily_closed' => MallTone.warning,
      _ => MallTone.neutral,
    };

MallStoreLink? mallLinkForUnit(List<MallStoreLink> links, String unitId) {
  for (final link in links) {
    if (link.unitId == unitId && (link.isApproved || link.isPending)) return link;
  }
  return null;
}

class MallLevelBadge extends StatelessWidget {
  const MallLevelBadge({super.key, required this.floor, this.size = 44});

  final MallFloor floor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final basement = (floor.levelNumber ?? 0) < 0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: basement ? const Color(0xFFF1F5F9) : MallTokens.soft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        floor.shortLabel,
        style: TextStyle(
          color: basement ? const Color(0xFF475569) : AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class MallFloorsView extends StatelessWidget {
  const MallFloorsView({
    super.key,
    required this.floors,
    required this.units,
    required this.links,
    required this.canManage,
    required this.onAdd,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MallFloor> floors;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final bool canManage;
  final VoidCallback onAdd;
  final ValueChanged<MallFloor> onOpen;
  final ValueChanged<MallFloor> onEdit;
  final ValueChanged<MallFloor> onDelete;

  @override
  Widget build(BuildContext context) {
    return MallPage(children: [
      MallPageTitle(
        title: 'Katlar',
        subtitle: 'Katlar alttan üste sıralanır. Mağazaları Mağazalar bölümünden kat ve mağaza no ile ekleyin.',
        actions: [if (canManage) MallPrimaryButton(label: 'Kat Ekle', icon: Icons.add, onPressed: onAdd)],
      ),
      if (floors.isEmpty)
        MallEmptyState(
          icon: Icons.layers_outlined,
          title: 'Henüz kat eklenmedi',
          message: 'Otopark, Zemin Kat, 1. Kat gibi katları ekleyerek başlayın.',
          actionLabel: canManage ? 'Kat Ekle' : null,
          onAction: canManage ? onAdd : null,
        )
      else
        MallGrid(minTileWidth: 300, children: [
          for (final floor in sortMallFloors(floors)) _floorCard(context, floor),
        ]),
    ]);
  }

  Widget _floorCard(BuildContext context, MallFloor floor) {
    final floorUnits = units.where((unit) => unit.floorId == floor.id).toList();
    final storeCount = links.where((link) => link.isApproved && link.floorId == floor.id).length;
    final emptyCount = floorUnits
        .where((unit) => unit.occupancy != 'occupied' && mallLinkForUnit(links, unit.id) == null)
        .length;
    return MallCard(
      key: ValueKey('mall-floor-${floor.id}'),
      onTap: () => onOpen(floor),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MallLevelBadge(floor: floor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(floor.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(mallFloorLevelLabel(floor), style: const TextStyle(color: MallTokens.muted)),
                  ],
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Kat işlemleri',
                  onSelected: (value) async {
                    if (value == 'edit') return onEdit(floor);
                    final ok = await confirmMallAction(
                      context,
                      title: 'Katı sil',
                      message: '"${floor.name}" silinecek. Bu işlem geri alınamaz.',
                      confirmLabel: 'Sil',
                    );
                    if (ok) onDelete(floor);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: floorUnits.isEmpty,
                      child: Text(floorUnits.isEmpty ? 'Sil' : 'Sil (önce mağaza alanlarını kaldırın)'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _metric('$storeCount', 'Mağaza'),
              _metric('$emptyCount', 'Boş alan'),
              _metric(floor.hasPlan ? 'Var' : 'Yok', 'Kat planı'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: MallTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class MallFloorDetailView extends StatelessWidget {
  const MallFloorDetailView({
    super.key,
    required this.floor,
    required this.units,
    required this.links,
    required this.canManage,
    required this.onBack,
    required this.onAdd,
    required this.onAddStore,
    required this.onEdit,
    required this.onDelete,
  });

  final MallFloor floor;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final bool canManage;
  final VoidCallback onBack;

  /// Adds an empty store area (no store yet).
  final VoidCallback onAdd;

  /// Opens the store wizard, optionally preset to an empty area's number.
  final ValueChanged<String?> onAddStore;
  final ValueChanged<MallUnit> onEdit;
  final ValueChanged<MallUnit> onDelete;

  @override
  Widget build(BuildContext context) {
    final sorted = [...units]..sort((a, b) => compareMallUnitCodes(a.unitCode, b.unitCode));
    final active = links.where((link) => link.isApproved && link.floorId == floor.id).length;
    final pending = links.where((link) => link.isPending && link.floorId == floor.id).length;
    final empty =
        units.where((unit) => unit.occupancy != 'occupied' && mallLinkForUnit(links, unit.id) == null).length;
    return MallPage(children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back, size: 18), label: const Text('Katlar')),
      ),
      MallPageTitle(
        title: floor.name,
        subtitle: mallFloorLevelLabel(floor),
        actions: [
          if (canManage) OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Boş Alan Ekle')),
          if (canManage)
            MallPrimaryButton(label: 'Mağaza Ekle', icon: Icons.add_business_outlined, onPressed: () => onAddStore(null)),
        ],
      ),
      MallGrid(minTileWidth: 200, children: [
        MallKpiCard(label: 'Mağaza Alanı', value: '${units.length}', icon: Icons.grid_view_outlined),
        MallKpiCard(label: 'Aktif Mağaza', value: '$active', icon: Icons.storefront, tone: MallTone.success),
        MallKpiCard(label: 'Onay Bekleyen', value: '$pending', icon: Icons.hourglass_top, tone: MallTone.warning),
        MallKpiCard(label: 'Boş Alan', value: '$empty', icon: Icons.crop_square, tone: MallTone.neutral),
      ]),
      if (units.isEmpty)
        MallEmptyState(
          icon: Icons.storefront_outlined,
          title: 'Bu katta mağaza yok',
          message: 'Mağaza Ekle ile mağazayı bulup mağaza numarasını girin; alan otomatik oluşur.',
          actionLabel: canManage ? 'Mağaza Ekle' : null,
          onAction: canManage ? () => onAddStore(null) : null,
        )
      else
        MallGrid(minTileWidth: 260, children: [for (final unit in sorted) _unitCard(context, unit)]),
    ]);
  }

  Widget _unitCard(BuildContext context, MallUnit unit) {
    final link = mallLinkForUnit(links, unit.id);
    return MallCard(
      key: ValueKey('mall-unit-${unit.id}'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Mağaza ${unit.unitCode}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              MallBadge(MallUnitOccupancy.label(unit.occupancy), tone: mallOccupancyTone(unit.occupancy), dense: true),
              if (canManage)
                PopupMenuButton<String>(
                  tooltip: 'Alan işlemleri',
                  onSelected: (value) async {
                    if (value == 'edit') return onEdit(unit);
                    final ok = await confirmMallAction(
                      context,
                      title: 'Mağaza alanını sil',
                      message: 'Mağaza ${unit.unitCode} alanı silinecek.',
                      confirmLabel: 'Sil',
                    );
                    if (ok) onDelete(unit);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: link == null,
                      child: Text(link == null ? 'Sil' : 'Sil (önce bağlantıyı kaldırın)'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [MallUnitType.label(unit.unitType), if (unit.areaM2 != null) '${unit.areaM2!.toStringAsFixed(0)} m²', ?unit.name]
                .join(' • '),
            style: const TextStyle(color: MallTokens.muted),
          ),
          const SizedBox(height: 14),
          if (link == null && canManage)
            TextButton.icon(
              onPressed: () => onAddStore(unit.unitCode),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Mağaza yerleştir'),
            )
          else
            Row(
              children: [
                Icon(link == null ? Icons.store_mall_directory_outlined : Icons.storefront,
                    size: 18, color: link == null ? MallTokens.muted : AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    link == null
                        ? 'Boş alan'
                        : link.isPending
                            ? '${link.storeName} • mağaza onayı bekleniyor'
                            : link.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: link == null ? FontWeight.w500 : FontWeight.w700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
