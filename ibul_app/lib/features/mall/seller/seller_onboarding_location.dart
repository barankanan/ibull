import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../seller/onboarding/seller_onboarding_chrome.dart';
import '../management/models/mall_store_link.dart';
import '../management/widgets/mall_panel_kit.dart';
import 'seller_mall_apply_dialog.dart';
import 'seller_mall_link_repository.dart';
import 'seller_mall_models.dart';

export 'seller_mall_models.dart' show SellerOnboardingLocationKind, SellerOnboardingMallDraft;

typedef SellerAreaMallLoader = Future<List<SellerMallOption>> Function(String city, String district);
typedef SellerMallFloorLoader = Future<List<SellerMallFloorOption>> Function(String mallId, String mallName);

/// "Mağazanız nerede?" plus city/district AVM list, floor and documents.
class SellerOnboardingLocationStep extends StatefulWidget {
  const SellerOnboardingLocationStep({
    super.key,
    required this.kind,
    required this.onKind,
    required this.standalone,
    required this.city,
    required this.district,
    required this.onPickCityDistrict,
    this.addressField,
    this.repository,
    this.listMalls,
    this.listFloors,
    this.pickFile,
    this.onMallDraft,
  });

  final SellerOnboardingLocationKind? kind;
  final ValueChanged<SellerOnboardingLocationKind> onKind;
  final Widget standalone;
  final String city;
  final String district;
  final VoidCallback onPickCityDistrict;
  final Widget? addressField;
  final SellerMallLinkRepository? repository;
  final SellerAreaMallLoader? listMalls;
  final SellerMallFloorLoader? listFloors;
  final SellerMallFilePicker? pickFile;
  final ValueChanged<SellerOnboardingMallDraft?>? onMallDraft;

  @override
  State<SellerOnboardingLocationStep> createState() => _SellerOnboardingLocationStepState();
}

class _SellerOnboardingLocationStepState extends State<SellerOnboardingLocationStep> {
  late final _repository = widget.repository ?? SellerMallLinkRepository();
  late final _pick = widget.pickFile ?? pickSellerMallFile;
  final _filter = TextEditingController();
  final _unit = TextEditingController();
  final _area = TextEditingController();
  final _note = TextEditingController();
  final _files = <String, SellerMallFile>{};
  late final _requestId = SellerMallApplicationDraft.newRequestId();
  List<SellerMallOption> _results = const [];
  SellerMallOption? _mall;
  String? _floorId;
  var _busy = false;
  var _loadingFloors = false;
  var _loaded = false;
  String? _error;

  SellerAreaMallLoader get _loadMalls =>
      widget.listMalls ?? ((city, district) => _repository.listMallsInArea(city: city, district: district));

  SellerMallFloorLoader get _loadFloors =>
      widget.listFloors ??
      ((mallId, mallName) => _repository.listFloorsForMall(mallId: mallId, mallName: mallName));

  bool get _hasArea => widget.city.trim().isNotEmpty && widget.district.trim().isNotEmpty;

  List<SellerMallOption> get _visible {
    final query = _filter.text.trim().toLowerCase();
    if (query.isEmpty) return _results;
    return _results.where((mall) => mall.name.toLowerCase().contains(query)).toList();
  }

  void _emit() {
    final mall = _mall;
    if (mall == null) {
      widget.onMallDraft?.call(null);
      return;
    }
    widget.onMallDraft?.call(SellerOnboardingMallDraft(
      requestId: _requestId,
      mall: mall,
      floorId: _floorId,
      unitCode: _unit.text.trim(),
      areaM2: double.tryParse(_area.text.replaceAll(',', '.')),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      files: _files.values.toList(),
    ));
  }

  void _resetMall({required bool emit}) {
    _mall = null;
    _floorId = null;
    _loadingFloors = false;
    _unit.clear();
    _note.clear();
    if (emit) widget.onMallDraft?.call(null);
  }

