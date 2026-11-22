import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/desktop_printer_setup_models.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/printer_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _printer(
  String id,
  String ip, {
  bool active = true,
  String connection = 'network',
}) => <String, dynamic>{
  'id': id,
  'restaurant_id': 'rest-1',
  'name': 'Yazıcı $id',
  'code': 'eth_${ip.replaceAll('.', '_')}_9100',
  'connection_type': connection,
  'ip_address': connection == 'network' ? ip : null,
  'port': 9100,
  'device_identifier': connection == 'network' ? 'tcp:$ip:9100' : 'usb:$id',
  'is_active': active,
  'created_at': '2026-11-20T10:00:00Z',
};

Map<String, dynamic> _mapping(
  String station,
  String printer, {
  bool primary = true,
}) => <String, dynamic>{
  'id': 'm-$station-$printer',
  'station_id': station,
  'printer_id': printer,
  'is_primary': primary,
  'created_at': '2026-11-20T10:00:00Z',
};

UnifiedPrinterModel _target(String host) => UnifiedPrinterModel(
  id: 'tcp:$host:9100',
  displayName: host,
  queueName: 'tcp:$host:9100',
  backend: DesktopPrinterBackend.tcp,
  os: DesktopPrinterOs.macos,
  isAvailable: true,
  canPrint: true,
  raw: <String, dynamic>{'host': host, 'port': 9100},
);

