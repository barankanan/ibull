import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';
import 'package:ibul_app/services/restaurant_offline/lan_tls.dart';

void main() {
  test('only an explicit private interface can be saved', () async {
    final choices = trustedLanInterfaces(<LanRawInterfaceAddress>[
      LanRawInterfaceAddress(
        name: 'lo0',
        address: InternetAddress.loopbackIPv4,
      ),
      LanRawInterfaceAddress(name: 'utun0', address: InternetAddress('10.8.0.2')),
      LanRawInterfaceAddress(name: 'en0', address: InternetAddress('192.168.1.20')),
      LanRawInterfaceAddress(name: 'en0', address: InternetAddress('8.8.8.8')),
    ]);
    expect(choices, hasLength(1));
    expect(choices.single.address, '192.168.1.20');
    expect(
      preferredTrustedLanInterface(const <LanInterfaceChoice>[
        LanInterfaceChoice(name: 'en1', address: '10.0.0.4'),
        LanInterfaceChoice(name: 'en0', address: '192.168.1.20'),
      ])?.address,
      '192.168.1.20',
    );
    expect(
      preferredTrustedLanInterface(const <LanInterfaceChoice>[
        LanInterfaceChoice(name: 'en1', address: '10.0.0.4'),
        LanInterfaceChoice(name: 'en0', address: '192.168.1.20'),
      ])?.address,
      '192.168.1.20',
    );

    final changed = checkSavedLanAddress(
      saved: const LanInterfaceSelection(name: 'en0', address: '192.168.1.20'),
      current: const <LanInterfaceChoice>[
        LanInterfaceChoice(name: 'en0', address: '192.168.1.40'),
      ],
    );
    expect(changed.state, LanSavedAddressState.changed);

    final blocked = decideAuthorityStart(
      interfaceSelected: true,
      operatorConfirmed: true,
      localMachineId: 'machine-a',
      restaurantId: 'rest',
      remoteDiscover: const <String, dynamic>{
        'service': 'ibul-lan',
        'restaurant_id': 'rest',
        'machine_id': 'machine-b',
      },
    );
    expect(blocked.allow, isFalse);
    expect(blocked.provesNoOtherServer, isFalse);
    expect(blocked.message, contains('Otomatik devralma yok'));
    final unanswered = decideAuthorityStart(
      interfaceSelected: true,
      operatorConfirmed: true,
      localMachineId: 'machine-a',
      restaurantId: 'rest',
    );
    expect(unanswered.allow, isTrue);
    expect(unanswered.provesNoOtherServer, isFalse);
    expect(unanswered.message, contains('kanıtlanmadı'));

    final directory = await Directory.systemTemp.createTemp('ibul-bind');
    final store = LanBindStore(directory);
    await store.write(
      const LanInterfaceSelection(name: 'en0', address: '192.168.1.20'),
    );
    final saved = await store.read();
    expect(saved?.address, '192.168.1.20');
    expect(lanFirewallNote('macos'), contains('macOS'));
    expect(lanFirewallNote('windows'), contains('Windows'));
  });

  test('server certificate names the selected address', () async {
    final directory = await Directory.systemTemp.createTemp('ibul-san');
    await LanTlsMaterial.open(directory);
    final reissued = await LanTlsMaterial.ensureServerAddress(
      directory,
      '192.168.1.20',
    );
    expect(reissued, isTrue);
    final again = await LanTlsMaterial.ensureServerAddress(
      directory,
      '192.168.1.20',
    );
    expect(again, isFalse);
    final text = await Process.run('openssl', <String>[
      'x509',
      '-in',
      '${directory.path}/server.pem',
      '-noout',
      '-ext',
      'subjectAltName',
    ]);
    expect('${text.stdout}', contains('192.168.1.20'));
    expect('${text.stdout}', contains('127.0.0.1'));
    final material = await LanTlsMaterial.open(directory);
    expect(material.serverFingerprint, hasLength(64));
  });
}
