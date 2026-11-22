import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/print_service_start_gate.dart';
import 'package:ibul_app/services/print_station_service.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _restaurant = '10000000-0000-0000-0000-000000000001';

/// The printer center starting (by hand or at launch) must not pour out the
/// tickets that were waiting from before: the recovery sweep of pending jobs
/// leaves them to the operator.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> requestedJobFetches;

  OrderPrintJobService serviceWith(List<Map<String, dynamic>> pending) {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      httpClient: MockClient((request) async {
        final query = request.url.query;
        if (request.url.path.endsWith('/print_jobs') &&
            request.method == 'GET' &&
            query.contains('status=eq.pending')) {
          return http.Response(
            jsonEncode(pending),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        if (request.url.path.endsWith('/print_jobs')) {
          requestedJobFetches.add('${request.method} $query');
        }
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    return OrderPrintJobService(
      client: client,
      printerRepository: PrinterRepository(client: client),
      printOrchestrator: DesktopPrintOrchestrator(
        printerRepository: PrinterRepository(client: client),
        printStationService: PrintStationService(client: client),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    requestedJobFetches = <String>[];
    PrintServiceStartGate.resetForTests();
    PrintServiceStartGate.enforce(); // a restaurant's center computer
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    PrintServiceStartGate.resetForTests();
  });

  test('jobs that waited from before Başlat are not picked up by the sweep', () async {
    final startedAt = DateTime.now().toUtc();
    PrintServiceStartGate.grant(startedAt);
    final result = await serviceWith(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'old-1',
        'created_at':
            startedAt.subtract(const Duration(hours: 3)).toIso8601String(),
      },
      <String, dynamic>{
        'id': 'old-2',
        'created_at':
            startedAt.subtract(const Duration(days: 2)).toIso8601String(),
      },
      // No readable time counts as old: holding costs one tap.
      <String, dynamic>{'id': 'old-3', 'created_at': null},
    ]).recoverPendingJobs(restaurantId: _restaurant);
    expect(result.pendingJobCount, 0);
    expect(result.attemptedJobIds, isEmpty);
    // Nothing about those jobs was fetched for dispatch.
    expect(requestedJobFetches, isEmpty);
  });

  test('with the center stopped nothing waiting is picked up at all', () async {
    // enforce() without grant(): closed, as at every launch and after Durdur.
    final result = await serviceWith(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'any',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    ]).recoverPendingJobs(restaurantId: _restaurant);
    expect(result.attemptedJobIds, isEmpty);
    expect(requestedJobFetches, isEmpty);
  });

  test('a job created after Başlat is still recovered', () async {
    final startedAt = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
    PrintServiceStartGate.grant(startedAt);
    final result = await serviceWith(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'old-1',
        'created_at':
            startedAt.subtract(const Duration(hours: 1)).toIso8601String(),
      },
      <String, dynamic>{
        'id': 'new-1',
        'created_at':
            startedAt.add(const Duration(minutes: 1)).toIso8601String(),
      },
    ]).recoverPendingJobs(restaurantId: _restaurant);
    expect(result.attemptedJobIds, <String>['new-1']);
  });
}
