import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_client.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_order_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _RealHttpOverrides();

  test('browser token reaches the same order authority without a client certificate', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final temp = await Directory.systemTemp.createTemp('ibul-browser-lan');
    addTearDown(() => temp.delete(recursive: true));
    final material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
    final orders = RestaurantLocalOrderQueueService();
    final prints = RestaurantLocalPrintQueueService();
    final seen = <String>[];
    final floor = RestaurantLanHostRegistry.ordersAccepted.stream.listen((order) {
      seen.add(order.localOrderId);
    });
    addTearDown(floor.cancel);
    final host = RestaurantLanHost(
      restaurantId: 'browser-rest',
      operatorFingerprint: material.operatorFingerprint,
      certificateDirectory: material.directory.path,
      orders: orders,
      printQueue: prints,
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      tablesOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 't3',
          'table_number': 3,
          'name': 'Bahçe 3',
          'display_label': 'Bahçe 3',
        },
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'corba',
          'name': 'Çorba',
          'station_id': 'ocak',
          'price': 40,
        },
      ],
      staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
      deviceStore: MemoryLanEnrollmentStore(),
    );
    await host.start(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    await host.startBrowserGate(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    addTearDown(host.stop);

    final operator = RestaurantLanClient(
      Uri.parse('https://127.0.0.1:${host.port}'),
      securityContext: material.operatorContext,
      pinnedServerFingerprint: material.serverFingerprint,
    );
    final issued = await operator.post('/lan/browser/issue', <String, Object?>{});
    expect(issued['status'], 200, reason: issued['error']?.toString());
    final code = issued['code']?.toString() ?? '';
    expect(code, isNotEmpty);

    final client = HttpClient()
      ..badCertificateCallback = (cert, name, port) => name == '127.0.0.1';
    addTearDown(client.close);
    final origin = 'https://127.0.0.1:${host.browserPort}';

    Future<Map<String, dynamic>> post(
      String path,
      Map<String, Object?> body, {
      String? token,
      String? requestOrigin,
    }) async {
      final request = await client.postUrl(
        Uri.parse('https://127.0.0.1:${host.browserPort}$path'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('origin', requestOrigin ?? origin);
      if (token != null) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      request.add(utf8.encode(jsonEncode(body)));
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      final json = Map<String, dynamic>.from(jsonDecode(text) as Map);
      json['status'] = response.statusCode;
      return json;
    }

    final paired = await post('/lan/browser/pair', <String, Object?>{
      'code': code,
      'staff_id': 'staff-a',
    });
    expect(paired['ok'], isTrue, reason: paired.toString());
    final token = paired['token']?.toString() ?? '';
    expect(token, isNotEmpty);
    final reused = await post('/lan/browser/pair', <String, Object?>{
      'code': code,
      'staff_id': 'staff-a',
    });
    expect(reused['status'], 401);

    final tables = await post(
      '/lan/browser/tables',
      <String, Object?>{
        'seq': 1,
        'body': <String, Object?>{'staff_id': 'staff-a'},
      },
      token: token,
    );
    expect(tables['status'], 200);
    expect((tables['tables'] as List).single['name'], 'Bahçe 3');

    final saved = await post(
      '/lan/browser/orders',
      <String, Object?>{
        'seq': 2,
        'body': <String, Object?>{
          'staff_id': 'staff-a',
          'local_order_id': 'browser-bahce-3',
          'table_number': 3,
          'table_name': 'Bahçe 3',
          'station_id': 'ocak',
          'revision': '1',
          'items': <Map<String, Object?>>[
            <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
          ],
        },
      },
      token: token,
    );
    expect(saved['saved'], isTrue, reason: saved.toString());
    expect(saved['duplicate'], isFalse);
    final replay = await post(
      '/lan/browser/orders',
      <String, Object?>{
        'seq': 2,
        'body': <String, Object?>{'staff_id': 'staff-a'},
      },
      token: token,
    );
    expect(replay['status'], 401);
    final duplicate = await post(
      '/lan/browser/orders',
      <String, Object?>{
        'seq': 3,
        'body': <String, Object?>{
          'staff_id': 'staff-a',
          'local_order_id': 'browser-bahce-3',
          'table_number': 3,
          'table_name': 'Bahçe 3',
          'station_id': 'ocak',
          'revision': '1',
          'items': <Map<String, Object?>>[
            <String, Object?>{'name': 'Çorba', 'quantity': 1, 'price': 40},
          ],
        },
      },
      token: token,
    );
    expect(duplicate['duplicate'], isTrue);
    expect(await orders.list('browser-rest'), hasLength(1));
    expect(await prints.list('browser-rest'), hasLength(1));
    expect(seen, <String>['browser-bahce-3']);
    final foreign = await post(
      '/lan/browser/floor',
      <String, Object?>{
        'seq': 4,
        'body': <String, Object?>{'staff_id': 'staff-a'},
      },
      token: token,
      requestOrigin: 'https://evil.example',
    );
    expect(foreign['status'], 401);
  });

  test('holds a browser gate for the manual browser check', () async {
    if (Platform.environment['IBUL_HOLD_BROWSER_GATE'] != '1') return;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final temp = await Directory.systemTemp.createTemp('ibul-browser-hold');
    final material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
    final host = RestaurantLanHost(
      restaurantId: 'browser-rest',
      operatorFingerprint: material.operatorFingerprint,
      certificateDirectory: material.directory.path,
      orders: RestaurantLocalOrderQueueService(),
      printQueue: RestaurantLocalPrintQueueService(),
      stationsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{'id': 'ocak'},
      ],
      tablesOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 't3',
          'table_number': 3,
          'name': 'Bahçe 3',
          'display_label': 'Bahçe 3',
        },
      ],
      productsOverride: const <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'corba',
          'name': 'Çorba',
          'station_id': 'ocak',
          'price': 40,
        },
      ],
      staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
      deviceStore: MemoryLanEnrollmentStore(),
    );
    await host.start(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    await host.startBrowserGate(
      address: InternetAddress.loopbackIPv4,
      securityContext: material.serverContext,
    );
    final operator = RestaurantLanClient(
      Uri.parse('https://127.0.0.1:${host.port}'),
      securityContext: material.operatorContext,
      pinnedServerFingerprint: material.serverFingerprint,
    );
    final issued = await operator.post('/lan/browser/issue', <String, Object?>{});
    // ignore: avoid_print
    print('BROWSER_URL=https://127.0.0.1:${host.browserPort}/lan/browser/app');
    // ignore: avoid_print
    print('BROWSER_CODE=${issued['code']}');
    await Future<void>.delayed(const Duration(minutes: 2));
    await host.stop();
  }, timeout: const Timeout(Duration(minutes: 3)));
}

class _RealHttpOverrides extends HttpOverrides {}
