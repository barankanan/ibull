import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_area_sections.dart';
import 'package:ibul_app/utils/garson_board_state.dart';
import 'package:ibul_app/utils/garson_table_order_state.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';

void main() {
  const bahceArea = <String, dynamic>{
    'id': 'area-bahce',
    'name': 'Bahçe',
    'sort_order': 1,
  };
  const tables = <Map<String, dynamic>>[
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
  ];

  GarsonAreaSectionsResult sampleSections() {
    return resolveGarsonAreaSections(
      areas: <Map<String, dynamic>>[bahceArea],
      tables: tables,
      activeOrders: const <Map<String, dynamic>>[],
    );
  }

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

  List<Map<String, dynamic>> sevenTables() {
    return <Map<String, dynamic>>[
      ...List<Map<String, dynamic>>.generate(
        3,
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
        3,
        (index) => <String, dynamic>{
          'id': 'salon-${index + 1}',
          'table_number': 20 + index + 1,
          'area_id': 'area-salon',
          'area_name': 'Salon',
          'area_table_number': index + 1,
          'display_label': 'Salon ${index + 1}',
        },
      ),
      <String, dynamic>{
        'id': 'teras-1',
        'table_number': 31,
        'area_id': 'area-teras',
        'area_name': 'Teras',
        'area_table_number': 1,
        'display_label': 'Teras 1',
      },
    ];
  }

  GarsonAreaSectionsResult sevenTableSections() {
    return resolveGarsonAreaSections(
      areas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
      tables: sevenTables(),
      activeOrders: const <Map<String, dynamic>>[],
    );
  }

  group('resolveGarsonRenderBundle', () {
    test('refresh current boş lastGood 3 alan -> grid render edilir', () {
      final lastGood = sevenTableSections();
      final current = const GarsonAreaSectionsResult(
        sections: <GarsonAreaSection>[],
        mode: GarsonAreaGroupingMode.blockedLoading,
        legacyMasaGroupDetected: false,
      );
      final bundle = resolveGarsonRenderBundle(
        currentSections: current,
        lastGoodSections: lastGood,
        fallbackAreas: const <Map<String, dynamic>>[],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'all',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: true,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.willShowGrid, isTrue);
      expect(bundle.willShowLoading, isFalse);
      expect(bundle.renderSections, hasLength(3));
      expect(bundle.totalTableCount, 7);
    });

    test('Toplam 7 count ile grid aynı renderSections kaynağını kullanır', () {
      final sections = sevenTableSections();
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'all',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.totalTableCount, 7);
      expect(
        bundle.renderSections.fold<int>(
          0,
          (sum, section) => sum + section.tables.length,
        ),
        7,
      );
    });

    test('selectedArea Tüm Alanlar tüm sectionları gösterir', () {
      final sections = sevenTableSections();
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'all',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );
      expect(bundle.renderSections, hasLength(3));
    });

    test('selectedArea areaName ile eşleşir', () {
      final sections = sevenTableSections();
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'name:Bahçe',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );
      expect(bundle.renderSections, hasLength(1));
      expect(bundle.renderSections.first.areaName, 'Bahçe');
      expect(bundle.totalTableCount, 3);
    });

    test('selectedArea areaId ile eşleşir', () {
      final sections = sevenTableSections();
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'id:area-salon',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );
      expect(bundle.renderSections, hasLength(1));
      expect(bundle.renderSections.first.areaName, 'Salon');
      expect(bundle.totalTableCount, 3);
    });

    test('manual refresh loading lastGood varken loading body yok', () {
      final lastGood = sevenTableSections();
      final current = const GarsonAreaSectionsResult(
        sections: <GarsonAreaSection>[],
        mode: GarsonAreaGroupingMode.blockedLoading,
        legacyMasaGroupDetected: false,
      );
      final bundle = resolveGarsonRenderBundle(
        currentSections: current,
        lastGoodSections: lastGood,
        fallbackAreas: <Map<String, dynamic>>[bahceArea, salonArea, terasArea],
        fallbackTables: sevenTables(),
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12, 13, 21, 22, 23, 31},
        areaFilterKey: 'all',
        uiTablesCount: 7,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: true,
        initialLoading: true,
        storeTablesReady: true,
      );

      expect(bundle.willShowLoading, isFalse);
      expect(bundle.willShowGrid, isTrue);
      expect(bundle.renderSections, isNotEmpty);
    });
  });

  group('Garson board render preservation', () {
    test('sections var orders boş -> grid gösterilir empty state yok', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: tables,
        areas: <Map<String, dynamic>>[bahceArea],
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final tableNumbers = garsonTableNumbersForDisplay(
        configuredTableNumbers: const <int>[11, 12],
        lastGoodTableNumbers: const <int>[11, 12],
        orderTableNumbers: const <int>[],
        storeTablesReady: true,
      );
      final decision = decideGarsonSectionsRender(
        currentSections: sections,
        lastGoodSections: sections,
        uiTablesCount: state.uiTables.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
      );

      expect(
        shouldShowGarsonNoTableOrderEmptyState(
          tableNumbers: tableNumbers,
          sectionsResult: decision.sectionsResult,
          state: state,
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
      expect(decision.willShowGrid, isTrue);
    });

    test('route change sonrası lastGoodSections korunur', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: const <Map<String, dynamic>>[],
        areas: const <Map<String, dynamic>>[],
        orders: const <Map<String, dynamic>>[],
        lastGoodTables: tables,
        lastGoodAreas: <Map<String, dynamic>>[bahceArea],
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final currentSections = resolveGarsonAreaSections(
        areas: const <Map<String, dynamic>>[],
        tables: const <Map<String, dynamic>>[],
        activeOrders: const <Map<String, dynamic>>[],
        tableNumbers: <int>{11, 12},
      );
      final decision = decideGarsonSectionsRender(
        currentSections: currentSections,
        lastGoodSections: state.lastGoodSections,
        uiTablesCount: state.uiTables.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
      );

      expect(decision.sectionsResult.sections, isNotEmpty);
      expect(decision.willShowEmpty, isFalse);
      expect(decision.reason, 'last_good_sections_fallback');
    });

    test('refresh loading sırasında önceki board korunur', () {
      expect(
        shouldShowGarsonInitialLoading(
          initialLoading: true,
          initialVisibleSeedDone: true,
          visibleOrderCount: 0,
          storeTableCount: 0,
          lastGoodTableCount: 2,
          hasEverRenderedBoard: true,
          manualRefreshInProgress: true,
        ),
        isFalse,
      );
    });

    test('refresh boş döndü ama lastGoodSections var -> board korunur', () {
      final sections = sampleSections();
      final current = GarsonBoardState(
        tables: tables,
        areas: <Map<String, dynamic>>[bahceArea],
        orders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 11, 'status': 'sent'},
        ],
        lastGoodTables: tables,
        lastGoodAreas: <Map<String, dynamic>>[bahceArea],
        lastGoodOrders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 11, 'status': 'sent'},
        ],
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );

      final next = applyManualRefresh(
        current: current,
        tables: const <Map<String, dynamic>>[],
        areas: const <Map<String, dynamic>>[],
        orders: const <Map<String, dynamic>>[],
        source: 'garson_manual_refresh_button',
      );

      expect(next.uiTables, hasLength(2));
      expect(next.lastGoodTables, hasLength(2));
      expect(next.lastGoodSections?.sections, isNotEmpty);
      expect(
        shouldShowGarsonNoTableOrderEmptyState(
          tableNumbers: const <int>[],
          sectionsResult: sections,
          state: next,
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
    });

    test('initial bootstrap loading -> empty state yok', () {
      final loadingSections = const GarsonAreaSectionsResult(
        sections: <GarsonAreaSection>[],
        mode: GarsonAreaGroupingMode.blockedLoading,
        legacyMasaGroupDetected: false,
      );
      final state = const GarsonBoardState(
        initialLoadStatus: GarsonInitialLoadStatus.loading,
      );

      expect(
        shouldShowGarsonNoTableOrderEmptyState(
          tableNumbers: const <int>[],
          sectionsResult: loadingSections,
          state: state,
          initialBootstrapFinished: false,
        ),
        isFalse,
      );
      expect(
        shouldShowGarsonInitialLoading(
          initialLoading: true,
          initialVisibleSeedDone: false,
          visibleOrderCount: 0,
          storeTableCount: 0,
        ),
        isTrue,
      );
    });

    test('DB gerçekten 0 masa -> empty state gösterilir', () {
      final state = const GarsonBoardState(
        initialLoadStatus: GarsonInitialLoadStatus.empty,
        hasEverLoadedTablesSuccessfully: false,
        hasEverRenderedBoardSuccessfully: false,
      );
      final sections = const GarsonAreaSectionsResult(
        sections: <GarsonAreaSection>[],
        mode: GarsonAreaGroupingMode.blockedLoading,
        legacyMasaGroupDetected: false,
      );

      expect(shouldShowEmptyState(state: state), isTrue);
      expect(
        shouldShowGarsonNoTableOrderEmptyState(
          tableNumbers: const <int>[],
          sectionsResult: sections,
          state: state,
          initialBootstrapFinished: true,
        ),
        isTrue,
      );
    });
  });

  // ─── Bug fix: tüm siparişler kapandığında masalar kaybolmamalı ───────────

  group('orders=0 tables=14 board preservation', () {
    List<Map<String, dynamic>> fourteenTables() {
      final areas = <String>['Bahçe', 'Salon', 'Teras'];
      final result = <Map<String, dynamic>>[];
      var n = 1;
      for (final area in areas) {
        for (var i = 0; i < (area == 'Teras' ? 4 : 5); i++) {
          result.add(<String, dynamic>{
            'id': 'table-${area.toLowerCase()}-$n',
            'table_number': n,
            'area_id': 'area-${area.toLowerCase()}',
            'area_name': area,
            'area_table_number': i + 1,
            'display_label': '$area ${i + 1}',
          });
          n++;
        }
      }
      return result;
    }

    List<Map<String, dynamic>> threeAreas() => <Map<String, dynamic>>[
      <String, dynamic>{'id': 'area-bahçe', 'name': 'Bahçe', 'sort_order': 1},
      <String, dynamic>{'id': 'area-salon', 'name': 'Salon', 'sort_order': 2},
      <String, dynamic>{'id': 'area-teras', 'name': 'Teras', 'sort_order': 3},
    ];

    test('14 configured table, active orders 0 → totalTableCount=14 willShowGrid=true willShowEmpty=false', () {
      final tbls = fourteenTables();
      final tableNums = tbls
          .map((t) => t['table_number'] as int)
          .toSet()
          .toList()
        ..sort();

      final sections = resolveGarsonAreaSections(
        areas: threeAreas(),
        tables: tbls,
        activeOrders: const <Map<String, dynamic>>[],
      );

      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: null,
        fallbackAreas: threeAreas(),
        fallbackTables: tbls,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: tableNums.toSet(),
        areaFilterKey: 'all',
        uiTablesCount: tbls.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.totalTableCount, 14);
      expect(bundle.occupiedTableCount, 0);
      expect(bundle.willShowGrid, isTrue);
      expect(bundle.willShowEmpty, isFalse);
      expect(bundle.renderSections, hasLength(3));
    });

    test('son sipariş kapatılınca occupied 1→0 tableCount 14 kalır', () {
      final tbls = fourteenTables();
      final tableNums = tbls
          .map((t) => t['table_number'] as int)
          .toSet()
          .toList()
        ..sort();

      // Before close: 1 active order on table 1
      final beforeSections = resolveGarsonAreaSections(
        areas: threeAreas(),
        tables: tbls,
        activeOrders: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'order-1',
            'table_number': 1,
            'status': 'preparing',
          },
        ],
      );
      expect(beforeSections.sections.expand((s) => s.tables).where((t) => t.isOccupied).length, 1);
      expect(beforeSections.sections.fold<int>(0, (sum, s) => sum + s.totalCount), 14);

      // After close: 0 active orders
      final afterSections = resolveGarsonAreaSections(
        areas: threeAreas(),
        tables: tbls,
        activeOrders: const <Map<String, dynamic>>[],
      );

      final bundle = resolveGarsonRenderBundle(
        currentSections: afterSections,
        lastGoodSections: null,
        fallbackAreas: threeAreas(),
        fallbackTables: tbls,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: tableNums.toSet(),
        areaFilterKey: 'all',
        uiTablesCount: tbls.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.totalTableCount, 14);
      expect(bundle.occupiedTableCount, 0);
      expect(bundle.willShowGrid, isTrue);
    });

    test('removeClosedTableOrdersFromBoardState tables ve areas dokunulmuyor', () {
      final tbls = fourteenTables();
      final closedOrder = <String, dynamic>{
        'id': 'order-tbl1',
        'table_number': 1,
        'status': 'closed',
      };
      final otherOrder = <String, dynamic>{
        'id': 'order-tbl5',
        'table_number': 5,
        'status': 'preparing',
      };
      final state = GarsonBoardState(
        tables: tbls,
        areas: threeAreas(),
        orders: <Map<String, dynamic>>[closedOrder, otherOrder],
        lastGoodTables: tbls,
        lastGoodAreas: threeAreas(),
        lastGoodOrders: <Map<String, dynamic>>[closedOrder, otherOrder],
        hasEverLoadedTablesSuccessfully: true,
        hasEverRenderedBoardSuccessfully: true,
      );

      final next = removeClosedTableOrdersFromBoardState(
        current: state,
        tableNumber: 1,
        closedOrderId: 'order-tbl1',
      );

      expect(next.tables.length, tbls.length, reason: 'tables must not change');
      expect(next.lastGoodTables.length, tbls.length, reason: 'lastGoodTables must not change');
      expect(next.areas.length, 3, reason: 'areas must not change');
      expect(next.orders.length, 1, reason: 'closed table order removed from orders');
      expect(next.lastGoodOrders.length, 1, reason: 'closed table order removed from lastGoodOrders');
      expect(next.orders.first['table_number'], 5);
    });

    test('orders=[], tables=14 boardState → garsonTableNumbersForDisplay configured tables döner', () {
      final tbls = fourteenTables();
      final configuredNums = tbls
          .map((t) => t['table_number'] as int)
          .where((n) => n > 0)
          .toSet()
          .toList()
        ..sort();

      final result = garsonTableNumbersForDisplay(
        configuredTableNumbers: configuredNums,
        lastGoodTableNumbers: configuredNums,
        orderTableNumbers: const <int>[],
        storeTablesReady: true,
      );

      expect(result.length, 14);
      expect(result, configuredNums);
    });

    test('refresh sonrası orders=0 board kaybolmaz willShowGrid=true', () {
      final tbls = fourteenTables();
      final tableNums = tbls.map((t) => t['table_number'] as int).toSet();

      final sections = resolveGarsonAreaSections(
        areas: threeAreas(),
        tables: tbls,
        activeOrders: const <Map<String, dynamic>>[],
      );
      expect(sections.sections, isNotEmpty);

      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: threeAreas(),
        fallbackTables: tbls,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: tableNums,
        areaFilterKey: 'all',
        uiTablesCount: tbls.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.willShowGrid, isTrue);
      expect(bundle.willShowEmpty, isFalse);
      expect(bundle.totalTableCount, 14);
    });

    test('Dolu Masa filtresi ve occupied=0 → configured tables state silinmez', () {
      final tbls = fourteenTables();
      final tableNums = tbls.map((t) => t['table_number'] as int).toSet().toList()..sort();

      // No occupied tables
      final ordersByTable = <int, List<Map<String, dynamic>>>{};
      final statusFiltered = tableNums.where((tableNo) {
        final tOrders = ordersByTable[tableNo] ?? <Map<String, dynamic>>[];
        return tOrders.isNotEmpty; // 'occupied' filter
      }).toList();

      expect(statusFiltered, isEmpty, reason: 'filter returns 0 with no orders');

      // Even with empty filtered list, the renderBundle from full tableNums is intact
      final sections = resolveGarsonAreaSections(
        areas: threeAreas(),
        tables: tbls,
        activeOrders: const <Map<String, dynamic>>[],
      );
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: threeAreas(),
        fallbackTables: tbls,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: tableNums.toSet(),
        areaFilterKey: 'all',
        uiTablesCount: tbls.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      // Chrome (chips) remain intact — Toplam Masa=14 even when filter shows 0
      expect(bundle.totalTableCount, 14);
      expect(bundle.occupiedTableCount, 0);
      expect(bundle.willShowGrid, isTrue);
      // The UI should show "Bu filtreyle eşleşen masa yok" (status filter guard)
      // not wipe the entire board
    });
  });
}
