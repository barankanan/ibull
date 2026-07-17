import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_discovery_result.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  group('PrinterDiscoveryNaming.defaultNameFor', () {
    test('varsayılan ad son okteti içerir', () {
      expect(
        PrinterDiscoveryNaming.defaultNameFor('192.168.1.45'),
        'POS Yazıcı - 45',
      );
    });

    test('oktet çakışırsa tam IP kullanılır', () {
      expect(
        PrinterDiscoveryNaming.defaultNameFor(
          '192.168.1.45',
          existingNames: ['POS Yazıcı - 45'],
        ),
        'POS Yazıcı - 192.168.1.45',
      );
    });

    test('iki farklı cihaz farklı oktetlerle benzersiz olur', () {
      final first = PrinterDiscoveryNaming.defaultNameFor('192.168.1.45');
      final second = PrinterDiscoveryNaming.defaultNameFor(
        '192.168.1.87',
        existingNames: [first],
      );
      expect(first, 'POS Yazıcı - 45');
      expect(second, 'POS Yazıcı - 87');
      expect(first == second, isFalse);
    });
  });

  group('PrinterDiscoveryNaming.isDuplicateName', () {
    test('case-insensitive ve trim ile çakışma bulur', () {
      expect(
        PrinterDiscoveryNaming.isDuplicateName(
          '  kasa yazicisi  '.toUpperCase(),
          ['Kasa YAZICISI'],
        ),
        isTrue,
      );
      expect(
        PrinterDiscoveryNaming.isDuplicateName('Bar Yazıcısı', ['Kasa']),
        isFalse,
      );
      expect(PrinterDiscoveryNaming.isDuplicateName('', ['Kasa']), isFalse);
    });
  });

  group('PrinterDiscoveryNaming.applyTemplate', () {
    test('çakışma yoksa şablon adı aynen kullanılır', () {
      expect(
        PrinterDiscoveryNaming.applyTemplate(
          'Kasa Yazıcısı',
          '192.168.1.45',
        ),
        'Kasa Yazıcısı',
      );
    });

    test('çakışmada sonuna IP okteti eklenir', () {
      expect(
        PrinterDiscoveryNaming.applyTemplate(
          'Kasa Yazıcısı',
          '192.168.1.45',
          existingNames: ['Kasa Yazıcısı'],
        ),
        'Kasa Yazıcısı - 45',
      );
    });

    test('oktet de çakışırsa tam IP eklenir', () {
      expect(
        PrinterDiscoveryNaming.applyTemplate(
          'Kasa Yazıcısı',
          '192.168.1.45',
          existingNames: ['Kasa Yazıcısı', 'Kasa Yazıcısı - 45'],
        ),
        'Kasa Yazıcısı - 192.168.1.45',
      );
    });

    test('beş hızlı şablon mevcut', () {
      expect(PrinterDiscoveryNaming.quickNameTemplates, [
        'Kasa Yazıcısı',
        'Mutfak Yazıcısı',
        'Bar Yazıcısı',
        'Adisyon Yazıcısı',
        'Paket Yazıcısı',
      ]);
    });
  });

  group('PrinterDiscoveryNaming.suggestedRoleForTemplate', () {
    test('mutfak/bar şablonları mutfak rolü önerir', () {
      expect(
        PrinterDiscoveryNaming.suggestedRoleForTemplate('Mutfak Yazıcısı'),
        'mutfak',
      );
      expect(
        PrinterDiscoveryNaming.suggestedRoleForTemplate('Bar Yazıcısı'),
        'mutfak',
      );
    });

    test('kasa/adisyon/paket şablonları adisyon rolü önerir', () {
      for (final template in [
        'Kasa Yazıcısı',
        'Adisyon Yazıcısı',
        'Paket Yazıcısı',
      ]) {
        expect(
          PrinterDiscoveryNaming.suggestedRoleForTemplate(template),
          'adisyon',
          reason: template,
        );
      }
    });
  });

  group('PrinterDiscoveryNaming.lastOctet', () {
    test('IPv4 son okteti döner', () {
      expect(PrinterDiscoveryNaming.lastOctet('192.168.1.45'), '45');
    });

    test('geçersiz IP için girdiyi döner', () {
      expect(PrinterDiscoveryNaming.lastOctet('yazıcı'), 'yazıcı');
    });
  });

  group('PrinterDiscoveryResult ortak model', () {
    test('fromDevice tüm alanları taşır', () {
      const device = EthernetDiscoveredDevice(
        host: '192.168.1.45',
        port: 9100,
        reachable: true,
        portOpen: true,
        latencyMs: 12,
      );
      final result = PrinterDiscoveryResult.fromDevice(
        device,
        source: PrinterDiscoverySource.androidDirect,
        suggestedName: 'POS Yazıcı - 45',
        profileId: 'pos80',
      );
      expect(result.id, '192.168.1.45:9100');
      expect(result.ipAddress, '192.168.1.45');
      expect(result.port, 9100);
      expect(result.latencyMs, 12);
      expect(result.suggestedName, 'POS Yazıcı - 45');
      expect(result.editableName, 'POS Yazıcı - 45');
      expect(result.source.value, 'android_direct');
      expect(result.testStatus, PrinterDiscoveryTestStatus.notTested);
    });

    test('kaynak etiketleri sözleşmeye uyar', () {
      expect(PrinterDiscoverySource.androidDirect.value, 'android_direct');
      expect(PrinterDiscoverySource.desktopAgent.value, 'desktop_agent');
      expect(PrinterDiscoverySource.manual.value, 'manual');
    });
  });

  group('EthernetDiscoveredDevice latencyMs', () {
    test('json parse latency_ms okur', () {
      final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
        'host': '192.168.1.45',
        'port': 9100,
        'latency_ms': 23,
      });
      expect(device.latencyMs, 23);
    });

    test('latency yoksa null kalır', () {
      final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
        'host': '192.168.1.45',
        'port': 9100,
      });
      expect(device.latencyMs, isNull);
    });
  });
}
