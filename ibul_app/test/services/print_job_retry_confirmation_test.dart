import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/services/print_job_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final scenario in ['unconfirmed', 'confirmed', 'race', 'completed']) {
    test('manual reprint $scenario', () async {
      final requests = <http.Request>[];
      final client = SupabaseClient('http://localhost.invalid', 'fixture',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(jsonEncode({
              'status': scenario == 'completed' ? 'completed' : 'failed',
              'retry_count': 0,
              'payload': {'items': [{'name': 'Soup'}], 'manual_reprint_token': 'old'},
            }), 200, headers: {'content-type': 'application/json'}, request: request);
          }
          return http.Response(scenario == 'race' ? '[]' : '[{"id":"job"}]',
            200, headers: {'content-type': 'application/json'}, request: request);
        }));
      final repository = PrintJobRepository(client: client);
      if (scenario == 'unconfirmed') {
        await expectLater(repository.retryJob('job'), throwsStateError);
        expect(requests, isEmpty);
      } else {
        expect(await repository.retryJob('job', operatorConfirmed: true),
          scenario == 'confirmed');
        final writes = requests.where((r) => r.method == 'PATCH').toList();
        if (scenario == 'completed') {
          expect(writes, isEmpty);
        } else {
          expect(writes, hasLength(1));
          expect(writes.single.url.queryParameters['status'], 'eq.failed');
          expect(writes.single.url.queryParameters['retry_count'], 'eq.0');
          final body = jsonDecode(writes.single.body);
          expect(body['retry_count'], 1);
          expect(body['payload']['items'], [{'name': 'Soup'}]);
          expect(body['payload']['manual_reprint_token'], isNot('old'));
          expect(body['payload']['requires_operator_review'], false);
          expect(body['payload']['operator_reprint_confirmed_at'], isNotNull);
        }
      }
      await client.dispose();
    });
  }
}
