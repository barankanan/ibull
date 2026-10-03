import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants.dart';
import '../../../core/turkiye_location_data.dart';
import '../../../services/location_access_service.dart';
import 'mall_location_sync.dart';

class MallLocationEditor extends StatefulWidget {
  const MallLocationEditor({
    super.key,
    required this.city,
    required this.district,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.onPoint,
    required this.onClearPoint,
    this.geocode = const NominatimMallGeocodeClient(),
    this.onCamera,
  });

  final TextEditingController city;
  final TextEditingController district;
  final TextEditingController address;
  final double? latitude;
  final double? longitude;
  final void Function(double latitude, double longitude) onPoint;
  final VoidCallback onClearPoint;
  final MallGeocodeClient geocode;
  final ValueChanged<MallMapFocus>? onCamera;

  @override
  State<MallLocationEditor> createState() => _MallLocationEditorState();
}

class _MallLocationEditorState extends State<MallLocationEditor> {
  final _gate = MallGeocodeGate();
  Timer? _addressTimer;
  MallLocationSource? _source;
  String _addressSnapshot = '';
  MallMapFocus? _focus;
  List<MallGeocodeHit> _suggestions = const [];
  String? _notice;
  var _searching = false;

  @override
  void dispose() {
    _addressTimer?.cancel();
    super.dispose();
  }

  List<String> get _districts => MallLocationSync.districtsFor(widget.city.text);

  Future<void> _selectCity(String city) async {
    _addressTimer?.cancel();
    widget.city.text = city;
    widget.district.text = '';
    _source = MallLocationSource.city;
    _suggestions = const [];
    widget.onClearPoint();
    setState(() => _notice = null);
    await _focusQuery(
      MallLocationSync.placeQuery(district: '', city: city),
      zoom: 10,
      source: MallLocationSource.city,
    );
  }

  Future<void> _selectDistrict(String district) async {
    _addressTimer?.cancel();
    widget.district.text = district;
    _source = MallLocationSource.district;
    _suggestions = const [];
    widget.onClearPoint();
    setState(() => _notice = null);
    await _focusQuery(
      MallLocationSync.placeQuery(district: district, city: widget.city.text),
      zoom: 13,
      source: MallLocationSource.district,
    );
  }

  void _onAddressChanged(String value) {
    _suggestions = const [];
    if (!MallLocationSync.shouldSearchAddress(
      source: _source,
      snapshot: _addressSnapshot,
      current: value,
    )) {
      return;
    }
    _addressTimer?.cancel();
    _addressTimer = Timer(const Duration(milliseconds: 800), () {
      _searchAddress(MallLocationSource.addressSearch);
    });
  }

  Future<void> _searchAddress(MallLocationSource source) async {
    final query = MallLocationSync.searchQuery(
      address: widget.address.text,
      district: widget.district.text,
      city: widget.city.text,
    );
    final id = _gate.begin();
    setState(() => _searching = true);
    final suggestions = await widget.geocode.suggest(query);
    if (!mounted || !_gate.isCurrent(id)) return;
    final hit = suggestions.isNotEmpty
        ? suggestions.first
        : await widget.geocode.search(query);
    if (!mounted || !_gate.isCurrent(id)) return;
    setState(() {
      _searching = false;
      _suggestions = suggestions;
      _source = source;
      _addressSnapshot = widget.address.text;
      if (hit == null) {
        _notice = MallLocationSync.geocodeMiss;
      } else {
        _notice = null;
        _applyHit(hit, zoom: 17, movePin: true);
      }
    });
  }

  Future<void> _focusQuery(
    String query, {
    required double zoom,
    required MallLocationSource source,
  }) async {
    final id = _gate.begin();
    final hit = await widget.geocode.search(query);
    if (!mounted || !_gate.isCurrent(id) || hit == null) return;
    _source = source;
    _moveCamera(hit.latitude, hit.longitude, zoom);
    setState(() {});
  }

  void _applyHit(MallGeocodeHit hit, {required double zoom, required bool movePin}) {
    _moveCamera(hit.latitude, hit.longitude, zoom);
    if (movePin) widget.onPoint(hit.latitude, hit.longitude);
  }

  void _moveCamera(double latitude, double longitude, double zoom) {
    final focus = MallMapFocus(latitude: latitude, longitude: longitude, zoom: zoom);
    _focus = focus;
    widget.onCamera?.call(focus);
  }

  void _onMapTap(double latitude, double longitude) {
    _addressTimer?.cancel();
    _gate.begin();
    _source = MallLocationSource.manualMap;
    _addressSnapshot = widget.address.text;
    _suggestions = const [];
    _notice = null;
    widget.onPoint(latitude, longitude);
    setState(() {});
  }

  Future<void> _usePinAsAddress() async {
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    if (latitude == null || longitude == null) return;
    final id = _gate.begin();
    final hit = await widget.geocode.reverse(latitude, longitude);
    if (!mounted || !_gate.isCurrent(id)) return;
    if (hit == null || (hit.street ?? '').trim().isEmpty) {
      setState(() => _notice = MallLocationSync.geocodeMiss);
      return;
    }
    _fillFromHit(hit);
    _addressSnapshot = widget.address.text;
    setState(() => _notice = null);
  }

