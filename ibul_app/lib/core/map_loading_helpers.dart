/// Pure helpers for map loading UI policy — keeps the map visible while
/// stores/location load in the background.
bool shouldShowStoreLoadingChip({
  required bool isMapReady,
  required bool isLoadingStores,
  required int businessCount,
}) {
  return isMapReady && isLoadingStores && businessCount == 0;
}

/// Failsafe: never leave loading flags set beyond [failsafe].
bool shouldForceClearMapLoading({
  required bool isLoadingStores,
  required bool isLoadingLocation,
  required Duration elapsed,
  required Duration failsafe,
}) {
  return elapsed >= failsafe && (isLoadingStores || isLoadingLocation);
}

class MapLatLng {
  const MapLatLng(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

MapLatLng resolveMapInitialCenter({
  MapLatLng? userLocation,
  required MapLatLng defaultCenter,
}) {
  return userLocation ?? defaultCenter;
}

String resolveMapStoresEmptyMessage({
  required int rawCount,
  required int markerCount,
}) {
  if (rawCount == 0) return 'Gösterilecek mağaza bulunamadı.';
  if (markerCount == 0) return 'Mağazaların konum bilgisi eksik.';
  return '';
}
