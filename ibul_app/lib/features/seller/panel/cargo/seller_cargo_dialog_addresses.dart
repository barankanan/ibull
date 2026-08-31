part of 'seller_cargo_dialog.dart';

mixin _CargoDialogAddresses on _CargoDialogStateBase, _CargoDialogGeo {
  Future<void> loadSavedAddresses({String? selectId}) async {
    if (!isLoadingSavedAddresses) {
      setState(() {
        isLoadingSavedAddresses = true;
        savedAddressesError = null;
      });
    }
    try {
      final loaded = await SellerSavedAddressService.instance
          .listForCurrentSeller();
      if (!mounted) return;
      setState(() {
        savedAddresses = loaded;
        selectedSavedAddressId =
            selectId ?? selectedSavedAddressId;
        isLoadingSavedAddresses = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        savedAddresses = <SellerSavedAddress>[];
        isLoadingSavedAddresses = false;
        savedAddressesError = e.toString().replaceFirst(
          'Exception: ',
          '',
        );
      });
    }
  }

  void applySavedAddress(SellerSavedAddress address) {
    customerNameController.text = address.customerName;
    customerPhoneController.text = address.customerPhone;
    buildingController.text = address.building;
    addressController.text = address.address;
    setState(() {
      selectedSavedAddressId = address.id;
      final matchedProvince = SellerCargoGeocode.matchProvinceOption(
        address.city,
      );
      selectedProvince = matchedProvince ?? address.city;
      final matchedDistrict = SellerCargoGeocode.matchDistrictOption(
        address.district,
        selectedProvince,
      );
      selectedDistrict = matchedDistrict ?? address.district;
      selectedLat = address.latitude;
      selectedLng = address.longitude;
      isAddressVerified = address.hasCoordinates;
      verifiedAddressText = address.hasCoordinates
          ? [
              if (address.building.isNotEmpty) address.building,
              address.address,
            ].join(', ')
          : null;
      addressSuggestions = <SellerCargoGeocodeSuggestion>[];
      showProvinceOptions = false;
      showDistrictOptions = false;
    });
    if (address.hasCoordinates) {
      setPreviewCenter(
        LatLng(address.latitude!, address.longitude!),
        zoom: 15.2,
        updateState: false,
      );
    } else {
      unawaited(
        focusMapToSelectedRegion(clearPickedPoint: false),
      );
    }
  }

  Future<void> saveAddress() async {
    final sellerId = widget.config.sellerId;
    if (sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satıcı oturumu doğrulanamadı.'),
        ),
      );
      return;
    }
    final normalizedPhone = customerPhoneController.text
        .replaceAll(RegExp(r'[^0-9]'), '')
        .trim();
    if (customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Müşteri adı zorunludur.')),
      );
      return;
    }
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
    if (addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açık adres zorunludur.')),
      );
      return;
    }

    setState(() {
      isSavingAddress = true;
    });
    try {
      final saved = await SellerSavedAddressService.instance
          .saveForCurrentSeller(
            customerName: customerNameController.text.trim(),
            customerPhone: normalizedPhone,
            city: selectedProvince,
            district: selectedDistrict,
            building: buildingController.text.trim(),
            address: addressController.text.trim(),
            latitude: selectedLat,
            longitude: selectedLng,
          );
      if (!mounted) return;
      await loadSavedAddresses(selectId: saved.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adres kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSavingAddress = false;
        });
      }
    }
  }

  Future<void> addCargoProduct() async {
    var catalog = List<SellerProduct>.from(widget.config.products());
    if (catalog.isEmpty) {
      try {
        catalog = await widget.config.loadProducts();
      } on Object catch (error, stackTrace) {
        RuntimeDiagnosticLogger.logFailure(
          'seller_cargo',
          error,
          stackTrace,
          context: 'load_products',
        );
        catalog = const <SellerProduct>[];
      }
    }
    if (!mounted) return;
    final picked = await showSellerCargoProductPicker(
      context: context,
      products: catalog,
    );
    if (picked == null || !mounted) return;
    setState(() {
      cargoLines = addOrIncrementSellerCargoLine(
        cargoLines,
        picked,
      );
    });
  }
}
