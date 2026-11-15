import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pilot_contract.dart';
import 'package:ibul_app/services/restaurant_offline/lan_pilot_gateway.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/staff_login_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _OpenHttp();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LanPilotMode.debugOverride = true;
    HttpOverrides.global = _OpenHttp();
  });

  tearDown(() async {
    LanPilotMode.debugOverride = null;
    LanPilotGateway.current = LanPilotGateway();
    await RestaurantLanHostRegistry.current?.stop();
  });

  testWidgets('bridge kapalıyken gönderim başarılı görünmez ve taslak kalır', (
    tester,
  ) async {
    await tester.runAsync(_startHost);
    LanPilotGateway.current = LanPilotGateway(port: 9);
    await _pump(tester, SellerPanelGarsonPreviewScenario.ordersWithDraftOnly);

    expect(find.text('Siparişi Gönder'), findsOneWidget);
    expect(find.text('Ciğer Şiş'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Siparişi Gönder'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await _settle(tester);

    expect(find.text(LanPilotContract.bridgeClosedMessage), findsWidgets);
    expect(find.text('Siparişi Gönder'), findsOneWidget);
    expect(find.text('Ciğer Şiş'), findsOneWidget);
    expect(find.text('Yazıcıya iletildi'), findsNothing);
    expect(find.text('Kuyruğa alındı'), findsNothing);
  });

  testWidgets('ürün eklenir, LAN kaydı ve mock fiş oluşur, tekrar çift yazmaz', (
    tester,
  ) async {
    final bridge = await tester.runAsync(_BridgePilot.start);
    if (bridge == null) fail('Köprü başlamadı.');
    addTearDown(bridge.stop);
    await tester.runAsync(_startHost);
    LanPilotGateway.current = LanPilotGateway(port: bridge.port)
      ..printerPort = bridge.printerPort;
    await _pump(tester, SellerPanelGarsonPreviewScenario.productsEmptyDraft);

    expect(find.text('Taslak boş'), findsOneWidget);
    await tester.tap(find.text('Ekle').first);
    await _settle(tester);
    expect(find.text('1 ürün'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.text('Sipariş'),
      ),
    );
    await _settle(tester);
    expect(find.text('Siparişi Gönder'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Siparişi Gönder'));
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    await _settle(tester);

    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .where((text) => text.trim().isNotEmpty)
        .toList();
    expect(
      labels.any(
        (text) =>
            text.contains('Yazıcıya iletildi') ||
            text.contains('Kuyruğa alındı') ||
            text.contains('sipariş kayıtlı'),
      ),
      isTrue,
      reason: labels.join(' | '),
    );
    expect(find.text('Siparişi Gönder'), findsNothing);
    final count = await tester.runAsync(bridge.orderCount);
    expect(count, 1);
    expect(bridge.tickets, isNotEmpty);
    expect(utf8.decode(bridge.tickets.first), contains('Ciğer Şiş'));

    final replay = await tester.runAsync(bridge.replayFirst);
    expect(replay?['duplicate'], isTrue);
    expect(await tester.runAsync(bridge.orderCount), 1);
    expect(bridge.tickets, hasLength(1));
  });
}

Future<void> _startHost() async {
  final temp = await Directory.systemTemp.createTemp('ibul-lan-ui');
  final material = await LanTlsMaterial.open(Directory('${temp.path}/host'));
  final host = RestaurantLanHost(
    restaurantId: 'preview-seller',
    operatorFingerprint: material.operatorFingerprint,
    certificateDirectory: material.directory.path,
    productsOverride: const <Map<String, dynamic>>[
      <String, dynamic>{'id': 'p-ciger', 'name': 'Ciğer Şiş', 'price': 280},
      <String, dynamic>{'id': 'p-kuzu', 'name': 'Kuzu Pirzola', 'price': 420},
      <String, dynamic>{'id': 'p-tavuk', 'name': 'Tavuk Bonfile', 'price': 220},
      <String, dynamic>{'id': 'p-ayran', 'name': 'Yayık Ayran', 'price': 40},
      <String, dynamic>{
        'id': 'p-salata',
        'name': 'Gavurdağı Salata',
        'price': 130,
      },
    ],
    staffStillAuthorized: (_) async => const StaffProbe(StaffProbeKind.active),
  );
  await host.start(
    address: InternetAddress.loopbackIPv4,
    port: 0,
    securityContext: material.serverContext,
  );
}

Future<void> _pump(
  WidgetTester tester,
  SellerPanelGarsonPreviewScenario scenario,
) async {
  tester.view.physicalSize = const Size(920, 932);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    SellerPanelGarsonPreview(
      scenario: scenario,
      enableLocalSubmit: false,
      viewportSize: const Size(920, 932),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 1));
  final exception = tester.takeException();
  if (exception != null &&
      !exception.toString().contains('MissingPluginException')) {
    fail('Garson ekranı hata verdi: $exception');
  }
}

class _OpenHttp extends HttpOverrides {}

class _BridgePilot {
  _BridgePilot(this.port, this.printerPort, this._process, this._printer);

  final int port;
  final int printerPort;
  final Process _process;
  final ServerSocket _printer;
  final List<List<int>> tickets = <List<int>>[];

  static Future<_BridgePilot> start() async {
    final printer = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final dataDir = await Directory.systemTemp.createTemp('ibul-lan-bridge');
    final root = Directory.current.path.endsWith('ibul_app')
        ? Directory.current.parent
        : Directory.current;
    final process = await Process.start(
      'python3',
      <String>['-m', 'local_print_bridge'],
      workingDirectory: root.path,
      environment: <String, String>{
        ...Platform.environment,
        'PYTHONPATH': root.path,
        'PRINT_BRIDGE_HOST': '127.0.0.1',
        'PRINT_BRIDGE_PORT': '$port',
        'PRINT_BRIDGE_DATA_DIR': dataDir.path,
      },
    );
    final pilot = _BridgePilot(port, printer.port, process, printer);
    printer.listen((socket) {
      final chunks = <int>[];
      socket.listen(
        chunks.addAll,
        onDone: () => pilot.tickets.add(chunks),
        onError: (_) {},
      );
    });
    final ready = await _waitUntilHealthy(port);
    if (!ready) {
      final error = await process.stderr.transform(utf8.decoder).join();
      await pilot.stop();
      fail('Köprü açılmadı: $error');
    }
    return pilot;
  }

  Future<int> orderCount() async {
    final body = await _get('/lan/v1/orders');
    return (body['count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, dynamic>> replayFirst() async {
    final listed = await _get('/lan/v1/orders');
    final ids = (listed['ids'] as List?) ?? const <Object>[];
    final id = ids.first.toString();
    final order = await _get('/lan/v1/orders?local_order_id=$id');
    final row = Map<String, dynamic>.from(order['order'] as Map);
    final items = (order['items'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return _post('/lan/v1/orders', <String, dynamic>{
      'restaurant_id': row['restaurant_id'],
      'local_order_id': id,
      'table_number': row['table_number'],
      'table_label': row['table_label'],
      'items': [
        for (final item in items)
          <String, dynamic>{
            'name': item['name'],
            'quantity': item['quantity'],
            'unit_price': (item['unit_cents'] as num) / 100,
            'station_id': item['station_id'],
          },
      ],
      'deliver_print': true,
      'printer': <String, dynamic>{'host': '127.0.0.1', 'port': printerPort},
    });
  }

  Future<void> stop() async {
    _process.kill();
    await _printer.close();
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final client = HttpClient();
    try {
      final request = await client.get('127.0.0.1', port, path);
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.post('127.0.0.1', port, path);
      final bytes = utf8.encode(jsonEncode(body));
      request.headers.contentType = ContentType.json;
      request.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } finally {
      client.close(force: true);
    }
  }
}

Future<bool> _waitUntilHealthy(int port) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    final client = HttpClient();
    try {
      final request = await client
          .get('127.0.0.1', port, '/health')
          .timeout(const Duration(milliseconds: 300));
      final response = await request.close();
      await response.drain<void>();
      if (response.statusCode == 200) return true;
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return false;
}
