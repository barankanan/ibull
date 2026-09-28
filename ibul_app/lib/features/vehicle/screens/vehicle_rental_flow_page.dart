import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../screens/login_page.dart';
import '../../../widgets/ibul_page_state.dart';
import '../../../features/seller/contracts/store_contract.dart';
import '../../../features/seller/contracts/store_contract_repository.dart';
import '../data/vehicle_listing_repository.dart';
import '../domain/turkish_national_id.dart';
import '../domain/vehicle_availability.dart';
import '../domain/vehicle_delivery_fee.dart';
import '../domain/vehicle_delivery_geocode.dart';
import '../domain/vehicle_pricing.dart';
import '../domain/vehicle_rental_validation.dart';
import '../models/vehicle_enums.dart';
import '../models/vehicle_listing.dart';
import '../services/vehicle_service.dart';
import '../widgets/vehicle_rental_chrome.dart';
import '../widgets/vehicle_rental_document_preview.dart';
import 'vehicle_rental_flow_checkout.dart';
import 'vehicle_rental_flow_steps.dart';

class VehicleRentalFlowPage extends StatefulWidget {
  const VehicleRentalFlowPage({super.key, required this.listingId});

  final String listingId;

  @override
  State<VehicleRentalFlowPage> createState() => _VehicleRentalFlowPageState();
}

class _VehicleRentalFlowPageState extends State<VehicleRentalFlowPage> {
  VehicleListing? _listing;
  bool _loading = true;
  String? _error;
  String? _stepError;
  int _step = 0;
  bool _selectingPickup = true;
  DateTime _month = DateTime.now();
  DateTime _pickup = VehicleRentalPricing.defaultPickup();
  DateTime _returnAt = VehicleRentalPricing.defaultReturn(
    VehicleRentalPricing.defaultPickup(),
    1,
  );
  VehicleDeliveryMode _pickupMode = VehicleDeliveryMode.galleryPickup;
  VehicleDeliveryMode _dropoffMode = VehicleDeliveryMode.galleryPickup;
  bool _airport = false;
  bool _terms = false;
  bool _consent = false;
  bool _receiverSelf = true;
  bool _busy = false;
  bool _summaryOpen = false;
  String? _reservationId;
  String? _submitStatus;
  String? _rentalCode;
  Map<String, dynamic>? _quote;
  List<VehicleBusyInterval> _busyWindows = const [];
  List<VehicleDeliveryZoneQuote> _zones = const [];
  LatLng? _pin;
  bool _pinFromMap = false;
  String? _pinBoundAddress;
  VehicleDocumentType? _docBusy;
  String _licenseClass = 'B';
  DateTime? _birthDate;
  DateTime? _licenseIssued;
  final _uploaded = <VehicleDocumentType>{};
  final _previews = <VehicleDocumentType, Uint8List>{};
  VehicleDocumentType? _uploadFailed;
  StoreContractVersion? _contract;
  bool _contractLoaded = false;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nationalId = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _neighborhood = TextEditingController();
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _note = TextEditingController();
  final _receiverName = TextEditingController();
  final _receiverPhone = TextEditingController();

  static const _labels = [
    'Tarih',
    'Teslim',
    'Bilgiler',
    'Belgeler',
    'Özet',
    'Ödeme',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _nationalId, _phone, _email, _city, _district, _neighborhood,
      _street, _building, _note, _receiverName, _receiverPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  VehicleRentalSettings get _settings =>
      _listing?.rental ?? const VehicleRentalSettings(dailyPrice: 0);

  int get _days => VehicleRentalPricing.rentalDays(pickupAt: _pickup, returnAt: _returnAt);

  double get _rentalSubtotal => VehicleRentalPricing.rentalSubtotal(
        days: _days,
        dailyPrice: _settings.dailyPrice,
        weeklyPrice: _settings.weeklyPrice,
        monthlyPrice: _settings.monthlyPrice,
      );

  double get _deliveryFee {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) return 0;
    if (_quote?['ok'] != true) return 0;
    return (_quote!['fee'] as num?)?.toDouble() ?? 0;
  }

