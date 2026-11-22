import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_station_printer.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_printer_dispatch_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

RestaurantLocalPrintJobRecord _job(
  String id,
  Map<String, dynamic> printer,
) {
  return RestaurantLocalPrintJobRecord(
    localJobId: id,
    restaurantId: 'rest-route',
    localOrderId: 'order-1',
    tableId: '27',
    tableName: 'Masa 27',
    documentType: 'kitchen',
    role: 'mutfak',
    station: 'ocak',
    printerSnapshot: printer,
    payloadSnapshot: <String, dynamic>{
      'revision': '1',
      'job_type': 'new_order',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çay', 'quantity': 1, 'station_id': 'ocak'},
      ],
    },
    status: RestaurantLocalPrintJobStatus.queued,
    attempts: 0,
    createdAt: DateTime.utc(2026, 11, 22),
  );
}

const _saved = <String, dynamic>{
  'printer_id': 'p-1',
  'printer_name': 'Mutfak',
  'transport_type': 'ethernet',
  'target_host': '192.168.10.100',
  'target_port': 9100,
  'host': '192.168.10.100',
  'port': 9100,
  'station_id': 'baska-istasyon',
  'role': 'mutfak',
  'document_type': 'kitchen',
};

void main() {
  late HttpServer bridge;
  late List<Map<String, dynamic>> printed;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    printed = <Map<String, dynamic>>[];
    bridge = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    bridge.listen((request) async {
      final text = await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path == '/health') {
        request.response.write(jsonEncode(<String, Object?>{
          'ok': true,
          'service': 'ibul-local-print-bridge',
        }));
      } else {
        printed.add(jsonDecode(text) as Map<String, dynamic>);
        request.response.write(jsonEncode(<String, Object?>{'ok': true}));
      }
      await request.response.close();
    });
  });

  tearDown(() => bridge.close(force: true));

  Uri base() => Uri.parse('http://127.0.0.1:${bridge.port}');

  test('the ticket carries the saved station printer target', () async {
    final queue = RestaurantLocalPrintQueueService();
    final job = await queue.enqueue(job: _job('job-routed', _saved));
    final done = await queue.deliverToBridge(job: job, bridgeBase: base());

    expect(done.status, RestaurantLocalPrintJobStatus.forwarded);
    expect(printed, hasLength(1));
    expect(printed.single['target_host'], '192.168.10.100');
    expect(printed.single['target_port'], 9100);
    expect(printed.single['transport_type'], 'ethernet');
    // The job's own station and identity are never replaced by the snapshot.
    expect(printed.single['station_id'], 'ocak');
    expect(printed.single['idempotency_key'], 'job-routed');
    expect(printed.single.containsKey('role'), isFalse);
  });

  test('a station without a printer sends nothing and fails for certain', () async {
    final queue = RestaurantLocalPrintQueueService();
    final job = await queue.enqueue(
      job: _job('job-unrouted', const <String, dynamic>{
        'resolution_error': 'Bu istasyon için yazıcı seçilmemiş.',
      }),
    );
    final done = await queue.deliverToBridge(job: job, bridgeBase: base());

    expect(done.status, RestaurantLocalPrintJobStatus.failed);
    expect(done.lastError, 'Bu istasyon için yazıcı seçilmemiş.');
    expect(printed, isEmpty);
  });

  test('a snapshot that names no transport leaves the bridge default', () async {
    expect(
      lanPrinterTargetFields(const <String, dynamic>{
        'id': 'x',
        'name': 'x',
        'backend': 'offline_cache',
      }),
      isEmpty,
    );
    final queue = RestaurantLocalPrintQueueService();
    final job = await queue.enqueue(
      job: _job('job-default', const <String, dynamic>{}),
    );
    await queue.deliverToBridge(job: job, bridgeBase: base());
    expect(printed.single.containsKey('target_host'), isFalse);
  });

  test('resolved printer is reused briefly, a failure is asked again', () async {
    var calls = 0;
    var ok = false;
    var now = DateTime.utc(2026, 11, 22, 12);
    final resolve = lanStationPrinterResolver(
      restaurantId: 'rest-route',
      clock: () => now,
      resolve: (station) async {
        calls++;
        return ok
            ? RestaurantPrinterDispatchResolution(
                ok: true,
                resolutionSource: 'station_mapping',
                printerSnapshot: <String, dynamic>{..._saved},
              )
            : RestaurantPrinterDispatchResolver.failure(
                resolutionSource: 'failed',
                errorMessage: 'Yazıcı yok.',
              );
      },
    );

    expect((await resolve('ocak'))['resolution_error'], 'Yazıcı yok.');
    ok = true;
    final first = await resolve('ocak');
    expect(first['target_host'], '192.168.10.100');
    expect(first['resolution_source'], 'station_mapping');
    await resolve('ocak');
    expect(calls, 2);
    now = now.add(const Duration(seconds: 31));
    await resolve('ocak');
    expect(calls, 3);
  });

  test('a slow or failing read keeps the last saved station printer', () async {
    var mode = 'ok';
    var now = DateTime.utc(2026, 11, 22, 12);
    final resolve = lanStationPrinterResolver(
      restaurantId: 'rest-route',
      clock: () => now,
      lookupTimeout: const Duration(milliseconds: 50),
      resolve: (station) async {
        if (mode == 'throw') throw const SocketException('offline');
        if (mode == 'slow') {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
        return RestaurantPrinterDispatchResolution(
          ok: true,
          resolutionSource: 'station_mapping',
          printerSnapshot: <String, dynamic>{..._saved},
        );
      },
    );

    mode = 'throw';
    await expectLater(resolve('ocak'), throwsA(isA<SocketException>()));
    mode = 'ok';
    expect((await resolve('ocak'))['target_host'], '192.168.10.100');
    now = now.add(const Duration(minutes: 5));
    mode = 'throw';
    expect((await resolve('ocak'))['target_host'], '192.168.10.100');
    mode = 'slow';
    expect((await resolve('ocak'))['target_host'], '192.168.10.100');
  });
}
