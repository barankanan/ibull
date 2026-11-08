import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_send_access.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';
import 'package:ibul_app/utils/table_labels.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

void main() {
  test('the same action keeps one key until it succeeds', () {
    final ledger = OrderSendKeyLedger();
    const fingerprint = 'rest|4|new_order|soup';
    final first = resolveOrderSendKey(ledger: ledger, fingerprint: fingerprint);
    final retry = resolveOrderSendKey(ledger: ledger, fingerprint: fingerprint);
    expect(retry, first);
    ledger.complete(fingerprint);
    final nextOrder = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: fingerprint,
    );
    expect(nextOrder, isNot(first));
  });

  test('a restarted ledger keeps the original key', () async {
    final saved = <String, String>{};
    final first = OrderSendKeyLedger();
    first.sink = (keys) async {
      saved
        ..clear()
        ..addAll(keys);
    };
    final key = resolveOrderSendKey(
      ledger: first,
      fingerprint: 'action',
      requestedKey: 'send-stable',
    );
    await first.flush();

    final restarted = OrderSendKeyLedger(restored: saved);
    expect(
      resolveOrderSendKey(
        ledger: restarted,
        fingerprint: 'action',
        requestedKey: 'send-after-restart',
      ),
      key,
    );
    restarted.complete('action');
    expect(
      resolveOrderSendKey(ledger: restarted, fingerprint: 'action'),
      isNot(key),
    );
  });

  test('a requested key is reused for the same action', () {
    final ledger = OrderSendKeyLedger();
    final key = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: 'action',
      requestedKey: 'send-stable',
    );
    expect(resolveOrderSendKey(ledger: ledger, fingerprint: 'action'), key);
  });

  test('missing idempotent RPC is a hard stop', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: 'PGRST202',
        message:
            'Could not find the function public.send_table_order_idempotent in the schema cache',
      ),
      contains('Gönderim durduruldu'),
    );
  });

  test('same key with a different order is reported', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: 'P0001',
        message: 'Bu işlem kimliği farklı bir siparişle kullanılmış.',
      ),
      contains('başka bir siparişle kullanılmış'),
    );
  });

  test('idempotency key is sent only when present', () {
    final withKey = buildCreateTableOrderRpcParams(
      restaurantId: 'rest',
      tableNumber: 4,
      items: const [
        {'name': 'Çorba'},
      ],
      notes: 'trace note',
      idempotencyKey: 'send-1',
    );
    expect(withKey['p_local_order_id'], 'send-1');
    expect(withKey.containsKey('p_idempotency_key'), isFalse);
    expect(withKey['p_order_type'], 'table');
    expect(withKey.keys, hasLength(9));

    final withoutKey = buildCreateTableOrderRpcParams(
      restaurantId: 'rest',
      tableNumber: 4,
      items: const [
        {'name': 'Çorba'},
      ],
      idempotencyKey: '   ',
    );
    expect(withoutKey.containsKey('p_local_order_id'), isFalse);
    expect(withoutKey.containsKey('p_idempotency_key'), isFalse);
  });

  test('a timed out save does not start a second insert', () async {
    var sends = 0;
    final hung = Completer<Map<String, dynamic>>();
    await expectLater(
      recoverOrderSaveAfterTimeout(
        timeout: const Duration(milliseconds: 20),
        pollAttempts: 2,
        pollInterval: Duration.zero,
        send: () {
          sends += 1;
          return hung.future;
        },
        lookup: () async => null,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Aynı gönderim anahtarı duruyor'),
        ),
      ),
    );
    expect(sends, 1);
  });

  test(
    'a timed out save returns the committed order without another insert',
    () async {
      var sends = 0;
      var lookups = 0;
      final result = await recoverOrderSaveAfterTimeout(
        timeout: const Duration(milliseconds: 20),
        pollAttempts: 3,
        pollInterval: Duration.zero,
        send: () {
          sends += 1;
          return Completer<Map<String, dynamic>>().future;
        },
        lookup: () async {
          lookups += 1;
          if (lookups < 2) return null;
          return <String, dynamic>{
            'order_id': 'committed',
            'idempotent_replay': true,
          };
        },
      );
      expect(sends, 1);
      expect(lookups, 2);
      expect(result, isA<Map<String, dynamic>>());
      expect((result as Map<String, dynamic>)['order_id'], 'committed');
    },
  );

  test('a completed save does not look the order up again', () async {
    var lookups = 0;
    final result = await recoverOrderSaveAfterTimeout(
      send: () async => <String, dynamic>{'order_id': 'fresh'},
      lookup: () async {
        lookups += 1;
        return <String, dynamic>{'order_id': 'other'};
      },
    );
    expect(lookups, 0);
    expect((result as Map<String, dynamic>)['order_id'], 'fresh');
  });

  test('replay prints only a pending ticket', () {
    const ids = <String>['pending-job', 'done-job', 'unknown-job'];
    expect(
      printJobIdsSafeForReplay(
        printJobIds: ids,
        statusById: const <String, String>{
          'pending-job': 'pending',
          'done-job': 'completed',
          'unknown-job': 'printing',
        },
        replay: true,
      ),
      <String>['pending-job'],
    );
    expect(
      printJobIdsSafeForReplay(
        printJobIds: ids,
        statusById: const <String, String>{'done-job': 'completed'},
        replay: false,
      ),
      ids,
    );
  });

  test('Bahçe 1 does not take Salon 1, another seller, or history', () {
    final bahce = <String, dynamic>{
      'id': 'bahce',
      'seller_id': 'seller-a',
      'table_number': 11,
      'area_name': 'Bahçe',
      'area_table_number': 1,
      'display_label': 'Bahçe 1',
    };
    final salon = <String, dynamic>{
      'id': 'salon',
      'seller_id': 'seller-a',
      'table_number': 1,
      'area_name': 'Salon',
      'area_table_number': 1,
      'display_label': 'Salon 1',
    };
    final bahceBill = <String, dynamic>{
      'id': 'open-bahce',
      'seller_id': 'seller-a',
      'table_number': 1,
      'area_name': 'Bahçe',
      'area_table_number': 1,
      'display_table_label': 'Bahçe 1',
      'status': 'sent',
      '_garson_source_table': 'table_orders',
      '_stored_table_number': 1,
      'total': 2490,
    };
    final salonBill = <String, dynamic>{
      'id': 'open-salon',
      'seller_id': 'seller-a',
      'table_number': 1,
      'area_name': 'Salon',
      'area_table_number': 1,
      'status': 'sent',
    };
    final otherSeller = <String, dynamic>{
      ...bahceBill,
      'id': 'other',
      'seller_id': 'seller-b',
    };
    final history = <String, dynamic>{
      ...bahceBill,
      'id': 'history',
      'status': 'closed',
    };

    final rows = garsonRowsForTableClose(
      table: bahce,
      canonicalTableNumber: 11,
      sellerId: 'seller-a',
      candidates: <Map<String, dynamic>>[
        bahceBill,
        salonBill,
        otherSeller,
        history,
      ],
    );
    expect(rows.map((row) => row['id']), ['open-bahce']);
    expect(
      garsonOrderBelongsToCloseTable(
        table: salon,
        canonicalTableNumber: 1,
        order: bahceBill,
        sellerId: 'seller-a',
      ),
      isFalse,
    );
    expect(
      garsonTableOrderNeedsRealign(
        order: bahceBill,
        table: bahce,
        canonicalTableNumber: 11,
        sellerId: 'seller-a',
      ),
      isTrue,
    );
    expect(
      garsonTableOrderNeedsRealign(
        order: salonBill,
        table: salon,
        canonicalTableNumber: 1,
        sellerId: 'seller-a',
      ),
      isFalse,
    );

    final visible = dropCachedBillsMissingFromOpenSnapshot(
      visibleOrders: <Map<String, dynamic>>[
        bahceBill,
        <String, dynamic>{'id': 'draft', 'status': 'draft', 'total': 2490},
      ],
      serverRead: const GarsonOpenOrderRead(
        orders: <Map<String, dynamic>>[],
        succeeded: true,
        complete: true,
      ),
    );
    expect(visible.map((row) => row['id']), ['draft']);
  });

  test('missing area, old visit and another seller do not move a table', () {
    final bahce = <String, dynamic>{
      'id': 'bahce',
      'seller_id': 'seller-a',
      'table_number': 11,
      'area_name': 'Bahçe',
      'area_table_number': 1,
      'display_label': 'Bahçe 1',
    };
    final numberOnly = <String, dynamic>{
      'id': 'number-only',
      'seller_id': 'seller-a',
      'table_number': 1,
      'status': 'sent',
      '_garson_source_table': 'table_orders',
    };
    final partialArea = <String, dynamic>{
      'id': 'partial',
      'seller_id': 'seller-a',
      'table_number': 1,
      'area_name': 'Bahçe',
      'status': 'sent',
      'display_table_label': 'Bahçe 1',
      '_garson_source_table': 'table_orders',
    };
    final salonIdOnBahceLabel = <String, dynamic>{
      'id': 'salon-id',
      'seller_id': 'seller-a',
      'table_id': 'salon',
      'table_number': 1,
      'area_name': 'Bahçe',
      'area_table_number': 1,
      'display_table_label': 'Bahçe 1',
      'status': 'sent',
      '_garson_source_table': 'table_orders',
    };
    final oldVisit = <String, dynamic>{
      'id': 'old',
      'seller_id': 'seller-a',
      'table_number': 11,
      'status': 'closed',
      '_garson_source_table': 'table_order_history',
    };
    final otherSeller = <String, dynamic>{
      'id': 'other-shop',
      'seller_id': 'seller-b',
      'table_id': 'bahce',
      'table_number': 1,
      'area_name': 'Bahçe',
      'area_table_number': 1,
      'display_table_label': 'Bahçe 1',
      'status': 'sent',
      '_garson_source_table': 'table_orders',
    };
    for (final order in [numberOnly, partialArea, salonIdOnBahceLabel, oldVisit, otherSeller]) {
      expect(
        garsonOrderBelongsToCloseTable(
          table: bahce,
          canonicalTableNumber: 11,
          order: order,
          sellerId: 'seller-a',
        ),
        isFalse,
        reason: order['id'].toString(),
      );
      expect(
        garsonTableOrderNeedsRealign(
          order: order,
          table: bahce,
          canonicalTableNumber: 11,
          sellerId: 'seller-a',
        ),
        isFalse,
        reason: order['id'].toString(),
      );
    }
    final cached = dropCachedBillsMissingFromOpenSnapshot(
      visibleOrders: <Map<String, dynamic>>[numberOnly],
      serverRead: const GarsonOpenOrderRead(
        orders: <Map<String, dynamic>>[],
        succeeded: true,
        complete: false,
      ),
    );
    expect(cached, hasLength(1));
    expect(
      dropCachedBillsMissingFromOpenSnapshot(
        visibleOrders: <Map<String, dynamic>>[numberOnly],
        serverRead: const GarsonOpenOrderRead(
          orders: <Map<String, dynamic>>[],
          succeeded: false,
          complete: true,
        ),
      ),
      hasLength(1),
    );
  });

  test('one pending job has a single winner and an uncertain print is not reprinted', () {
    final job = <String, String>{'status': 'pending'};
    final first = claimPendingJob(job);
    final second = claimPendingJob(job);
    expect(first, PrintClaimResult.won);
    expect(second, PrintClaimResult.lost);
    expect(job['status'], 'claimed');
    expect(
      interpretPrintClaim(requestFailed: true, updatedRowCount: 1),
      PrintClaimResult.uncertain,
    );
    expect(
      shouldAutomaticallyRequeuePrint(
        claim: PrintClaimResult.won,
        dispatch: classifyPrintDispatchFailure('TimeoutException: timed out'),
      ),
      isFalse,
    );
    expect(
      shouldAutomaticallyRequeuePrint(
        claim: PrintClaimResult.lost,
        dispatch: PrintDispatchVerdict.notSent,
      ),
      isFalse,
    );
    expect(
      shouldAutomaticallyRequeuePrint(
        claim: PrintClaimResult.won,
        dispatch: classifyPrintDispatchFailure('SocketException: Connection refused'),
      ),
      isTrue,
    );
  });

  test('print anchor is terminal and is not a cancellation', () {
    expect(OrderStatusConstants.isTerminalStatus('print_anchor'), isTrue);
    expect(OrderStatusConstants.isCancelledStatus('print_anchor'), isFalse);
    expect(isGarsonActiveOrderStatus('print_anchor'), isFalse);
  });

  test('view-only order send names the required grant', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42501',
        message: 'Bu restoran için sipariş gönderme yetkiniz yok.',
      ),
      'Sipariş gönderilemedi. Bu işlem için Siparişleri Yönet veya Tam Erişim yetkisi gerekir.',
    );
  });

  test('older restaurant permission error keeps the print guidance', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42501',
        message: 'Bu restoran için işlem yetkiniz yok.',
      ),
      contains('email veya telefon eşleşmesi gerekli'),
    );
  });

  test('orders schema mismatch stays specific', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42703',
        message: 'column "table_number" of relation "orders" does not exist',
      ),
      contains('create_table_order_with_print_jobs_impl'),
    );
  });

  test('v_item alias failure stays specific', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '42P01',
        message: 'missing FROM-clause entry for table "v_item"',
      ),
      contains('v_item'),
    );
  });

  test('unrelated database text is returned unchanged', () {
    expect(
      friendlyOrderSendRpcMessage(
        code: '22023',
        message: 'Sipariş kalemleri boş olamaz.',
      ),
      'Sipariş kalemleri boş olamaz.',
    );
  });

  test('Bahçe 1 uses canonical 11 and Salon 1 stays 1', () {
    final tables = <Map<String, dynamic>>[
      {'table_number': 1, 'display_label': 'Salon 1', 'area_name': 'Salon'},
      {
        'table_number': 11,
        'display_label': 'Bahçe 1',
        'area_name': 'Bahçe',
        'area_table_number': 1,
      },
    ];
    expect(
      canonicalStoreTableNumber(
        requestedNumber: 1,
        displayLabel: 'Bahçe 1',
        tables: tables,
      ),
      11,
    );
    expect(
      canonicalStoreTableNumber(
        requestedNumber: 11,
        displayLabel: 'Bahçe 1',
        tables: tables,
      ),
      11,
    );
    expect(
      canonicalStoreTableNumber(
        requestedNumber: 1,
        displayLabel: 'Salon 1',
        tables: tables,
      ),
      1,
    );
  });

  test('a filtered short read is complete and a capped or failed read is not', () {
    expect(
      openOrderReadIsComplete(
        tableFetchFailed: false,
        restaurantFetchFailed: false,
        openTableOrders: 0,
        openCustomerOrders: 10,
      ),
      isTrue,
    );
    expect(
      openOrderReadIsComplete(
        tableFetchFailed: false,
        restaurantFetchFailed: false,
        openTableOrders: 0,
        openCustomerOrders: 200,
      ),
      isFalse,
    );
    expect(
      openOrderReadIsComplete(
        tableFetchFailed: true,
        restaurantFetchFailed: false,
        openTableOrders: 0,
        openCustomerOrders: 0,
      ),
      isFalse,
    );
    expect(
      openOrderReadIsComplete(
        tableFetchFailed: false,
        restaurantFetchFailed: false,
        openTableOrders: null,
        openCustomerOrders: 0,
      ),
      isFalse,
    );
  });

  test('a different cart does not reuse another send key', () {
    final ledger = OrderSendKeyLedger();
    final first = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: 'bahce|11|salad-1',
    );
    final changed = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: 'bahce|11|salad-3',
    );
    expect(changed, isNot(first));
    final retry = resolveOrderSendKey(
      ledger: ledger,
      fingerprint: 'bahce|11|salad-1',
    );
    expect(retry, first);
  });
}
