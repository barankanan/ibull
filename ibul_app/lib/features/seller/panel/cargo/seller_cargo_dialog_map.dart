part of 'seller_cargo_dialog.dart';

mixin _CargoDialogMap on _CargoDialogStateBase, _CargoDialogGeo {
  Widget cargoMapPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
    const SizedBox(height: 10),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAddressVerified
              ? Colors.green.shade300
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAddressVerified
                    ? Icons.verified
                    : Icons.gps_not_fixed,
                size: 18,
                color: isAddressVerified
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isAddressVerified
                      ? 'Adres haritada doğrulandı'
                      : 'Adresi haritada doğrulayın',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isAddressVerified
                        ? Colors.green.shade700
                        : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () => unawaited(openMapPicker()),
                icon: const Icon(
                  Icons.map_outlined,
                  size: 16,
                ),
                label: const Text('Haritadan Seç'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
          if (isResolvingRegionCenter) ...[
            const SizedBox(height: 6),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 6),
          SizedBox(
            height: 170,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                key: ValueKey<String>(
                  'cargo_preview_${selectedProvince}_${selectedDistrict}_${(selectedLat ?? previewCenter.latitude).toStringAsFixed(4)}_${(selectedLng ?? previewCenter.longitude).toStringAsFixed(4)}',
                ),
                mapController: previewMapController,
                options: MapOptions(
                  initialCenter:
                      (selectedLat != null &&
                          selectedLng != null)
                      ? LatLng(selectedLat!, selectedLng!)
                      : previewCenter,
                  initialZoom:
                      (selectedLat != null &&
                          selectedLng != null)
                      ? 15.2
                      : 11,
                  onTap: (_, latLng) {
                    setState(() {
                      selectedLat = latLng.latitude;
                      selectedLng = latLng.longitude;
                      isAddressVerified = true;
                      addressSuggestions =
                          <
                            SellerCargoGeocodeSuggestion
                          >[];
                    });
                    setPreviewCenter(
                      LatLng(
                        latLng.latitude,
                        latLng.longitude,
                      ),
                      zoom: 15.2,
                      updateState: false,
                    );
                    unawaited(
                      reverseGeocodeFromPoint(
                        lat: latLng.latitude,
                        lng: latLng.longitude,
                        fillAddressIfEmpty: true,
                      ),
                    );
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ibul.app',
                  ),
                  if (selectedLat != null &&
                      selectedLng != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 42,
                          height: 42,
                          point: LatLng(
                            selectedLat!,
                            selectedLng!,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (verifiedAddressText != null &&
              verifiedAddressText!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              verifiedAddressText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black54,
              ),
            ),
          ],
          if (selectedLat != null &&
              selectedLng != null) ...[
            const SizedBox(height: 6),
            Text(
              'Konum: ${selectedLat!.toStringAsFixed(5)}, ${selectedLng!.toStringAsFixed(5)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    ),
    const SizedBox(height: 12),
      ],
    );
  }
}