  Future<void> _useCurrent() async {
    final permission = await LocationAccessService.instance.ensurePermission();
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => _notice = 'Konum izni verilmedi. Haritadan noktayı elle seçebilirsiniz.');
      return;
    }
    final position = await LocationAccessService.instance.getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      setState(() => _notice = 'Konum alınamadı. Haritadan noktayı elle seçebilirsiniz.');
      return;
    }
    final id = _gate.begin();
    _source = MallLocationSource.currentLocation;
    widget.onPoint(position.latitude, position.longitude);
    _moveCamera(position.latitude, position.longitude, 16);
    final hit = await widget.geocode.reverse(position.latitude, position.longitude);
    if (!mounted || !_gate.isCurrent(id)) return;
    if (hit != null) _fillFromHit(hit);
    _addressSnapshot = widget.address.text;
    setState(() => _notice = null);
  }

  void _applySuggestion(MallGeocodeHit hit) {
    _addressTimer?.cancel();
    _gate.begin();
    final city = MallLocationSync.matchOption(hit.city, TurkiyeLocationData.provinces);
    if (city != null) {
      widget.city.text = city;
      final district = MallLocationSync.matchOption(
        hit.district,
        MallLocationSync.districtsFor(city),
      );
      if (district != null) widget.district.text = district;
    }
    final label = hit.label.split(',').first.trim();
    if (label.isNotEmpty) widget.address.text = label;
    _source = MallLocationSource.addressSearch;
    _addressSnapshot = widget.address.text;
    _suggestions = const [];
    _notice = null;
    _applyHit(hit, zoom: 17, movePin: true);
    setState(() {});
  }

  void _fillFromHit(MallGeocodeHit hit) {
    final city = MallLocationSync.matchOption(hit.city, TurkiyeLocationData.provinces);
    if (city != null) {
      widget.city.text = city;
      final district = MallLocationSync.matchOption(
        hit.district,
        MallLocationSync.districtsFor(city),
      );
      if (district != null) widget.district.text = district;
    }
    final street = (hit.street ?? '').trim();
    if (street.isNotEmpty) widget.address.text = street;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _select(
          label: 'Şehir *',
          value: widget.city.text,
          options: TurkiyeLocationData.provinces,
          enabled: true,
          onSelected: _selectCity,
        ),
        const SizedBox(height: 12),
        _select(
          label: 'İlçe *',
          value: widget.district.text,
          options: _districts,
          enabled: widget.city.text.trim().isNotEmpty,
          onSelected: _selectDistrict,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.address,
          maxLines: 3,
          onChanged: (value) {
            setState(() {});
            _onAddressChanged(value);
          },
          decoration: const InputDecoration(
            labelText: 'Açık adres *',
            hintText: 'Numune Mah. İbrahim Karaoğlanoğlu Cad. No:29',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        for (final hit in _suggestions.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(hit.label, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => _applySuggestion(hit),
          ),
        if (_notice != null) ...[
          const SizedBox(height: 8),
          Text(_notice!, style: const TextStyle(color: AppColors.danger)),
        ],
        const SizedBox(height: 12),
        MallLocationPicker(
          latitude: widget.latitude,
          longitude: widget.longitude,
          focus: _focus,
          onChanged: _onMapTap,
          onCurrentLocation: _useCurrent,
        ),
        if (widget.latitude != null && _source == MallLocationSource.manualMap)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _usePinAsAddress,
              child: const Text('Bu konumu adres olarak kullan'),
            ),
          ),
      ],
    );
  }

  Widget _select({
    required String label,
    required String value,
    required List<String> options,
    required bool enabled,
    required ValueChanged<String> onSelected,
  }) {
    return Autocomplete<String>(
      key: ValueKey('$label|$value|${options.length}|$enabled'),
      initialValue: TextEditingValue(text: enabled ? value : ''),
      optionsBuilder: (text) {
        if (!enabled) return const Iterable<String>.empty();
        final query = MallLocationSync.foldTr(text.text);
        return options.where((option) {
          return query.isEmpty || MallLocationSync.foldTr(option).contains(query);
        });
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focus, onSubmit) {
        return TextField(
          controller: controller,
          focusNode: focus,
          enabled: enabled,
          readOnly: !enabled,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }
}

class MallLocationPicker extends StatefulWidget {
  const MallLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.focus,
    this.onCurrentLocation,
    this.enabled = true,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double latitude, double longitude) onChanged;
  final MallMapFocus? focus;
  final Future<void> Function()? onCurrentLocation;
  final bool enabled;

  @override
  State<MallLocationPicker> createState() => _MallLocationPickerState();
}

class _MallLocationPickerState extends State<MallLocationPicker> {
  final MapController _controller = MapController();
  var _locating = false;
  MallMapFocus? _applied;

  @override
  void didUpdateWidget(MallLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focus = widget.focus;
    if (focus == null || identical(focus, _applied)) return;
    _applied = focus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.move(LatLng(focus.latitude, focus.longitude), focus.zoom);
    });
  }

  Future<void> _current() async {
    final action = widget.onCurrentLocation;
    if (action == null) return;
    setState(() => _locating = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = widget.latitude != null && widget.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('AVM ana giriş noktasını haritada işaretleyin.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: !widget.enabled || _locating ? null : _current,
          icon: const Icon(Icons.my_location, size: 16),
          label: Text(_locating ? 'Bulunuyor...' : 'Bulunduğum Konum'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 280,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderStrong),
          ),
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(
                widget.latitude ?? 39,
                widget.longitude ?? 35,
              ),
              initialZoom: hasPin ? 15 : 5.5,
              onTap: widget.enabled
                  ? (_, point) => widget.onChanged(point.latitude, point.longitude)
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ibul.app',
              ),
              if (hasPin)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.latitude!, widget.longitude!),
                      width: 36,
                      height: 36,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 36,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
