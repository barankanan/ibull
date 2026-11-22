import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/print_station_service.dart';
import 'package:ibul_app/services/printer_link_status.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _restaurant = '10000000-0000-0000-0000-000000000001';

/// One fake world: a Supabase that answers the order RPC as [rpc] says, and a
/// bridge that only records what it is asked to print. [events] keeps the
/// order in which the two were reached.
class _World {
  _World({required this.rpc});

  final Future<http.Response> Function(http.Request request, int call) rpc;
  final events = <String>[];
  final prints = <Map<String, dynamic>>[];
  var rpcCalls = 0;

  late final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    httpClient: MockClient((request) async {
      if (request.url.path.endsWith('/rpc/create_table_order_with_print_jobs')) {
        rpcCalls += 1;
        events.add('rpc');
        return rpc(request, rpcCalls);
      }
      return http.Response('[]', 200,
          headers: {'content-type': 'application/json'}, request: request);
    }),
  );

  http.Client bridge() => MockClient((request) async {
    if (request.url.path == '/print/kitchen') {
      events.add('print');
      prints.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
    }
    return http.Response(jsonEncode({'ok': true, 'bytes_sent': 10}), 200,
        headers: {'content-type': 'application/json'}, request: request);
  });

  OrderPrintJobService service() => OrderPrintJobService(
    client: client,
    printerRepository: PrinterRepository(client: client),
    printOrchestrator: DesktopPrintOrchestrator(
      printerRepository: PrinterRepository(client: client),
      printStationService: PrintStationService(client: client),
    ),
  );
}

http.Response _json(Object body, int status, http.Request request) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'}, request: request);

Future<http.Response> _saved(http.Request request, String orderId) async =>
    _json({
      'order_id': orderId,
      'print_job_ids': <String>[],
      'order_saved_at': '2026-11-17T18:00:00Z',
    }, 200, request);

Future<http.Response> _refused(http.Request request) async => _json(
  {'code': '42501', 'message': 'Bu restoran için işlem yetkiniz yok.'},
  403,
  request,
);

const _items = [
  {'product_id': 'p1', 'name': 'Adana', 'quantity': 1, 'price': 100},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    try {
      await Supabase.initialize(
        url: 'https://example.supabase.co',
        anonKey: 'test-key',
      );
    } catch (_) {}
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    PhysicalPrintGate.observe(true);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    OrderPrintJobService.debugLanPrintHttpClientFactory = null;
  });

  Future<Object?> send(
    _World world, {
    required String localOrderId,
    String tableName = 'Bahçe 1',
    int tableNumber = 11,
    bool staff = false,
  }) async {
    OrderPrintJobService.debugLanPrintHttpClientFactory = world.bridge;
    try {
      await world.service().dispatchNewOrder(
        restaurantId: _restaurant,
        tableNumber: tableNumber,
        tableName: tableName,
        items: _items,
        localOrderId: localOrderId,
        skipOfflineFallback: true,
        printAfterCommit: staff,
      );
      return null;
    } catch (error) {
      return error;
    }
  }

  test('owner order refused with 403 prints nothing', () async {
    final world = _World(rpc: (request, _) => _refused(request));
    final error = await send(world, localOrderId: 'o-403');
    expect(error, isNotNull);
    expect(world.prints, isEmpty);
  });

  test('staff order refused with 403 prints nothing', () async {
    final world = _World(rpc: (request, _) => _refused(request));
    final error = await send(world, localOrderId: 's-403', staff: true);
    expect(error, isNotNull);
    expect(world.prints, isEmpty);
  });

  test('a saved order prints once, and only after the save', () async {
    final world = _World(rpc: (request, _) => _saved(request, 'order-1'));
    final error = await send(world, localOrderId: 'ok-1');
    expect(error, isNull);
    expect(world.rpcCalls, 1);
    expect(world.prints, hasLength(1));
    expect(world.events, ['rpc', 'print']);
  });

  test('a lost connection saves nothing, prints nothing, reports failure', () async {
    final world = _World(
      rpc: (request, _) async => throw http.ClientException('Connection closed'),
    );
    final error = await send(world, localOrderId: 'net-1');
    expect(error, isNotNull);
    expect(world.prints, isEmpty);
  });

  test('the same request sent twice carries one print identity', () async {
    final world = _World(rpc: (request, _) => _saved(request, 'order-7'));
    await send(world, localOrderId: 'retry-7');
    await send(world, localOrderId: 'retry-7');
    expect(world.prints, hasLength(2));
    // The bridge suppresses the second by this key.
    expect(
      world.prints[0]['logical_print_key'],
      world.prints[1]['logical_print_key'],
    );
  });

  test('two real orders on one table with the same products get two tickets', () async {
    final world = _World(
      rpc: (request, call) => _saved(request, 'order-$call'),
    );
    await send(world, localOrderId: 'first');
    await send(world, localOrderId: 'second');
    expect(world.prints, hasLength(2));
    expect(
      world.prints[0]['logical_print_key'],
      isNot(world.prints[1]['logical_print_key']),
    );
  });

  test('the ticket header is the chosen table, not the internal number', () async {
    for (final table in const [
      ('Bahçe 1', 11),
      ('Bahçe 4', 10),
      ('Salon 1', 1),
    ]) {
      final world = _World(rpc: (request, _) => _saved(request, 'o-${table.$2}'));
      await send(
        world,
        localOrderId: 'label-${table.$2}',
        tableName: table.$1,
        tableNumber: table.$2,
      );
      expect(world.prints.single['table_name'], table.$1);
      expect(world.prints.single['display_table_label'], table.$1);
    }
  });

  test('two waiters sending at once keep their own tables', () async {
    final world = _World(
      rpc: (request, call) async {
        // The first answer arrives last.
        if (call == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 60));
        }
        final body = jsonDecode(request.body) as Map;
        return _saved(request, 'order-${body['p_table_number']}');
      },
    );
    await Future.wait([
      send(world, localOrderId: 'w1', tableName: 'Bahçe 1', tableNumber: 11),
      send(world, localOrderId: 'w2', tableName: 'Salon 1', tableNumber: 1),
    ]);
    expect(world.prints, hasLength(2));
    for (final ticket in world.prints) {
      final expected = ticket['table_number'].toString() == '11'
          ? 'Bahçe 1'
          : 'Salon 1';
      expect(ticket['table_name'], expected);
    }
  });
}
