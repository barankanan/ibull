import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/garson_operation_rules.dart';
import 'package:ibul_app/services/customer_table_proximity.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/restaurant_offline/print_evidence.dart';
import 'package:ibul_app/services/waiter_submit_identity.dart';
import 'package:ibul_app/widgets/restaurant_offline_banner.dart';

void main() {
  test('per-person total is a view, not a payment permission', () {
    expect(
      TableLevelPolicy.canShowPerPersonTotal(
        orderStatuses: const ['sent'],
        canViewBill: true,
      ),
      isTrue,
    );
    expect(
      TableLevelPolicy.canShowPerPersonTotal(
        orderStatuses: const ['sent'],
        canViewBill: false,
      ),
      isFalse,
    );
    expect(
      TableLevelPolicy.canShowPerPersonTotal(
        orderStatuses: const ['closed'],
        canViewBill: true,
      ),
      isFalse,
    );
  });

  test('saved order label stays distinct from a finished print', () {
    expect(
      garsonSubmitSavedLabel(
        isUpdate: false,
        physicallyDispatched: false,
        printFailed: false,
      ),
      'Kuyruğa alındı',
    );
    expect(
      garsonSubmitSavedLabel(
        isUpdate: false,
        physicallyDispatched: true,
        printFailed: false,
      ),
      'Yazıcıya iletildi',
    );
    expect(
      garsonSubmitSavedLabel(
        isUpdate: false,
        physicallyDispatched: false,
        printFailed: true,
      ),
      'Baskı başarısız, sipariş kayıtlı',
    );
    expect(
      garsonSubmitSavedLabel(
        isUpdate: true,
        physicallyDispatched: false,
        printFailed: false,
      ),
      'Sipariş kaydedildi',
    );
  });

  test('timeout copy does not offer a second order', () {
    expect(
      OrderPrintJobService.orderCommitUnverifiedMessage,
      'Sipariş sonucu doğrulanamadı',
    );
    expect(
      OrderPrintJobService.commitRecoveryAction(
        localOrderId: 'waiter-1',
        found: true,
        alreadyRetried: false,
      ),
      'recovered',
    );
    expect(
      OrderPrintJobService.commitRecoveryAction(
        localOrderId: 'waiter-1',
        found: false,
        alreadyRetried: false,
      ),
      'retry_same_key',
    );
    expect(
      OrderPrintJobService.commitRecoveryAction(
        localOrderId: 'waiter-1',
        found: false,
        alreadyRetried: true,
      ),
      'unverified',
    );
    expect(
      OrderPrintJobService.commitRecoveryAction(
        localOrderId: '',
        found: false,
        alreadyRetried: false,
      ),
      'unverified',
    );
    expect(
      OrderPrintJobService.commitFailureIsUnreachable(
        Exception('SocketException: Failed host lookup'),
      ),
      isTrue,
    );
    expect(OrderPrintJobService.commitLookupPolls, greaterThan(1));
    expect(
      OrderPrintJobService.pendingPrintJobIdsForDispatch(
        printJobIds: const <String>['new-job', 'done-job'],
        statusById: const <String, String>{
          'new-job': 'pending',
          'done-job': 'completed',
        },
        idempotentReplay: true,
      ),
      <String>['new-job'],
    );
    expect(
      OrderPrintJobService.pendingPrintJobIdsForDispatch(
        printJobIds: const <String>['done-job'],
        statusById: const <String, String>{'done-job': 'completed'},
        idempotentReplay: false,
      ),
      <String>['done-job'],
    );
  });

  test('the live order RPC uses p_local_order_id, not p_idempotency_key', () {
    final params = createTableOrderRpcParams(
      restaurantId: 'restaurant-1',
      tableNumber: 11,
      items: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'quantity': 1, 'price': 40},
      ],
      localOrderId: 'waiter-11',
    );
    expect(params['p_local_order_id'], 'waiter-11');
    expect(params.containsKey('p_idempotency_key'), isFalse);
    expect(params.containsKey('p_local_print_evidence'), isFalse);
    expect(params.keys, hasLength(9));
  });

  test('restart keeps the waiter send key', () async {
    final memory = <String, String>{};
    const scope = 'seller:4';
    await WaiterSubmitIdentityStore(memory: memory).save(
      scope,
      const WaiterSubmitIdentity(key: 'waiter-9', payload: 'same-cart'),
    );
    final restored = await WaiterSubmitIdentityStore(memory: memory).read(scope);
    expect(restored?.key, 'waiter-9');
    expect(restored?.payload, 'same-cart');
  });

  test('per person amounts keep the kuruş remainder visible', () {
    final four = BillShare.fromAmount(1200, 4);
    expect(four.eachAmount, 300);
    expect(four.extraPeople, 0);
    final three = BillShare.fromAmount(10, 3);
    expect(three.eachCents, 333);
    expect(three.extraPeople, 1);
    final seven = BillShare.fromAmount(1200, 7);
    expect(seven.eachCents, 17142);
    expect(seven.extraPeople, 6);
    expect(seven.eachCents * 7 + seven.extraPeople, seven.totalCents);
    for (final people in [2, 3, 4, 5, 7]) {
      final share = BillShare.fromAmount(1200, people);
      expect(share.eachCents * people + share.extraPeople, share.totalCents);
    }
  });

  test('print delay marks do not treat a missing device ack as printed', () {
    final saved = DateTime.utc(2026, 11, 3, 12);
    final queued = saved.add(const Duration(milliseconds: 40));
    final marks = PrintPathDelayMarks(
      orderSavedAt: saved,
      printJobCreatedAt: queued,
      rpcSentAt: saved,
      rpcReceivedAt: queued.add(const Duration(milliseconds: 20)),
    );
    expect(marks.deviceConfirmed, isFalse);
    expect(
      marks.millisecondsBetween(marks.orderSavedAt, marks.printJobCreatedAt),
      40,
    );
  });

  test('an unverified send keeps its identity', () async {
    final store = WaiterSubmitIdentityStore(memory: <String, String>{});
    const scope = 'seller:4';
    await store.save(
      scope,
      const WaiterSubmitIdentity(key: 'waiter-7', payload: 'same'),
    );
    final again = await store.read(scope);
    expect(again?.key, 'waiter-7');
    expect(again?.payload, 'same');
    await store.clear(scope);
    expect(await store.read(scope), isNull);
  });

  test('customer fix is refused without a precise location', () {
    expect(
      CustomerTableProximity.rejection(
        latitude: null,
        longitude: null,
        accuracyMeters: null,
      ),
      contains('doğrulanamadı'),
    );
    expect(
      CustomerTableProximity.rejection(
        latitude: 41,
        longitude: 29,
        accuracyMeters: 80,
      ),
      contains('doğruluğu yetersiz'),
    );
    expect(
      CustomerTableProximity.rejection(
        latitude: 41.01,
        longitude: 28.97,
        accuracyMeters: 12,
      ),
      isNull,
    );
  });

  test('waiter status does not claim a local server that is down', () {
    expect(
      waiterConnectionLabel(
        internet: false,
        localServerListening: false,
        printerReady: true,
        pendingSync: 0,
      ),
      'Yerel sipariş merkezi kullanılamıyor',
    );
    expect(
      waiterConnectionLabel(
        internet: true,
        localServerListening: false,
        printerReady: true,
        pendingSync: 0,
      ),
      'Çevrimiçi',
    );
    expect(
      waiterConnectionLabel(
        internet: true,
        localServerListening: false,
        printerReady: true,
        pendingSync: 2,
      ),
      'Senkronize ediliyor...',
    );
    expect(
      waiterConnectionLabel(
        internet: false,
        localServerListening: true,
        printerReady: false,
        pendingSync: 0,
      ),
      'Çevrimdışı — Yerel sistem aktif',
    );
  });
}
