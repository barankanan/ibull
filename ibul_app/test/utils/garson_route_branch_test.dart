import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_area_sections.dart';
import 'package:ibul_app/utils/garson_board_state.dart';

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
      tableNumbers: <int>{11, 12},
    );
  }

  GarsonRenderBundle boardBundle({
    required GarsonBoardState state,
    List<int> tableNumbers = const <int>[11, 12],
  }) {
    final sections = sampleSections();
    return resolveGarsonRenderBundle(
      currentSections: sections,
      lastGoodSections: state.lastGoodSections,
      fallbackAreas: state.uiAreas,
      fallbackTables: state.uiTables,
      fallbackOrders: state.uiOrders,
      tableNumbers: tableNumbers.toSet(),
      areaFilterKey: 'all',
      uiTablesCount: state.uiTables.length,
      hasEverRenderedBoard: state.hasEverRenderedBoardSuccessfully,
      initialBootstrapFinished: true,
      isRefreshing: false,
      initialLoading: false,
      storeTablesReady: true,
    );
  }

  group('Garson route branch', () {
    test('board sections var, isGarsonTableRouteOpen=false -> board, no empty', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: tables,
        areas: <Map<String, dynamic>>[bahceArea],
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final bundle = boardBundle(state: state);

      expect(bundle.willShowGrid, isTrue);
      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: false,
          selectedTableContextValid: false,
          renderBundle: bundle,
          state: state,
          allTableNumbers: const <int>[11, 12],
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
      expect(
        decideGarsonRouteBranchRender(
          isGarsonModule: true,
          isTableRouteOpen: false,
          selectedTableNumber: null,
          selectedTableValid: false,
          willShowNoOrderEmpty: false,
          willShowGrid: bundle.willShowGrid,
          boardSectionsCount: sections.sections.length,
          boardTablesCount: state.uiTables.length,
        ),
        GarsonRouteBranchRender.board,
      );
    });

    test('masa kapatıldıktan sonra route state temizlenir', () {
      expect(
        shouldClearStaleGarsonTableRoute(
          isGarsonModule: true,
          isTableRouteOpen: false,
          selectedTableNumber: 11,
          selectedTableValid: true,
          boardSectionsCount: 1,
          boardTablesCount: 2,
        ),
        isTrue,
      );
      expect(
        decideGarsonRouteBranchRender(
          isGarsonModule: true,
          isTableRouteOpen: false,
          selectedTableNumber: null,
          selectedTableValid: false,
          willShowNoOrderEmpty: false,
          willShowGrid: true,
          boardSectionsCount: 1,
          boardTablesCount: 2,
        ),
        GarsonRouteBranchRender.board,
      );
    });

    test('stale selectedTable ama board sections var -> board', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: tables,
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final bundle = boardBundle(state: state);

      expect(
        shouldClearStaleGarsonTableRoute(
          isGarsonModule: true,
          isTableRouteOpen: false,
          selectedTableNumber: 11,
          selectedTableValid: true,
          boardSectionsCount: sections.sections.length,
          boardTablesCount: state.uiTables.length,
        ),
        isTrue,
      );
      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: false,
          selectedTableContextValid: true,
          renderBundle: bundle,
          state: state,
          allTableNumbers: const <int>[11, 12],
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
    });

    test('refresh board sırasında table detail branch düşmez', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: tables,
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final bundle = resolveGarsonRenderBundle(
        currentSections: const GarsonAreaSectionsResult(
          sections: <GarsonAreaSection>[],
          mode: GarsonAreaGroupingMode.blockedLoading,
          legacyMasaGroupDetected: false,
        ),
        lastGoodSections: sections,
        fallbackAreas: state.uiAreas,
        fallbackTables: state.uiTables,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: const <int>{11, 12},
        areaFilterKey: 'all',
        uiTablesCount: state.uiTables.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: true,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.willShowGrid, isTrue);
      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: false,
          selectedTableContextValid: false,
          renderBundle: bundle,
          state: state,
          allTableNumbers: const <int>[11, 12],
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
    });

    test('gerçek masa detayında boş masa -> empty sadece route açıkken', () {
      const emptyState = GarsonBoardState(
        initialLoadStatus: GarsonInitialLoadStatus.empty,
        hasEverLoadedTablesSuccessfully: false,
        hasEverRenderedBoardSuccessfully: false,
      );
      const emptySections = GarsonAreaSectionsResult(
        sections: <GarsonAreaSection>[],
        mode: GarsonAreaGroupingMode.blockedLoading,
        legacyMasaGroupDetected: false,
      );
      final bundle = GarsonRenderBundle(
        decision: GarsonSectionsRenderDecision(
          sectionsResult: emptySections,
          willShowGrid: false,
          willShowEmpty: true,
          reason: 'true_empty_after_bootstrap',
        ),
        renderSections: const <GarsonAreaSection>[],
        sectionsResult: emptySections,
        totalTableCount: 0,
        occupiedTableCount: 0,
        willShowGrid: false,
        willShowLoading: false,
        willShowEmpty: true,
        reason: 'true_empty_after_bootstrap',
      );

      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: true,
          selectedTableContextValid: true,
          renderBundle: bundle,
          state: emptyState,
          allTableNumbers: const <int>[],
          initialBootstrapFinished: true,
        ),
        isTrue,
      );
      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: false,
          selectedTableContextValid: false,
          renderBundle: bundle,
          state: emptyState,
          allTableNumbers: const <int>[],
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
    });

    test('occupied filter boş ama configured tables var -> board empty yok', () {
      final sections = sampleSections();
      final state = GarsonBoardState(
        tables: tables,
        lastGoodSections: sections,
        hasEverRenderedBoardSuccessfully: true,
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );
      final bundle = resolveGarsonRenderBundle(
        currentSections: sections,
        lastGoodSections: sections,
        fallbackAreas: state.uiAreas,
        fallbackTables: state.uiTables,
        fallbackOrders: const <Map<String, dynamic>>[],
        tableNumbers: const <int>{11, 12},
        areaFilterKey: 'all',
        uiTablesCount: state.uiTables.length,
        hasEverRenderedBoard: true,
        initialBootstrapFinished: true,
        isRefreshing: false,
        initialLoading: false,
        storeTablesReady: true,
      );

      expect(bundle.willShowEmpty, isFalse);
      expect(
        shouldShowGarsonNoOrderEmptyOnBoard(
          isGarsonTableRouteOpen: false,
          selectedTableContextValid: false,
          renderBundle: bundle,
          state: state,
          allTableNumbers: const <int>[11, 12],
          initialBootstrapFinished: true,
        ),
        isFalse,
      );
    });
  });
}
