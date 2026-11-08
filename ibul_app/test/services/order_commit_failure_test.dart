import 'dart:async';
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

  setUp(OrderPrintJobService.debugResetUnsettledOrderSaves);

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

  test(
    'failed save retains retry key and never dispatches a print job',
    () async {
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
    },
  );

  test(
    'timed out save reads the committed order and does not insert again',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final firstRpc = Completer<http.Response>();
      var rpcCount = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith(
            '/rpc/create_table_order_with_print_jobs',
          )) {
            rpcCount += 1;
            return firstRpc.future;
          }
          if (request.url.path.endsWith('/orders') &&
              request.url.query.contains('local_order_id')) {
            return http.Response(
              jsonEncode({'id': 'order-1', 'order_number': '1042'}),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }
          if (request.url.path.endsWith('/print_jobs')) {
            return http.Response(
              jsonEncode([
                {'id': 'job-1', 'status': 'completed'},
              ]),
              200,
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
        orderSaveTimeout: const Duration(milliseconds: 40),
        orderCommitPollAttempts: 1,
        orderCommitPollInterval: Duration.zero,
      );

      final result = await service.dispatchNewOrder(
        restaurantId: '10000000-0000-0000-0000-000000000001',
        tableNumber: 1,
        items: [
          {'name': 'Soup', 'quantity': 1, 'price': 10},
        ],
        idempotencyKey: 'same-retry-key',
      );

      expect(rpcCount, 1);
      expect(result.orderId, 'order-1');
      expect(result.dispatchedJobCount, 0);
      expect(result.physicallyDispatched, isFalse);
      firstRpc.complete(
        http.Response(
          jsonEncode({
            'order_id': 'late-duplicate',
            'print_job_ids': <String>['job-late'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await client.dispose();
    },
  );

  test('a retry reads the committed order before inserting again', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    var rpcCount = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith(
          '/rpc/create_table_order_with_print_jobs',
        )) {
          rpcCount += 1;
          return http.Response(
            jsonEncode({
              'code': '57014',
              'message': 'canceling statement due to statement timeout',
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/orders') &&
            request.url.query.contains('local_order_id') &&
            rpcCount > 0) {
          return http.Response(
            jsonEncode({'id': 'order-1', 'order_number': '1042'}),
            200,
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
    final result = await service.dispatchNewOrder(
      restaurantId: '10000000-0000-0000-0000-000000000001',
      tableNumber: 1,
      items: [
        {'name': 'Soup', 'quantity': 1, 'price': 10},
      ],
      idempotencyKey: 'same-retry-key',
    );

    expect(rpcCount, 1);
    expect(result.orderId, 'order-1');
    expect(result.dispatchedJobCount, 0);
    await client.dispose();
  });

  test(
    'a retry while the first save is still running does not insert again',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final hangingRpc = Completer<http.Response>();
      http.BaseRequest? rpcRequest;
      var rpcCount = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-key',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith(
            '/rpc/create_table_order_with_print_jobs',
          )) {
            rpcCount += 1;
            rpcRequest = request;
            return hangingRpc.future;
          }
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(OrderPrintJobService.debugResetUnsettledOrderSaves);
      final service = OrderPrintJobService(
        client: client,
        printerRepository: PrinterRepository(client: client),
        printOrchestrator: DesktopPrintOrchestrator(
          printerRepository: PrinterRepository(client: client),
          printStationService: PrintStationService(client: client),
        ),
        orderSaveTimeout: const Duration(milliseconds: 30),
        orderCommitPollAttempts: 2,
        orderCommitPollInterval: Duration.zero,
      );

      send() {
        return service.dispatchNewOrder(
          restaurantId: '10000000-0000-0000-0000-000000000001',
          tableNumber: 1,
          items: [
            {'name': 'Soup', 'quantity': 1, 'price': 10},
          ],
          idempotencyKey: 'still-running-key',
        );
      }

      await expectLater(
        send(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Aynı gönderim anahtarı duruyor'),
          ),
        ),
      );
      await expectLater(
        send(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Aynı gönderim anahtarı duruyor'),
          ),
        ),
      );

      expect(rpcCount, 1);
      hangingRpc.complete(
        http.Response(
          jsonEncode({
            'order_id': 'late-order',
            'order_number': '1042',
            'print_job_ids': <String>[],
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: rpcRequest,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final replay = await send();
      expect(rpcCount, 1);
      expect(replay.orderId, 'late-order');
      expect(replay.dispatchedJobCount, 0);
      await client.dispose();
    },
  );
}
