import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/map_loading_helpers.dart';

void main() {
  const defaultCenter = MapLatLng(36.2025, 36.1605);

  group('map loading never stuck', () {
    test('map renders with default center when location is null', () {
      expect(
        resolveMapInitialCenter(
          userLocation: null,
          defaultCenter: defaultCenter,
        ),
        defaultCenter,
      );
    });

    test('store loading chip only on small overlay, not fullscreen', () {
      expect(
        shouldShowStoreLoadingChip(
          isMapReady: true,
          isLoadingStores: true,
          businessCount: 0,
        ),
        isTrue,
      );
      expect(
        shouldShowStoreLoadingChip(
          isMapReady: true,
          isLoadingStores: true,
          businessCount: 3,
        ),
        isFalse,
      );
      expect(
        shouldShowStoreLoadingChip(
          isMapReady: false,
          isLoadingStores: true,
          businessCount: 0,
        ),
        isFalse,
      );
    });

    test('failsafe clears loading after timeout even if stores still loading',
        () {
      expect(
        shouldForceClearMapLoading(
          isLoadingStores: true,
          isLoadingLocation: false,
          elapsed: const Duration(seconds: 5),
          failsafe: const Duration(seconds: 5),
        ),
        isTrue,
      );
      expect(
        shouldForceClearMapLoading(
          isLoadingStores: true,
          isLoadingLocation: true,
          elapsed: const Duration(seconds: 2),
          failsafe: const Duration(seconds: 5),
        ),
        isFalse,
      );
    });

    test('location timeout does not block map — loading flags can clear', () {
      expect(
        shouldForceClearMapLoading(
          isLoadingStores: false,
          isLoadingLocation: true,
          elapsed: const Duration(seconds: 6),
          failsafe: const Duration(seconds: 5),
        ),
        isTrue,
      );
    });
  });

  group('map empty messages', () {
    test('raw count zero', () {
      expect(
        resolveMapStoresEmptyMessage(rawCount: 0, markerCount: 0),
        'Gösterilecek mağaza bulunamadı.',
      );
    });

    test('raw count positive but no markers', () {
      expect(
        resolveMapStoresEmptyMessage(rawCount: 5, markerCount: 0),
        'Mağazaların konum bilgisi eksik.',
      );
    });
  });
}
