import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/models/seller_product.dart';

SellerProduct _mkProduct({
  required String id,
  double price = 10,
  int stock = 1,
  String status = 'active',
  double? discountPrice,
  String name = 'Test',
}) {
  return SellerProduct(
    id: id,
    name: name,
    brand: 'b',
    mainCategory: 'm',
    subCategory: 's',
    price: price,
    stock: stock,
    sku: 'sku-$id',
    status: status,
    createdAt: DateTime.utc(2026, 5, 25),
    discountPrice: discountPrice,
  );
}

void main() {
  group('seller panel lifecycle log helpers', () {
    test('route-name helper can run before didChangeDependencies', () {
      expect(sellerPanelLifecycleRouteNameForLog(null), '-');
      expect(sellerPanelLifecycleRouteNameForLog(''), '-');
      expect(sellerPanelLifecycleRouteNameForLog(' /seller '), '/seller');
    });

    test('lifecycle log builder does not require context', () {
      final line = buildSellerPanelLifecycleLogLine(
        phase: 'initState',
        instanceId: 'instance-1',
        widgetKey: 'widget-key',
        oldWidgetKey: '-',
        newWidgetKey: 'widget-key',
        initialModule: 'garson',
        oldInitialModule: '-',
        newInitialModule: 'garson',
        selectedModule: 'garson',
        controllerModule: 'garson',
        hasUserSelected: true,
        routeName: sellerPanelLifecycleRouteNameForLog(null),
        ownerKey: 'seller-1',
      );
      expect(line, contains('[SELLER_PANEL_LIFECYCLE][initState]'));
      expect(line, contains('route=-'));
      expect(line, contains('selectedModule=garson'));
    });

    test('dispose lifecycle log can use cached route fallback', () {
      final line = buildSellerPanelLifecycleLogLine(
        phase: 'dispose',
        instanceId: 'instance-2',
        widgetKey: 'widget-key',
        oldWidgetKey: '-',
        newWidgetKey: '-',
        initialModule: 'products',
        oldInitialModule: '-',
        newInitialModule: 'products',
        selectedModule: 'products',
        controllerModule: 'products',
        hasUserSelected: true,
        routeName: sellerPanelLifecycleRouteNameForLog(null),
        ownerKey: 'seller-2',
      );
      expect(line, contains('[SELLER_PANEL_LIFECYCLE][dispose]'));
      expect(line, contains('route=-'));
    });
  });

  group('resolveSellerModuleAfterProfileReload', () {
    test('background profile reload keeps products module on food store', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.products,
          storeCategory: 'Yemek & İçecek',
          garsonOnly: false,
        ),
        SellerModule.products,
      );
    });

    test('background profile reload keeps garson on food store', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.garson,
          storeCategory: 'Restoran',
          garsonOnly: false,
        ),
        SellerModule.garson,
      );
    });

    test('non-food store still keeps garson', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.garson,
          storeCategory: 'Giyim',
          garsonOnly: false,
        ),
        SellerModule.garson,
      );
    });

    test('non-food store still keeps system', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.system,
          storeCategory: 'Giyim',
          garsonOnly: false,
        ),
        SellerModule.system,
      );
    });

    test('waiter entry always garson', () {
      expect(
        resolveSellerModuleAfterProfileReload(
          currentModule: SellerModule.products,
          storeCategory: 'Giyim',
          garsonOnly: true,
        ),
        SellerModule.garson,
      );
    });
  });

  group('evaluateSellerNavigationWrite — user-lock + parent restore', () {
    test('first user tap unlocks and applies', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.dashboard,
        next: SellerModule.garson,
        hasUserSelectedModule: false,
        userInitiated: true,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.apply);
      expect(decision.nextHasUserSelectedModule, isTrue);
    });

    test('async profile reload BLOCKED after user has chosen garson', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.garson,
        next: SellerModule.dashboard,
        hasUserSelectedModule: true,
        userInitiated: false,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.blocked);
      expect(
        decision.nextHasUserSelectedModule,
        isTrue,
        reason: 'blocking must not clear the user-selected lock',
      );
    });

    test('async dashboard refresh BLOCKED after user has chosen garson', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.garson,
        next: SellerModule.dashboard,
        hasUserSelectedModule: true,
        userInitiated: false,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.blocked);
    });

    test('async path cannot move system to dashboard after user selection', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.system,
        next: SellerModule.dashboard,
        hasUserSelectedModule: true,
        userInitiated: false,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.blocked);
    });

    test(
      'async path cannot move products to dashboard after user selection',
      () {
        final decision = evaluateSellerNavigationWrite(
          current: SellerModule.products,
          next: SellerModule.dashboard,
          hasUserSelectedModule: true,
          userInitiated: false,
          parentRestore: false,
        );
        expect(decision.action, SellerNavigationWriteAction.blocked);
      },
    );

    test(
      'parent restore (garson table route pop) APPLIES even when locked',
      () {
        final decision = evaluateSellerNavigationWrite(
          current: SellerModule.dashboard,
          next: SellerModule.garson,
          hasUserSelectedModule: true,
          userInitiated: false,
          parentRestore: true,
        );
        expect(decision.action, SellerNavigationWriteAction.apply);
        expect(decision.nextHasUserSelectedModule, isTrue);
      },
    );

    test(
      'parent restore (garson table route pop) APPLIES even when unlocked',
      () {
        final decision = evaluateSellerNavigationWrite(
          current: SellerModule.dashboard,
          next: SellerModule.garson,
          hasUserSelectedModule: false,
          userInitiated: false,
          parentRestore: true,
        );
        expect(decision.action, SellerNavigationWriteAction.apply);
        expect(
          decision.nextHasUserSelectedModule,
          isFalse,
          reason:
              'parent restore is system-driven and must NOT promote the user '
              'lock — the user did not explicitly choose a module here',
        );
      },
    );

    test('first-time async write (no user selection yet) is allowed', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.garson,
        next: SellerModule.dashboard,
        hasUserSelectedModule: false,
        userInitiated: false,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.apply);
      expect(decision.nextHasUserSelectedModule, isFalse);
    });

    test('write to same module is a noop and preserves lock', () {
      final decision = evaluateSellerNavigationWrite(
        current: SellerModule.garson,
        next: SellerModule.garson,
        hasUserSelectedModule: true,
        userInitiated: true,
        parentRestore: false,
      );
      expect(decision.action, SellerNavigationWriteAction.noop);
      expect(decision.nextHasUserSelectedModule, isTrue);
    });

    test(
      'user tap on the same module still keeps the lock as true (idempotent)',
      () {
        final decision = evaluateSellerNavigationWrite(
          current: SellerModule.dashboard,
          next: SellerModule.dashboard,
          hasUserSelectedModule: false,
          userInitiated: true,
          parentRestore: false,
        );
        expect(decision.action, SellerNavigationWriteAction.noop);
        // Even though the action is noop, the user tap is observable intent
        // and must promote the lock so that subsequent async writes cannot
        // change the module.
        expect(decision.nextHasUserSelectedModule, isTrue);
      },
    );
  });

  group('shouldHardBlockGarsonDashboardWrite — garson hard-block', () {
    test('blocks async dashboard write when current=garson', () {
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.garson,
          next: SellerModule.dashboard,
          hasUserSelectedModule: false,
          isGarsonTableRouteOpen: false,
          userInitiated: false,
          parentRestore: false,
        ),
        isTrue,
      );
    });

    test('blocks async dashboard write when garson table route open', () {
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

    test('blocks async dashboard write when user has selected a module', () {
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.products,
          next: SellerModule.dashboard,
          hasUserSelectedModule: true,
          isGarsonTableRouteOpen: false,
          userInitiated: false,
          parentRestore: false,
        ),
        isTrue,
      );
    });

    test('userInitiated=true is NEVER blocked', () {
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.garson,
          next: SellerModule.dashboard,
          hasUserSelectedModule: true,
          isGarsonTableRouteOpen: true,
          userInitiated: true,
          parentRestore: false,
        ),
        isFalse,
      );
    });

    test('parentRestore=true is NEVER blocked', () {
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.garson,
          next: SellerModule.dashboard,
          hasUserSelectedModule: true,
          isGarsonTableRouteOpen: true,
          userInitiated: false,
          parentRestore: true,
        ),
        isFalse,
      );
    });

    test('non-dashboard target is NOT subject to the hard-block', () {
      expect(
        shouldHardBlockGarsonDashboardWrite(
          current: SellerModule.garson,
          next: SellerModule.orders,
          hasUserSelectedModule: true,
          isGarsonTableRouteOpen: false,
          userInitiated: false,
          parentRestore: false,
        ),
        isFalse,
      );
    });

    test(
      'cold start (no user lock, not on garson, no route) is NOT blocked',
      () {
        expect(
          shouldHardBlockGarsonDashboardWrite(
            current: SellerModule.dashboard,
            next: SellerModule.dashboard,
            hasUserSelectedModule: false,
            isGarsonTableRouteOpen: false,
            userInitiated: false,
            parentRestore: false,
          ),
          isFalse,
          reason:
              'an initial async write to dashboard before the user has '
              'chosen anything must still be allowed (e.g. profile reload '
              'restoring last-selected module after a hot reload)',
        );
      },
    );

    test(
      'user lock on garson + async tries to switch to dashboard: BLOCKED',
      () {
        // This is the exact bug scenario from the user report: user is on
        // garson, lock is set, async profile load tries to send them to
        // dashboard. Must be blocked.
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
      },
    );
  });

  group('resolveSellerPanelRenderTarget — build-time hard rule', () {
    test('garson selected + food store → renders garson', () {
      expect(
        resolveSellerPanelRenderTarget(
          selectedModule: SellerModule.garson,
          storeCategory: 'Yemek & İçecek',
          isWaiterEntry: false,
        ),
        SellerPanelRenderTargets.garson,
      );
    });

    test('garson selected + non-food store → placeholder, NEVER dashboard', () {
      final target = resolveSellerPanelRenderTarget(
        selectedModule: SellerModule.garson,
        storeCategory: 'Giyim',
        isWaiterEntry: false,
      );
      expect(target, SellerPanelRenderTargets.garsonPlaceholder);
      expect(
        target,
        isNot(SellerPanelRenderTargets.dashboard),
        reason: 'silent dashboard fallback is the bug this rule prevents',
      );
    });

    test('garson selected + empty category → placeholder, NEVER dashboard', () {
      final target = resolveSellerPanelRenderTarget(
        selectedModule: SellerModule.garson,
        storeCategory: '',
        isWaiterEntry: false,
      );
      expect(target, SellerPanelRenderTargets.garsonPlaceholder);
      expect(target, isNot(SellerPanelRenderTargets.dashboard));
    });

    test('garson selected + null category → placeholder, NEVER dashboard', () {
      final target = resolveSellerPanelRenderTarget(
        selectedModule: SellerModule.garson,
        storeCategory: null,
        isWaiterEntry: false,
      );
      expect(target, SellerPanelRenderTargets.garsonPlaceholder);
      expect(target, isNot(SellerPanelRenderTargets.dashboard));
    });

    test('garson selected + waiter entry always renders garson', () {
      expect(
        resolveSellerPanelRenderTarget(
          selectedModule: SellerModule.garson,
          storeCategory: 'Giyim',
          isWaiterEntry: true,
        ),
        SellerPanelRenderTargets.garson,
      );
    });

    test('system selected + non-food store → placeholder, NEVER dashboard', () {
      final target = resolveSellerPanelRenderTarget(
        selectedModule: SellerModule.system,
        storeCategory: 'Giyim',
        isWaiterEntry: false,
      );
      expect(target, SellerPanelRenderTargets.systemPlaceholder);
      expect(target, isNot(SellerPanelRenderTargets.dashboard));
    });

    test('dashboard selected → dashboard render', () {
      expect(
        resolveSellerPanelRenderTarget(
          selectedModule: SellerModule.dashboard,
          storeCategory: 'Yemek',
          isWaiterEntry: false,
        ),
        SellerPanelRenderTargets.dashboard,
      );
    });

    test('other modules pass through with their own name', () {
      for (final module in <SellerModule>[
        SellerModule.products,
        SellerModule.collections,
        SellerModule.orders,
        SellerModule.store,
        SellerModule.team,
        SellerModule.campaigns,
        SellerModule.finance,
        SellerModule.reviews,
        SellerModule.support,
      ]) {
        expect(
          resolveSellerPanelRenderTarget(
            selectedModule: module,
            storeCategory: 'Yemek',
            isWaiterEntry: false,
          ),
          module.name,
          reason: '$module should render its own module, not dashboard',
        );
      }
    });
  });

  group('shouldRunDashboardRefresh — dashboard refresh visibility gate', () {
    test('runs only when dashboard is selected', () {
      expect(
        shouldRunDashboardRefresh(selectedModule: SellerModule.dashboard),
        isTrue,
      );
    });

    test('skipped when garson is selected', () {
      expect(
        shouldRunDashboardRefresh(selectedModule: SellerModule.garson),
        isFalse,
      );
    });

    test('skipped for every non-dashboard module', () {
      for (final module in <SellerModule>[
        SellerModule.products,
        SellerModule.collections,
        SellerModule.orders,
        SellerModule.garson,
        SellerModule.system,
        SellerModule.store,
        SellerModule.team,
        SellerModule.campaigns,
        SellerModule.finance,
        SellerModule.reviews,
        SellerModule.support,
      ]) {
        expect(
          shouldRunDashboardRefresh(selectedModule: module),
          isFalse,
          reason:
              'dashboard refresh must not run while user is on $module — '
              'the symptom is "Genel Bakış sayıları sürekli gidip geliyor"',
        );
      }
    });
  });

  group('sellerProductsListSignature — products refresh loop guard', () {
    test('identical lists produce identical signatures', () {
      final a = <SellerProduct>[
        _mkProduct(id: 'p1', price: 12, stock: 5),
        _mkProduct(id: 'p2', price: 25, stock: 9),
      ];
      final b = <SellerProduct>[
        // same data, different list order
        _mkProduct(id: 'p2', price: 25, stock: 9),
        _mkProduct(id: 'p1', price: 12, stock: 5),
      ];
      expect(
        sellerProductsListSignature(a),
        sellerProductsListSignature(b),
        reason:
            'list order must NOT change the signature — sort guarantees '
            'the realtime retry loop will not invalidate the dashboard '
            'snapshot when the order of incoming rows differs',
      );
    });

    test('price change invalidates the signature', () {
      final a = <SellerProduct>[_mkProduct(id: 'p1', price: 12)];
      final b = <SellerProduct>[_mkProduct(id: 'p1', price: 13)];
      expect(
        sellerProductsListSignature(a),
        isNot(sellerProductsListSignature(b)),
      );
    });

    test('stock change invalidates the signature', () {
      final a = <SellerProduct>[_mkProduct(id: 'p1', stock: 5)];
      final b = <SellerProduct>[_mkProduct(id: 'p1', stock: 7)];
      expect(
        sellerProductsListSignature(a),
        isNot(sellerProductsListSignature(b)),
      );
    });

    test('status change invalidates the signature', () {
      final a = <SellerProduct>[_mkProduct(id: 'p1', status: 'active')];
      final b = <SellerProduct>[_mkProduct(id: 'p1', status: 'archived')];
      expect(
        sellerProductsListSignature(a),
        isNot(sellerProductsListSignature(b)),
      );
    });

    test('discount price change invalidates the signature', () {
      final a = <SellerProduct>[_mkProduct(id: 'p1')];
      final b = <SellerProduct>[_mkProduct(id: 'p1', discountPrice: 9.99)];
      expect(
        sellerProductsListSignature(a),
        isNot(sellerProductsListSignature(b)),
      );
    });

    test('cosmetic name edit does NOT invalidate the signature', () {
      // Renaming a product (or editing its description) must NOT bust the
      // dashboard snapshot cache — dashboard summaries do not depend on
      // those fields.
      final a = <SellerProduct>[_mkProduct(id: 'p1', name: 'A')];
      final b = <SellerProduct>[_mkProduct(id: 'p1', name: 'B')];
      expect(sellerProductsListSignature(a), sellerProductsListSignature(b));
    });

    test('adding a product invalidates the signature', () {
      final a = <SellerProduct>[_mkProduct(id: 'p1')];
      final b = <SellerProduct>[_mkProduct(id: 'p1'), _mkProduct(id: 'p2')];
      expect(
        sellerProductsListSignature(a),
        isNot(sellerProductsListSignature(b)),
      );
    });

    test('empty list yields a stable signature distinct from non-empty', () {
      expect(sellerProductsListSignature(const []), 'empty');
      expect(
        sellerProductsListSignature(const []),
        isNot(
          sellerProductsListSignature(<SellerProduct>[_mkProduct(id: 'p1')]),
        ),
      );
    });
  });

  group('tableOrdersDashboardSignature — dashboard refresh loop guard', () {
    test('identical orders produce identical signatures', () {
      final a = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'updated_at': '2026-05-25T10:00:00Z',
          'total_price': 120.5,
        },
        {
          'id': 'o-2',
          'status': 'sent',
          'updated_at': '2026-05-25T10:05:00Z',
          'total_price': 80.0,
        },
      ];
      final b = <Map<String, dynamic>>[
        // Same data, different list order — signature must be stable.
        Map<String, dynamic>.from(a[1]),
        Map<String, dynamic>.from(a[0]),
      ];
      expect(
        tableOrdersDashboardSignature(a),
        tableOrdersDashboardSignature(b),
      );
    });

    test('status change invalidates the signature', () {
      final a = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'open', 'updated_at': 't', 'total_price': 1},
      ];
      final b = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'closed', 'updated_at': 't', 'total_price': 1},
      ];
      expect(
        tableOrdersDashboardSignature(a),
        isNot(tableOrdersDashboardSignature(b)),
      );
    });

    test('adding an order invalidates the signature', () {
      final a = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'open'},
      ];
      final b = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'open'},
        {'id': 'o-2', 'status': 'open'},
      ];
      expect(
        tableOrdersDashboardSignature(a),
        isNot(tableOrdersDashboardSignature(b)),
      );
    });

    test('empty snapshot has a stable signature distinct from non-empty', () {
      expect(tableOrdersDashboardSignature(const []), 'empty');
      expect(
        tableOrdersDashboardSignature(const []),
        isNot(
          tableOrdersDashboardSignature(<Map<String, dynamic>>[
            {'id': 'o-1', 'status': 'open'},
          ]),
        ),
      );
    });

    test('total_amount change invalidates the signature', () {
      final a = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'open', 'total_amount': 50.0},
      ];
      final b = <Map<String, dynamic>>[
        {'id': 'o-1', 'status': 'open', 'total_amount': 75.5},
      ];
      expect(
        tableOrdersDashboardSignature(a),
        isNot(tableOrdersDashboardSignature(b)),
      );
    });

    test('item count change invalidates the signature', () {
      final a = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'items': [
            {'name': 'Burger'},
          ],
        },
      ];
      final b = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'items': [
            {'name': 'Burger'},
            {'name': 'Cola'},
          ],
        },
      ];
      expect(
        tableOrdersDashboardSignature(a),
        isNot(tableOrdersDashboardSignature(b)),
      );
    });

    test('table_id / table_name change invalidates the signature', () {
      final a = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'table_id': 't-1',
          'table_name': 'Salon 1 - Masa 1',
        },
      ];
      final b = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'table_id': 't-2',
          'table_name': 'Salon 2 - Masa 4',
        },
      ];
      expect(
        tableOrdersDashboardSignature(a),
        isNot(tableOrdersDashboardSignature(b)),
      );
    });

    test('non-summary fields do NOT invalidate the signature', () {
      // Some background field like `printer_id` or `notes` changing must NOT
      // be treated as a dashboard data change — otherwise unrelated edits
      // would trigger the refresh storm we're guarding against.
      final a = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'table_id': 't-1',
          'total_price': 99,
          'printer_id': 'p-1',
          'notes': 'old note',
        },
      ];
      final b = <Map<String, dynamic>>[
        {
          'id': 'o-1',
          'status': 'open',
          'table_id': 't-1',
          'total_price': 99,
          'printer_id': 'p-99',
          'notes': 'new note',
        },
      ];
      expect(
        tableOrdersDashboardSignature(a),
        tableOrdersDashboardSignature(b),
      );
    });
  });
}
