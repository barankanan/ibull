import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../models/mall_floor.dart';
import '../models/mall_store_link.dart';
import '../models/mall_unit.dart';
import '../services/mall_management_repository.dart';
import '../services/mall_operations_repository.dart';
import 'mall_panel_kit.dart';
import 'mall_structure_views.dart';

/// Mağaza Bul → Konumlandır → Bağlantı İste. A code only finds the store; the
/// link becomes active only after the store owner approves it.
Future<bool> showMallStoreLinkDialog(
  BuildContext context, {
  required String mallId,
  required List<MallFloor> floors,
  required List<MallUnit> units,
  required List<MallStoreLink> links,
  required MallOperationsRepository operations,
  String? floorId,
  String? unitCode,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    builder: (_) => _StoreWizard(
      mallId: mallId,
      floors: sortMallFloors(floors),
      units: units,
      links: links,
      operations: operations,
      initialFloorId: floorId,
      initialUnitCode: unitCode,
    ),
  );
  return sent ?? false;
}

class _StoreWizard extends StatefulWidget {
  const _StoreWizard({
    required this.mallId,
    required this.floors,
    required this.units,
    required this.links,
    required this.operations,
    this.initialFloorId,
    this.initialUnitCode,
  });

  final String mallId;
  final List<MallFloor> floors;
  final List<MallUnit> units;
  final List<MallStoreLink> links;
  final MallOperationsRepository operations;
  final String? initialFloorId;
  final String? initialUnitCode;

  @override
  State<_StoreWizard> createState() => _StoreWizardState();
}

class _StoreWizardState extends State<_StoreWizard> {
  static const _steps = ['Mağaza Bul', 'Konumlandır', 'Bağlantı İste'];

  final _query = TextEditingController();
  late final _unitCode = TextEditingController(text: widget.initialUnitCode ?? '');
  final _area = TextEditingController();
  final _note = TextEditingController();
  var _step = 0;
  var _mode = 'search';
  var _busy = false;
  var _searched = false;
  String? _error;
  List<MallBranchCandidate> _results = const [];
  MallBranchCandidate? _store;
  late String? _floorId = widget.floors.any((floor) => floor.id == widget.initialFloorId)
      ? widget.initialFloorId
      : (widget.floors.length == 1 ? widget.floors.first.id : null);

  @override
  void dispose() {
    _query.dispose();
    _unitCode.dispose();
    _area.dispose();
    _note.dispose();
    super.dispose();
  }

  MallFloor? get _floor => widget.floors.where((floor) => floor.id == _floorId).firstOrNull;

  List<MallUnit> get _vacantOnFloor => widget.units
      .where((unit) =>
          unit.floorId == _floorId &&
          unit.occupancy != 'occupied' &&
          mallLinkForUnit(widget.links, unit.id) == null)
      .toList()
    ..sort((a, b) => compareMallUnitCodes(a.unitCode, b.unitCode));

