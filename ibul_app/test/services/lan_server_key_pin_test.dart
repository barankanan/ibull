import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_cert_material.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_client.dart';

Uint8List _der(String pem) => base64.decode(
  pem
      .split('\n')
      .where((line) => line.isNotEmpty && !line.startsWith('-----'))
      .join(),
);

void main() {
  test('a new address changes the certificate but not the key pin', () async {
    final directory = await Directory.systemTemp.createTemp('ibul-key-pin');
    addTearDown(() => directory.delete(recursive: true));
    await LanTlsMaterial.open(directory);
    final before = await File('${directory.path}/server.pem').readAsString();
    expect(
      await LanTlsMaterial.ensureServerAddress(directory, '192.168.10.158'),
      isTrue,
    );
    final after = await File('${directory.path}/server.pem').readAsString();

    expect(certificateSha256Hex(after), isNot(certificateSha256Hex(before)));
    final key = certificatePublicKeySha256Hex(_der(before));
    expect(key, hasLength(64));
    expect(certificatePublicKeySha256Hex(_der(after)), key);
    // The CA is another key: it must not satisfy the server pin.
    final ca = await File('${directory.path}/ca.pem').readAsString();
    expect(certificatePublicKeySha256Hex(_der(ca)), isNot(key));
    expect(certificatePublicKeySha256Hex(Uint8List.fromList(<int>[1, 2])), '');
  });

  test('the client follows the saved key and refuses any other server', () async {
    final directory = await Directory.systemTemp.createTemp('ibul-key-pin');
    final other = await Directory.systemTemp.createTemp('ibul-key-pin-other');
    addTearDown(() => directory.delete(recursive: true));
    addTearDown(() => other.delete(recursive: true));
    final first = await LanTlsMaterial.open(directory);
    final oldFingerprint = first.serverFingerprint;
    final key = certificatePublicKeySha256Hex(
      _der(await File('${directory.path}/server.pem').readAsString()),
    );
    await LanTlsMaterial.ensureServerAddress(directory, '192.168.10.158');
    final moved = await LanTlsMaterial.open(directory);
    expect(moved.serverFingerprint, isNot(oldFingerprint));

    Future<HttpServer> serve(SecurityContext context) async {
      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        context,
      );
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"service":"ibul-lan"}');
        await request.response.close();
      });
      return server;
    }

    final center = await serve(moved.serverContext);
    addTearDown(() => center.close(force: true));
    final stranger = await serve((await LanTlsMaterial.open(other)).serverContext);
    addTearDown(() => stranger.close(force: true));

    RestaurantLanClient client(int port, {String keyPin = ''}) {
      return RestaurantLanClient(
        Uri.parse('https://127.0.0.1:$port'),
        securityContext: SecurityContext(withTrustedRoots: false),
        pinnedServerFingerprint: oldFingerprint,
        pinnedServerKey: keyPin,
      );
    }

    // Old certificate pin alone: the moved center is not recognized.
    await expectLater(
      client(center.port).get('/lan/discover'),
      throwsA(isA<SocketException>()),
    );
    // With the saved key the same center is accepted on its new certificate.
    final paired = client(center.port, keyPin: key);
    expect((await paired.get('/lan/discover'))['service'], 'ibul-lan');
    expect(paired.seenServerFingerprint, moved.serverFingerprint);
    expect(paired.seenServerKey, key);
    // Another machine announcing itself does not hold the key.
    await expectLater(
      client(stranger.port, keyPin: key).get('/lan/discover'),
      throwsA(isA<SocketException>()),
    );
  });
}
