import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/map_store_filter_helpers.dart';

void main() {
  group('filterMapStoreIndices', () {
    const names = <String>['Mağaza A', 'Mağaza B', 'Uzak Mağaza'];
    const categories = <String>['restoran', 'market', 'restoran'];
    const distances = <double?>[1.0, 5.0, 25.0];

    test('empty search shows all stores when no filters', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: '',
        filterCategories: const [],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: false,
      );
      expect(indices, [0, 1, 2]);
    });

    test('no user location — radius filter does not drop stores', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: '',
        filterCategories: const [],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: false,
      );
      expect(indices, contains(2));
    });

    test('with user location — radius filter applies only after user applies it', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: '',
        filterCategories: const [],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: true,
        userAppliedDistanceFilter: true,
      );
      expect(indices, [0, 1]);
      expect(indices, isNot(contains(2)));
    });

    test('with user location on first open — radius filter does not drop stores', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: '',
        filterCategories: const [],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: true,
        userAppliedDistanceFilter: false,
      );
      expect(indices, [0, 1, 2]);
    });

    test('filter after search can return zero', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: 'yok-böyle',
        filterCategories: const [],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: false,
      );
      expect(indices, isEmpty);
    });

    test('product search candidates still respect active filters', () {
      final indices = filterMapStoreIndices(
        businessCount: names.length,
        businessNameAt: (i) => names[i],
        categoryAt: (i) => categories[i],
        distanceKmAt: (i) => distances[i],
        searchQuery: '',
        filterCategories: const ['market'],
        filterOpenNow: false,
        filterDistanceKm: 10,
        hasUserLocation: false,
        candidateIndices: const [0, 1, 2],
      );
      expect(indices, [1]);
    });
  });

  group('resolveMapFilteredEmptyMessage', () {
    test('raw count zero', () {
      expect(
        resolveMapFilteredEmptyMessage(
          rawCount: 0,
          markerCount: 0,
          filteredCount: 0,
          searchQuery: '',
          filterCategories: const [],
          hasUserLocation: false,
          filterDistanceKm: 10,
        ),
        'Gösterilecek mağaza bulunamadı.',
      );
    });

    test('raw positive but no coordinates', () {
      expect(
        resolveMapFilteredEmptyMessage(
          rawCount: 5,
          markerCount: 0,
          filteredCount: 0,
          searchQuery: '',
          filterCategories: const [],
          hasUserLocation: false,
          filterDistanceKm: 10,
        ),
        'Mağazaların konum bilgisi eksik.',
      );
    });

    test('filter/search zero with markers present', () {
      expect(
        resolveMapFilteredEmptyMessage(
          rawCount: 5,
          markerCount: 5,
          filteredCount: 0,
          searchQuery: 'pizza',
          filterCategories: const [],
          hasUserLocation: false,
          filterDistanceKm: 10,
        ),
        'Filtreye uygun mağaza bulunamadı.',
      );
    });
  });

  group('shouldApplyMapDistanceFilter', () {
    test('false without user location', () {
      expect(
        shouldApplyMapDistanceFilter(
          hasUserLocation: false,
          userAppliedDistanceFilter: true,
        ),
        isFalse,
      );
    });

    test('false on first open even with user location', () {
      expect(
        shouldApplyMapDistanceFilter(
          hasUserLocation: true,
          userAppliedDistanceFilter: false,
        ),
        isFalse,
      );
    });

    test('true when user applied distance filter', () {
      expect(
        shouldApplyMapDistanceFilter(
          hasUserLocation: true,
          userAppliedDistanceFilter: true,
        ),
        isTrue,
      );
    });
  });
}
