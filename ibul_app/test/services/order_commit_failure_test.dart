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
    } catch (_) {
      // A previous test in the same process may already have initialized it.
    }
  });

  test('failed save retains retry key and never dispatches a print job', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final writes = <Uri>[];
    final keys = <String>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        writes.add(request.url);
        if (request.url.path.endsWith(
          '/rpc/create_table_order_with_print_jobs',
        )) {
          keys.add(jsonDecode(request.body)['p_local_order_id'] as String);
          return http.Response(
            jsonEncode({
              'code': '42703',
              'message': 'column "id" does not exist',
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    final service = OrderPrintJobService(
      client: client,
      printerRepository: PrinterRepository(client: client),
      printOrchestrator: DesktopPrintOrchestrator(
        printerRepository: PrinterRepository(client: client),
        printStationService: PrintStationService(client: client),
      ),
    );
    for (var attempt = 0; attempt < 2; attempt++) {
      await expectLater(
        service.dispatchNewOrder(
          restaurantId: '10000000-0000-0000-0000-000000000001',
          tableNumber: 1,
          items: [
            {'name': 'Soup', 'quantity': 1, 'price': 10},
          ],
          idempotencyKey: 'same-retry-key',
        ),
        throwsException,
      );
    }
    expect(keys, ['same-retry-key', 'same-retry-key']);
    expect(
      writes.where(
        (uri) =>
            uri.path.contains('/print/') || uri.path.endsWith('/print_jobs'),
      ),
      isEmpty,
    );
    await client.dispose();
  });
}
