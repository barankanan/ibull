import 'package:flutter/material.dart';

import '../../../../app/ibul_router.dart';
import '../../../../app/marketplace_paths.dart';
import '../../../../core/constants.dart';
import '../models/mall_floor.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import 'mall_panel_kit.dart';
import 'mall_structure_views.dart';

/// Aktif Mağazalar (floor by floor, bottom to top), Gelen Başvurular (stores
/// applying; the AVM decides), Gönderilen Davetler (the store decides) and
/// Boş Alanlar. Invites and applications share one request model.
class MallStoresView extends StatefulWidget {
  const MallStoresView({
    super.key,
    required this.floors,
    required this.units,
    required this.links,
    required this.canManage,
    required this.onAddStore,
    required this.onCancel,
    required this.onOpenFloors,
    required this.onReview,
  });

  final List<MallFloor> floors;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final bool canManage;
  final Future<void> Function({String? floorId, String? unitCode}) onAddStore;
  final ValueChanged<MallStoreLink> onCancel;
  final VoidCallback onOpenFloors;
  final ValueChanged<MallStoreLink> onReview;

  @override
  State<MallStoresView> createState() => _MallStoresViewState();
}

class _MallStoresViewState extends State<MallStoresView> {
  var _tab = 'aktif';

  List<MallStoreLink> get _links => widget.links;

  bool _isEmpty(MallUnit unit) => unit.occupancy != 'occupied' && mallLinkForUnit(_links, unit.id) == null;

  @override
  Widget build(BuildContext context) {
    final active = _links.where((link) => link.isApproved).length;
    final incoming = _links.where((link) => link.isIncoming).toList();
    final invites = _links.where((link) => link.isSentInvite).toList();
    final empty = widget.units.where(_isEmpty).toList();
    return MallPage(children: [
      MallPageTitle(
        title: 'Mağazalar',
        subtitle: 'AVM daveti mağaza onayıyla, mağaza başvurusu sizin onayınızla aktif olur.',
        actions: [
          if (widget.canManage && widget.floors.isNotEmpty)
            MallPrimaryButton(
              key: const ValueKey('mall-add-store'),
              label: 'Mağaza Ekle',
              icon: Icons.add_business_outlined,
              onPressed: () => widget.onAddStore(),
            ),
        ],
      ),
      MallGrid(minTileWidth: 200, children: [
        MallKpiCard(label: 'Aktif Mağazalar', value: '$active', icon: Icons.storefront, tone: MallTone.success),
        MallKpiCard(label: 'Gelen Başvurular', value: '${incoming.length}', icon: Icons.inbox_outlined, tone: MallTone.warning),
        MallKpiCard(label: 'Gönderilen Davetler', value: '${invites.length}', icon: Icons.outgoing_mail, tone: MallTone.neutral),
        MallKpiCard(label: 'Boş Alanlar', value: '${empty.length}', icon: Icons.crop_square, tone: MallTone.neutral),
      ]),
      MallSegmented(
        key: const ValueKey('mall-stores-tabs'),
        items: {
          'aktif': 'Aktif Mağazalar',
          'basvurular': 'Gelen Başvurular (${incoming.length})',
          'davetler': 'Gönderilen Davetler (${invites.length})',
          'bos': 'Boş Alanlar',
        },
        selected: _tab,
        onChanged: (value) => setState(() => _tab = value),
      ),
      if (widget.floors.isEmpty)
        MallEmptyState(
          icon: Icons.layers_outlined,
          title: 'Önce kat ekleyin',
          message: 'Mağazalar kat bazında listelenir. Katlar bölümünden Zemin Kat, 1. Kat gibi katları oluşturun.',
          actionLabel: 'Katlara Git',
          onAction: widget.onOpenFloors,
        )
      else
        ...switch (_tab) {
          'basvurular' => _requestList(incoming,
              empty: 'Henüz mağaza başvurusu yok. Mağazalar satıcı panelinden "AVM\'ye Başvur" ile başvurur.'),
          'davetler' => _requestList(invites, empty: 'Bekleyen davet yok.'),
          'bos' => _emptyAreas(empty),
          _ => [for (final floor in sortMallFloors(widget.floors)) _floorSection(floor)],
        },
    ]);
  }

