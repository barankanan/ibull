import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pilot_contract.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pilot_gateway.dart';

void main() {
  HttpOverrides.global = _OpenHttp();

  test('pilot and cloud are different authorities', () {
    expect(
      lanPilotMayCallSupabase(orderAuthority(lanPilotEnabled: false)),
      isTrue,
    );
    expect(
      lanPilotMayCallSupabase(orderAuthority(lanPilotEnabled: true)),
      isFalse,
    );
    expect(LanPilotMode.fromEnvironment, isFalse);
  });

  test('a lost response is recovered by the same order id', () async {
    final stored = <String, Map<String, dynamic>>{};
    var posts = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.method == 'POST') {
        posts += 1;
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        final id = (body as Map)['local_order_id'].toString();
        stored[id] = <String, dynamic>{
          'ok': true,
          'saved': true,
          'local_order_id': id,
          'print_jobs': <Map<String, dynamic>>[
            <String, dynamic>{'id': 'job-1', 'status': 'sent'},
          ],
        };
        await Future<void>.delayed(const Duration(milliseconds: 400));
        request.response.statusCode = 200;
        request.response.write(jsonEncode(stored[id]));
        await request.response.close();
        return;
      }
      final id = request.uri.queryParameters['local_order_id'] ?? '';
      final found = stored[id];
      request.response.statusCode = found == null ? 404 : 200;
      if (found != null) request.response.write(jsonEncode(found));
      await request.response.close();
    });
    final gateway = LanPilotGateway(
      port: server.port,
      timeout: const Duration(milliseconds: 80),
    );
    final saved = await gateway.submit(
      restaurantId: 'rest',
      localOrderId: 'order-1',
      tableNumber: 8,
      tableLabel: 'Masa 8',
      waiterName: 'Ayse',
      notes: '',
      items: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Cay', 'quantity': 1, 'price': 12},
      ],
    );
    expect(saved['saved'], isTrue);
    expect(saved['recovered'], isTrue);
    expect(posts, 1);
    await server.close(force: true);
  });

  test('a closed bridge does not report the order as sent', () async {
    final gateway = LanPilotGateway(port: 9, timeout: const Duration(milliseconds: 200));
    expect(
      () => gateway.submit(
        restaurantId: 'rest',
        localOrderId: 'order-2',
        tableNumber: 8,
        tableLabel: 'Masa 8',
        waiterName: 'Ayse',
        notes: '',
        items: const <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Cay', 'quantity': 1, 'price': 12},
        ],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          LanPilotContract.bridgeClosedMessage,
        ),
      ),
    );
  });
}

class _OpenHttp extends HttpOverrides {}
