import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/print_station_service.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  test('failed save retains retry key and never dispatches a print job', () async {
    SharedPreferences.setMockInitialValues({});
    // Tüm istekler: yapılandırma okumaları (ör. GET /printers) baskı gönderimi
    // sayılmaz; yalnızca yazma yöntemleri baskı işi oluşturabilir.
    final requests = <http.BaseRequest>[];
    final keys = <String>[];
    final client = SupabaseClient('https://example.supabase.co', 'test-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/rpc/create_table_order_with_print_jobs')) {
          keys.add(jsonDecode(request.body)['p_local_order_id'] as String);
          return http.Response(jsonEncode({'code': '42703', 'message': 'column "id" does not exist'}), 400,
            headers: {'content-type': 'application/json'}, request: request);
        }
        return http.Response('[]', 200, headers: {'content-type': 'application/json'}, request: request);
      }));
    final service = OrderPrintJobService(
      client: client,
      printerRepository: PrinterRepository(client: client),
      printOrchestrator: DesktopPrintOrchestrator(
        printerRepository: PrinterRepository(client: client),
        printStationService: PrintStationService(client: client),
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(service.dispatchNewOrder(
        restaurantId: '10000000-0000-0000-0000-000000000001', tableNumber: 1,
        items: [{'name': 'Soup', 'quantity': 1, 'price': 10}],
        localOrderId: 'same-retry-key', skipOfflineFallback: true,
      ), throwsException);
    }
    expect(keys, ['same-retry-key', 'same-retry-key']);
    // Kayıt başarısızsa hiçbir baskı işi yazılmamalı: `print_jobs` tablosuna
    // yazma veya sipariş RPC'si dışında baskı RPC'si yok.
    final printWrites = requests.where((request) {
      if (request.method == 'GET') return false;
      final path = request.url.path;
      if (path.endsWith('/rpc/create_table_order_with_print_jobs')) return false;
      return path.contains('/print_jobs') ||
          (path.contains('/rpc/') && path.contains('print'));
    });
    expect(printWrites, isEmpty);
    expect(
      requests.where((r) => r.url.path.endsWith('/rpc/create_table_order_with_print_jobs')),
      hasLength(2),
    );
    await service.disposeBroadcastSender();
    await client.dispose();
  });
}