  List<Widget> _requestList(List<MallStoreLink> items, {required String empty}) {
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(empty, textAlign: TextAlign.center, style: const TextStyle(color: MallTokens.muted)),
        ),
      ];
    }
    return [MallGrid(minTileWidth: 340, children: [for (final link in items) _requestCard(link)])];
  }

  Widget _requestCard(MallStoreLink link) {
    return MallCard(
      key: ValueKey('mall-request-${link.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          mallLogo(link.logoUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(link.storeName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              if (link.category != null) Text(link.category!, style: const TextStyle(color: MallTokens.muted)),
              const SizedBox(height: 6),
              MallBadge(link.fromStore ? 'İnceleme bekliyor' : 'Mağaza onayı bekleniyor', tone: MallTone.warning, dense: true),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(
          [link.placeLabel, if (link.areaM2 != null) '${link.areaM2!.toStringAsFixed(0)} m²'].join(' • '),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (link.fromStore) ...[
          const SizedBox(height: 6),
          Text('Talep eden: ${link.storeName}', style: const TextStyle(color: MallTokens.muted)),
          const SizedBox(height: 6),
          for (final doc in link.documents)
            Row(children: [
              const Icon(Icons.check, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(doc.label, style: const TextStyle(fontSize: 13))),
            ]),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: link.fromStore
              ? MallPrimaryButton(
                  key: ValueKey('mall-review-${link.id}'),
                  label: 'İncele',
                  onPressed: widget.canManage ? () => widget.onReview(link) : null,
                )
              : TextButton(
                  onPressed: widget.canManage ? () => _confirmCancel(link) : null, child: const Text('Daveti Geri Çek')),
        ),
      ]),
    );
  }

  List<Widget> _emptyAreas(List<MallUnit> empty) {
    if (empty.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Boş alan yok.', textAlign: TextAlign.center, style: TextStyle(color: MallTokens.muted)),
        ),
      ];
    }
    final floors = {for (final floor in widget.floors) floor.id: floor};
    final sorted = [...empty]..sort((a, b) => compareMallUnitCodes(a.unitCode, b.unitCode));
    return [
      MallCard(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(children: [
          for (final unit in sorted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${floors[unit.floorId]?.name ?? ''} • ${unit.unitCode}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: unit.areaM2 == null ? null : Text('${unit.areaM2!.toStringAsFixed(0)} m²'),
              trailing: widget.canManage
                  ? TextButton(
                      onPressed: () => widget.onAddStore(floorId: unit.floorId, unitCode: unit.unitCode),
                      child: const Text('Mağaza Ekle'))
                  : null,
            ),
        ]),
      ),
    ];
  }

  Widget _floorSection(MallFloor floor) {
    final floorUnits = widget.units.where((unit) => unit.floorId == floor.id).toList()
      ..sort((a, b) => compareMallUnitCodes(a.unitCode, b.unitCode));
    final stores = floorUnits.where((unit) => mallLinkForUnit(_links, unit.id)?.isApproved ?? false).length;
    final empty = floorUnits.where(_isEmpty).length;
    return MallCard(
      key: ValueKey('mall-store-floor-${floor.id}'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            MallLevelBadge(floor: floor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(floor.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('$stores mağaza • $empty boş alan', style: const TextStyle(color: MallTokens.muted, fontSize: 13)),
              ]),
            ),
            if (widget.canManage)
              TextButton.icon(
                onPressed: () => widget.onAddStore(floorId: floor.id),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Bu kata ekle'),
              ),
          ]),
          const SizedBox(height: 8),
          if (floorUnits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Bu katta henüz mağaza yok.', style: TextStyle(color: MallTokens.muted)),
            )
          else
            for (final unit in floorUnits) ...[const Divider(height: 1), _unitRow(floor, unit)],
        ],
      ),
    );
  }

  Widget _unitRow(MallFloor floor, MallUnit unit) {
    final link = mallLinkForUnit(_links, unit.id);
    final Widget status;
    final List<Widget> actions;
    if (link != null && link.isApproved) {
      status = const MallBadge('Aktif', tone: MallTone.success, dense: true);
      actions = [
        if (link.storeId != null)
          TextButton(
            onPressed: () => IbulRouter.go(context, MarketplacePaths.store(link.storeId!)),
            child: const Text('Görüntüle'),
          ),
        if (widget.canManage)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'view' && link.storeId != null) {
                IbulRouter.go(context, MarketplacePaths.store(link.storeId!));
              }
              if (value == 'remove') _confirmCancel(link);
            },
            itemBuilder: (_) => [
              if (link.storeId != null) const PopupMenuItem(value: 'view', child: Text('Mağazayı Gör')),
              const PopupMenuItem(value: 'place', enabled: false, child: Text('Konumu Düzenle')),
              const PopupMenuItem(value: 'remove', child: Text('AVM\'den Çıkar')),
            ],
          ),
      ];
    } else if (link != null && link.fromStore) {
      status = const MallBadge('Başvuru var', tone: MallTone.warning, dense: true);
      actions = [if (widget.canManage) TextButton(onPressed: () => widget.onReview(link), child: const Text('İncele'))];
    } else if (link != null) {
      status = const MallBadge('Mağaza onayı bekleniyor', tone: MallTone.warning, dense: true);
      actions = [
        if (widget.canManage) TextButton(onPressed: () => _confirmCancel(link), child: const Text('Geri Çek')),
      ];
    } else {
      status = MallBadge(unit.occupancy == 'temporarily_closed' ? 'Geçici kapalı' : 'Boş', dense: true);
      actions = [
        if (widget.canManage)
          TextButton(
            onPressed: () => widget.onAddStore(floorId: floor.id, unitCode: unit.unitCode),
            child: const Text('Mağaza Ekle'),
          ),
      ];
    }
    return Padding(
      key: ValueKey('mall-store-row-${unit.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Text(unit.unitCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
        ),
        if (link != null) ...[mallLogo(link.logoUrl, size: 36), const SizedBox(width: 10)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(link?.storeName ?? (unit.name ?? 'Boş alan'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: link == null ? FontWeight.w500 : FontWeight.w700)),
            Text(
              [?link?.category, if (unit.areaM2 != null) '${unit.areaM2!.toStringAsFixed(0)} m²'].join(' • '),
              style: const TextStyle(color: MallTokens.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            status,
          ]),
        ),
        ...actions,
      ]),
    );
  }

  Future<void> _confirmCancel(MallStoreLink link) async {
    final ok = await confirmMallAction(
      context,
      title: link.isPending ? 'Daveti geri çek' : 'AVM\'den Çıkar',
      message: link.isPending
          ? '${link.storeName} için gönderilen davet iptal edilecek.'
          : '${link.storeName} artık bu AVM içerisinde gösterilmeyecek. '
              'Mağaza yeni konum onayı yapılana kadar haritada görünmeyecektir.',
      confirmLabel: link.isPending ? 'Geri Çek' : 'AVM\'den Çıkar',
    );
    if (ok) widget.onCancel(link);
  }
}