  String? _placementError() {
    if (_floorId == null) return 'Kat seçin.';
    final codeError = MallUnitValidation.codeError(_unitCode.text);
    if (codeError != null) return codeError;
    final areaError = MallUnitValidation.areaError(_area.text);
    if (areaError != null) return areaError;
    if (_note.text.trim().length > 500) return 'Not en fazla 500 karakter olabilir.';
    final code = _unitCode.text.trim().toLowerCase();
    final existing = widget.units.where((unit) => unit.unitCode.trim().toLowerCase() == code).firstOrNull;
    if (existing == null) return null;
    if (existing.floorId != _floorId) {
      final other = widget.floors.where((floor) => floor.id == existing.floorId).firstOrNull;
      return 'Mağaza ${existing.unitCode} ${other?.name ?? 'başka bir kat'} katında kayıtlı.';
    }
    final link = mallLinkForUnit(widget.links, existing.id);
    if (link != null || existing.occupancy == 'occupied') {
      return 'Mağaza ${existing.unitCode} dolu${link == null ? '' : ' (${link.storeName})'}.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: 'Mağaza Ekle',
      width: 860,
      actions: _actions(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepper(),
          const SizedBox(height: 20),
          if (_error != null) ...[MallInlineError(_error!), const SizedBox(height: 16)],
          ...switch (_step) {
            0 => _findStep(),
            1 => _placeStep(),
            _ => _confirmStep(),
          },
        ],
      ),
    );
  }

  List<Widget> _actions() {
    return [
      TextButton(
        onPressed: _busy
            ? null
            : () => _step == 0
                ? Navigator.pop(context, false)
                : setState(() {
                    _step -= 1;
                    _error = null;
                  }),
        child: Text(_step == 0 ? 'Vazgeç' : 'Geri'),
      ),
      if (_step == 1)
        MallPrimaryButton(
          key: const ValueKey('mall-wizard-next'),
          label: 'Devam',
          icon: Icons.arrow_forward,
          onPressed: () {
            final error = _placementError();
            setState(() {
              _error = error;
              if (error == null) _step = 2;
            });
          },
        ),
      if (_step == 2)
        MallPrimaryButton(
          key: const ValueKey('mall-wizard-send'),
          label: _busy ? 'Gönderiliyor…' : 'Bağlantı İste',
          icon: Icons.send_outlined,
          onPressed: _busy ? null : _send,
        ),
    ];
  }

  Widget _stepper() {
    return Row(children: [
      for (var i = 0; i < _steps.length; i++) ...[
        if (i > 0) const Expanded(child: Divider(indent: 8, endIndent: 8)),
        CircleAvatar(
          radius: 14,
          backgroundColor: i <= _step ? AppColors.primary : MallTokens.soft,
          child: i < _step
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: i <= _step ? Colors.white : MallTokens.muted)),
        ),
        const SizedBox(width: 8),
        Text(_steps[i],
            style: TextStyle(
                fontWeight: i == _step ? FontWeight.w800 : FontWeight.w500,
                color: i == _step ? null : MallTokens.muted)),
      ],
    ]);
  }

  List<Widget> _findStep() {
    final byCode = _mode == 'code';
    return [
      MallSegmented(
        items: const {'search': 'İBUL\'da Ara', 'code': 'Mağaza Koduyla Bul'},
        selected: _mode,
        onChanged: (value) => setState(() {
          _mode = value;
          _query.clear();
          _results = const [];
          _searched = false;
          _error = null;
        }),
      ),
      const SizedBox(height: 16),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('mall-store-query'),
              controller: _query,
              autofocus: true,
              textCapitalization: byCode ? TextCapitalization.characters : TextCapitalization.none,
              onSubmitted: (_) => _search(),
              decoration: mallInput(
                byCode ? 'Mağaza kodu' : 'Mağaza adı veya kategori',
                hint: byCode ? 'IBL-7K4P9X' : 'Örn. Teknosa, elektronik',
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 52,
            child: MallPrimaryButton(
                key: const ValueKey('mall-store-search'),
                label: byCode ? 'Bul' : 'Ara',
                onPressed: _busy ? null : _search),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        byCode
            ? 'Kod, mağazanın satıcı panelindeki AVM Bağlantı Kodu\'dur. Kod yalnız mağazayı bulur; bağlantı için mağaza onayı gerekir.'
            : 'Büyük/küçük harf fark etmez, adın bir kısmını yazmanız yeterli.',
        style: const TextStyle(color: MallTokens.muted, fontSize: 12),
      ),
      const SizedBox(height: 16),
      if (_busy)
        const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
      else if (_searched && _results.isEmpty)
        Text(
          byCode ? 'Bu koda ait aktif mağaza bulunamadı.' : 'Eşleşen mağaza bulunamadı.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: MallTokens.muted),
        )
      else
        for (final item in _results) _resultCard(item),
    ];
  }

  Widget _resultCard(MallBranchCandidate item) {
    final details = [?item.category, if (item.locationLabel.isNotEmpty) item.locationLabel].join(' • ');
    return Container(
      key: ValueKey('mall-store-result-${item.branchId}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: MallTokens.border), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        mallLogo(item.logoUrl, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(item.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              if (item.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: AppColors.primary),
              ],
            ]),
            if (details.isNotEmpty) Text(details, style: const TextStyle(color: MallTokens.muted, fontSize: 13)),
            if (item.branchCode.isNotEmpty)
              Text('Kod: ${item.branchCode}', style: const TextStyle(color: MallTokens.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(width: 12),
        if (item.alreadyLinked)
          MallBadge(item.linkStatus == 'approved' ? 'Zaten bağlı' : 'Talep bekliyor', tone: MallTone.primary, dense: true)
        else
          OutlinedButton(
            key: ValueKey('mall-request-${item.branchId}'),
            onPressed: () => setState(() {
              _store = item;
              _step = 1;
              _error = null;
            }),
            child: const Text('Seç'),
          ),
      ]),
    );
  }

  List<Widget> _placeStep() {
    final store = _store!;
    final vacant = _vacantOnFloor;
    return [
      _storeHeader(store),
      const SizedBox(height: 20),
      DropdownButtonFormField<String>(
        key: const ValueKey('mall-link-floor'),
        initialValue: _floorId,
        decoration: mallInput('Kat *'),
        items: [
          for (final floor in widget.floors)
            DropdownMenuItem(value: floor.id, child: Text('${floor.shortLabel} • ${floor.name}')),
        ],
        onChanged: (value) => setState(() {
          _floorId = value;
          _error = null;
        }),
      ),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: TextField(
            key: const ValueKey('mall-link-unit-code'),
            controller: _unitCode,
            decoration: mallInput('Mağaza No *', hint: 'Örn. 105, Z-12'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            key: const ValueKey('mall-link-area'),
            controller: _area,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: mallInput('m² (opsiyonel)'),
          ),
        ),
      ]),
      if (vacant.isNotEmpty) ...[
        const SizedBox(height: 10),
        const Text('Bu kattaki boş alanlar:', style: TextStyle(color: MallTokens.muted, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final unit in vacant)
            ChoiceChip(
              label: Text(unit.unitCode),
              selected: _unitCode.text.trim().toLowerCase() == unit.unitCode.toLowerCase(),
              onSelected: (_) => setState(() {
                _unitCode.text = unit.unitCode;
                if (unit.areaM2 != null) _area.text = unit.areaM2!.toStringAsFixed(0);
              }),
            ),
        ]),
      ],
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('mall-link-note'),
        controller: _note,
        maxLines: 2,
        maxLength: 500,
        decoration: mallInput('Not (opsiyonel)', hint: 'Mağaza sahibine iletilir'),
      ),
    ];
  }

  List<Widget> _confirmStep() {
    final store = _store!;
    final area = _area.text.trim();
    final note = _note.text.trim();
    return [
      _storeHeader(store),
      const SizedBox(height: 20),
      _summaryRow('Konum', '${_floor?.name ?? '-'} • Mağaza ${_unitCode.text.trim()}'),
      if (area.isNotEmpty) _summaryRow('Alan', '$area m²'),
      if (note.isNotEmpty) _summaryRow('Not', note),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: MallTokens.soft, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text('Mağaza sahibine bildirim gider. Mağaza onaylayınca bu konumda aktif olarak listelenir.'),
          ),
        ]),
      ),
    ];
  }

  Widget _storeHeader(MallBranchCandidate store) {
    return Row(children: [
      mallLogo(store.logoUrl, size: 44),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(store.storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text([?store.category, if (store.locationLabel.isNotEmpty) store.locationLabel].join(' • '),
              style: const TextStyle(color: MallTokens.muted, fontSize: 13)),
        ]),
      ),
    ]);
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: MallTokens.muted))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'En az 2 karakter girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = _mode == 'code'
          ? await widget.operations.findBranchByCode(widget.mallId, query)
          : await widget.operations.findBranches(widget.mallId, query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searched = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final area = _area.text.trim();
      await widget.operations.requestStoreLink(
        mallId: widget.mallId,
        branchId: _store!.branchId,
        floorId: _floorId!,
        unitCode: _unitCode.text,
        areaM2: area.isEmpty ? null : double.parse(area.replaceAll(',', '.')),
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyMallError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