  Future<void> _selectMall(SellerMallOption mall) async {
    setState(() {
      _mall = mall;
      _floorId = null;
      _unit.clear();
      _loadingFloors = true;
      _error = null;
    });
    _emit();
    try {
      final floors = await _loadFloors(mall.id, mall.name);
      if (!mounted || _mall?.id != mall.id) return;
      final sorted = [...floors]..sort(SellerMallFloorOption.compare);
      setState(() {
        _mall = mall.withFloors(sorted);
        _floorId = sorted.length == 1 ? sorted.first.id : null;
        _loadingFloors = false;
        if (sorted.isEmpty) {
          _error = 'Bu AVM için kat kaydı bulunamadı.';
        }
      });
      _emit();
    } catch (_) {
      if (!mounted || _mall?.id != mall.id) return;
      setState(() {
        _loadingFloors = false;
        _error = 'Katlar yüklenemedi. Lütfen tekrar deneyin.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.kind == SellerOnboardingLocationKind.mall && _hasArea) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    }
  }

  @override
  void didUpdateWidget(covariant SellerOnboardingLocationStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final areaChanged = oldWidget.city != widget.city || oldWidget.district != widget.district;
    if (areaChanged) {
      setState(() {
        _results = const [];
        _loaded = false;
        _error = null;
        _resetMall(emit: true);
      });
    }
    final shouldLoad = widget.kind == SellerOnboardingLocationKind.mall && _hasArea;
    if (shouldLoad && (areaChanged || oldWidget.kind != widget.kind)) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _filter.dispose();
    _unit.dispose();
    _area.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Mağazanız nerede?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 4),
      const Text(
        'Önce konum tipini seçin. AVM içindeyseniz isim yazmanıza gerek yok.',
        style: TextStyle(color: SellerOnboardTokens.muted, height: 1.4),
      ),
      const SizedBox(height: 10),
      RadioGroup<SellerOnboardingLocationKind>(
        groupValue: widget.kind,
        onChanged: (value) {
          if (value == null) return;
          widget.onKind(value);
          if (value == SellerOnboardingLocationKind.standalone) {
            setState(() => _resetMall(emit: true));
          } else if (_hasArea) {
            _refresh();
          }
        },
        child: const Column(children: [
          RadioListTile<SellerOnboardingLocationKind>(
            key: ValueKey('seller-location-standalone'),
            value: SellerOnboardingLocationKind.standalone,
            title: Text('Bağımsız adreste / cadde mağazası'),
          ),
          RadioListTile<SellerOnboardingLocationKind>(
            key: ValueKey('seller-location-mall'),
            value: SellerOnboardingLocationKind.mall,
            title: Text('AVM içerisinde'),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (widget.kind != null) _cityDistrictRow(),
      if (widget.kind == SellerOnboardingLocationKind.standalone) ...[
        if (widget.addressField != null) ...[const SizedBox(height: 12), widget.addressField!],
        const SizedBox(height: 12),
        widget.standalone,
      ],
      if (widget.kind == SellerOnboardingLocationKind.mall) ...[const SizedBox(height: 16), _mallBlock()],
    ]);
  }

  Widget _cityDistrictRow() {
    return Row(children: [
      Expanded(child: _areaChip('İl *', widget.city.isEmpty ? 'İl seçin' : widget.city)),
      const SizedBox(width: 12),
      Expanded(child: _areaChip('İlçe *', widget.district.isEmpty ? 'İlçe seçin' : widget.district)),
    ]);
  }

  Widget _areaChip(String label, String value) {
    return InkWell(
      key: ValueKey('seller-onboard-area-$label'),
      onTap: widget.onPickCityDistrict,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SellerOnboardTokens.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: SellerOnboardTokens.muted)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _mallBlock() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_error != null) ...[
        _softAlert(_error!),
        const SizedBox(height: 12),
      ],
      if (_mall == null) ...[
        TextField(
          key: const ValueKey('seller-onboard-mall-filter'),
          controller: _filter,
          decoration: mallInput('Liste içinde ara', hint: 'İsteğe bağlı'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 14),
        const Text('Bu bölgedeki AVM’ler', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (!_hasArea)
          const SellerOnboardEmpty(
            key: ValueKey('seller-onboard-mall-need-area'),
            icon: Icons.location_city_outlined,
            title: 'AVM seçmek için önce il ve ilçe bilgisi girin.',
          )
        else if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          )
        else if (_loaded && _results.isEmpty)
          const SellerOnboardEmpty(
            key: ValueKey('seller-onboard-mall-empty'),
            icon: Icons.storefront_outlined,
            title: 'Bu bölgede uygun AVM bulunamadı.',
            subtitle: 'Bağımsız mağaza olarak devam edebilir veya başka ilçe seçebilirsiniz.',
          )
        else
          Column(
            key: const ValueKey('seller-onboard-mall-list'),
            children: [for (final mall in _visible) _mallCard(mall)],
          ),
      ] else ...[
        _selectedMallCard(),
        const SizedBox(height: 14),
        if (_loadingFloors)
          const Padding(
            key: ValueKey('seller-onboard-floors-loading'),
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Katlar yükleniyor...'),
          )
        else
          DropdownButtonFormField<String>(
            key: const ValueKey('seller-onboard-floor'),
            initialValue: _mall!.floors.any((floor) => floor.id == _floorId) ? _floorId : null,
            isExpanded: true,
            decoration: mallInput('Kat *', hint: _mall!.floors.isEmpty ? 'Kat bulunamadı' : 'Kat seçin'),
            items: [
              for (final floor in _mall!.floors) DropdownMenuItem(value: floor.id, child: Text(floor.name)),
            ],
            onChanged: _mall!.floors.isEmpty
                ? null
                : (value) {
                    setState(() => _floorId = value);
                    _emit();
                  },
          ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('seller-onboard-unit'),
          controller: _unit,
          decoration: mallInput(
            'Mağaza No / Alan Kodu *',
            hint: 'AVM içerisindeki mağaza veya alan numarası. Örn: 105, Z-12.',
          ),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('seller-onboard-area'),
          controller: _area,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: mallInput('Alan (m²)'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('seller-onboard-note'),
          controller: _note,
          maxLines: 3,
          decoration: mallInput('Not / açıklama'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 16),
        const Text('AVM kira sözleşmesi veya yer tahsis belgesi — birini yükleyin.', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final type in MallLinkDocument.types)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(MallLinkDocument.labelFor(type)),
            subtitle: Text(_files[type]?.name ?? (MallLinkDocument.required.contains(type) ? 'Zorunlu (birini yükleyin)' : 'İsteğe bağlı')),
            trailing: TextButton(
              key: ValueKey('seller-onboard-pick-$type'),
              onPressed: () async {
                try {
                  final file = await _pick(type);
                  if (file != null) setState(() => _files[type] = file);
                  _emit();
                } catch (error) {
                  setState(() => _error = 'Belge yüklenemedi. Lütfen tekrar deneyin.');
                }
              },
              child: Text(_files.containsKey(type) ? 'Değiştir' : 'Yükle'),
            ),
          ),
        const SizedBox(height: 8),
        _placementSummary(),
      ],
    ]);
  }

  Widget _selectedMallCard() {
    final mall = _mall!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDD7F5)),
      ),
      child: Row(children: [
        mallLogo(mall.logoUrl, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mall.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            if (mall.locationLabel.isNotEmpty)
              Text(mall.locationLabel, style: const TextStyle(color: SellerOnboardTokens.muted)),
          ]),
        ),
        TextButton(
          onPressed: () => setState(() {
            _resetMall(emit: true);
          }),
          child: const Text('AVM değiştir'),
        ),
      ]),
    );
  }

  Widget _placementSummary() {
    return Container(
      key: const ValueKey('seller-onboard-mall-summary'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Konum özeti', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Seçilen AVM:\n${_mall!.name}'),
        if (_mall!.locationLabel.isNotEmpty) Text(_mall!.locationLabel),
        Text('Seçilen Kat:\n${_floorId == null ? '—' : _mall!.floors.where((f) => f.id == _floorId).firstOrNull?.name ?? '—'}'),
        Text('Mağaza No:\n${_unit.text.trim().isEmpty ? '—' : _unit.text.trim()}'),
      ]),
    );
  }

  Widget _mallCard(SellerMallOption mall) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      child: Row(children: [
        mallLogo(mall.logoUrl, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mall.name, key: ValueKey('seller-onboard-mall-${mall.name}'), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              [if (mall.locationLabel.isNotEmpty) mall.locationLabel, if (mall.isVerified) 'Doğrulandı'].join(' • '),
              style: const TextStyle(color: SellerOnboardTokens.muted, fontSize: 12),
            ),
          ]),
        ),
        FilledButton(
          onPressed: () => _selectMall(mall),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('Seç'),
        ),
      ]),
    );
  }

  Widget _softAlert(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Text(text, style: const TextStyle(color: Color(0xFF9A3412))),
    );
  }

  Future<void> _refresh() async {
    if (!_hasArea) {
      setState(() {
        _results = const [];
        _loaded = false;
        _busy = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await _loadMalls(widget.city, widget.district);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'AVM listesi yüklenemedi. Lütfen tekrar deneyin.';
        _results = const [];
        _loaded = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
