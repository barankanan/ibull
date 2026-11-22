import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ibul_app/services/local_print_service.dart';
import 'package:ibul_app/services/printer_link_status.dart';

void main() {
  test('a healthy bridge answer carries its body to the caller', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final client = MockClient((request) async {
      expect(request.url.path, '/health');
      return http.Response(
        jsonEncode({
          'ok': true,
          'print_station': {'enabled': false, 'print_system_enabled': true},
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = LocalPrintService(
      client: client,
      baseUri: Uri.parse('http://127.0.0.1:18771'),
    );
    final status = await service.checkAvailability();
    expect(status.isAvailable, isTrue, reason: "${status.reason} ${status.details}");
    expect(status.details, isA<Map>());
    // This is what the waiter page reads; it used to be "unknown" (null).
    expect(
      printSystemEnabledFromHealth(
        Map<String, dynamic>.from(status.details! as Map),
      ),
      isTrue,
    );
  });
}
