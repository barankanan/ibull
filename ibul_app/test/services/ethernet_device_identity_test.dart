import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  test('an open port alone is never labelled as a printer', () {
    final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
      'host': '192.168.10.60',
      'port': 9100,
      'reachable': true,
      'port_open': true,
    });
    expect(device.printerVerified, isFalse);
    expect(device.reachabilityLabel, 'Port açık · yazıcı doğrulanamadı');
  });

  test('only a verified status reply is labelled as a printer', () {
    final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
      'host': '192.168.10.55',
      'port': 9100,
      'reachable': true,
      'port_open': true,
      'printer_verified': true,
    });
    expect(device.printerVerified, isTrue);
    expect(device.reachabilityLabel, 'Yazıcı doğrulandı');
  });

  test('a bridge that does not send the flag counts as unverified', () {
    final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
      'host': '192.168.10.70',
      'port': 9100,
      'port_open': true,
      'printer_verified': 'true',
    });
    expect(device.printerVerified, isFalse);
  });

  test('a closed port reports no answer', () {
    final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
      'host': '192.168.10.80',
      'port': 9100,
    });
    expect(device.reachabilityLabel, 'Yanıt yok');
  });
}
