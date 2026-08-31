part of 'seller_cargo_dialog.dart';

mixin _CargoDialogForm on _CargoDialogStateBase, _CargoDialogGeo, _CargoDialogAddresses, _CargoDialogMap {
  Widget selectorButton({
    required String label,
    required String value,
    required IconData icon,
    required bool isOpen,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOpen
                ? AppColors.primary
                : Colors.grey.shade400,
            width: isOpen ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isOpen
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget inlineOptions({
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 190),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          final item = options[index];
          return InkWell(
            onTap: () => onSelected(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Text(
                item,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildCargoDialog() {
    return AlertDialog(
      title: const Text('Kargo Cik Alani'),
      content: SizedBox(
        width: 680,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dis kaynakli siparisi IHIZ sistemine ekleyin. Kayit, kuryelerin gorev havuzuna "hazir" olarak duser.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFD6E2FF),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: Color(0xFF1D4ED8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.config.walletReady()
                              ? 'Kullanilabilir bakiye: ${widget.config.currencyFormat(widget.config.walletAvailable())}'
                              : (widget.config.walletError() ??
                                    'Cuzdan bilgisi alinamadi'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final toppedUp =
                                    await widget.config.showWalletTopup();
                                if (toppedUp &&
                                    mounted &&
                                    mounted) {
                                  setState(() {});
                                }
                              },
                        child: const Text('Bakiye Yukle'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 328,
                      child: TextFormField(
                        controller: customerNameController,
                        decoration: inputDecoration(
                          'Musteri Ad Soyad',
                        ),
                        validator: (value) =>
                            (value ?? '').trim().isEmpty
                            ? 'Zorunlu alan'
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 328,
                      child: TextFormField(
                        controller: customerPhoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: inputDecoration('Telefon'),
                        validator: (value) {
                          final phone = (value ?? '').trim();
                          if (phone.isEmpty) return 'Zorunlu alan';
                          if (phone.length < 10) {
                            return 'En az 10 hane girin';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: selectorButton(
                        label: 'İl',
                        value: selectedProvince,
                        icon: Icons.location_city,
                        isOpen: showProvinceOptions,
                        onTap: () {
                          setState(() {
                            showProvinceOptions =
                                !showProvinceOptions;
                            showDistrictOptions = false;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: selectorButton(
                        label: 'İlçe',
                        value: selectedDistrict,
                        icon: Icons.map_outlined,
                        isOpen: showDistrictOptions,
                        onTap: () {
                          setState(() {
                            showDistrictOptions =
                                !showDistrictOptions;
                            showProvinceOptions = false;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (showProvinceOptions)
                  inlineOptions(
                    options: SellerCargoGeoData.provinces,
                    onSelected: (province) {
                      final districts =
                          SellerCargoGeoData.districtsFor(province);
                      setState(() {
                        selectedProvince = province;
                        if (!districts.contains(selectedDistrict)) {
                          selectedDistrict = districts.isNotEmpty
                              ? districts.first
                              : 'Merkez';
                        }
                        showProvinceOptions = false;
                      });
                      unawaited(
                        focusMapToSelectedRegion(
                          clearPickedPoint: true,
                        ),
                      );
                    },
                  ),
                if (showDistrictOptions)
                  inlineOptions(
                    options: effectiveDistrictOptions(),
                    onSelected: (district) {
                      setState(() {
                        selectedDistrict = district;
                        showDistrictOptions = false;
                      });
                      unawaited(
                        focusMapToSelectedRegion(
                          clearPickedPoint: true,
                        ),
                      );
                    },
                  ),
                if (isDetectingLocationRegion) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Konumunuza göre il/ilçe algılanıyor...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B6B86),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: buildingController,
                  decoration: inputDecoration(
                    'Bina, Site, Referans (Opsiyonel)',
                  ),
                  onChanged: (_) => scheduleLookup(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: inputDecoration(
                    'Açık Adres (Mahalle, Sokak, Kapı No)',
                  ),
                  onChanged: (_) => scheduleLookup(),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Zorunlu alan'
                      : null,
                ),
                if (isSearchingAddress) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
                if (addressSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 190),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: addressSuggestions.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = addressSuggestions[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            suggestion.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          onTap: () =>
                              unawaited(applySuggestion(suggestion)),
                        );
                      },
                    ),
                  ),
                ],
                cargoMapPreview(),
                SellerCargoProductLinesSection(
                  lines: cargoLines,
                  currencyFormat: widget.config.currencyFormat,
                  onAdd: () => unawaited(addCargoProduct()),
                  onQuantityChanged: (productId, quantity) {
                    setState(() {
                      cargoLines = updateSellerCargoLineQuantity(
                        cargoLines,
                        productId,
                        quantity,
                      );
                    });
                  },
                  onRemove: (productId) {
                    setState(() {
                      cargoLines = cargoLines
                          .where(
                            (line) => line.productId != productId,
                          )
                          .toList(growable: false);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: inputDecoration('Siparis Notu'),
                ),
                const SizedBox(height: 16),
                if (savedAddressesError != null) ...[
                  Text(
                    savedAddressesError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB42318),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SellerCargoSavedAddressesSection(
                  addresses: savedAddresses,
                  selectedId: selectedSavedAddressId,
                  isLoading: isLoadingSavedAddresses,
                  onSelected: applySavedAddress,
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: Listenable.merge([
                    customerNameController,
                    customerPhoneController,
                    addressController,
                    buildingController,
                  ]),
                  builder: (context, _) {
                    final addressParts = <String>[
                      addressController.text.trim(),
                      if (buildingController.text.trim().isNotEmpty)
                        buildingController.text.trim(),
                      selectedDistrict,
                      selectedProvince,
                    ].where((part) => part.trim().isNotEmpty);
                    return SellerCargoOrderSummary(
                      customerName:
                          customerNameController.text.trim(),
                      customerPhone:
                          customerPhoneController.text.trim(),
                      addressText: addressParts.join(', '),
                      lines: cargoLines,
                      shippingAmount: 0,
                      currencyFormat: widget.config.currencyFormat,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting || isSavingAddress
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
        OutlinedButton.icon(
          onPressed: isSubmitting || isSavingAddress
              ? null
              : () => unawaited(saveAddress()),
          icon: isSavingAddress
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bookmark_add_outlined, size: 18),
          label: Text(
            isSavingAddress ? 'Kaydediliyor...' : 'Adresi Kaydet',
          ),
        ),
        FilledButton.icon(
          onPressed: isSubmitting || isSavingAddress
              ? null
              : submit,
          icon: isSubmitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                )
              : const Icon(Icons.add_rounded),
          label: Text(
            isSubmitting ? 'Olusturuluyor...' : 'Siparişi Çık',
          ),
        ),
      ],
    );
  }
}
