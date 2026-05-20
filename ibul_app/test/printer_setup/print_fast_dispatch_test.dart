import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/turkish_encoding_calibration.dart';
import 'package:ibul_app/services/desktop_print_orchestrator.dart';
import 'package:ibul_app/services/printer_encoding_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });
  test('buildFastRoleTestPayload stamps guarantee encoding without store fetch', () {
    final orchestrator = DesktopPrintOrchestrator();
    final payload = orchestrator.buildFastRoleTestPayload(
      role: PrinterSetupRole.adisyon,
      profile: PrinterEncodingProfile(
        printerId: 'windows:POS-58',
        encoding: 'cp857',
        codePage: 13,
        verifiedAt: DateTime(2026, 5, 20),
        printMode: kTurkishPrintModeGuarantee,
        candidateId: 'turkish_guarantee',
      ),
      storeName: 'Test Store',
    );

    expect(payload.body['store_name'], 'Test Store');
    expect(payload.body['turkish_print_mode'], kTurkishPrintModeGuarantee);
    expect(payload.body['render_mode'], 'image');
    expect(payload.body['encoding_profile_verified'], isTrue);
    expect(payload.body['table_no'], 'TEST');
  });

  test('resolvePrinterFromBridgeMaps matches live bridge id', () {
    final orchestrator = DesktopPrintOrchestrator();
    final printer = orchestrator.resolvePrinterFromBridgeMaps(
      bridgePrinters: <Map<String, dynamic>>[
        <String, dynamic>{
          'isLive': true,
          'id': 'windows:POS-58',
          'name': 'POS-58',
          'queue': 'POS-58',
          'backend': 'windows-spool',
        },
      ],
      printerId: 'windows:POS-58',
      os: DesktopPrinterOs.windows,
    );

    expect(printer, isNotNull);
    expect(printer!.id, 'windows:POS-58');
    expect(printer.queueName, 'POS-58');
  });
}
