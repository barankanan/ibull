import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants.dart';
import '../../../../core/runtime_diagnostic_logger.dart';
import '../../../../models/seller_product.dart';
import '../../../../models/seller_saved_address.dart';
import '../../../../services/seller_saved_address_service.dart';
import '../widgets/store_location_change_dialog.dart';
import 'seller_cargo_dialog_config.dart';
import 'seller_cargo_geo_data.dart';
import 'seller_cargo_geocode.dart';
import 'seller_cargo_geocode_queries.dart';
import 'seller_cargo_geocode_suggestion.dart';
import 'seller_cargo_order_builder.dart';
import 'seller_cargo_order_line.dart';
import 'seller_cargo_product_picker.dart';
import 'seller_cargo_saved_addresses_section.dart';

part 'seller_cargo_dialog_geo.dart';
part 'seller_cargo_dialog_addresses.dart';
part 'seller_cargo_dialog_map.dart';
part 'seller_cargo_dialog_form.dart';

class SellerExternalCargoDialog extends StatefulWidget {
  const SellerExternalCargoDialog({super.key, required this.config});

  final SellerCargoDialogConfig config;

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required SellerCargoDialogConfig config,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => SellerExternalCargoDialog(config: config),
    );
  }

  @override
  State<SellerExternalCargoDialog> createState() =>
      _SellerExternalCargoDialogState();
}

