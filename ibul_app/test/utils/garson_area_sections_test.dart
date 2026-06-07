import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_area_sections.dart';

void main() {
  const bahceArea = <String, dynamic>{
    'id': 'area-bahce',
    'name': 'Bahçe',
    'sort_order': 1,
  };
  const salonArea = <String, dynamic>{
    'id': 'area-salon',
    'name': 'Salon',
    'sort_order': 2,
  };
  const terasArea = <String, dynamic>{
    'id': 'area-teras',
    'name': 'Teras',
    'sort_order': 3,
  };

  List<Map<String, dynamic>> sampleTables() {
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'table-bahce-1',
        'table_number': 11,
        'area_id': 'area-bahce',
        'area_name': 'Bahçe',
        'area_table_number': 1,
        'display_label': 'Bahçe 1',
      },
      <String, dynamic>{
        'id': 'table-bahce-2',
        'table_number': 12,
        'area_id': 'area-bahce',
        'area_name': 'Bahçe',
        'area_table_number': 2,
        'display_label': 'Bahçe 2',
      },
      <String, dynamic>{
        'id': 'table-salon-1',
        'table_number': 21,
        'area_id': 'area-salon',
        'area_name': 'Salon',
        'area_table_number': 1,
        'display_label': 'Salon 1',
      },
      <String, dynamic>{
        'id': 'table-salon-2',
        'table_number': 22,
        'area_id': 'area-salon',
        'area_name': 'Salon',
        'area_table_number': 2,
        'display_label': 'Salon 2',
      },
      <String, dynamic>{
        'id': 'table-teras-1',
        'table_number': 31,
        'area_id': 'area-teras',
        'area_name': 'Teras',
        'area_table_number': 1,
        'display_label': 'Teras 1',
      },
    ];
  }

  group('resolveGarsonAreaSections', () {
    test('store_table_areas ile Bahçe Salon Teras section üretir', () {
      final result = resolveGarsonAreaSections(
        areas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        tables: sampleTables(),
        activeOrders: const <Map<String, dynamic>>[],
      );

      expect(result.mode, GarsonAreaGroupingMode.areaBased);
      expect(result.sections, hasLength(3));
      expect(
        result.sections.map((section) => section.areaName).toList(),
        <String>['Bahçe', 'Salon', 'Teras'],
      );
      expect(
        result.sections.any((section) => section.areaName == 'Masa 1'),
        isFalse,
      );
      expect(result.sections.first.tables.first.displayLabel, 'Bahçe 1');
    });

    test('areas geç gelirken legacy Masa X label area olarak yansımaz, '
        'fiziksel masalar "Salon" altında synthesize edilir', () {
      // BUG-FIX (Render Gap): Previously this returned blockedLoading + empty
      // sections, which caused "Toplam Masa: 0" on deployments with no
      // store_table_areas AND no area_name on the tables.  New contract:
      // synthesize an implicit "Salon" bucket so the physical catalog is
      // always visible.  The legacy guard still applies — no `Masa X` area
      // name is emitted.
      final result = resolveGarsonAreaSections(
        areas: const <Map<String, dynamic>>[],
        tables: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'table-1',
            'table_number': 1,
            'display_label': 'Masa 1',
            'table_name': 'Masa 1',
          },
          <String, dynamic>{
            'id': 'table-2',
            'table_number': 2,
            'display_label': 'Masa 2',
            'table_name': 'Masa 2',
          },
        ],
        activeOrders: const <Map<String, dynamic>>[],
      );

      expect(result.mode, GarsonAreaGroupingMode.areaNameFallback);
      expect(result.sections, hasLength(1));
      expect(result.sections.first.areaName, 'Salon');
      expect(result.sections.first.totalCount, 2);
      expect(
        result.sections.any((s) => isGarsonForbiddenSectionLabel(s.areaName)),
        isFalse,
        reason: 'Legacy "Masa N" labels must never reach the section list.',
      );
      expect(result.isLoading, isFalse);
    });

    test('restart sonrası first render: Masa label kullanılmaz, '
        '4 masa Salon altında listelenir', () {
      final result = resolveGarsonAreaSections(
        areas: const <Map<String, dynamic>>[],
        tables: List<Map<String, dynamic>>.generate(
          4,
          (index) => <String, dynamic>{
            'id': 'table-${index + 1}',
            'table_number': index + 1,
            'display_label': 'Masa ${index + 1}',
          },
        ),
        activeOrders: const <Map<String, dynamic>>[],
      );

      // No area named "Masa N" should ever be created.
      expect(
        result.sections.where((s) => s.areaName.startsWith('Masa')),
        isEmpty,
      );
      // But the catalog must still be rendered (Toplam Masa invariant).
      expect(result.sections, hasLength(1));
      expect(result.sections.first.areaName, 'Salon');
      expect(result.sections.first.totalCount, 4);
      expect(result.isLoading, isFalse);
    });

    test('tables.area_name fallback Bahçe Salon Teras ile gruplar', () {
      final result = resolveGarsonAreaSections(
        areas: const <Map<String, dynamic>>[],
        tables: sampleTables(),
        activeOrders: const <Map<String, dynamic>>[],
      );

      expect(result.mode, GarsonAreaGroupingMode.areaNameFallback);
      expect(
        result.sections.map((section) => section.areaName).toSet(),
        <String>{'Bahçe', 'Salon', 'Teras'},
      );
      expect(
        result.sections.any(
          (section) => isGarsonForbiddenSectionLabel(section.areaName),
        ),
        isFalse,
      );
    });

    test('legacy label guard: Masa N area_name yok sayılır ama '
        'fiziksel masalar yine Salon altında render edilir', () {
      expect(isGarsonForbiddenSectionLabel('Masa 1'), isTrue);
      expect(isGarsonForbiddenSectionLabel('Masa 4'), isTrue);
      expect(isGarsonForbiddenSectionLabel('Genel Masa'), isTrue);
      expect(isGarsonForbiddenSectionLabel('Bahçe'), isFalse);
      expect(isGarsonForbiddenSectionLabel('Salon'), isFalse);

      final result = resolveGarsonAreaSections(
        areas: const <Map<String, dynamic>>[],
        tables: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'table-1',
            'table_number': 1,
            'area_name': 'Masa 1',
            'display_label': 'Masa 1',
          },
        ],
        activeOrders: const <Map<String, dynamic>>[],
      );

      // The legacy detection bit must still flag this row.
      expect(result.legacyMasaGroupDetected, isTrue);
      // BUG-FIX: but the result is no longer empty — the physical table is
      // grouped into "Salon" so the user doesn't see "Toplam Masa: 0".
      expect(result.sections, hasLength(1));
      expect(result.sections.first.areaName, 'Salon');
      expect(result.sections.first.totalCount, 1);
      expect(
        result.sections.any((s) => isGarsonForbiddenSectionLabel(s.areaName)),
        isFalse,
      );
      expect(result.isLoading, isFalse);
    });

    test('14 masa Bahçe Salon Teras alanlarına dağılır', () {
      final tables = <Map<String, dynamic>>[
        ...List<Map<String, dynamic>>.generate(
          5,
          (index) => <String, dynamic>{
            'id': 'bahce-${index + 1}',
            'table_number': 10 + index + 1,
            'area_id': 'area-bahce',
            'area_name': 'Bahçe',
            'area_table_number': index + 1,
            'display_label': 'Bahçe ${index + 1}',
          },
        ),
        ...List<Map<String, dynamic>>.generate(
          6,
          (index) => <String, dynamic>{
            'id': 'salon-${index + 1}',
            'table_number': 20 + index + 1,
            'area_id': 'area-salon',
            'area_name': 'Salon',
            'area_table_number': index + 1,
            'display_label': 'Salon ${index + 1}',
          },
        ),
        ...List<Map<String, dynamic>>.generate(
          3,
          (index) => <String, dynamic>{
            'id': 'teras-${index + 1}',
            'table_number': 30 + index + 1,
            'area_id': 'area-teras',
            'area_name': 'Teras',
            'area_table_number': index + 1,
            'display_label': 'Teras ${index + 1}',
          },
        ),
      ];

      final result = resolveGarsonAreaSections(
        areas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        tables: tables,
        activeOrders: const <Map<String, dynamic>>[],
      );

      expect(result.sections, hasLength(3));
      expect(result.sections[0].totalCount, 5);
      expect(result.sections[1].totalCount, 6);
      expect(result.sections[2].totalCount, 3);
      expect(
        result.sections.fold<int>(
          0,
          (sum, section) => sum + section.totalCount,
        ),
        14,
      );
    });
  });

  group('resolveGarsonRenderBundle', () {
    test(
      'tableNumbers geçici olarak boşalsa bile fiziksel masa fallback ile grid korunur',
      () {
        final current = const GarsonAreaSectionsResult(
          sections: <GarsonAreaSection>[],
          mode: GarsonAreaGroupingMode.areaBased,
          legacyMasaGroupDetected: false,
        );

        final bundle = resolveGarsonRenderBundle(
          currentSections: current,
          lastGoodSections: null,
          fallbackAreas: <Map<String, dynamic>>[
            bahceArea,
            salonArea,
            terasArea,
          ],
          fallbackTables: sampleTables(),
          fallbackOrders: const <Map<String, dynamic>>[],
          tableNumbers: const <int>{},
          areaFilterKey: 'all',
          uiTablesCount: 0,
          hasEverRenderedBoard: true,
          initialBootstrapFinished: true,
          isRefreshing: false,
          initialLoading: false,
          storeTablesReady: true,
        );

        expect(bundle.willShowGrid, isTrue);
        expect(bundle.willShowEmpty, isFalse);
        expect(bundle.totalTableCount, sampleTables().length);
        expect(bundle.renderSections, isNotEmpty);
      },
    );
  });
}
