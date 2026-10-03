import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_floor.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import '../services/mall_management_repository.dart';
import 'mall_media_picker.dart';
import 'mall_panel_kit.dart';
import 'mall_structure_views.dart';

const mallNoFloorPlanMessage = 'Bu kat için iç mekan planı henüz yüklenmedi.';

class MallIndoorMapView extends StatefulWidget {
  const MallIndoorMapView({
    super.key,
    required this.mallId,
    required this.floors,
    required this.units,
    required this.links,
    required this.canManage,
    required this.repository,
    required this.onChanged,
  });

  final String mallId;
  final List<MallFloor> floors;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final bool canManage;
  final MallManagementRepository repository;
  final Future<void> Function() onChanged;

  @override
  State<MallIndoorMapView> createState() => _MallIndoorMapViewState();
}

class _MallIndoorMapViewState extends State<MallIndoorMapView> {
  String? _floorId;
  String? _placingUnitId;
  var _busy = false;
  String? _error;

  MallFloor? get _floor {
    if (widget.floors.isEmpty) return null;
    return widget.floors.where((floor) => floor.id == _floorId).firstOrNull ?? widget.floors.first;
  }

  @override
  Widget build(BuildContext context) {
    final floor = _floor;
    if (floor == null) {
      return const MallPage(children: [
        MallPageTitle(title: 'İç Mekan Haritası'),
        MallEmptyState(
          icon: Icons.map_outlined,
          title: 'Önce kat ekleyin',
          message: 'Harita kat bazında çalışır. Katlar bölümünden ilk katı oluşturun.',
        ),
      ]);
    }
    final units = widget.units.where((unit) => unit.floorId == floor.id).toList()
      ..sort((a, b) => compareMallUnitCodes(a.unitCode, b.unitCode));
    return MallPage(children: [
      MallPageTitle(
        title: 'İç Mekan Haritası',
        subtitle: 'Kat planını yükleyin ve mağazaları plan üzerinde konumlandırın.',
        actions: [
          if (widget.canManage && floor.hasPlan)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _uploadPlan(floor),
              icon: const Icon(Icons.upload_outlined, size: 18),
              label: const Text('Kat Planı Yükle'),
            ),
        ],
      ),
      if (_error != null) MallInlineError(_error!, onClose: () => setState(() => _error = null)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final item in widget.floors)
          ChoiceChip(
            key: ValueKey('mall-map-floor-${item.id}'),
            label: Text('${item.shortLabel} • ${item.name}'),
            selected: item.id == floor.id,
            showCheckmark: false,
            selectedColor: MallTokens.soft,
            side: const BorderSide(color: MallTokens.border),
            onSelected: (_) => setState(() {
              _floorId = item.id;
              _placingUnitId = null;
            }),
          ),
      ]),
      if (!floor.hasPlan)
        MallEmptyState(
          icon: Icons.map_outlined,
          title: mallNoFloorPlanMessage,
          message: 'JPG, PNG veya WEBP kat planı yükleyin (en fazla 10 MB). Mağazalar plan üzerinde işaretlenir.',
          actionLabel: widget.canManage ? 'Plan Yükle' : null,
          onAction: widget.canManage && !_busy ? () => _uploadPlan(floor) : null,
        )
      else
        MallCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_placingUnitId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    const Icon(Icons.touch_app_outlined, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${units.firstWhere((unit) => unit.id == _placingUnitId).unitCode} için plan üzerinde bir noktaya dokunun.',
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => _placingUnitId = null), child: const Text('Vazgeç')),
                  ]),
                ),
              _PlanCanvas(
                key: ValueKey(floor.planUrl),
                url: floor.planUrl!,
                units: units.where((unit) => unit.isPlaced).toList(),
                links: widget.links,
                onTap: _placingUnitId == null ? null : (x, y) => _place(_placingUnitId!, x, y),
                onMarker: widget.canManage ? _markerMenu : null,
              ),
            ],
          ),
        ),
      if (units.isNotEmpty) _unitList(floor, units),
    ]);
  }

  Widget _unitList(MallFloor floor, List<MallUnit> units) {
    return MallCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MallCardTitle('${floor.name} mağazaları'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final unit in units)
              InputChip(
                avatar: Icon(unit.isPlaced ? Icons.place : Icons.place_outlined, size: 18,
                    color: unit.isPlaced ? AppColors.primary : MallTokens.muted),
                label: Text(_markerLabel(unit)),
                selected: unit.id == _placingUnitId,
                selectedColor: MallTokens.soft,
                showCheckmark: false,
                onPressed: widget.canManage && floor.hasPlan
                    ? () => setState(() => _placingUnitId = unit.id)
                    : null,
              ),
          ]),
          if (widget.canManage && floor.hasPlan)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('Konumlandırmak için mağazaya, sonra plan üzerindeki noktaya dokunun.',
                  style: TextStyle(color: MallTokens.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  String _markerLabel(MallUnit unit) {
    final link = mallLinkForUnit(widget.links, unit.id);
    if (link == null) return '${unit.unitCode} • boş';
    return link.isPending ? '${unit.unitCode} • ${link.storeName} (onay bekliyor)' : '${unit.unitCode} • ${link.storeName}';
  }

  Future<void> _markerMenu(MallUnit unit) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => MallFormDialog(
        title: _markerLabel(unit),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kapat')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Konumu Kaldır')),
        ],
        child: Text('Durum: ${MallUnitOccupancy.label(unit.occupancy)} • ${MallUnitType.label(unit.unitType)}'),
      ),
    );
    if (remove == true) await _run(() => widget.repository.setUnitPosition(mallId: widget.mallId, unitId: unit.id));
  }

  Future<void> _place(String unitId, double x, double y) async {
    setState(() => _placingUnitId = null);
    await _run(() => widget.repository.setUnitPosition(mallId: widget.mallId, unitId: unitId, x: x, y: y));
  }

  Future<void> _uploadPlan(MallFloor floor) async {
    await _run(() async {
      final file = await pickMallImage(tag: 'FLOOR_PLAN');
      if (file == null) return;
      final url = await widget.repository.uploadMedia(
        mallId: widget.mallId,
        kind: 'floor-plans',
        fileName: file.name,
        bytes: file.bytes,
      );
      await widget.repository.setFloorPlan(mallId: widget.mallId, floorId: floor.id, url: url);
    }, success: 'Kat planı kaydedildi.');
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await widget.onChanged();
      if (mounted && success != null) showMallSnack(context, success);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Shows the plan at its natural aspect ratio; markers use normalized 0-1 coordinates.
class _PlanCanvas extends StatefulWidget {
  const _PlanCanvas({super.key, required this.url, required this.units, required this.links, this.onTap, this.onMarker});

  final String url;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final void Function(double x, double y)? onTap;
  final ValueChanged<MallUnit>? onMarker;

  @override
  State<_PlanCanvas> createState() => _PlanCanvasState();
}

class _PlanCanvasState extends State<_PlanCanvas> {
  late final ImageProvider _image = NetworkImage(widget.url);
  ImageStream? _stream;
  late final _listener = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _aspect = info.image.width / info.image.height);
    },
    onError: (_, _) {
      if (mounted) setState(() => _failed = true);
    },
  );
  double? _aspect;
  var _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = _image.resolve(createLocalImageConfiguration(context))..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const MallInlineError('Kat planı görseli yüklenemedi.');
    final aspect = _aspect;
    if (aspect == null) {
      return const SizedBox(height: 320, child: Center(child: CircularProgressIndicator()));
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 720),
      child: AspectRatio(
        aspectRatio: aspect,
        child: LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            onTapUp: widget.onTap == null
                ? null
                : (details) => widget.onTap!(
                      (details.localPosition.dx / box.maxWidth).clamp(0.0, 1.0),
                      (details.localPosition.dy / box.maxHeight).clamp(0.0, 1.0),
                    ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image(image: _image, fit: BoxFit.fill),
                  ),
                ),
                for (final unit in widget.units)
                  Positioned(
                    left: unit.mapX! * box.maxWidth - 60,
                    top: unit.mapY! * box.maxHeight - 56,
                    width: 120,
                    child: _marker(unit),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _marker(MallUnit unit) {
    final link = mallLinkForUnit(widget.links, unit.id);
    final occupied = unit.occupancy == 'occupied';
    final color = occupied ? AppColors.primary : const Color(0xFF6B7280);
    return GestureDetector(
      key: ValueKey('mall-marker-${unit.id}'),
      onTap: widget.onMarker == null ? null : () => widget.onMarker!(unit),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color),
              boxShadow: MallTokens.shadow,
            ),
            child: Column(
              children: [
                Text(unit.unitCode, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 12)),
                Text(
                  link?.storeName ?? (occupied ? 'Dolu' : MallUnitOccupancy.label(unit.occupancy)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          Icon(Icons.location_on, color: color, size: 20),
        ],
      ),
    );
  }
}
