import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/printer_error_messages.dart';

void main() {
  test('cups_queue_stuck maps to clear-queue action', () {
    final p = presentPrinterErrorCode(
      'cups_queue_stuck',
      platform: TargetPlatform.macOS,
      canClearQueue: true,
    );
    expect(p.title, contains('kuyruğu'));
    expect(p.canClearQueue, isTrue);
    expect(p.primaryActionLabel, 'Kuyruğu Temizle');
  });

  test('bridge_unreachable on Windows maps to download installer', () {
    final p = presentPrinterErrorCode(
      'bridge_unreachable',
      platform: TargetPlatform.windows,
    );
    expect(p.canDownloadInstaller, isTrue);
    expect(p.primaryActionLabel, 'Uygulamayı İndir');
  });

  test('stale_printer maps to rescan', () {
    final p = presentPrinterErrorCode(
      'stale_printer',
      platform: TargetPlatform.macOS,
    );
    expect(p.primaryActionLabel, 'Yeniden Tara');
    expect(p.severity, PrinterErrorSeverity.warning);
  });

  test('installer_missing has deploy/hosting hint', () {
    final p = presentPrinterErrorCode(
      'installer_missing',
      platform: TargetPlatform.windows,
    );
    expect(p.message, contains('IbulSellerSetup.exe'));
  });

  test('tcp_timeout maps to friendly unreachable title', () {
    final p = presentPrinterErrorCode('tcp_timeout');
    expect(p.title, 'Yazıcıya ulaşılamadı');
    expect(p.code, 'tcp_timeout');
  });

  test('tcp_refused is distinct from timeout', () {
    final refused = presentPrinterErrorCode('tcp_refused');
    final timeout = presentPrinterErrorCode('tcp_timeout');
    expect(refused.title, isNot(timeout.title));
    expect(refused.message, contains('port'));
  });

  test('tcp_unreachable normalizes to network_unreachable', () {
    final p = presentPrinterErrorCode('tcp_unreachable');
    expect(p.code, 'network_unreachable');
    expect(p.title, contains('Ağ'));
  });

  test('resolveEthernetConnectionProbeResult maps timeout with subnet hint', () {
    final diagnostic = resolveEthernetConnectionProbeResult(
      <String, dynamic>{
        'ok': false,
        'errorCode': 'tcp_timeout',
        'error': '192.168.1.100:9100 zaman aşımı',
        'local_ips': <String>['192.168.1.34'],
        'same_subnet': true,
        'reachable': false,
        'port_open': false,
      },
      host: '192.168.1.100',
      port: 9100,
    );
    expect(diagnostic.ok, isFalse);
    expect(diagnostic.errorCode, 'tcp_timeout');
    expect(diagnostic.title, 'Yazıcıya ulaşılamadı');
    expect(diagnostic.message, contains('192.168.1.100:9100'));
    expect(diagnostic.message, contains('Bilgisayar IP: 192.168.1.34'));
  });

  test('resolveEthernetConnectionProbeResult flags different subnet', () {
    final diagnostic = resolveEthernetConnectionProbeResult(
      <String, dynamic>{
        'ok': false,
        'errorCode': 'tcp_unreachable',
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
        'suggested_message':
            'Bilgisayarınız 192.168.10.x ağında, yazıcı 192.168.1.x ağında. '
            'Bu cihazlar aynı ağda değil. Yazıcı IP\'sini işletme ağına alın.',
      },
      host: '192.168.1.100',
      port: 9100,
    );
    expect(diagnostic.errorCode, 'network_unreachable');
    expect(diagnostic.message, contains('192.168.10.x'));
    expect(diagnostic.message, contains('işletme ağına alın'));
  });

  test('formatDifferentSubnetWarning uses operator-friendly copy', () {
    final message = formatDifferentSubnetWarning(
      localIps: <String>['192.168.10.158'],
      printerHost: '192.168.1.100',
    );
    expect(message, contains('192.168.10.x'));
    expect(message, contains('192.168.1.x'));
    expect(message, contains('işletme ağına alın'));
  });

  test('parseEthernetScanResult maps discovered devices', () {
    final result = parseEthernetScanResult(<String, dynamic>{
      'ok': true,
      'local_ips': <String>['192.168.10.158'],
      'subnets': <String>['192.168.10.0/24'],
      'devices': <Map<String, dynamic>>[
        <String, dynamic>{
          'host': '192.168.10.55',
          'port': 9100,
          'reachable': true,
          'port_open': true,
        },
      ],
    });
    expect(result.ok, isTrue);
    expect(result.devices, hasLength(1));
    expect(result.devices.first.host, '192.168.10.55');
    expect(result.primarySubnet, '192.168.10.0/24');
  });

  test('suggestEthernetNetworkSettings derives migration target from local IP', () {
    final plan = suggestEthernetNetworkSettings(
      <String>['192.168.10.158'],
      printerHost: '192.168.1.100',
    );
    expect(plan.suggestedPrinterIp, '192.168.10.100');
    expect(plan.suggestedTargetSubnet, '192.168.10.0/24');
    expect(plan.suggestedGateway, '192.168.10.1');
    expect(plan.hasMismatch, isTrue);
    expect(plan.networkState, 'network_mismatch');
  });

  test('ethernetScanNoDeviceMessage explains cross-subnet manual IP', () {
    final message = ethernetScanNoDeviceMessage(
      scanResult: const EthernetScanResult(
        ok: true,
        localIps: <String>['192.168.10.158'],
        subnets: <String>['192.168.10.0/24'],
        noDeviceReason: 'printer_on_different_subnet',
      ),
      printerHost: '192.168.1.100',
    );
    expect(message, contains('Self-test fişindeki IP farklı ağdaysa'));
  });

  test('resolveEthernetConnectionProbeResult maps network_mismatch code', () {
    final diagnostic = resolveEthernetConnectionProbeResult(
      <String, dynamic>{
        'ok': false,
        'errorCode': 'network_mismatch',
        'local_ips': <String>['192.168.10.158'],
        'same_subnet': false,
        'suggested_printer_ip': '192.168.10.100',
        'suggested_message':
            'Bilgisayarınız 192.168.10.x ağında, yazıcı 192.168.1.x ağında. '
            'Bu cihazlar aynı ağda değil. Yazıcı IP\'sini işletme ağına alın.',
      },
      host: '192.168.1.100',
      port: 9100,
    );
    expect(diagnostic.errorCode, 'network_mismatch');
    expect(diagnostic.title, 'Ağ uyumsuzluğu');
    expect(diagnostic.message, contains('192.168.10.x'));
  });

  test('ethernetTechnicalAliasCommands are generated for printer subnet', () {
    final commands = ethernetTechnicalAliasCommands(
      printerHost: '192.168.1.100',
    );
    expect(commands, hasLength(2));
    expect(commands.first, contains('192.168.1.50'));
  });
}