UnifiedPrinterModel _fromRecord(PrinterModel printer) =>
    _target(printer.ipAddress ?? '');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<void> save({
    required List<Map<String, dynamic>> printers,
    required List<Map<String, dynamic>> mappings,
    String? kitchenRole,
  }) async {
    await PrinterRepository.rememberLastGoodRows(
      'station_config',
      'rest-1',
      kitchenRole == null
          ? const <Object>[]
          : <Object>[
              <String, dynamic>{
                'restaurant_id': 'rest-1',
                'kitchen_printer_id': kitchenRole,
              },
            ],
    );
    await PrinterRepository.rememberLastGoodRows('printers', 'rest-1', printers);
    await PrinterRepository.rememberLastGoodRows(
      'station_printers',
      'rest-1',
      mappings,
    );
  }

  Future<FastPathStationPrinters> resolve(List<String> stations) =>
      resolveFastPathStationPrinters(
        restaurantId: 'rest-1',
        stationIds: stations,
        toBridgeTarget: _fromRecord,
      );

  group('saved station assignments', () {
    test('are unknown until both lists were read on this device', () async {
      expect(await PrinterRepository.lastGoodStationPrinters('rest-1'), isNull);
      await PrinterRepository.rememberLastGoodRows(
        'printers',
        'rest-1',
        <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
      );
      expect(await PrinterRepository.lastGoodStationPrinters('rest-1'), isNull);
    });

    test('a station keeps its printer; the primary one wins', () async {
      await save(
        printers: <Map<String, dynamic>>[
          _printer('p1', '192.168.10.100'),
          _printer('p2', '192.168.10.101'),
        ],
        mappings: <Map<String, dynamic>>[
          _mapping('ocak', 'p2', primary: false),
          _mapping('ocak', 'p1'),
          _mapping('firin', 'p2'),
        ],
      );
      final saved = (await PrinterRepository.lastGoodStationPrinters('rest-1'))!;
      expect(saved.printerFor('ocak')!.id, 'p1');
      expect(saved.printerFor('firin')!.id, 'p2');
      expect(saved.isAssigned('adisyon'), isFalse);
    });

    test('are kept per restaurant', () async {
      await save(
        printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
        mappings: <Map<String, dynamic>>[_mapping('ocak', 'p1')],
      );
      expect(await PrinterRepository.lastGoodStationPrinters('rest-2'), isNull);
    });
  });

  group('fast local kitchen print picks the printer per station', () {
    test('each station goes to its own printer, not to one printer for all', () async {
      await save(
        printers: <Map<String, dynamic>>[
          _printer('p1', '192.168.10.100'),
          _printer('p2', '192.168.10.101'),
        ],
        mappings: <Map<String, dynamic>>[
          _mapping('ocak', 'p1'),
          _mapping('firin', 'p2'),
        ],
      );
      final result = await resolve(<String>['ocak', 'firin']);
      expect(result.refusal, isNull);
      expect(result.printers.map((p) => p.raw['host']), <String>[
        '192.168.10.100',
        '192.168.10.101',
      ]);
    });

    test('a station without an assignment uses the kitchen role printer', () async {
      await save(
        printers: <Map<String, dynamic>>[
          _printer('p1', '192.168.10.100'),
          _printer('pk', '192.168.10.50'),
        ],
        mappings: <Map<String, dynamic>>[_mapping('ocak', 'p1')],
        kitchenRole: 'pk',
      );
      final result = await resolve(<String>['ocak', 'salata']);
      expect(result.printers.map((p) => p.raw['host']), <String>[
        '192.168.10.100',
        '192.168.10.50',
      ]);
    });

    test('no assignment and no kitchen printer: nothing is sent to a default', () async {
      await save(
        printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
        mappings: <Map<String, dynamic>>[_mapping('ocak', 'p1')],
      );
      final result = await resolve(<String>['ocak', 'salata']);
      expect(result.refusal, 'no_kitchen_role_printer');
      expect(result.printers, isEmpty);
    });

    test('assignments not known on this device: nothing is guessed', () async {
      final result = await resolve(<String>['ocak']);
      expect(result.refusal, 'station_printers_unknown');
    });

    test('an assigned printer whose record is gone is not replaced by another', () async {
      await save(
        printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
        mappings: <Map<String, dynamic>>[_mapping('firin', 'deleted')],
      );
      final result = await resolve(<String>['firin']);
      expect(result.refusal, 'station_printer_record_missing');
    });

    test('a switched-off or non-network printer leaves the ticket to the queue', () async {
      await save(
        printers: <Map<String, dynamic>>[
          _printer('p1', '192.168.10.100', active: false),
          _printer('p2', '', connection: 'usb'),
        ],
        mappings: <Map<String, dynamic>>[
          _mapping('ocak', 'p1'),
          _mapping('firin', 'p2'),
        ],
      );
      expect(
        (await resolve(<String>['ocak'])).refusal,
        'station_printer_inactive',
      );
      expect(
        (await resolve(<String>['firin'])).refusal,
        'station_printer_not_ethernet',
      );
    });

    test('one unsettled station stops the whole order: no partial printing', () async {
      await save(
        printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
        mappings: <Map<String, dynamic>>[
          _mapping('ocak', 'p1'),
          _mapping('firin', 'deleted'),
        ],
      );
      final result = await resolve(<String>['ocak', 'firin']);
      expect(result.refusal, isNotNull);
      expect(result.printers, isEmpty);
    });

    test('one printer assigned to several stations on purpose keeps working', () async {
      // The real setup: "aa" serves adisyon, mutfak, kasap, Ocak and fırın.
      await save(
        printers: <Map<String, dynamic>>[_printer('aa', '192.168.10.100')],
        mappings: <Map<String, dynamic>>[
          for (final station in <String>['mutfak', 'kasap', 'ocak', 'firin'])
            _mapping(station, 'aa'),
        ],
        kitchenRole: 'aa',
      );
      final result = await resolve(<String>['mutfak', 'kasap', 'ocak', 'firin']);
      expect(result.refusal, isNull);
      expect(
        result.printers.map((p) => p.raw['host']).toSet(),
        <String>{'192.168.10.100'},
      );
      expect(result.printers, hasLength(4));
    });

    test('the printer that printed last is never used in place of a saved one', () async {
      await save(
        printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
        mappings: const <Map<String, dynamic>>[],
      );
      // No assignment and no saved kitchen role: refused, whatever printed last.
      expect((await resolve(<String>['ocak'])).refusal, 'no_kitchen_role_printer');
    });

    test('assignments not read yet are read once, then decided from the copy', () async {
      var loads = 0;
      Future<FastPathStationPrinters> ask() => resolveFastPathStationPrinters(
        restaurantId: 'rest-1',
        stationIds: const <String>['ocak'],
        toBridgeTarget: _fromRecord,
        loadSaved: () async {
          loads++;
          await save(
            printers: <Map<String, dynamic>>[_printer('p1', '192.168.10.100')],
            mappings: <Map<String, dynamic>>[_mapping('ocak', 'p1')],
          );
        },
      );
      expect((await ask()).printers.single.raw['host'], '192.168.10.100');
      expect((await ask()).printers.single.raw['host'], '192.168.10.100');
      expect(loads, 1);
    });

    test('a read that hangs does not hold the order: the queue path takes it', () async {
      final result = await resolveFastPathStationPrinters(
        restaurantId: 'rest-1',
        stationIds: const <String>['ocak'],
        toBridgeTarget: _fromRecord,
        loadTimeout: const Duration(milliseconds: 20),
        loadSaved: () => Future<void>.delayed(const Duration(seconds: 5)),
      );
      expect(result.refusal, 'station_printers_unknown');
    });
  });
}
