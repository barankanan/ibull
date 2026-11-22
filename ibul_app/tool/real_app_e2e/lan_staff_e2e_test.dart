// Drives a RUNNING isolated seller app over its real TLS LAN server as a
// waiter device. Not a unit test: it needs the app's LAN center to be up and
// is skipped unless IBUL_E2E_PORT is set. Never touches production.
//
//   IBUL_E2E_PORT=18783 IBUL_E2E_MATERIAL=<ibul-lan/<restaurantId>> \
//   IBUL_E2E_CLIENTS=<dir> IBUL_E2E_PHASE=pair|order|tables \
//   IBUL_E2E_STAFF=<auth user id> [IBUL_E2E_ORDER_ID=.. IBUL_E2E_TABLE=1] \
//   flutter test tool/real_app_e2e/lan_staff_e2e_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_cert_material.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_client.dart';

String _env(String key, [String fallback = '']) =>
    Platform.environment[key]?.trim().isNotEmpty == true
    ? Platform.environment[key]!.trim()
    : fallback;

void main() {
  final port = _env('IBUL_E2E_PORT');
  test('real-app LAN client', () async {
    final material = Directory(_env('IBUL_E2E_MATERIAL'));
    final staff = _env('IBUL_E2E_STAFF');
    final phase = _env('IBUL_E2E_PHASE');
    final label = _env('IBUL_E2E_LABEL', staff);
    final dir = Directory('${_env('IBUL_E2E_CLIENTS')}/$label');
    final base = Uri.parse('https://${_env('IBUL_E2E_HOST', '127.0.0.1')}:$port');
    final serverFp = certificateSha256Hex(
      await File('${material.path}/server.pem').readAsString(),
    );
    final ca = '${material.path}/ca.pem';

    RestaurantLanClient anonymous() => RestaurantLanClient(
      base,
      securityContext: SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(ca),
      pinnedServerFingerprint: serverFp,
    );

    void emit(String what, Map<String, dynamic> value) =>
        stdout.writeln('E2E $what ${jsonEncode(value)}');

    if (phase == 'pair') {
      final owner = RestaurantLanClient(
        base,
        securityContext: SecurityContext(withTrustedRoots: false)
          ..useCertificateChain('${material.path}/operator.pem')
          ..usePrivateKey('${material.path}/operator.key')
          ..setTrustedCertificates(ca),
        pinnedServerFingerprint: serverFp,
      );
      final issued = await owner.post('/lan/pair/issue', <String, Object?>{});
      final code = issued['code']?.toString() ?? '';
      if (code.isEmpty) {
        emit('pair', <String, dynamic>{'ok': false, 'step': 'issue', 'status': issued['status']});
        return;
      }
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      final request = await LanClientRequest.generate(directory: dir, commonName: staff);
      final redeemed = await anonymous().post('/lan/pair/redeem', <String, Object?>{
        'code': code,
        'staff_id': staff,
        'csr': request.csr,
      });
      if (redeemed['ok'] == true) {
        await request.installSignedCertificate(
          certificate: redeemed['certificate'].toString(),
          caPath: ca,
        );
      }
      emit('pair', <String, dynamic>{
        'ok': redeemed['ok'] == true,
        'status': redeemed['status'],
        'error': redeemed['error'],
      });
      return;
    }

    final client = RestaurantLanClient(
      base,
      securityContext: SecurityContext(withTrustedRoots: false)
        ..useCertificateChain('${dir.path}/client.pem')
        ..usePrivateKey('${dir.path}/client.key')
        ..setTrustedCertificates(ca),
      pinnedServerFingerprint: serverFp,
      staffId: staff,
    )..seq = DateTime.now().millisecondsSinceEpoch;

    if (phase == 'tables') {
      final tables = await client.postAuthorized('/lan/tables', <String, Object?>{});
      final products = await client.postAuthorized('/lan/products', <String, Object?>{});
      emit('tables', <String, dynamic>{
        'status': tables['status'],
        'tables': tables['tables'],
        'products_status': products['status'],
        'products': products['products'],
        'stations': products['stations'],
        'error': tables['error'],
      });
      return;
    }
    if (phase == 'order') {
      final sentAt = DateTime.now().millisecondsSinceEpoch;
      final result = await client.postAuthorized('/lan/orders', <String, Object?>{
        'local_order_id': _env('IBUL_E2E_ORDER_ID'),
        'table_number': int.parse(_env('IBUL_E2E_TABLE', '1')),
        'station_id': _env('IBUL_E2E_STATION'),
        'items': <Map<String, Object?>>[
          <String, Object?>{
            'name': _env('IBUL_E2E_ITEM', 'E2E Test Ürünü'),
            'quantity': 1,
            'price': int.parse(_env('IBUL_E2E_PRICE', '25')),
            'station_id': _env('IBUL_E2E_STATION'),
          },
        ],
      });
      emit('order', <String, dynamic>{
        'status': result['status'],
        'saved': result['saved'],
        'error': result['error'],
        'print_status': result['print_status'],
        'local_order_id': _env('IBUL_E2E_ORDER_ID'),
        'sent_ms': sentAt,
        'answer_ms': DateTime.now().millisecondsSinceEpoch,
        'duplicate': result['duplicate'],
      });
    }
  }, skip: port.isEmpty ? 'IBUL_E2E_PORT not set' : false);
}
