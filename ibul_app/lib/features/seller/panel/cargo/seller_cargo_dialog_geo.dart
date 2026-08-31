part of 'seller_cargo_dialog.dart';

mixin _CargoDialogGeo on _CargoDialogStateBase {
  InputDecoration inputDecoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
    );
  }

  void setPreviewCenter(
    LatLng center, {
    double zoom = 12,
    bool updateState = true,
  }) {
    if (updateState) {
      setState(() {
        previewCenter = center;
      });
    } else {
      previewCenter = center;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        previewMapController.move(center, zoom);
      } on Object catch (error, stackTrace) {
        RuntimeDiagnosticLogger.logFailure(
          'seller_cargo',
          error,
          stackTrace,
          context: 'map_move',
        );
      }
    });
  }

  List<String> effectiveDistrictOptions() {
    final options = SellerCargoGeoData.districtsFor(
      selectedProvince,
    );
    if (selectedDistrict.trim().isNotEmpty &&
        !options.contains(selectedDistrict)) {
      return <String>[selectedDistrict, ...options];
    }
    return options;
  }

  Future<void> focusMapToSelectedRegion({
    bool clearPickedPoint = false,
  }) async {
    if (clearPickedPoint) {
      setState(() {
        selectedLat = null;
        selectedLng = null;
        isAddressVerified = false;
      });
    }
    final fallback =
        SellerCargoGeoData.centers[selectedProvince] ??
        const LatLng(39.0, 35.0);
    setState(() {
      isResolvingRegionCenter = true;
    });
    setPreviewCenter(fallback, zoom: 10.8, updateState: true);

    try {
      final query = <String>[
        selectedDistrict.trim(),
        selectedProvince.trim(),
        'Türkiye',
      ].where((e) => e.isNotEmpty).join(', ');
      final batch = await SellerCargoGeocode.fetchAddressSuggestions(query);
      if (batch.isNotEmpty) {
        final center = LatLng(batch.first.lat, batch.first.lng);
        setPreviewCenter(center, zoom: 12.8, updateState: true);
      }
    } on Object catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'seller_cargo',
        error,
        stackTrace,
        context: 'geocode',
      );
    } finally {
      if (mounted) {
        setState(() {
          isResolvingRegionCenter = false;
        });
      }
    }
  }

  Future<void> lookupAddressSuggestions() async {
    final detail = addressController.text.trim();
    if (detail.length < 4) {
      setState(() {
        isSearchingAddress = false;
        addressSuggestions = <SellerCargoGeocodeSuggestion>[];
      });
      return;
    }
    final normalizedDetail = SellerCargoGeocodeQueries.normalizeAddressQueryText(
      detail,
    );
    final streetToken = SellerCargoGeocodeQueries.extractStreetToken(normalizedDetail);
    final streetQueries = SellerCargoGeocodeQueries.buildStreetFocusedQueries(
      normalizedDetail: normalizedDetail,
      building: buildingController.text.trim(),
      selectedDistrict: selectedDistrict,
      selectedProvince: selectedProvince,
    );
    final genericQueries = SellerCargoGeocodeQueries.buildAddressQueries(
      detail: detail,
      building: buildingController.text.trim(),
      selectedDistrict: selectedDistrict,
      selectedProvince: selectedProvince,
    );
    final queries = <String>{
      ...streetQueries,
      ...genericQueries,
    }.toList(growable: false);
    if (queries.isEmpty) return;

    final requestId = ++addressLookupRequestId;
    setState(() {
      isSearchingAddress = true;
    });
    try {
      final collected = <SellerCargoGeocodeSuggestion>[];
      final maxRequests = streetToken == null ? 4 : 6;
      final effectiveQueries = queries.take(maxRequests);
      for (final query in effectiveQueries) {
        final batch = await SellerCargoGeocode.fetchAddressSuggestions(query);
        if (!mounted ||
            requestId != addressLookupRequestId) {
          return;
        }
        if (batch.isNotEmpty) {
          collected.addAll(batch);
        }
        if (collected.length >= 24) break;
        if (streetToken != null) {
          final hasStrongStreet = collected.any(
            (s) =>
                SellerCargoGeocode.scoreSuggestion(
                  s,
                  detail: detail,
                  selectedProvince: selectedProvince,
                  selectedDistrict: selectedDistrict,
                ) >=
                70,
          );
          if (hasStrongStreet && collected.length >= 8) {
            break;
          }
        }
      }

      final deduped = <String, SellerCargoGeocodeSuggestion>{};
      for (final suggestion in collected) {
        final key =
            '${suggestion.lat.toStringAsFixed(6)}_${suggestion.lng.toStringAsFixed(6)}_${suggestion.label.toLowerCase()}';
        deduped.putIfAbsent(key, () => suggestion);
      }

      final sorted = deduped.values.toList(growable: false)
        ..sort(
          (a, b) =>
              SellerCargoGeocode.scoreSuggestion(
                b,
                detail: detail,
                selectedProvince: selectedProvince,
                selectedDistrict: selectedDistrict,
              ).compareTo(
                SellerCargoGeocode.scoreSuggestion(
                  a,
                  detail: detail,
                  selectedProvince: selectedProvince,
                  selectedDistrict: selectedDistrict,
                ),
              ),
        );

      setState(() {
        isSearchingAddress = false;
        addressSuggestions = sorted.take(8).toList(growable: false);
      });
    } on Object catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'seller_cargo',
        error,
        stackTrace,
        context: 'address_lookup',
      );
      if (!mounted ||
          requestId != addressLookupRequestId) {
        return;
      }
      setState(() {
        isSearchingAddress = false;
        addressSuggestions = <SellerCargoGeocodeSuggestion>[];
      });
    }
  }

  void scheduleLookup() {
    if (isAddressVerified) {
      setState(() {
        isAddressVerified = false;
      });
    }
    addressLookupDebounce?.cancel();
    addressLookupDebounce = Timer(
      const Duration(milliseconds: 500),
      lookupAddressSuggestions,
    );
  }

  Future<void> applySuggestion(
    SellerCargoGeocodeSuggestion suggestion,
  ) async {
    setState(() {
      selectedLat = suggestion.lat;
      selectedLng = suggestion.lng;
      isAddressVerified = true;
      verifiedAddressText = suggestion.label;
      final matchedProvince = SellerCargoGeocode.matchProvinceOption(
        suggestion.province,
      );
      if (matchedProvince != null) {
        selectedProvince = matchedProvince;
      }
      final matchedDistrict = SellerCargoGeocode.matchDistrictOption(
        suggestion.district,
        selectedProvince,
      );
      if (matchedDistrict != null) {
        selectedDistrict = matchedDistrict;
      } else if (suggestion.district.trim().isNotEmpty) {
        selectedDistrict = suggestion.district.trim();
      }
      addressSuggestions = <SellerCargoGeocodeSuggestion>[];
      showProvinceOptions = false;
      showDistrictOptions = false;
    });
    setPreviewCenter(
      LatLng(suggestion.lat, suggestion.lng),
      zoom: 15.2,
      updateState: false,
    );
  }

  Future<void> reverseGeocodeFromPoint({
    required double lat,
    required double lng,
    bool fillAddressIfEmpty = false,
  }) async {
    try {
      final resolved = await SellerCargoGeocode.reverseGeocode(
        lat: lat,
        lng: lng,
      );
      if (!mounted || resolved == null) return;
      setState(() {
        final matchedProvince = SellerCargoGeocode.matchProvinceOption(
          resolved.province,
        );
        if (matchedProvince != null) {
          selectedProvince = matchedProvince;
        }
        final matchedDistrict = SellerCargoGeocode.matchDistrictOption(
          resolved.district,
          selectedProvince,
        );
        if (matchedDistrict != null) {
          selectedDistrict = matchedDistrict;
        } else if (resolved.district.trim().isNotEmpty) {
          selectedDistrict = resolved.district.trim();
        }
        verifiedAddressText = resolved.label;
        isAddressVerified = true;
      });
      if (fillAddressIfEmpty &&
          addressController.text.trim().isEmpty) {
        addressController.text = resolved.label;
      }
    } on Object catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'seller_cargo',
        error,
        stackTrace,
        context: 'reverse_geocode',
      );
    }
  }

  Future<void> prefillRegionFromCurrentLocation() async {
    setState(() {
      isDetectingLocationRegion = true;
    });
    try {
      final resolved = await SellerCargoGeocode.resolveCurrentLocation();
      if (!mounted || resolved == null) return;
      setPreviewCenter(
        LatLng(resolved.lat, resolved.lng),
        zoom: 12.4,
        updateState: true,
      );
      setState(() {
        final matchedProvince = SellerCargoGeocode.matchProvinceOption(
          resolved.province,
        );
        if (matchedProvince != null) {
          selectedProvince = matchedProvince;
        }
        final matchedDistrict = SellerCargoGeocode.matchDistrictOption(
          resolved.district,
          selectedProvince,
        );
        if (matchedDistrict != null) {
          selectedDistrict = matchedDistrict;
        } else {
          final districts = SellerCargoGeoData.districtsFor(
            selectedProvince,
          );
          if (!districts.contains(selectedDistrict)) {
            selectedDistrict = districts.isNotEmpty
                ? districts.first
                : 'Merkez';
          }
        }
      });
    } on Object catch (error, stackTrace) {
      RuntimeDiagnosticLogger.logFailure(
        'seller_cargo',
        error,
        stackTrace,
        context: 'geocode',
      );
    } finally {
      if (mounted) {
        setState(() {
          isDetectingLocationRegion = false;
        });
      }
    }
  }

  Future<void> openMapPicker() async {
    final initialLat = selectedLat ?? previewCenter.latitude;
    final initialLng = selectedLng ?? previewCenter.longitude;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StoreLocationChangeDialog(
        initialLat: initialLat,
        initialLng: initialLng,
      ),
    );
    if (picked == null || !mounted) return;
    final lat = (picked['lat'] as num?)?.toDouble();
    final lng = (picked['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    setState(() {
      selectedLat = lat;
      selectedLng = lng;
      isAddressVerified = true;
      addressSuggestions = <SellerCargoGeocodeSuggestion>[];
    });
    setPreviewCenter(
      LatLng(lat, lng),
      zoom: 15.2,
      updateState: false,
    );
    await reverseGeocodeFromPoint(
      lat: lat,
      lng: lng,
      fillAddressIfEmpty: true,
    );
  }
}
