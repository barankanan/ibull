import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/utils/garson_board_state.dart';

/// Regression tests for the products / garson realtime stream lifecycle.
///
/// These tests pin down the rules that prevent the panel rebuild loop the
/// user reported: products realtime times out → fallback snapshot fetch
/// → re-subscribe → same data → setState → panel rebuild → render_decision
/// log spam → garson screen flickers / Genel Bakış sayıları gidip geliyor.
///
/// All rules below are pure-function helpers so a single mistake
/// (e.g. forgetting to gate a setState by signature mismatch) becomes a
/// test failure rather than a runtime "every rebuild re-subscribes" smell.
void main() {
  group('resolveTableOrdersStreamLifecycle — garson stream cache', () {
    test('first call with no cache → start a new subscription', () {
      final decision = resolveTableOrdersStreamLifecycle(
        requestedSellerId: 'seller-1',
        cachedSellerId: null,
      );
      expect(decision.action, TableOrdersStreamLifecycleAction.start);
      expect(decision.nextSellerKey, 'seller-1');
    });

    test('rebuild with same seller key → reuse the cached subscription', () {
      final decision = resolveTableOrdersStreamLifecycle(
        requestedSellerId: 'seller-1',
        cachedSellerId: 'seller-1',
      );
      expect(
        decision.action,
        TableOrdersStreamLifecycleAction.reuse,
        reason:
            'every build call MUST reuse the cached stream — opening a new '
            'realtime subscription per build is the bug we are guarding '
            'against',
      );
      expect(decision.nextSellerKey, 'seller-1');
    });

    test('seller switch → start a fresh subscription', () {
      final decision = resolveTableOrdersStreamLifecycle(
        requestedSellerId: 'seller-2',
        cachedSellerId: 'seller-1',
      );
      expect(decision.action, TableOrdersStreamLifecycleAction.start);
      expect(decision.nextSellerKey, 'seller-2');
    });

    test('10 successive build calls with the same seller all reuse', () {
      String? cachedKey;
      var startCount = 0;
      var reuseCount = 0;
      for (var i = 0; i < 10; i++) {
        final decision = resolveTableOrdersStreamLifecycle(
          requestedSellerId: 'seller-1',
          cachedSellerId: cachedKey,
        );
        if (decision.action == TableOrdersStreamLifecycleAction.start) {
          startCount += 1;
        } else {
          reuseCount += 1;
        }
        cachedKey = decision.nextSellerKey;
      }
      expect(
        startCount,
        1,
        reason: 'only the very first build call may open a new subscription',
      );
      expect(reuseCount, 9);
    });

    test('cached seller key is preserved across reuse decisions', () {
      final decision = resolveTableOrdersStreamLifecycle(
        requestedSellerId: 'seller-1',
        cachedSellerId: 'seller-1',
      );
      expect(decision.nextSellerKey, 'seller-1');
    });
  });

  group('shouldPublishProductsUpdate — products realtime loop guard', () {
    test('first publish (no previous signature) is always allowed', () {
      expect(
        shouldPublishProductsUpdate(
          previousSignature: null,
          previousCount: 0,
          nextSignature: '1#a|active|10.0000|5|-',
          nextCount: 1,
        ),
        isTrue,
      );
    });

    test('identical signature + identical count → suppress publish', () {
      expect(
        shouldPublishProductsUpdate(
          previousSignature: '1#a|active|10.0000|5|-',
          previousCount: 1,
          nextSignature: '1#a|active|10.0000|5|-',
          nextCount: 1,
        ),
        isFalse,
        reason:
            'realtime retry tick re-emits the same payload — publishing it '
            'rebuilds the panel for nothing',
      );
    });

    test('signature change → publish', () {
      expect(
        shouldPublishProductsUpdate(
          previousSignature: '1#a|active|10.0000|5|-',
          previousCount: 1,
          nextSignature: '1#a|active|11.0000|5|-',
          nextCount: 1,
        ),
        isTrue,
      );
    });

    test('count change with same signature → still publish (defensive)', () {
      // The signature already includes the count prefix, but the helper has
      // a defensive cross-check on `nextCount`. Verifying the cross-check
      // catches future signature regressions.
      expect(
        shouldPublishProductsUpdate(
          previousSignature: 'empty',
          previousCount: 0,
          nextSignature: 'empty',
          nextCount: 1,
        ),
        isTrue,
      );
    });

    test('repeated identical publishes never escape the loop guard', () {
      // Simulate the worst-case retry storm: 30 ticks with identical data.
      var publishCount = 0;
      const sig = '2#a|active|10.0000|5|-;b|active|20.0000|3|-';
      for (var i = 0; i < 30; i++) {
        final shouldPublish = shouldPublishProductsUpdate(
          previousSignature: sig,
          previousCount: 2,
          nextSignature: sig,
          nextCount: 2,
        );
        if (shouldPublish) publishCount += 1;
      }
      expect(
        publishCount,
        0,
        reason:
            '30 identical realtime retries must produce zero panel '
            'rebuilds — this is the heart of the fix',
      );
    });
  });

  group('module preservation across realtime fallback', () {
    // The two rules below combine to prevent products realtime from ever
    // navigating the user away from garson. They are tested individually
    // elsewhere (see seller_navigation_preservation_test.dart) but the
    // combination is the actual user-visible guarantee.

    test('products timeout fallback while user on garson — no dashboard '
        'refresh allowed', () {
      // Dashboard refresh must skip when the user is on garson. The
      // products fallback path used to call _refreshDashboardData
      // indirectly — this guard ensures it cannot.
      expect(
        shouldRunDashboardRefresh(selectedModule: SellerModule.garson),
        isFalse,
      );
    });

    test('products timeout fallback while user on garson — no async '
        'dashboard write allowed', () {
      // The realtime fallback is async and not user-initiated. If
      // anything in that branch tried to flip the module to dashboard,
      // the hard-block must reject it.
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.garson,
          next: SellerModule.dashboard,
          hasUserSelectedModule: true,
          isGarsonTableRouteOpen: false,
          userInitiated: false,
          parentRestore: false,
        ),
        isTrue,
      );
    });

    test('products timeout fallback while user is in a garson table route — '
        'route preservation hard-block holds', () {
      // Even if _selectedModule were somehow not garson at the moment
      // of the timeout (e.g. between a setState frame), the route-open
      // flag still pins navigation to garson.
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.dashboard,
          next: SellerModule.dashboard,
          hasUserSelectedModule: false,
          isGarsonTableRouteOpen: true,
          userInitiated: false,
          parentRestore: false,
        ),
        isTrue,
      );
    });

    test('products timeout fallback render decision: garson stays garson '
        'across 10 rebuilds', () {
      // The realtime fallback triggers a setState which re-runs build.
      // resolveSellerPanelRenderTarget must be deterministic on identical
      // inputs so the user never sees a transient dashboard frame.
      final results = <String>[];
      for (var i = 0; i < 10; i++) {
        results.add(
          resolveSellerPanelRenderTarget(
            selectedModule: SellerModule.garson,
            storeCategory: 'Yemek & İçecek',
            isWaiterEntry: false,
          ),
        );
      }
      expect(
        results,
        List<String>.filled(10, SellerPanelRenderTargets.garson),
        reason:
            '10 rebuilds during the realtime retry window must all '
            'render garson — even one dashboard frame is a regression',
      );
    });

    test('waiter entry guarantees garson render even on non-food store '
        '(profile not loaded yet edge case)', () {
      // While the seller profile is still loading the storeCategory
      // can be empty/null. The render decision must NOT silently fall
      // back to dashboard for waiter sessions.
      for (final category in <String?>[null, '', 'Giyim']) {
        expect(
          resolveSellerPanelRenderTarget(
            selectedModule: SellerModule.garson,
            storeCategory: category,
            isWaiterEntry: true,
          ),
          SellerPanelRenderTargets.garson,
        );
      }
    });
  });

  group('garson manual refresh policy', () {
    test('background update cannot clear visible board state', () {
      final current = GarsonBoardState(
        tables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 1},
        ],
        areas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahce'},
        ],
        orders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 1, 'status': 'new'},
        ],
        lastGoodTables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 1},
        ],
        lastGoodAreas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahce'},
        ],
        lastGoodOrders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 1, 'status': 'new'},
        ],
        hasEverLoadedTablesSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );

      final next = applyBackgroundUpdate(
        current: current,
        incomingTables: const <Map<String, dynamic>>[],
        incomingOrders: const <Map<String, dynamic>>[],
        source: 'table_orders_stream',
      );

      expect(next.uiTables, hasLength(1));
      expect(next.uiOrders, hasLength(1));
      expect(next.pendingTables, isEmpty);
      expect(next.pendingOrders, isEmpty);
      expect(next.hasPendingRemoteChanges, isTrue);
    });

    test('manual refresh with empty incoming keeps last good tables', () {
      final current = GarsonBoardState(
        tables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 11},
        ],
        areas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahce'},
        ],
        orders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 11, 'status': 'new'},
        ],
        lastGoodTables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 11},
        ],
        lastGoodAreas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahce'},
        ],
        lastGoodOrders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 11, 'status': 'new'},
        ],
        hasEverLoadedTablesSuccessfully: true,
        hasEverRenderedBoardSuccessfully: true,
        initialLoadStatus: GarsonInitialLoadStatus.loaded,
      );

      final next = applyManualRefresh(
        current: current,
        tables: const <Map<String, dynamic>>[],
        areas: const <Map<String, dynamic>>[],
        orders: const <Map<String, dynamic>>[],
        source: 'garson_manual_refresh_button',
      );

      expect(next.uiTables, hasLength(1));
      expect(next.lastGoodTables, hasLength(1));
      expect(next.hasEverRenderedBoardSuccessfully, isTrue);
    });

    test('initial bootstrap with tables seeds visible board state', () {
      final next = applyInitialBootstrap(
        current: const GarsonBoardState(),
        tables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 1},
          {'id': 'table-2', 'table_number': 2},
        ],
        areas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahce'},
        ],
        orders: const <Map<String, dynamic>>[],
        source: 'initial_bootstrap',
      );

      expect(next.tables, hasLength(2));
      expect(next.lastGoodTables, hasLength(2));
      expect(next.hasEverLoadedTablesSuccessfully, isTrue);
      expect(next.initialLoadStatus, GarsonInitialLoadStatus.loaded);
    });

    test('garson active + background products stream publish is blocked', () {
      expect(
        shouldBlockGarsonBackgroundPublish(
          selectedModule: SellerModule.garson,
          manualRefreshInProgress: false,
          hasPublishedData: true,
          source: 'products_stream',
        ),
        isTrue,
      );
    });

    test('garson active + products timeout fallback publish is blocked', () {
      expect(
        shouldBlockGarsonBackgroundPublish(
          selectedModule: SellerModule.garson,
          manualRefreshInProgress: false,
          hasPublishedData: true,
          source: 'products_stream_timeout',
        ),
        isTrue,
      );
    });

    test('garson active + table_orders stream publish is blocked', () {
      expect(
        shouldBlockGarsonBackgroundPublish(
          selectedModule: SellerModule.garson,
          manualRefreshInProgress: false,
          hasPublishedData: true,
          source: 'table_orders_stream',
        ),
        isTrue,
      );
    });

    test(
      'garson active + table_orders stream error fallback may publish',
      () {
        expect(
          shouldAutoApplyGarsonVisibleSnapshot(
            source: 'table_orders_stream_error',
          ),
          isTrue,
        );
        expect(
          shouldBlockGarsonBackgroundPublish(
            selectedModule: SellerModule.garson,
            manualRefreshInProgress: false,
            hasPublishedData: true,
            source: 'table_orders_stream_error',
          ),
          isFalse,
        );
      },
    );

    test('initial garson bootstrap sources are not blocked', () {
      for (final source in const <String>[
        'initial_bootstrap',
        'garson_initial_load',
        'garson_module_opened',
      ]) {
        expect(
          shouldBlockGarsonBackgroundPublish(
            selectedModule: SellerModule.garson,
            manualRefreshInProgress: false,
            hasPublishedData: false,
            source: source,
          ),
          isFalse,
          reason: 'source=$source must seed visible Garson state on restart',
        );
      }
    });

    test('manual refresh in progress bypasses block', () {
      expect(
        shouldBlockGarsonBackgroundPublish(
          selectedModule: SellerModule.garson,
          manualRefreshInProgress: true,
          hasPublishedData: true,
          source: 'garson_manual_refresh_button',
        ),
        isFalse,
      );
    });

    test('second manual refresh request is skipped while running', () {
      expect(shouldSkipManualGarsonRefresh(refreshInProgress: true), isTrue);
      expect(shouldSkipManualGarsonRefresh(refreshInProgress: false), isFalse);
    });

    test(
      'background refresh source is blocked but manual and initial seed are allowed',
      () {
        expect(
          shouldAllowGarsonManualRefresh(
            source: 'products_stream',
            allowInitialAutoSeed: false,
          ),
          isFalse,
        );
        expect(
          shouldAllowGarsonManualRefresh(
            source: 'garson_manual_refresh_button',
            allowInitialAutoSeed: false,
          ),
          isTrue,
        );
        expect(
          shouldAllowGarsonManualRefresh(
            source: 'garson_module_opened',
            allowInitialAutoSeed: true,
          ),
          isTrue,
        );
      },
    );

    test('incoming empty tables snapshot preserves visible garson grid', () {
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'table_orders_stream',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: false,
          hasIncomingOrders: false,
        ),
        isTrue,
      );
    });

    test('manual refresh empty orders snapshot may clear visible order', () {
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'mobile_pull_to_refresh',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: true,
          hasIncomingOrders: false,
        ),
        isFalse,
      );
    });

    test('local table action may clear visible order after close/payment', () {
      expect(
        shouldPreserveGarsonVisibleDataOnIncomingEmpty(
          source: 'garson_local_table_action',
          hasVisibleTables: true,
          hasVisibleOrders: true,
          hasIncomingTables: true,
          hasIncomingOrders: false,
        ),
        isFalse,
      );
    });

    test('garson initial visible seed only runs once while visible', () {
      expect(
        shouldRunGarsonInitialVisibleSeed(
          isGarsonVisible: true,
          initialVisibleSeedDone: false,
          initialLoading: false,
        ),
        isTrue,
      );
      expect(
        shouldRunGarsonInitialVisibleSeed(
          isGarsonVisible: false,
          initialVisibleSeedDone: false,
          initialLoading: false,
        ),
        isFalse,
      );
      expect(
        shouldRunGarsonInitialVisibleSeed(
          isGarsonVisible: true,
          initialVisibleSeedDone: true,
          initialLoading: false,
        ),
        isFalse,
      );
      expect(
        shouldRunGarsonInitialVisibleSeed(
          isGarsonVisible: true,
          initialVisibleSeedDone: false,
          initialLoading: true,
        ),
        isFalse,
      );
    });

    test(
      'garson initial bootstrap load runs only when cache is incomplete',
      () {
        expect(
          shouldRunGarsonInitialBootstrapLoad(
            hasStoreTables: false,
            hasProducts: true,
            hasPublishedOrders: true,
          ),
          isTrue,
        );
        expect(
          shouldRunGarsonInitialBootstrapLoad(
            hasStoreTables: true,
            hasProducts: false,
            hasPublishedOrders: true,
          ),
          isTrue,
        );
        expect(
          shouldRunGarsonInitialBootstrapLoad(
            hasStoreTables: true,
            hasProducts: true,
            hasPublishedOrders: false,
          ),
          isTrue,
        );
        expect(
          shouldRunGarsonInitialBootstrapLoad(
            hasStoreTables: true,
            hasProducts: true,
            hasPublishedOrders: true,
          ),
          isFalse,
        );
      },
    );

    test(
      'cached data while waiting does not show infinite initial spinner',
      () {
        expect(
          shouldShowGarsonInitialLoading(
            initialLoading: true,
            initialVisibleSeedDone: false,
            visibleOrderCount: 0,
            storeTableCount: 0,
          ),
          isTrue,
        );
        expect(
          shouldShowGarsonInitialLoading(
            initialLoading: true,
            initialVisibleSeedDone: false,
            visibleOrderCount: 1,
            storeTableCount: 0,
          ),
          isFalse,
        );
        expect(
          shouldShowGarsonInitialLoading(
            initialLoading: false,
            initialVisibleSeedDone: false,
            visibleOrderCount: 0,
            storeTableCount: 0,
          ),
          isFalse,
        );
        expect(
          shouldShowGarsonInitialLoading(
            initialLoading: true,
            initialVisibleSeedDone: true,
            visibleOrderCount: 0,
            storeTableCount: 0,
          ),
          isFalse,
        );
      },
    );

    test(
      'table orders signature is stable across ordering but detects change',
      () {
        final first = tableOrdersListSignature(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': '2',
            'table_number': 7,
            'status': 'new',
            'updated_at': '2026-05-26T10:00:00Z',
            'items': const <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'id': '1',
            'table_number': 5,
            'status': 'sent',
            'updated_at': '2026-05-26T09:00:00Z',
            'items': const <Map<String, dynamic>>[],
          },
        ]);
        final reordered = tableOrdersListSignature(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'table_number': 5,
            'status': 'sent',
            'updated_at': '2026-05-26T09:00:00Z',
            'items': const <Map<String, dynamic>>[],
          },
          <String, dynamic>{
            'id': '2',
            'table_number': 7,
            'status': 'new',
            'updated_at': '2026-05-26T10:00:00Z',
            'items': const <Map<String, dynamic>>[],
          },
        ]);
        final changed = tableOrdersListSignature(<Map<String, dynamic>>[
          <String, dynamic>{
            'id': '1',
            'table_number': 5,
            'status': 'done',
            'updated_at': '2026-05-26T09:00:00Z',
            'items': const <Map<String, dynamic>>[],
          },
        ]);
        expect(first, reordered);
        expect(changed, isNot(first));
      },
    );

    test('ui state falls back to last good tables and orders', () {
      final state = buildGarsonUiState(
        visibleTables: const <Map<String, dynamic>>[],
        visibleAreas: const <Map<String, dynamic>>[],
        visibleOrders: const <Map<String, dynamic>>[],
        lastGoodTables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 1},
          {'id': 'table-2', 'table_number': 2},
        ],
        lastGoodAreas: const <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahçe'},
        ],
        lastGoodOrders: const <Map<String, dynamic>>[
          {'id': 'order-1', 'table_number': 1},
        ],
        pendingIncomingTables: const <Map<String, dynamic>>[],
        pendingIncomingAreas: const <Map<String, dynamic>>[],
        pendingIncomingOrders: const <Map<String, dynamic>>[],
        hasPendingRemoteChanges: true,
        hasEverLoadedTablesSuccessfully: true,
        hasEverLoadedOrdersSuccessfully: true,
        lastAppliedSource: 'initial_bootstrap_success',
      );

      expect(state.uiTables, hasLength(2));
      expect(state.uiAreas, hasLength(1));
      expect(state.uiOrders, hasLength(1));
      expect(state.uiTablesSource, 'last_good');
      expect(state.uiOrdersSource, 'last_good');
      expect(
        shouldShowGarsonEmptyStateFromUiState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: true,
          initialBootstrapFailed: false,
        ),
        isFalse,
      );
    });

    test('empty state only shows before any successful table bootstrap', () {
      final state = buildGarsonUiState(
        visibleTables: const <Map<String, dynamic>>[],
        visibleAreas: const <Map<String, dynamic>>[],
        visibleOrders: const <Map<String, dynamic>>[],
        lastGoodTables: const <Map<String, dynamic>>[],
        lastGoodAreas: const <Map<String, dynamic>>[],
        lastGoodOrders: const <Map<String, dynamic>>[],
        pendingIncomingTables: const <Map<String, dynamic>>[],
        pendingIncomingAreas: const <Map<String, dynamic>>[],
        pendingIncomingOrders: const <Map<String, dynamic>>[],
        hasPendingRemoteChanges: false,
        hasEverLoadedTablesSuccessfully: false,
        hasEverLoadedOrdersSuccessfully: false,
        lastAppliedSource: 'none',
      );

      expect(
        shouldShowGarsonEmptyStateFromUiState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: true,
          initialBootstrapFailed: false,
        ),
        isTrue,
      );
      expect(
        shouldShowGarsonEmptyStateFromUiState(
          state: state,
          initialLoading: true,
          initialBootstrapFinished: false,
          initialBootstrapFailed: false,
        ),
        isFalse,
      );
    });

    test('pending chip stays hidden before first successful tables load', () {
      final state = buildGarsonUiState(
        visibleTables: const <Map<String, dynamic>>[],
        visibleAreas: const <Map<String, dynamic>>[],
        visibleOrders: const <Map<String, dynamic>>[],
        lastGoodTables: const <Map<String, dynamic>>[],
        lastGoodAreas: const <Map<String, dynamic>>[],
        lastGoodOrders: const <Map<String, dynamic>>[],
        pendingIncomingTables: const <Map<String, dynamic>>[
          {'id': 'table-1', 'table_number': 1},
        ],
        pendingIncomingAreas: const <Map<String, dynamic>>[],
        pendingIncomingOrders: const <Map<String, dynamic>>[],
        hasPendingRemoteChanges: true,
        hasEverLoadedTablesSuccessfully: false,
        hasEverLoadedOrdersSuccessfully: false,
        lastAppliedSource: 'none',
      );

      expect(shouldShowGarsonPendingChangesChip(state: state), isFalse);
      expect(
        resolveGarsonGridLoadState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: false,
          initialBootstrapFailed: false,
        ),
        GarsonGridLoadState.pendingChangesAvailable,
      );
    });

    test('bootstrap success with zero tables becomes loaded_no_tables', () {
      final state = buildGarsonUiState(
        visibleTables: const <Map<String, dynamic>>[],
        visibleAreas: const <Map<String, dynamic>>[],
        visibleOrders: const <Map<String, dynamic>>[],
        lastGoodTables: const <Map<String, dynamic>>[],
        lastGoodAreas: const <Map<String, dynamic>>[],
        lastGoodOrders: const <Map<String, dynamic>>[],
        pendingIncomingTables: const <Map<String, dynamic>>[],
        pendingIncomingAreas: const <Map<String, dynamic>>[],
        pendingIncomingOrders: const <Map<String, dynamic>>[],
        hasPendingRemoteChanges: false,
        hasEverLoadedTablesSuccessfully: false,
        hasEverLoadedOrdersSuccessfully: true,
        lastAppliedSource: 'garson_initial_load',
      );

      expect(
        resolveGarsonGridLoadState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: true,
          initialBootstrapFailed: false,
        ),
        GarsonGridLoadState.loadedNoTables,
      );
    });

    test('bootstrap failure becomes load_failed instead of empty', () {
      final state = buildGarsonUiState(
        visibleTables: const <Map<String, dynamic>>[],
        visibleAreas: const <Map<String, dynamic>>[],
        visibleOrders: const <Map<String, dynamic>>[],
        lastGoodTables: const <Map<String, dynamic>>[],
        lastGoodAreas: const <Map<String, dynamic>>[],
        lastGoodOrders: const <Map<String, dynamic>>[],
        pendingIncomingTables: const <Map<String, dynamic>>[],
        pendingIncomingAreas: const <Map<String, dynamic>>[],
        pendingIncomingOrders: const <Map<String, dynamic>>[],
        hasPendingRemoteChanges: false,
        hasEverLoadedTablesSuccessfully: false,
        hasEverLoadedOrdersSuccessfully: false,
        lastAppliedSource: 'none',
      );

      expect(
        resolveGarsonGridLoadState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: true,
          initialBootstrapFailed: true,
        ),
        GarsonGridLoadState.loadFailed,
      );
      expect(
        shouldShowGarsonEmptyStateFromUiState(
          state: state,
          initialLoading: false,
          initialBootstrapFinished: true,
          initialBootstrapFailed: true,
        ),
        isFalse,
      );
    });

    test(
      'board state empty rule only trips before a successful table load',
      () {
        final failed = const GarsonBoardState(
          initialLoadStatus: GarsonInitialLoadStatus.failed,
        );
        expect(shouldShowEmptyState(state: failed), isTrue);

        final loadedBefore = const GarsonBoardState(
          lastGoodTables: <Map<String, dynamic>>[
            {'id': 'table-1', 'table_number': 1},
          ],
          hasEverLoadedTablesSuccessfully: true,
          initialLoadStatus: GarsonInitialLoadStatus.loaded,
        );
        expect(shouldShowEmptyState(state: loadedBefore), isFalse);
      },
    );
  });

  group('shouldBlockGarsonBackgroundPublish', () {
    test('submit and local table mutation sources are never blocked', () {
      for (final source in const <String>[
        'garson_order_submit',
        'garson_table_route_popped',
        'garson_local_table_action',
      ]) {
        expect(
          shouldBlockGarsonBackgroundPublish(
            selectedModule: SellerModule.garson,
            manualRefreshInProgress: false,
            hasPublishedData: true,
            source: source,
          ),
          isFalse,
          reason:
              'source=$source must publish immediately so the Garson grid '
              'reflects a freshly submitted order when the table flow closes',
        );
      }
    });
  });

  group('shouldClearGarsonCatalogAsNonFood — first-open category race', () {
    test('profile not loaded yet → NEVER clear (category unknown)', () {
      // The exact regression: on first garson open the profile is still
      // loading and `_storeCategory == ''`, so isSellerFoodStoreCategory('')
      // is false. Clearing here wrongly shows "Henüz tanımlı masa yok" and
      // feeds the bootstrap-retry auto-refresh loop.
      expect(
        shouldClearGarsonCatalogAsNonFood(
          hasLoadedProfile: false,
          isFoodCategory: false,
        ),
        isFalse,
        reason: 'category is simply not known yet — must keep/fetch catalog',
      );
    });

    test('profile loaded + genuinely non-food → clear', () {
      expect(
        shouldClearGarsonCatalogAsNonFood(
          hasLoadedProfile: true,
          isFoodCategory: false,
        ),
        isTrue,
      );
    });

    test('profile loaded + food store → keep catalog', () {
      expect(
        shouldClearGarsonCatalogAsNonFood(
          hasLoadedProfile: true,
          isFoodCategory: true,
        ),
        isFalse,
      );
    });

    test('food category is always safe even before profile resolves', () {
      expect(
        shouldClearGarsonCatalogAsNonFood(
          hasLoadedProfile: false,
          isFoodCategory: true,
        ),
        isFalse,
      );
    });
  });
}
