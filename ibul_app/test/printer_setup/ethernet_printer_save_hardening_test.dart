import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/printer_profile.dart';

void main() {
  group('PrinterProfile canonicalDatabaseId', () {
    test('UI POS-80 label maps to canonical pos80', () {
      expect(PrinterProfile.canonicalDatabaseId('POS-80'), 'pos80');
      expect(PrinterProfile.canonicalDatabaseId('pos80'), 'pos80');
    });

    test('generic 80mm profile stays canonical', () {
      expect(
        PrinterProfile.canonicalDatabaseId('generic_80mm_escpos'),
        'generic_80mm_escpos',
      );
    });

    test('POS-58 maps to pos58', () {
      expect(PrinterProfile.canonicalDatabaseId('POS-58'), 'pos58');
    });

    test('unknown profile returns null', () {
      expect(PrinterProfile.canonicalDatabaseId('not-a-profile'), isNull);
    });
  });

  group('Ethernet endpoint helpers', () {
    test('device_identifier uses tcp host port format', () {
      expect(
        PrinterModel.ethernetPrinterId(host: '192.168.10.100', port: 9100),
        'tcp:192.168.10.100:9100',
      );
    });

    test('default port is 9100', () {
      expect(PrinterModel.ethernetDefaultPort, 9100);
    });
  });

  group('Ethernet form naming', () {
    test('empty name resolves to host-based default', () {
      const host = '192.168.10.100';
      final generated = 'Ethernet Yazıcı $host';
      expect(generated, 'Ethernet Yazıcı 192.168.10.100');
    });
  });
}