  String get _deliverySummaryText {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) return '0 TL';
    if (_quote?['ok'] == true) return moneyLabel(_deliveryFee);
    return '—';
  }

  double get _deposit => _settings.deposit;

  double get _total => VehicleRentalPricing.checkoutTotal(
        rentalSubtotal: _rentalSubtotal,
        deliveryFee: _deliveryFee,
        deposit: _deposit,
      );

  String? get _durationError => VehicleRentalPricing.durationMessage(
        days: _days,
        minDays: _settings.minDays,
        maxDays: _settings.maxDays,
        pickupAt: _pickup,
      );

  bool get _roadZones => _zones.any((z) => !z.isAirport);

  bool get _airportZones => _zones.any((z) => z.isAirport);

  bool get _homeEnabled => _settings.homeDelivery && _roadZones;

  bool get _mapEnabled => _settings.mapPointDelivery && _roadZones;

  double? get _customerLat =>
      _pickupMode == VehicleDeliveryMode.galleryPickup
          ? _listing?.gallery?.lat
          : _pin?.latitude;

  double? get _customerLng =>
      _pickupMode == VehicleDeliveryMode.galleryPickup
          ? _listing?.gallery?.lng
          : _pin?.longitude;

  bool? get _zoneOk {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) return true;
    if (_pin == null) return null;
    if (_quote == null) return null;
    return _quote!['ok'] == true;
  }

  String? get _zoneMessage {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) {
      return 'Galeriden teslim · Teslim 0 TL';
    }
    if (_pin == null) {
      return 'Teslim konumunu haritada seçin.';
    }
    if (_quote == null) return null;
    if (_quote!['ok'] == true) {
      final km = (_quote!['km'] as num?)?.toDouble();
      final kmText = km == null ? '' : 'Mesafe: ${km.toStringAsFixed(1)} km. ';
      return '✓ Bu adrese teslimat yapılabilir. $kmText Teslim ücreti: ${moneyLabel(_deliveryFee)}';
    }
    return VehicleDeliveryQuoteError.sanitizeForUi(
      _quote!['error']?.toString(),
    );
  }

  String get _addressText {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) {
      return [
        _listing?.gallery?.address,
        _listing?.gallery?.district,
        _listing?.gallery?.city,
      ].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
    }
    return [
      _city.text, _district.text, _neighborhood.text, _street.text,
      _building.text, _note.text,
    ].where((e) => e.trim().isNotEmpty).join(', ');
  }

  String get _deliveryAddressKey => [
        _city.text,
        _district.text,
        _neighborhood.text,
        _street.text,
      ].map((e) => e.trim().toLowerCase()).join('|');

  bool _isGalleryCoordinate(LatLng point) {
    final gallery = _listing?.gallery;
    if (gallery?.lat == null || gallery?.lng == null) return false;
    return VehicleDeliveryFeeCalculator.haversineKm(
          fromLat: point.latitude,
          fromLng: point.longitude,
          toLat: gallery!.lat!,
          toLng: gallery.lng!,
        ) <=
        0.2;
  }

  void _discardStalePin() {
    if (_pin == null || _pinFromMap) return;
    final staleGallery = _isGalleryCoordinate(_pin!);
    final addressChanged =
        _pinBoundAddress != null && _pinBoundAddress != _deliveryAddressKey;
    if (staleGallery || addressChanged) {
      debugPrint(
        'vehicle delivery discarded stale pin gallery=$staleGallery '
        'addressChanged=$addressChanged',
      );
      _pin = null;
      _pinBoundAddress = null;
      _quote = null;
    }
  }

  void _showStepError(String message) {
    if (!mounted) return;
    setState(() {
      _stepError = VehicleDeliveryQuoteError.sanitizeForUi(message);
    });
  }

  String get _customerNote => jsonEncode({
        'license_class': _licenseClass,
        'license_issued': _licenseIssued?.toIso8601String().split('T').first,
        'receiver_self': _receiverSelf,
        if (!_receiverSelf) 'receiver_name': _receiverName.text.trim(),
        if (!_receiverSelf) 'receiver_phone': _receiverPhone.text.trim(),
      });

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: IbulPageState.loading());
    if (_error != null || _listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: IbulPageState.error(title: _error ?? 'Hata', onAction: _load),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final done = _step >= _labels.length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Kiralama · ${_listing!.title}', overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.ink,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: VehicleRentalStepper(
              labels: _labels,
              index: done ? _labels.length - 1 : _step,
            ),
          ),
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 65, child: _stepPane(wide: true)),
                      Expanded(flex: 35, child: _summaryPane()),
                    ],
                  )
                : _stepPane(wide: false),
          ),
        ],
      ),
      bottomNavigationBar: done
          ? null
          : SafeArea(
              child: _bottomBar(wide: wide),
            ),
    );
  }

  Widget _stepPane({required bool wide}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (_stepError != null) VehicleRentalErrorBanner(message: _stepError!),
        if (_step == 0)
          VehicleRentalDatesStep(
            pickup: _pickup,
            returnAt: _returnAt,
            days: _days,
            datesFree: VehicleAvailability.isFree(
              pickupAt: _pickup,
              returnAt: _returnAt,
              busy: _busyWindows,
            ),
            minDays: _settings.minDays,
            maxDays: _settings.maxDays,
            busy: _busyWindows,
            month: _month,
            selectingPickup: _selectingPickup,
            durationError: _durationError,
            onSelectPickup: (d) => _setPickupDate(d),
            onSelectReturn: (d) => _setReturnDate(d),
            onToggleTarget: () => setState(() => _selectingPickup = !_selectingPickup),
            onMonth: (m) => setState(() => _month = m),
            onPickPickupTime: () => _pickTime(true),
            onPickReturnTime: () => _pickTime(false),
          ),
        if (_step == 1)
          VehicleRentalDeliveryStep(
            listing: _listing!,
            pickupMode: _pickupMode,
            dropoffMode: _dropoffMode,
            city: _city,
            district: _district,
            neighborhood: _neighborhood,
            street: _street,
            building: _building,
            note: _note,
            receiverSelf: _receiverSelf,
            receiverName: _receiverName,
            receiverPhone: _receiverPhone,
            airport: _airport,
            pin: _pin,
            homeEnabled: _homeEnabled,
            mapEnabled: _mapEnabled,
            airportEnabled: _airportZones,
            zoneOk: _zoneOk,
            zoneMessage: _zoneMessage,
            onPickupMode: _setPickupMode,
            onDropoffMode: (v) => setState(() => _dropoffMode = v),
            onReceiverSelf: (v) => setState(() => _receiverSelf = v),
            onAirport: (v) {
              setState(() => _airport = v);
              _refreshQuote();
            },
            onPin: (point) => _setPin(point, fromMap: true),
            onLocate: _locateFromAddress,
          ),
        if (_step == 2)
          VehicleRentalCustomerStep(
            firstName: _firstName,
            lastName: _lastName,
            nationalId: _nationalId,
            phone: _phone,
            email: _email,
            licenseClass: _licenseClass,
            birthDate: _birthDate,
            licenseIssued: _licenseIssued,
            minAge: _settings.minDriverAge ?? 18,
            minLicenseYears: _settings.minLicenseYears ?? 0,
            consent: _consent,
            onBirthDate: _pickBirth,
            onLicenseIssued: _pickLicense,
            onLicenseClass: (v) => setState(() => _licenseClass = v),
            onConsent: (v) => setState(() => _consent = v),
          ),
        if (_step == 3)
          VehicleRentalDocsStep(
            uploaded: _uploaded,
            busyType: _docBusy,
            previews: _previews,
            uploadFailed: _uploadFailed,
            onUpload: _uploadDoc,
            onReplace: _uploadDoc,
            onDelete: _deleteDoc,
            onRetry: _retryDoc,
            onView: _viewDoc,
          ),
        if (_step == 4)
          VehicleRentalSummaryStep(
            listing: _listing!,
            days: _days,
            pickup: _pickup,
            returnAt: _returnAt,
            pickupLabel: deliveryModeLabel(_pickupMode, dropoff: false),
            dropoffLabel: deliveryModeLabel(_dropoffMode, dropoff: true),
            customerName: '${_firstName.text} ${_lastName.text}'.trim(),
            customerPhone: _phone.text.trim(),
            customerEmail: _maskEmail(_email.text),
            nationalIdMasked: TurkishNationalId.mask(_nationalId.text),
            address: _addressText,
            rental: _rentalSubtotal,
            delivery: _deliveryFee,
            deposit: _deposit,
            total: _total,
            terms: _terms,
            contractMissing: _contractLoaded && _contract == null,
            onViewContract: _viewContract,
            onTerms: (v) => setState(() => _terms = v),
          ),
        if (_step == 5)
          VehicleRentalPaymentStep(total: _total),
        if (_step >= 6)
          VehicleRentalDoneStep(status: _submitStatus, rentalCode: _rentalCode),
        if (wide && _step < 6) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _busy ? null : _continue,
              child: Text(_cta()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryPane() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: VehicleRentalSummaryPanel(
        listing: _listing!,
        pickup: _pickup,
        returnAt: _returnAt,
        days: _days,
        rental: _rentalSubtotal,
        delivery: _deliveryFee,
        deposit: _deposit,
        total: _total,
        pickupLabel: deliveryModeLabel(_pickupMode, dropoff: false),
        dropoffLabel: deliveryModeLabel(_dropoffMode, dropoff: true),
        deliveryText: _deliverySummaryText,
      ),
    );
  }

  Widget _bottomBar({required bool wide}) {
    if (wide) return const SizedBox.shrink();
    return Material(
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _summaryOpen = !_summaryOpen),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Toplam  ${moneyLabel(_total)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(_summaryOpen ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_summaryOpen) _summaryPane(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _continue,
                child: Text(_cta()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cta() => switch (_step) {
        5 => 'TALEBİ SATICIYA GÖNDER',
        _ => 'Devam Et',
      };

  void _setPickupDate(DateTime day) {
    final next = VehicleRentalPricing.atHour(day, hour: _pickup.hour, minute: _pickup.minute);
    var ret = _returnAt;
    final earliest = VehicleRentalPricing.earliestReturnAt(next, _settings.minDays);
    if (!ret.isAfter(next) || VehicleRentalPricing.rentalDays(pickupAt: next, returnAt: ret) < _settings.minDays) {
      ret = earliest;
    }
    setState(() {
      _pickup = next;
      _returnAt = ret;
      _stepError = null;
    });
  }

  void _setReturnDate(DateTime day) {
    setState(() {
      _returnAt = VehicleRentalPricing.atHour(day, hour: _returnAt.hour, minute: _returnAt.minute);
      _stepError = null;
    });
  }

  Future<void> _pickTime(bool pickup) async {
    final initial = pickup ? _pickup : _returnAt;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(initial.year, initial.month, initial.day, time.hour, time.minute);
      if (pickup) {
        _pickup = value;
      } else {
        _returnAt = value;
      }
    });
  }

  Future<void> _pickBirth() async {
    final minAge = _settings.minDriverAge ?? 18;
    final last = DateTime.now().subtract(Duration(days: 365 * minAge));
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1950),
      lastDate: last,
      initialDate: _birthDate ?? DateTime(last.year - 5, 1, 1),
    );
    if (date == null || !mounted) return;
    setState(() => _birthDate = date);
  }

  Future<void> _pickLicense() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      initialDate: _licenseIssued ?? DateTime(DateTime.now().year - 3, 1, 1),
    );
    if (date == null || !mounted) return;
    setState(() => _licenseIssued = date);
  }

  void _setPickupMode(VehicleDeliveryMode mode) {
    setState(() {
      _pickupMode = mode;
      _stepError = null;
      if (mode == VehicleDeliveryMode.galleryPickup) {
        _quote = {'ok': true, 'fee': 0, 'km': 0, 'label': 'gallery_pickup'};
      } else {
        _quote = null;
        _discardStalePin();
      }
    });
    _ensureDeliveryLocation();
  }

  void _setPin(LatLng point, {bool fromMap = false}) {
    setState(() {
      _pin = point;
      _pinFromMap = fromMap;
      _pinBoundAddress = _deliveryAddressKey;
      _stepError = null;
    });
    _refreshQuote();
    if (fromMap) _fillAddressFromPin(point);
  }

  void _applySavedAddress() {
    if (!mounted) return;
    final app = context.read<AppState>();
    final addresses = app.deliveryAddresses;
    if (addresses.isEmpty) return;
    Map<String, String> chosen = addresses.first;
    final current = app.currentDeliveryAddress;
    if (current != null && current.trim().isNotEmpty) {
      for (final row in addresses) {
        if (row['detail'] == current) {
          chosen = row;
          break;
        }
      }
    }
    final resolved = VehicleResolvedDelivery.fromSaved(chosen);
    if (resolved == null) return;
    if (_city.text.trim().isEmpty && resolved.city != null) {
      _city.text = resolved.city!;
    }
    if (_district.text.trim().isEmpty && resolved.district != null) {
      _district.text = resolved.district!;
    }
    if (_neighborhood.text.trim().isEmpty && resolved.neighborhood != null) {
      _neighborhood.text = resolved.neighborhood!;
    }
    if (_street.text.trim().isEmpty && resolved.street != null) {
      _street.text = resolved.street!;
    }
    if (_pin == null && resolved.point != null) {
      final visibleCity = _city.text.trim().toLowerCase();
      final savedCity = (resolved.city ?? '').trim().toLowerCase();
      final cityEmpty = visibleCity.isEmpty;
      final cityMatches = savedCity.isNotEmpty &&
          visibleCity.isNotEmpty &&
          (visibleCity.contains(savedCity) || savedCity.contains(visibleCity));
      if (cityEmpty || cityMatches) {
        _pin = resolved.point;
        _pinFromMap = false;
        _pinBoundAddress = _deliveryAddressKey;
      }
    }
  }

  void _applyAddressText(String raw) {
    final parts = raw
        .split(RegExp(r'\s*[/,]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (_city.text.trim().isEmpty && parts.length >= 3) {
      _city.text = parts[0];
      _district.text = parts[1];
      _neighborhood.text = parts[2];
      if (parts.length > 3) {
        _street.text = parts.sublist(3).join(', ');
      }
      return;
    }
    if (_street.text.trim().isEmpty) _street.text = raw;
  }

  Future<void> _fillAddressFromPin(LatLng point) async {
    final resolved = await VehicleDeliveryGeocode.reverse(point);
    if (!mounted || resolved == null) return;
    if (_city.text.trim().isEmpty && resolved.city != null) {
      _city.text = resolved.city!;
    }
    if (_district.text.trim().isEmpty && resolved.district != null) {
      _district.text = resolved.district!;
    }
    if (_neighborhood.text.trim().isEmpty && resolved.neighborhood != null) {
      _neighborhood.text = resolved.neighborhood!;
    }
    if (_street.text.trim().isEmpty && resolved.street != null) {
      _street.text = resolved.street!;
    }
    if (mounted) setState(() {});
  }

  Future<void> _ensureDeliveryLocation({bool geocode = true}) async {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) {
      await _refreshQuote();
      return;
    }
    _discardStalePin();
    if (_pin == null) {
      _applySavedAddress();
      if (_pin != null && mounted) setState(() {});
    }
    if (geocode &&
        !_pinFromMap &&
        (_pin == null || _pinBoundAddress != _deliveryAddressKey)) {
      if (_pin != null) {
        _pin = null;
        _pinBoundAddress = null;
      }
      await _locateFromAddress(silent: true);
    }
    await _refreshQuote();
  }

  Future<bool> _locateFromAddress({bool silent = false}) async {
    final found = await VehicleDeliveryGeocode.lookupParts(
      city: _city.text,
      district: _district.text,
      neighborhood: _neighborhood.text,
      street: _street.text,
    );
    if (!mounted) return false;
    if (found == null) {
      if (!silent) {
        _showStepError(
          'Teslim konumu belirlenemedi. Haritadan konum seçin.',
        );
      }
      return false;
    }
    _setPin(found);
    return true;
  }

  Future<void> _refreshQuote() async {
    if (_pickupMode == VehicleDeliveryMode.galleryPickup) {
      if (!mounted) return;
      setState(() {
        _quote = {'ok': true, 'fee': 0, 'km': 0, 'label': 'gallery_pickup'};
      });
      return;
    }
    if (_pin == null) {
      if (!mounted) return;
      setState(() => _quote = null);
      return;
    }
    try {
      final quote = await VehicleService.instance.reservations.quoteDelivery(
        listingId: widget.listingId,
        mode: _pickupMode,
        lat: _pin!.latitude,
        lng: _pin!.longitude,
        airport: _airport,
      );
      debugPrint(
        'vehicle delivery quote mode=${_pickupMode.wire} '
        'lat=${_pin!.latitude} lng=${_pin!.longitude} '
        'ok=${quote['ok']} error=${quote['error']} km=${quote['km']}',
      );
      if (!mounted) return;
      setState(() => _quote = quote);
    } catch (error, stack) {
      debugPrint('vehicle delivery quote: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _quote = {
          'ok': false,
          'error': 'location_required',
        };
      });
    }
  }

  String? _validateCurrent() {
    if (_step == 0) {
      return VehicleRentalValidation.dates(
        pickupAt: _pickup,
        returnAt: _returnAt,
        settings: _settings,
        busy: _busyWindows,
      );
    }
    if (_step == 1) {
      if (!_receiverSelf &&
          (_receiverName.text.trim().isEmpty || _receiverPhone.text.trim().length < 10)) {
        return 'Teslim alacak kişinin adını ve telefonunu girin.';
      }
      return VehicleRentalValidation.pickup(
        mode: _pickupMode,
        address: _addressText,
        settings: _settings,
        lat: _customerLat,
        lng: _customerLng,
        zonesConfigured: _pickupMode == VehicleDeliveryMode.galleryPickup || _roadZones,
        quoteError: _pickupMode == VehicleDeliveryMode.galleryPickup
            ? null
            : (_quote != null && _quote!['ok'] != true)
                ? _quote!['error']?.toString()
                : null,
      );
    }
    if (_step == 2) {
      if (!_consent) return 'Gizlilik ve açık rıza metnini onaylayın.';
      return VehicleRentalValidation.customer(
        firstName: _firstName.text,
        lastName: _lastName.text,
        phone: _phone.text,
        email: _email.text,
        nationalId: _nationalId.text,
        birthDate: _birthDate,
        licenseIssued: _licenseIssued,
        settings: _settings,
      );
    }
    if (_step == 3) return VehicleRentalValidation.documents(_uploaded);
    if (_step == 4) {
      if (_contract == null) {
        return 'Bu mağaza henüz araç kiralama sözleşmesi tanımlamamış.';
      }
      if (!_terms) return 'Araç kiralama sözleşmesini kabul edin.';
    }
    return null;
  }

  Future<void> _continue() async {
    final message = _validateCurrent();
    if (message != null) {
      _showStepError(message);
      return;
    }
    if (!await _ensureLogin()) return;
    setState(() {
      _busy = true;
      _stepError = null;
    });
    try {
      if (_step == 0) {
        await _persistDraft(datesOnly: true);
        setState(() => _step = 1);
      } else if (_step == 1) {
        await _ensureDeliveryLocation();
        if (!mounted) return;
        final blocked = VehicleRentalValidation.pickup(
          mode: _pickupMode,
          address: _addressText,
          settings: _settings,
          lat: _customerLat,
          lng: _customerLng,
          zonesConfigured:
              _pickupMode == VehicleDeliveryMode.galleryPickup || _roadZones,
          quoteError: _pickupMode == VehicleDeliveryMode.galleryPickup
              ? null
              : (_quote != null && _quote!['ok'] != true)
                  ? _quote!['error']?.toString()
                  : null,
        );
        if (blocked != null) {
          _showStepError(blocked);
          return;
        }
        await _persistDraft();
        setState(() => _step = 2);
      } else if (_step == 2) {
        await _persistDraft();
        setState(() => _step = 3);
      } else if (_step == 3) {
        await _persistDraft();
        setState(() => _step = 4);
      } else if (_step == 4) {
        setState(() => _step = 5);
      } else if (_step == 5) {
        await _persistDraft();
        if (_reservationId == null) {
          throw VehicleRepositoryException(
            'Kiralama talebi oluşturulamadı. Lütfen tekrar deneyin.',
            code: 'rental_create_failed',
          );
        }
        final versionId = _contract?.versionId;
        if (versionId == null || versionId.isEmpty) {
          throw VehicleRepositoryException(
            'Araç kiralama sözleşmesi kabul edilmeden talep gönderilemez.',
            code: 'contract_required',
          );
        }
        await StoreContractRepository().acceptForRental(
          reservationId: _reservationId!,
          versionId: versionId,
        );
        final submitted = await VehicleService.instance.reservations.submitForReview(
          _reservationId!,
        );
        _submitStatus = submitted['status']?.toString();
        _rentalCode = submitted['rental_code']?.toString();
        setState(() => _step = 6);
      }
    } catch (error, stack) {
      debugPrint('vehicle rental continue code=${_errorCode(error)}\n$stack');
      if (mounted) {
        _showStepError(
          VehicleRentalValidation.friendlyError(
            error,
            code: _errorCode(error),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _load() async {
    try {
      final listing = await VehicleService.instance.listings.getById(
        widget.listingId,
      );
      final busy = listing == null
          ? const <VehicleBusyInterval>[]
          : await VehicleService.instance.reservations.busyWindows(listing.id);
      if (!mounted) return;
      final minDays = listing?.rental?.minDays ?? 1;
      var pickup = VehicleRentalPricing.defaultPickup();
      var ret = VehicleRentalPricing.defaultReturn(pickup, minDays);
      _prefillProfile();
      try {
        final draft = await VehicleService.instance.reservations.latestDraft(
          listingId: widget.listingId,
        );
        if (draft != null) {
          pickup = draft.pickupAt.toLocal();
          ret = draft.returnAt.toLocal();
          _reservationId = draft.id;
          _pickupMode = draft.deliveryMode;
          _dropoffMode = draft.dropoffMode ?? VehicleDeliveryMode.galleryPickup;
          if ((draft.deliveryAddress ?? '').isNotEmpty) {
            _applyAddressText(draft.deliveryAddress!);
          }
          _restoreName(draft.customerName);
          if ((draft.customerPhone ?? '').isNotEmpty) {
            _phone.text = draft.customerPhone!;
          }
          if ((draft.customerEmail ?? '').isNotEmpty) {
            _email.text = draft.customerEmail!;
          }
          if ((draft.customerNationalId ?? '').isNotEmpty) {
            _nationalId.text = draft.customerNationalId!;
          }
          if (draft.deliveryMode != VehicleDeliveryMode.galleryPickup &&
              draft.deliveryLat != null &&
              draft.deliveryLng != null) {
            final restored = LatLng(draft.deliveryLat!, draft.deliveryLng!);
            final gallery = listing?.gallery;
            final nearGallery = gallery?.lat != null &&
                gallery?.lng != null &&
                VehicleDeliveryFeeCalculator.haversineKm(
                      fromLat: restored.latitude,
                      fromLng: restored.longitude,
                      toLat: gallery!.lat!,
                      toLng: gallery.lng!,
                    ) <=
                    0.2;
            if (!nearGallery) {
              _pin = restored;
              _pinFromMap = false;
              _pinBoundAddress = _deliveryAddressKey;
            }
          }
        }
      } catch (error, stack) {
        debugPrint('vehicle rental draft restore: $error\n$stack');
      }
      List<VehicleDeliveryZoneQuote> zones = const [];
      if (listing != null) {
        try {
          zones = await VehicleService.instance.reservations.listDeliveryZones(
            listing.sellerId,
          );
        } catch (error, stack) {
          debugPrint('vehicle rental zones: $error\n$stack');
        }
      }
      if (!mounted) return;
      var mode = _pickupMode;
      final hasRoad = zones.any((z) => !z.isAirport);
      if (mode == VehicleDeliveryMode.homeDelivery &&
          !(listing?.rental?.homeDelivery == true && hasRoad)) {
        mode = VehicleDeliveryMode.galleryPickup;
      }
      if (mode == VehicleDeliveryMode.mapPoint &&
          !(listing?.rental?.mapPointDelivery == true && hasRoad)) {
        mode = VehicleDeliveryMode.galleryPickup;
      }
      setState(() {
        _listing = listing;
        _busyWindows = busy;
        _zones = zones;
        _pickup = pickup;
        _returnAt = ret;
        _pickupMode = mode;
        _month = DateTime(pickup.year, pickup.month);
        _loading = false;
        if (listing == null) _error = 'İlan bulunamadı';
      });
      await _loadContract(listing?.sellerId);
      await _refreshQuote();
    } catch (error, stack) {
      debugPrint('vehicle rental load: $error\n$stack');
      if (!mounted) return;
      setState(() {
        _error = VehicleRentalValidation.friendlyError(error);
        _loading = false;
      });
    }
  }

  void _prefillProfile() {
    final user = context.read<AppState>().currentUser;
    if (user == null) return;
    _restoreName(user['name']?.toString());
    final phone = user['phone']?.toString() ?? '';
    if (phone.isNotEmpty) _phone.text = phone;
    final email = user['email']?.toString() ?? '';
    if (email.isNotEmpty) _email.text = email;
    final birth = DateTime.tryParse(user['birth_date']?.toString() ?? '');
    if (birth != null) _birthDate = birth;
    if (_street.text.isEmpty) {
      final address = user['address']?.toString() ?? '';
      if (address.isNotEmpty) _applyAddressText(address);
    }
    _applySavedAddress();
  }

  void _restoreName(String? raw) {
    final parts = (raw ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return;
    _firstName.text = parts.first;
    if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
  }

  Future<bool> _ensureLogin() async {
    if (context.read<AppState>().isLoggedIn) return true;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
    if (!mounted) return false;
    if (context.read<AppState>().isLoggedIn) {
      _prefillProfile();
      return true;
    }
    return false;
  }

  Future<void> _persistDraft({bool datesOnly = false}) async {
    final incomplete = datesOnly ||
        (_pickupMode != VehicleDeliveryMode.galleryPickup && _pin == null);
    final mode =
        incomplete ? VehicleDeliveryMode.galleryPickup : _pickupMode;
    final address = incomplete || _addressText.trim().isEmpty
        ? (incomplete ? null : _addressText)
        : _addressText;
    final lat = mode == VehicleDeliveryMode.galleryPickup ? null : _pin?.latitude;
    final lng = mode == VehicleDeliveryMode.galleryPickup ? null : _pin?.longitude;
    if (_reservationId == null) {
      final created = await VehicleService.instance.reservations.createReservation(
        listingId: widget.listingId,
        pickupAt: _pickup,
        returnAt: _returnAt,
        mode: mode,
        address: address,
        lat: lat,
        lng: lng,
        airport: _airport,
        dropoffMode: _dropoffMode,
        dropoffAddress:
            _dropoffMode == VehicleDeliveryMode.galleryPickup ? null : address,
        customerName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        customerPhone: _phone.text.trim(),
        customerBirthDate: _birthDate,
        customerEmail: _email.text.trim(),
        customerNote: _customerNote,
        customerNationalId: TurkishNationalId.digitsOf(_nationalId.text),
      );
      _reservationId = created['reservation_id']?.toString();
    } else {
      await VehicleService.instance.reservations.updateDraft(
        reservationId: _reservationId!,
        pickupAt: _pickup,
        returnAt: _returnAt,
        mode: mode,
        address: address,
        lat: lat,
        lng: lng,
        airport: _airport,
        dropoffMode: _dropoffMode,
        dropoffAddress:
            _dropoffMode == VehicleDeliveryMode.galleryPickup ? null : address,
        customerName: '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim(),
        customerPhone: _phone.text.trim(),
        customerBirthDate: _birthDate,
        customerEmail: _email.text.trim(),
        customerNote: _customerNote,
        customerNationalId: TurkishNationalId.digitsOf(_nationalId.text),
      );
    }
    final listingId = _listing?.id;
    if (listingId != null) {
      final busy = await VehicleService.instance.reservations.busyWindows(
        listingId,
      );
      if (mounted) setState(() => _busyWindows = busy);
    }
  }

  Future<void> _uploadDoc(VehicleDocumentType type) async {
    if (!await _ensureLogin()) return;
    try {
      if (_reservationId == null) await _persistDraft();
      if (!mounted) return;
      final uid = context.read<AppState>().currentUser?['uid']?.toString();
      if (uid == null || _reservationId == null) return;
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (file == null) return;
      var name = file.name;
      if (!name.contains('.')) name = '$name.jpg';
      final picked = Uint8List.fromList(await file.readAsBytes());
      if (!mounted) return;
      final draft = await showVehicleDocumentPreview(
        context: context,
        type: type,
        bytes: picked,
        fileName: name,
      );
      if (draft == null || !mounted) return;
      await _commitDoc(type, uid, draft);
    } catch (error, stack) {
      debugPrint('vehicle kyc pick code=${_errorCode(error)}\n$stack');
      if (!mounted) return;
      setState(() {
        _docBusy = null;
        _uploadFailed = type;
        _stepError = VehicleRentalValidation.friendlyError(
          error,
          code: 'document_upload_failed',
        );
      });
    }
  }

  Future<void> _commitDoc(
    VehicleDocumentType type,
    String uid,
    VehicleDocumentDraft draft,
  ) async {
    setState(() {
      _docBusy = type;
      _uploadFailed = null;
      _previews[type] = draft.bytes;
    });
    try {
      await VehicleService.instance.reservations.deleteKyc(
        reservationId: _reservationId!,
        type: type,
      );
      await VehicleService.instance.reservations.uploadKycBytes(
        reservationId: _reservationId!,
        customerId: uid,
        type: type,
        bytes: draft.bytes,
        fileName: draft.fileName,
      );
      if (!mounted) return;
      setState(() {
        _uploaded.add(type);
        _docBusy = null;
        _stepError = null;
      });
    } catch (error, stack) {
      debugPrint('vehicle kyc upload code=${_errorCode(error)}\n$stack');
      if (!mounted) return;
      setState(() {
        _docBusy = null;
        _uploadFailed = type;
        _stepError = VehicleRentalValidation.friendlyError(
          error,
          code: 'document_upload_failed',
        );
      });
    }
  }

  Future<void> _retryDoc(VehicleDocumentType type) async {
    final preview = _previews[type];
    final uid = context.read<AppState>().currentUser?['uid']?.toString();
    if (preview == null || uid == null || _reservationId == null) {
      await _uploadDoc(type);
      return;
    }
    await _commitDoc(
      type,
      uid,
      VehicleDocumentDraft(bytes: preview, fileName: '${type.wire}.jpg'),
    );
  }

  Future<void> _viewDoc(VehicleDocumentType type) async {
    final preview = _previews[type];
    if (preview == null || !mounted) return;
    await showVehicleDocumentPreview(
      context: context,
      type: type,
      bytes: preview,
      fileName: '${type.wire}.jpg',
    );
  }

  Future<void> _loadContract(String? sellerId) async {
    if (sellerId == null || sellerId.isEmpty) {
      setState(() => _contractLoaded = true);
      return;
    }
    try {
      final contract = await StoreContractRepository().active(
        sellerId: sellerId,
        type: StoreContractTypes.vehicleRental,
      );
      if (!mounted) return;
      setState(() {
        _contract = contract;
        _contractLoaded = true;
      });
    } catch (error, stack) {
      debugPrint('vehicle rental contract load\n$stack');
      if (!mounted) return;
      setState(() => _contractLoaded = true);
    }
  }

  Future<void> _viewContract() async {
    final contract = _contract;
    if (contract == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contract.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('Sürüm ${contract.version}'),
                const SizedBox(height: 12),
                Expanded(
                  child: contract.isText
                      ? SingleChildScrollView(
                          child: SelectableText(contract.bodyText ?? ''),
                        )
                      : Center(
                          child: FilledButton(
                            onPressed: () async {
                              final url = await StoreContractRepository()
                                  .signedPdfUrl(contract);
                              if (url == null) return;
                              await launchUrl(Uri.parse(url));
                            },
                            child: const Text('PDF görüntüle'),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _maskEmail(String raw) {
    final value = raw.trim();
    final at = value.indexOf('@');
    if (at <= 0) return value;
    final name = value.substring(0, at);
    final domain = value.substring(at);
    final keep = name.length >= 2 ? name.substring(0, 2) : name;
    return '$keep***$domain';
  }

  String? _errorCode(Object error) {
    if (error is VehicleRepositoryException) return error.code;
    final raw = '$error';
    if (raw.contains('gen_random_bytes') || raw.contains('42883')) {
      return 'database_function_missing';
    }
    if (raw.contains('SocketException')) return 'network_failed';
    return null;
  }

  Future<void> _deleteDoc(VehicleDocumentType type) async {
    if (_reservationId == null) return;
    try {
      await VehicleService.instance.reservations.deleteKyc(
        reservationId: _reservationId!,
        type: type,
      );
      if (!mounted) return;
      setState(() {
        _uploaded.remove(type);
        _previews.remove(type);
        _uploadFailed = _uploadFailed == type ? null : _uploadFailed;
      });
    } catch (error, stack) {
      debugPrint('vehicle kyc delete: $error\n$stack');
      if (!mounted) return;
      setState(() => _stepError = 'Belge silinemedi');
    }
  }
}
