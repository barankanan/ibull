import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/models/printer_profile.dart';
import 'package:ibul_app/services/mobile_ethernet_printer_service.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  group('IP validasyonu', () {
    test('geçerli IPv4 kabul edilir', () {
      expect(isValidEthernetIpv4('192.168.1.100'), isTrue);
      expect(isValidEthernetIpv4('10.0.0.1'), isTrue);
    });

    test('geçersiz IP reddedilir', () {
      expect(isValidEthernetIpv4(''), isFalse);
      expect(isValidEthernetIpv4('yazıcı'), isFalse);
      expect(isValidEthernetIpv4('192.168.1'), isFalse);
      expect(isValidEthernetIpv4('192.168.1.999'), isFalse);
      expect(isValidEthernetIpv4('192.168.1.1.1'), isFalse);
    });
  });

  group('Port validasyonu', () {
    test('1-65535 arası geçerlidir', () {
      expect(MobileEthernetScanMath.isValidPort(9100), isTrue);
      expect(MobileEthernetScanMath.isValidPort(1), isTrue);
      expect(MobileEthernetScanMath.isValidPort(65535), isTrue);
    });

    test('aralık dışı ve null geçersizdir', () {
      expect(MobileEthernetScanMath.isValidPort(0), isFalse);
      expect(MobileEthernetScanMath.isValidPort(65536), isFalse);
      expect(MobileEthernetScanMath.isValidPort(-1), isFalse);
      expect(MobileEthernetScanMath.isValidPort(null), isFalse);
    });
  });

  group('Tarama aralığı üretimi', () {
    test('telefon 192.168.1.34 ise 1-254 arası taranır, kendi IP hariç', () {
      final hosts = MobileEthernetScanMath.buildScanHosts('192.168.1.34');
      expect(hosts.length, 253);
      expect(hosts.first, '192.168.1.1');
      expect(hosts.last, '192.168.1.254');
      expect(hosts.contains('192.168.1.34'), isFalse);
      expect(hosts.contains('192.168.1.0'), isFalse);
      expect(hosts.contains('192.168.1.255'), isFalse);
    });

    test('geçersiz local IP için boş liste döner', () {
      expect(MobileEthernetScanMath.buildScanHosts('bozuk'), isEmpty);
      expect(MobileEthernetScanMath.buildScanHosts(''), isEmpty);
    });

    test('subnet prefix doğru çözülür', () {
      expect(
        MobileEthernetScanMath.subnetPrefixOf('192.168.1.34'),
        '192.168.1',
      );
      expect(MobileEthernetScanMath.subnetPrefixOf('geçersiz'), isNull);
    });

    test('progress etiketi aralığı gösterir', () {
      expect(
        MobileEthernetScanMath.scanRangeLabel('192.168.1.34'),
        '192.168.1.1 - 192.168.1.254 taranıyor',
      );
    });
  });

  group('Yazıcı profili seçimi', () {
    test('Ethernet kurulum profilleri POS-80, POS-58 ve Generic içerir', () {
      final ids =
          PrinterProfile.ethernetSetupProfiles.map((p) => p.id).toList();
      expect(ids, contains(PrinterProfile.pos80.id));
      expect(ids, contains(PrinterProfile.pos58.id));
      expect(ids, contains(PrinterProfile.generic80mmEscpos.id));
    });

    test('profil id ile çözülür ve kesici bilgisi taşır', () {
      final pos80 = PrinterProfile.byId(PrinterProfile.pos80.id);
      expect(pos80, isNotNull);
      expect(pos80!.paperWidthMm, 80);
      final pos58 = PrinterProfile.byId(PrinterProfile.pos58.id);
      expect(pos58!.paperWidthMm, 58);
    });
  });

  group('ESC/POS test fişi payload', () {
    final now = DateTime(2026, 7, 14, 12, 30);

    test('init + CP857 codepage ile başlar', () {
      final bytes = MobileEscPosTestReceipt.build(
        host: '192.168.1.50',
        port: 9100,
        autoCut: true,
        now: now,
      );
      expect(bytes.sublist(0, 2), [0x1B, 0x40]); // ESC @
      expect(bytes.sublist(2, 5), [0x1B, 0x74, 13]); // ESC t 13 (CP857)
    });

    test('autoCut açıkken kesme komutuyla biter, kapalıyken bitmez', () {
      final withCut = MobileEscPosTestReceipt.build(
        host: '192.168.1.50',
        port: 9100,
        autoCut: true,
        now: now,
      );
      expect(
        withCut.sublist(withCut.length - 4),
        MobileEscPosTestReceipt.cutCommand,
      );
      final withoutCut = MobileEscPosTestReceipt.build(
        host: '192.168.1.50',
        port: 9100,
        autoCut: false,
        now: now,
      );
      expect(
        withoutCut.sublist(withoutCut.length - 4),
        isNot(MobileEscPosTestReceipt.cutCommand),
      );
    });

    test('cash drawer komutu (ESC p) asla gönderilmez', () {
      final bytes = MobileEscPosTestReceipt.build(
        host: '192.168.1.50',
        port: 9100,
        autoCut: true,
        now: now,
      );
      for (var i = 0; i < bytes.length - 1; i++) {
        expect(
          bytes[i] == 0x1B && bytes[i + 1] == 0x70,
          isFalse,
          reason: 'ESC p (cash drawer) payload içinde bulunmamalı',
        );
      }
    });

    test('Türkçe karakterler CP857 karşılıklarına çevrilir', () {
      final encoded = MobileEscPosTestReceipt.encodeCp857('ç ğ ı ö ş ü İ');
      expect(encoded, [
        0x87, 0x20, // ç
        0xA7, 0x20, // ğ
        0x8D, 0x20, // ı
        0x94, 0x20, // ö
        0x9F, 0x20, // ş
        0x81, 0x20, // ü
        0x98, // İ
      ]);
    });

    test('bilinmeyen karakter "?" olur, ASCII aynen geçer', () {
      expect(MobileEscPosTestReceipt.encodeCp857('AB1'), [0x41, 0x42, 0x31]);
      expect(MobileEscPosTestReceipt.encodeCp857('€'), [0x3F]);
    });

    test('fiş içeriği tarih, IP/port ve Türkçe test satırını içerir', () {
      final bytes = MobileEscPosTestReceipt.build(
        sellerName: 'Deneme Restoran',
        host: '192.168.1.50',
        port: 9100,
        autoCut: false,
        now: now,
      );
      List<int> enc(String s) => MobileEscPosTestReceipt.encodeCp857(s);
      bool containsSeq(List<int> haystack, List<int> needle) {
        for (var i = 0; i <= haystack.length - needle.length; i++) {
          var match = true;
          for (var j = 0; j < needle.length; j++) {
            if (haystack[i + j] != needle[j]) {
              match = false;
              break;
            }
          }
          if (match) return true;
        }
        return false;
      }

      expect(containsSeq(bytes, enc('İBUL')), isTrue);
      expect(containsSeq(bytes, enc('Yazıcı Testi')), isTrue);
      expect(containsSeq(bytes, enc('14.07.2026 12:30')), isTrue);
      expect(containsSeq(bytes, enc('Satıcı: Deneme Restoran')), isTrue);
      expect(containsSeq(bytes, enc('192.168.1.50:9100')), isTrue);
      expect(containsSeq(bytes, enc('ç ğ ı ö ş ü İ')), isTrue);
    });
  });

  group('Tarama oturumu iptali', () {
    test('cancel çağrılınca isCancelled true olur', () {
      final session = MobileEthernetScanSession();
      expect(session.isCancelled, isFalse);
      session.cancel();
      expect(session.isCancelled, isTrue);
    });
  });

  group('Kayıt / storage serileştirme', () {
    test('PrinterModel.fromMap Ethernet alanlarını korur', () {
      final printer = PrinterModel.fromMap(<String, dynamic>{
        'id': 'printer-1',
        'restaurant_id': 'seller-1',
        'name': 'Kasa Yazıcısı',
        'code': 'eth_192_168_1_50_9100',
        'connection_type': PrinterModel.networkConnectionType,
        'ip_address': '192.168.1.50',
        'port': 9100,
        'paper_width_mm': 80,
        'supports_cut': true,
        'is_active': true,
        'printer_profile_id': PrinterProfile.pos80.id,
        'created_at': '2026-07-14T09:00:00Z',
        'updated_at': '2026-07-14T09:30:00Z',
      });
      expect(printer.name, 'Kasa Yazıcısı');
      expect(printer.isEthernetConnection, isTrue);
      expect(printer.ipAddress, '192.168.1.50');
      expect(printer.paperWidthMm, 80);
      expect(printer.supportsCut, isTrue);
    });

    test('ethernetPrinterId deterministik üretilir', () {
      expect(
        PrinterModel.ethernetPrinterId(host: '192.168.1.50', port: 9100),
        PrinterModel.ethernetPrinterId(host: '192.168.1.50', port: 9100),
      );
      expect(
        PrinterModel.ethernetPrinterId(host: '192.168.1.50', port: 9100),
        isNot(PrinterModel.ethernetPrinterId(host: '192.168.1.51', port: 9100)),
      );
    });

    test('EthernetDiscoveredDevice json roundtrip', () {
      final device = EthernetDiscoveredDevice.fromJson(<String, dynamic>{
        'host': '192.168.1.77',
        'port': 9100,
        'reachable': true,
        'port_open': true,
        'same_subnet': true,
      });
      expect(device.host, '192.168.1.77');
      expect(device.port, 9100);
      expect(device.portOpen, isTrue);
      expect(device.endpointLabel, '192.168.1.77:9100');
    });
  });
}
