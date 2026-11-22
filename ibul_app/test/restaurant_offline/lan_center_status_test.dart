import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_center_status.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/features/seller/panel/widgets/offline_page_widgets.dart';
import 'package:ibul_app/widgets/lan_center_status_card.dart';

RestaurantLocalOrderRecord _order(
  String id,
  int table,
  RestaurantLocalOrderSyncStatus sync,
  double total,
) => RestaurantLocalOrderRecord(
  localOrderId: id,
  restaurantId: 'r1',
  tableId: 't$table',
  tableName: 'Masa $table',
  tableNumber: table,
  waiterId: 'w',
  waiterName: 'W',
  items: const <Map<String, dynamic>>[],
  notes: '',
  total: total,
  stationGroups: const <Map<String, dynamic>>[],
  printStatus: 'pending',
  syncStatus: sync,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

RestaurantLocalPrintJobRecord _job(
  String id,
  String orderId,
  RestaurantLocalPrintJobStatus status,
) => RestaurantLocalPrintJobRecord(
  localJobId: id,
  restaurantId: 'r1',
  localOrderId: orderId,
  tableId: 't',
  tableName: 'Masa',
  documentType: 'kitchen',
  role: 'mutfak',
  station: 's1',
  printerSnapshot: const <String, dynamic>{},
  payloadSnapshot: const <String, dynamic>{},
  status: status,
  attempts: 0,
  createdAt: DateTime(2026),
);

void main() {
  final orders = <RestaurantLocalOrderRecord>[
    _order('o1', 1, RestaurantLocalOrderSyncStatus.pendingSync, 100),
    _order('o2', 1, RestaurantLocalOrderSyncStatus.syncFailed, 50),
    _order('o3', 2, RestaurantLocalOrderSyncStatus.conflict, 10),
    _order('o4', 3, RestaurantLocalOrderSyncStatus.synced, 999),
    _order('o5', 9, RestaurantLocalOrderSyncStatus.pendingSync, 5),
  ];
  final tables = <Map<String, dynamic>>[
    <String, dynamic>{'table_number': 1},
    <String, dynamic>{'table_number': 2},
    <String, dynamic>{'table_number': 3},
  ];

  Future<Map<String, dynamic>> build({
    Uri? bridge,
    bool limited = false,
    List<RestaurantLocalPrintJobRecord>? jobs,
    bool probeResult = true,
  }) => buildLanCenterStatus(
    machineId: 'mac-1',
    printBridgeUri: bridge,
    tables: tables,
    printers: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'p1',
        'name': 'Mutfak',
        'connection_type': 'ethernet',
        'ip_address': '192.168.1.50',
        'port': 9100,
        'api_key': 'SECRET',
      },
    ],
    stations: <Map<String, dynamic>>[
      <String, dynamic>{'id': 's1', 'name': 'Ocak'},
      <String, dynamic>{'id': 's2', 'name': 'Bar'},
    ],
    stationPrinters: <Map<String, dynamic>>[
      <String, dynamic>{'station_id': 's1', 'printer_id': 'p1'},
    ],
    orders: orders,
    printJobs: jobs,
    branchLimited: limited,
    probe: (_) async => probeResult,
    now: DateTime.utc(2026, 1, 2),
  );

  test('counts sync, overview and stations without secrets or revenue', () async {
    final out = await build(bridge: Uri.parse('http://127.0.0.1:3001'));
    expect((out['print_center'] as Map)['reachable'], isTrue);
    expect(out['sync'], <String, dynamic>{
      'pending': 2,
      'failed': 1,
      'conflict': 1,
      'synced': 1,
    });
    final overview = out['overview'] as Map;
    expect(overview['tables_total'], 3);
    expect(overview['tables_with_local_orders'], 2);
    expect(overview['local_orders'], 4);
    expect(overview['local_provisional_total'], 165.0);
    final stations = out['stations'] as List;
    expect((stations[0] as Map)['printer'], 'Mutfak');
    expect((stations[1] as Map)['printer'], isNull);
    expect((stations[1] as Map).containsKey('printer'), isTrue);
    final printer = (out['printers'] as List).single as Map;
    expect(printer['host'], '192.168.1.50');
    expect(out.toString(), isNot(contains('SECRET')));
    expect(out.containsKey('revenue'), isFalse);
    expect(out['generated_at'], '2026-01-02T00:00:00.000Z');
    expect(out['machine_id'], 'mac-1');
  });

  test('missing bridge or silent bridge is not reachable; no queue is zeros', () async {
    final none = await build();
    expect((none['print_center'] as Map)['available'], isFalse);
    expect((none['print_center'] as Map)['reachable'], isFalse);
    final silent = await build(
      bridge: Uri.parse('http://127.0.0.1:3001'),
      probeResult: false,
    );
    expect((silent['print_center'] as Map)['reachable'], isFalse);
    final jobs = none['print_jobs'] as Map;
    expect(jobs['available'], isFalse);
    expect(jobs['queued'], 0);
    expect(jobs['failed'], 0);
  });

  test('print job counts and branch limit', () async {
    final out = await build(
      limited: true,
      jobs: <RestaurantLocalPrintJobRecord>[
        _job('j1', 'o1', RestaurantLocalPrintJobStatus.queued),
        _job('j2', 'o2', RestaurantLocalPrintJobStatus.failed),
        _job('j3', 'o3', RestaurantLocalPrintJobStatus.uncertain),
        _job('j4', 'o4', RestaurantLocalPrintJobStatus.printed),
        _job('j5', 'o5', RestaurantLocalPrintJobStatus.failed),
      ],
    );
    final jobs = out['print_jobs'] as Map;
    expect(jobs['queued'], 1);
    expect(jobs['failed'], 1);
    expect(jobs['uncertain'], 1);
    expect(jobs['printed'], 1);
    // o5 is on table 9, outside this member's branch.
    expect((out['overview'] as Map)['local_orders'], 3);
    expect((out['sync'] as Map)['pending'], 1);
  });

  testWidgets('card at 360 px: loaded and unreachable, no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = await build(bridge: Uri.parse('http://127.0.0.1:3001'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LanCenterStatusCard(fetch: () async => data),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana bilgisayar · Yazıcı Merkezi'), findsOneWidget);
    expect(find.text('açık'), findsOneWidget);
    expect(find.text('Ocak → Mutfak'), findsOneWidget);
    expect(find.text('Bar → yazıcı eşleşmedi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LanCenterStatusCard(
              key: const ValueKey('second'),
              fetch: () async {
                calls++;
                throw StateError('yok');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lan_center_unreachable')), findsOneWidget);
    expect(find.textContaining('kapalı'), findsNothing);
    await tester.tap(find.byKey(const Key('lan_center_retry')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline overview labels the center as source', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final data = await build(bridge: Uri.parse('http://127.0.0.1:3001'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineOverviewLoader(
            restaurantId: 'r1',
            centerStatus: () async => data,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ana bilgisayardan'), findsWidgets);
    expect(find.text('Toplam masa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