abstract class _CargoDialogStateBase extends State<SellerExternalCargoDialog> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController customerNameController;
  late final TextEditingController customerPhoneController;
  late final TextEditingController addressController;
  late final TextEditingController buildingController;
  late final TextEditingController noteController;
  late final MapController previewMapController;

  late String selectedProvince;
  late String selectedDistrict;
  bool showProvinceOptions = false;
  bool showDistrictOptions = false;
  double? selectedLat;
  double? selectedLng;
  late LatLng previewCenter;
  bool isAddressVerified = false;
  String? verifiedAddressText;
  bool isSearchingAddress = false;
  bool isResolvingRegionCenter = false;
  bool isDetectingLocationRegion = false;
  bool didRequestLocationRegionPrefill = false;
  Timer? addressLookupDebounce;
  int addressLookupRequestId = 0;
  List<SellerCargoGeocodeSuggestion> addressSuggestions =
      <SellerCargoGeocodeSuggestion>[];
  List<SellerSavedAddress> savedAddresses = <SellerSavedAddress>[];
  String? selectedSavedAddressId;
  bool isLoadingSavedAddresses = true;
  bool isSavingAddress = false;
  bool didRequestSavedAddresses = false;
  String? savedAddressesError;
  List<SellerCargoOrderLine> cargoLines = <SellerCargoOrderLine>[];
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    customerNameController = TextEditingController();
    customerPhoneController = TextEditingController();
    addressController = TextEditingController();
    buildingController = TextEditingController();
    noteController = TextEditingController();
    previewMapController = MapController();

    selectedProvince = widget.config.initialProvince.trim();
    if (!SellerCargoGeoData.provinces.contains(selectedProvince)) {
      selectedProvince = 'İstanbul';
    }
    selectedDistrict = widget.config.initialDistrict.trim().isNotEmpty
        ? widget.config.initialDistrict.trim()
        : SellerCargoGeoData.defaultDistrict(selectedProvince);
    previewCenter =
        SellerCargoGeoData.centers[selectedProvince] ?? const LatLng(39.0, 35.0);
  }

  @override
  void dispose() {
    addressLookupDebounce?.cancel();
    customerNameController.dispose();
    customerPhoneController.dispose();
    addressController.dispose();
    buildingController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final sellerId = widget.config.sellerId;
    if (sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satıcı oturumu doğrulanamadı.'),
        ),
      );
      return;
    }
    if (cargoLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Siparişe en az bir ürün ekleyin.'),
        ),
      );
      return;
    }
    if (widget.config.walletReady() && widget.config.walletAvailable() <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kargo siparisi icin once satıcı cüzdanina bakiye yukleyin.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
    });
    try {
      final normalizedPhone = customerPhoneController.text
          .replaceAll(RegExp(r'[^0-9]'), '')
          .trim();
      if (normalizedPhone.length < 10 ||
          normalizedPhone.length > 11) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Telefon numarası 10 veya 11 haneli olmalıdır.',
            ),
          ),
        );
        return;
      }
      if (selectedProvince.trim().isEmpty ||
          selectedDistrict.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen il ve ilçe seçin.')),
        );
        return;
      }
      if (selectedLat == null ||
          selectedLng == null ||
          !isAddressVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İHIZ teslimatı için adresi haritada doğrulamanız gerekir.',
            ),
          ),
        );
        return;
      }

      final finalAddress = addressController.text.trim();

      final mergedNoteParts = <String>[
        if (noteController.text.trim().isNotEmpty)
          noteController.text.trim(),
        if (verifiedAddressText != null &&
            verifiedAddressText!.trim().isNotEmpty)
          'Map: ${verifiedAddressText!.trim()}',
      ];

      final createdOrder =
          await widget.config.createOrder(
        sellerId: sellerId,
        customerName: customerNameController.text.trim(),
        customerPhone: normalizedPhone,
        customerAddress: finalAddress,
        building: buildingController.text.trim(),
        city: selectedProvince,
        district: selectedDistrict,
        customerLat: selectedLat,
        customerLng: selectedLng,
        quantity: 1,
        unitPrice: 0,
        productLines: cargoLines
            .map((line) => line.toServiceMap())
            .toList(growable: false),
        note: mergedNoteParts.isEmpty
            ? null
            : mergedNoteParts.join('\n'),
        storeName: widget.config.storeName,
      );
      String? printWarning;
      try {
        final storedItems = (createdOrder['items'] is List)
            ? List<Map<String, dynamic>>.from(
                (createdOrder['items'] as List).map(
                  (row) => Map<String, dynamic>.from(
                    row as Map,
                  ),
                ),
              )
            : const <Map<String, dynamic>>[];
        final printResult = await widget.config.createPrintJobs(
          restaurantId: sellerId,
          orderId: createdOrder['id']?.toString() ?? '',
          orderNumber:
              createdOrder['order_number']?.toString() ?? '',
          orderItems: storedItems,
          productLines: cargoLines
              .map((line) => line.toServiceMap())
              .toList(growable: false),
          storeName: widget.config.storeName,
          createdAt: createdOrder['created_at']?.toString(),
        );
        if (!printResult.ok) {
          printWarning =
              'Sipariş oluşturuldu ancak yazdırma başlatılamadı';
        }
      } on Object catch (printError, stackTrace) {
        RuntimeDiagnosticLogger.logFailure(
          'seller_cargo',
          printError,
          stackTrace,
          context: 'print_jobs',
        );
        printWarning =
            'Sipariş oluşturuldu ancak yazdırma başlatılamadı';
      }
      await widget.config.reloadWallet();
      if (!mounted) return;
      Navigator.of(context).pop(<String, dynamic>{
        'ok': true,
        'order_id': createdOrder['id']?.toString() ?? '',
        'order_number':
            createdOrder['order_number']?.toString() ?? '',
        'print_warning': ?printWarning,
      });
    } on Object catch (e, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'seller_cargo',
        e,
        stackTrace,
        context: 'create_order',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SellerCargoGeocode.mapCreateError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }
}

class _SellerExternalCargoDialogState extends _CargoDialogStateBase
    with _CargoDialogGeo, _CargoDialogAddresses, _CargoDialogMap, _CargoDialogForm {
  @override
  Widget build(BuildContext context) {
    if (!didRequestLocationRegionPrefill) {
      didRequestLocationRegionPrefill = true;
      unawaited(prefillRegionFromCurrentLocation());
    }
    if (!didRequestSavedAddresses) {
      didRequestSavedAddresses = true;
      unawaited(loadSavedAddresses());
    }
    return buildCargoDialog();
  }
}
