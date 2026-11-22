import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/map_store_filter_helpers.dart';

void main() {
  group('resolveMapStoreOpenNow', () {
    final noon = DateTime(2026, 11, 18, 12);
    final lateNight = DateTime(2026, 11, 18, 23, 30);

    test('seller-closed store is closed regardless of hours', () {
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: false,
          workingHours: '24 Saat',
          now: noon,
        ),
        isFalse,
      );
    });

    test('uses working hours range against the current time', () {
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: true,
          workingHours: '09:00 - 18:00',
          now: noon,
        ),
        isTrue,
      );
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: true,
          workingHours: '09:00 - 18:00',
          now: lateNight,
        ),
        isFalse,
      );
      // Gece yarısını aşan aralık.
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: null,
          workingHours: '18:00 - 02:00',
          now: lateNight,
        ),
        isTrue,
      );
    });

    test('24 saat is always open', () {
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: true,
          workingHours: '24 Saat',
          now: lateNight,
        ),
        isTrue,
      );
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: null,
          workingHours: '7/24',
          now: lateNight,
        ),
        isTrue,
      );
    });

    test('missing or unparseable data stays unknown', () {
      expect(
        resolveMapStoreOpenNow(isStoreOpen: null, workingHours: null),
        isNull,
      );
      expect(
        resolveMapStoreOpenNow(
          isStoreOpen: null,
          workingHours: 'Hafta içi',
          now: noon,
        ),
        isNull,
      );
      expect(
        resolveMapStoreOpenNow(isStoreOpen: true, workingHours: ''),
        isTrue,
      );
    });
  });

  group('open-now filter', () {
    // Eski davranış: indekse göre her 5. mağaza gizleniyordu (i % 5 == 0).
    List<int> run({required List<bool?> open, required bool filterOpenNow}) =>
        filterMapStoreIndices(
          businessCount: open.length,
          businessNameAt: (i) => 'Mağaza $i',
          categoryAt: (_) => 'market',
          distanceKmAt: (_) => 1.0,
          searchQuery: '',
          filterCategories: const [],
          filterOpenNow: filterOpenNow,
          filterDistanceKm: 10,
          hasUserLocation: false,
          isOpenNowAt: (i) => open[i],
        );

    test('hides only stores known to be closed', () {
      final open = <bool?>[true, false, null, true, false, true];
      expect(run(open: open, filterOpenNow: true), [0, 2, 3, 5]);
    });

    test('does not hide stores by index', () {
      final open = List<bool?>.filled(11, true);
      expect(run(open: open, filterOpenNow: true), hasLength(11));
    });

    test('filter off keeps closed stores', () {
      expect(run(open: const [false, false], filterOpenNow: false), [0, 1]);
    });

    test('empty result under open-now filter reports a filter message', () {
      expect(
        resolveMapFilteredEmptyMessage(
          rawCount: 3,
          markerCount: 3,
          filteredCount: 0,
          searchQuery: '',
          filterCategories: const [],
          hasUserLocation: false,
          filterDistanceKm: 10,
          filterOpenNow: true,
        ),
        'Filtreye uygun mağaza bulunamadı.',
      );
    });
  });

  group('filterMapStoreIndices', () {
    test('search matches Turkish dotted/dotless I regardless of case', () {
      const trNames = <String>['İstanbul Kebap', 'ISITICI Dünyası', 'Çiçekçi'];
      List<int> search(String query) => filterMapStoreIndices(
            businessCount: trNames.length,
            businessNameAt: (i) => trNames[i],
            categoryAt: (_) => 'market',
            distanceKmAt: (_) => 1.0,
            searchQuery: query,
            filterCategories: const [],
            filterOpenNow: false,
            filterDistanceKm: 10,
            hasUserLocation: false,
          );
      expect(search('istanbul'), [0]);
      expect(search('İSTANBUL'), [0]);
      expect(search('ısıtıcı'), [1]);
      expect(search('cicek'), [2]);
      expect(search('  kebap '), [0]);
    });

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
