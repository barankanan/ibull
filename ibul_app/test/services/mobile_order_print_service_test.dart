import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/printer_model.dart';
import 'package:ibul_app/services/mobile_ethernet_printer_service.dart';
import 'package:ibul_app/services/mobile_order_print_service.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

/// Test fişiyle AYNI transport sınıfını (MobileEthernetPrinterService)
/// genişletir; socket açmak yerine gönderilen byte'ları kaydeder.
class _FakeTransport extends MobileEthernetPrinterService {
  final List<({String host, int port, List<int> bytes})> sent = [];
  bool failNext = false;

  @override
  Future<EthernetConnectionDiagnostic> sendBytes({
    required String host,
    required int port,
    required List<int> bytes,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (failNext) {
      return EthernetConnectionDiagnostic(
        ok: false,
        errorCode: 'connection_refused',
        title: 'Yazıcıya ulaşılamadı',
        message: 'Yazıcıya ulaşılamadı. Telefon ve yazıcı aynı Wi-Fi '
            'ağında mı kontrol edin.',
        host: host,
        port: port,
      );
    }
    sent.add((host: host, port: port, bytes: bytes));
    return EthernetConnectionDiagnostic(
      ok: true,
      errorCode: 'ready',
      title: 'Gönderildi',
      message: 'Gönderildi.',
      host: host,
      port: port,
    );
  }
}

PrinterModel buildPrinter({
  String id = 'printer-1',
  String name = 'Kasa Yazıcısı',
  String ip = '192.168.1.50',
  int port = 9100,
  bool isActive = true,
  List<String> roles = const <String>[],
  String connectionType = PrinterModel.networkConnectionType,
}) {
  return PrinterModel.fromMap(<String, dynamic>{
    'id': id,
    'restaurant_id': 'seller-1',
    'name': name,
    'code': 'eth_${ip.replaceAll('.', '_')}_$port',
    'connection_type': connectionType,
    'ip_address': ip,
    'port': port,
    'paper_width_mm': 80,
    'supports_cut': true,
    'is_active': isActive,
    'printer_profile_id': 'pos80',
    'assigned_roles': roles,
  });
}

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

bool bytesContainText(List<int> bytes, String text) =>
    containsSeq(bytes, MobileEscPosTestReceipt.encodeCp857(text));

Map<String, dynamic> buildPayload({
  List<Map<String, dynamic>>? items,
  String itemsKey = 'items',
}) {
  return <String, dynamic>{
    'store_name': 'Deneme Restoran',
    'branch': 'MERKEZ ŞUBE',
    'table_no': '5',
    'display_table_label': 'Bahçe Masa 5',
    'order_created_at': '2026-07-16T12:30:00',
    itemsKey: items ??
        <Map<String, dynamic>>[
          {'name': 'Adana Dürüm', 'qty': 2, 'price': 120.0, 'total': 240.0},
        ],
    'grand_total': 240.0,
  };
}

void main() {
  setUp(MobileOrderPrintService.resetDuplicateGuardForTest);

  MobileOrderPrintService buildService({
    required _FakeTransport transport,
    List<PrinterModel>? printers,
    DateTime Function()? now,
  }) {
    return MobileOrderPrintService(
      transport: transport,
      fetchPrinters: (_) async => printers ?? [buildPrinter()],
      now: now,
    );
  }

  group('MobileEscPosOrderReceipt builder', () {
    test('tek ürünlü fişte ürün adı ve adet bulunur', () {
      final payload = buildPayload();
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, '2 x Adana Dürüm'), isTrue);
      expect(bytesContainText(bytes, 'Deneme Restoran'), isTrue);
      expect(bytesContainText(bytes, 'Bahçe Masa 5'), isTrue);
      expect(bytesContainText(bytes, 'TOPLAM'), isTrue);
    });

    test('çok ürünlü siparişte bütün ürünler fişe eklenir', () {
      final payload = buildPayload(items: [
        {'name': 'Adana Dürüm', 'qty': 2, 'total': 240.0},
        {'name': 'Ayran', 'qty': 3, 'total': 45.0},
        {'name': 'Künefe', 'qty': 1, 'total': 90.0},
      ]);
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'Adana Dürüm'), isTrue);
      expect(bytesContainText(bytes, 'Ayran'), isTrue);
      expect(bytesContainText(bytes, 'Künefe'), isTrue);
    });

    test('ürün adı farklı map alanlarından güvenli okunur', () {
      expect(
        MobileEscPosOrderReceipt.resolveItemName({'display_label': 'A'}),
        'A',
      );
      expect(MobileEscPosOrderReceipt.resolveItemName({'name': 'B'}), 'B');
      expect(
        MobileEscPosOrderReceipt.resolveItemName({'product_name': 'C'}),
        'C',
      );
      expect(MobileEscPosOrderReceipt.resolveItemName({'title': 'D'}), 'D');
      expect(MobileEscPosOrderReceipt.resolveItemName({'name': ''}), '-');
    });

    test('quantity int, double ve string olduğunda doğru dönüştürülür', () {
      expect(MobileEscPosOrderReceipt.resolveQuantity({'qty': 3}), 3);
      expect(MobileEscPosOrderReceipt.resolveQuantity({'quantity': 2.0}), 2);
      expect(MobileEscPosOrderReceipt.resolveQuantity({'count': '4'}), 4);
      expect(MobileEscPosOrderReceipt.resolveQuantity({'qty': '2,0'}), 2);
      expect(MobileEscPosOrderReceipt.resolveQuantity({'qty': 0}), 1);
      expect(MobileEscPosOrderReceipt.resolveQuantity({}), 1);
    });

    test('items farklı payload anahtarlarından yüklenir', () {
      for (final key in ['items', 'order_items', 'orderItems', 'cart_items']) {
        final items = MobileEscPosOrderReceipt.extractItems({
          key: [
            {'name': 'Ürün', 'qty': 1},
          ],
        });
        expect(items, hasLength(1), reason: key);
      }
      expect(MobileEscPosOrderReceipt.extractItems({'items': []}), isEmpty);
      expect(MobileEscPosOrderReceipt.extractItems({}), isEmpty);
    });

    test('Türkçe karakter içeren ürün adları kaybolmaz (CP857)', () {
      final payload = buildPayload(items: [
        {'name': 'Çiğ Köfte Şöleni', 'qty': 1, 'total': 75.0},
      ]);
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'Çiğ Köfte Şöleni'), isTrue);
      // Soru işaretine düşmediğini de doğrula: 'Çiğ' → C387 değil CP857 0x80.
      expect(bytesContainText(bytes, '?i? K?fte'), isFalse);
    });

    test('ürün notu ve miktar etiketi fişe eklenir', () {
      final payload = buildPayload(items: [
        {
          'name': 'Kuşbaşı',
          'qty': 1,
          'total': 150.0,
          'amount_label': '500 g',
          'note': 'az pişmiş',
        },
      ]);
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, '500 g'), isTrue);
      expect(bytesContainText(bytes, 'Not: az pişmiş'), isTrue);
    });

    test('formatLine sağa hizalar ve uzun adı kısaltır', () {
      expect(
        MobileEscPosOrderReceipt.formatLine('2 x Ayran', '45.00', 32).length,
        32,
      );
      final line = MobileEscPosOrderReceipt.formatLine(
        'Çok Uzun Bir Ürün Adı ' * 3,
        '999.00',
        32,
      );
      expect(line.length, 32);
      expect(line.endsWith('999.00'), isTrue);
    });

    test('fiş alt notu (footer_note) fişin altına basılır', () {
      final payload = buildPayload()
        ..['footer_note'] = 'Afiyet olsun, yine bekleriz.';
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'Afiyet olsun, yine bekleriz.'), isTrue);
    });

    test('footer_note yoksa alt not basılmaz (boş footer üretilmez)', () {
      final payload = buildPayload();
      expect(payload.containsKey('footer_note'), isFalse);
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'Afiyet olsun'), isFalse);
    });

    test('şube/telefon payloadda yoksa fişe hiç basılmaz (demo fallback yok)',
        () {
      final payload = buildPayload()..remove('branch');
      // Ne şube satırı ne de "Tel:" öneki basılmalı; asla MERKEZ ŞUBE/555.
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'MERKEZ ŞUBE'), isFalse);
      expect(bytesContainText(bytes, 'Tel:'), isFalse);
    });

    test('telefon doluysa "Tel:" öneki ile basılır', () {
      final payload = buildPayload()
        ..['phone'] = '05376247077'
        ..remove('branch');
      final bytes = MobileEscPosOrderReceipt.build(
        payload: payload,
        items: MobileEscPosOrderReceipt.extractItems(payload),
      );
      expect(bytesContainText(bytes, 'Tel: 05376247077'), isTrue);
    });
  });

  group('MobileOrderPrintService routing', () {
    test('kategori/rol ataması olmayan aktif yazıcı tüm ürünleri alır',
        () async {
      final transport = _FakeTransport();
      final service = buildService(
        transport: transport,
        printers: [buildPrinter(roles: const [])],
      );
      final result = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(items: [
          {'name': 'Ürün A', 'qty': 1, 'total': 10.0},
          {'name': 'Ürün B', 'qty': 2, 'total': 20.0},
        ]),
        orderId: 'order-1',
      );
      expect(result.ok, isTrue);
      expect(transport.sent, hasLength(1));
      expect(bytesContainText(transport.sent.single.bytes, 'Ürün A'), isTrue);
      expect(bytesContainText(transport.sent.single.bytes, 'Ürün B'), isTrue);
    });

    test('receipt rolü atanan yazıcı tercih edilir', () async {
      final service = MobileOrderPrintService(
        transport: _FakeTransport(),
        fetchPrinters: (_) async => [
          buildPrinter(id: 'kitchen-1', ip: '192.168.1.60', roles: ['kitchen']),
          buildPrinter(id: 'receipt-1', ip: '192.168.1.50', roles: ['receipt']),
        ],
      );
      final resolved = await service.resolveReceiptPrinter('seller-1');
      expect(resolved?.id, 'receipt-1');
    });

    test('yalnız mutfak rolü varsa güvenli fallback yine basar', () async {
      final service = MobileOrderPrintService(
        transport: _FakeTransport(),
        fetchPrinters: (_) async => [
          buildPrinter(id: 'kitchen-1', roles: ['kitchen']),
        ],
      );
      final resolved = await service.resolveReceiptPrinter('seller-1');
      expect(resolved?.id, 'kitchen-1');
    });

    test('pasif ve ethernet olmayan yazıcılar elenir', () async {
      final service = MobileOrderPrintService(
        transport: _FakeTransport(),
        fetchPrinters: (_) async => [
          buildPrinter(id: 'inactive', isActive: false),
          buildPrinter(id: 'usb', connectionType: 'usb'),
        ],
      );
      expect(await service.resolveReceiptPrinter('seller-1'), isNull);
    });

    test('kayıtlı yazıcı yeniden açılışta repository üzerinden bulunur',
        () async {
      // Kalıcılık Supabase `printers` tablosunda; resolver her çağrıda
      // repository'den okur — uygulama yeniden başlasa da aynı kayıt döner.
      var fetchCount = 0;
      final service = MobileOrderPrintService(
        transport: _FakeTransport(),
        fetchPrinters: (restaurantId) async {
          fetchCount++;
          expect(restaurantId, 'seller-1');
          return [buildPrinter()];
        },
      );
      final resolved = await service.resolveReceiptPrinter('seller-1');
      expect(resolved, isNotNull);
      expect(resolved!.ethernetHost, '192.168.1.50');
      expect(resolved.ethernetPort, 9100);
      expect(fetchCount, 1);
    });
  });

  group('MobileOrderPrintService baskı yönetimi', () {
    test('boş ürün listesinde socket çağrılmaz ve açıklayıcı hata döner',
        () async {
      final transport = _FakeTransport();
      final service = buildService(transport: transport);
      final result = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(items: []),
        orderId: 'order-1',
      );
      expect(result.ok, isFalse);
      expect(result.errorCode, 'empty_items');
      expect(transport.sent, isEmpty);
    });

    test('yazıcı yoksa açıklayıcı hata döner, socket çağrılmaz', () async {
      final transport = _FakeTransport();
      final service = buildService(transport: transport, printers: []);
      final result = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-1',
      );
      expect(result.ok, isFalse);
      expect(result.errorCode, 'printer_not_found');
      expect(transport.sent, isEmpty);
    });

    test('aynı sipariş kısa aralıkta iki kez basılmaz', () async {
      final transport = _FakeTransport();
      var fakeNow = DateTime(2026, 7, 16, 12, 0, 0);
      final service = buildService(
        transport: transport,
        now: () => fakeNow,
      );
      final first = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-dup',
      );
      expect(first.ok, isTrue);
      final second = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-dup',
      );
      expect(second.ok, isFalse);
      expect(second.errorCode, 'duplicate_print_suppressed');
      expect(transport.sent, hasLength(1));
      // Pencere geçince tekrar basılabilir.
      fakeNow = fakeNow.add(const Duration(seconds: 9));
      final third = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-dup',
      );
      expect(third.ok, isTrue);
      expect(transport.sent, hasLength(2));
    });

    test('transport hatası ok=false döner, başarı mesajı üretilmez', () async {
      final transport = _FakeTransport()..failNext = true;
      final service = buildService(transport: transport);
      final result = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-1',
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('aynı Wi-Fi'));
    });

    test('sipariş baskısı test fişiyle aynı transport sınıfını kullanır',
        () async {
      final transport = _FakeTransport();
      final service = buildService(transport: transport);
      // Aynı instance hem test fişini hem siparişi gönderebilmeli.
      final testResult = await transport.printTestReceipt(
        host: '192.168.1.50',
        port: 9100,
      );
      expect(testResult.ok, isTrue);
      final orderResult = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-1',
      );
      expect(orderResult.ok, isTrue);
      // İki baskı da aynı sendBytes yolundan geçti.
      expect(transport.sent, hasLength(2));
      expect(transport.sent.first.host, transport.sent.last.host);
    });

    test('doğru IP ve porta gönderilir', () async {
      final transport = _FakeTransport();
      final service = buildService(
        transport: transport,
        printers: [buildPrinter(ip: '10.0.0.77', port: 9101)],
      );
      final result = await service.printReceiptPayload(
        restaurantId: 'seller-1',
        payload: buildPayload(),
        orderId: 'order-1',
      );
      expect(result.ok, isTrue);
      expect(transport.sent.single.host, '10.0.0.77');
      expect(transport.sent.single.port, 9101);
    });
  });
}
