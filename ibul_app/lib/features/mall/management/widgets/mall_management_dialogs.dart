import 'package:flutter/material.dart';
import '../models/mall_floor.dart';
import '../models/mall_unit.dart';
import 'mall_panel_kit.dart';

Future<MallFloorDraft?> showMallFloorDialog(BuildContext context, {MallFloor? existing}) {
  return showDialog<MallFloorDraft>(
    context: context,
    builder: (context) => _FloorDialog(existing: existing),
  );
}

Future<bool> confirmMallAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Onayla',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => MallFormDialog(
      title: title,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        MallPrimaryButton(label: confirmLabel, onPressed: () => Navigator.pop(context, true)),
      ],
      child: Text(message),
    ),
  );
  return result ?? false;
}

class _FloorDialog extends StatefulWidget {
  const _FloorDialog({this.existing});
  final MallFloor? existing;

  @override
  State<_FloorDialog> createState() => _FloorDialogState();
}

class _FloorDialogState extends State<_FloorDialog> {
  late int? _level = widget.existing == null ? 0 : widget.existing!.levelNumber;
  late final _name = TextEditingController(
      text: widget.existing?.name ?? MallFloorLevels.defaultName(0));
  String? _nameError;

  List<int?> get _levels => [
        if (widget.existing != null && widget.existing!.levelNumber == null) null,
        ...{...MallFloorLevels.choices, ?widget.existing?.levelNumber}.toList()..sort(),
      ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _levelText(int? level) {
    if (level == null) return 'Belirtilmedi';
    if (level == -1) return '-1 • B1 / Otopark';
    if (level < 0) return '$level • B${-level}';
    return '$level • ${MallFloorLevels.defaultName(level)}';
  }

  void _pickLevel(int? level) {
    final current = _name.text.trim();
    final previousDefault = _level == null ? null : MallFloorLevels.defaultName(_level!);
    setState(() {
      if (level != null && (current.isEmpty || current == previousDefault)) {
        _name.text = MallFloorLevels.defaultName(level);
      }
      _level = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: widget.existing == null ? 'Kat Ekle' : 'Katı Düzenle',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        MallPrimaryButton(label: 'Kaydet', onPressed: _submit),
      ],
      child: Column(
        children: [
          DropdownButtonFormField<int?>(
            key: const ValueKey('mall-floor-level'),
            initialValue: _level,
            decoration: mallInput('Kat seviyesi *'),
            items: [for (final level in _levels) DropdownMenuItem(value: level, child: Text(_levelText(level)))],
            onChanged: _pickLevel,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('mall-floor-name'),
            controller: _name,
            decoration: mallInput('Kat adı *', hint: 'Örn. Otopark, Zemin Kat', error: _nameError),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Katlar seviyeye göre alttan üste sıralanır. Adı dilediğiniz gibi değiştirebilirsiniz.',
                style: TextStyle(color: MallTokens.muted, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _submit() {
    setState(() => _nameError = MallFloorValidation.nameError(_name.text));
    if (_nameError != null) return;
    Navigator.pop(
      context,
      MallFloorDraft(
        name: _name.text.trim(),
        levelNumber: _level,
        sortOrder: _level ?? widget.existing?.sortOrder ?? 0,
      ),
    );
  }
}

Future<MallUnitDraft?> showMallUnitDialog(
  BuildContext context, {
  required List<MallFloor> floors,
  String? floorId,
  MallUnit? existing,
}) {
  return showDialog<MallUnitDraft>(
    context: context,
    builder: (context) => _UnitDialog(
      floors: floors,
      floorId: floorId ?? existing?.floorId,
      existing: existing,
    ),
  );
}

class _UnitDialog extends StatefulWidget {
  const _UnitDialog({required this.floors, this.floorId, this.existing});

  final List<MallFloor> floors;
  final String? floorId;
  final MallUnit? existing;

  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  late String? _floorId = widget.floorId ?? (widget.floors.isEmpty ? null : widget.floors.first.id);
  late final _code = TextEditingController(text: widget.existing?.unitCode ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _area = TextEditingController(text: widget.existing?.areaM2?.toString() ?? '');
  late String _type = widget.existing?.unitType ?? 'store';
  late final bool _occupied = widget.existing?.occupancy == 'occupied';
  late String _occupancy = MallUnitOccupancy.editable.contains(widget.existing?.occupancy)
      ? widget.existing!.occupancy
      : 'vacant';
  String? _codeError;
  String? _areaError;
  String? _floorError;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MallFormDialog(
      title: widget.existing == null ? 'Boş Alan Ekle' : 'Mağaza Alanını Düzenle',
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        MallPrimaryButton(label: 'Kaydet', onPressed: _submit),
      ],
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _floorId,
            decoration: mallInput('Kat *', error: _floorError),
            items: [
              for (final floor in widget.floors) DropdownMenuItem(value: floor.id, child: Text(floor.name)),
            ],
            onChanged: (value) => setState(() => _floorId = value),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('mall-unit-code'),
                  controller: _code,
                  decoration: mallInput('Mağaza no *', hint: 'Örn. 102', error: _codeError),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _area,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: mallInput('Alan (m²)', error: _areaError),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: mallInput('Etiket', hint: 'İsteğe bağlı')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: mallInput('Alan türü'),
            items: [
              for (final type in MallUnitType.values)
                DropdownMenuItem(value: type, child: Text(MallUnitType.label(type))),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'store'),
          ),
          const SizedBox(height: 16),
          if (_occupied)
            const Align(
              alignment: Alignment.centerLeft,
              child: MallBadge('Dolu — onaylı mağaza bağlantısı var', tone: MallTone.success),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _occupancy,
              decoration: mallInput('Durum'),
              items: [
                for (final value in MallUnitOccupancy.editable)
                  DropdownMenuItem(value: value, child: Text(MallUnitOccupancy.label(value))),
              ],
              onChanged: (value) => setState(() => _occupancy = value ?? 'vacant'),
            ),
        ],
      ),
    );
  }

  void _submit() {
    setState(() {
      _codeError = MallUnitValidation.codeError(_code.text);
      _areaError = MallUnitValidation.areaError(_area.text);
      _floorError = _floorId == null ? 'Kat seçin.' : null;
    });
    if (_codeError != null || _areaError != null || _floorError != null) return;
    final areaText = _area.text.trim();
    Navigator.pop(
      context,
      MallUnitDraft(
        floorId: _floorId!,
        unitCode: _code.text.trim(),
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
        unitType: _type,
        occupancy: _occupancy,
        areaM2: areaText.isEmpty ? null : double.tryParse(areaText.replaceAll(',', '.')),
      ),
    );
  }
}
