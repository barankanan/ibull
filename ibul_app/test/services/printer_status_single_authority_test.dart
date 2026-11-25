import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/printer_center/printer_service_status.dart';
import 'package:ibul_app/services/printer_link_status.dart';
import 'package:ibul_app/services/printer_readiness.dart';

/// The bottom-right chip, the Garson badge and the printer center must give
/// one answer about one printer. The reported fault: the chip said "Yazıcı
/// doğrulanmadı" while the printer center showed the same printer connected
/// and tickets printed. The printer answer was measured only by the Garson
/// page, and about the last address the bridge had written to, not about the
/// saved printers.
void main() {
  tearDown(PhysicalPrintGate.resetForTests);

  PrinterReadiness chip() => describePrinterReadiness(
    bridge: ReadinessBridge.online,
    registeredPrinters: 1,
    stationAssignments: 1,
    serviceEnabled: PhysicalPrintGate.allowed,
    isPrintCenter: true,
    printerReachable: PhysicalPrintGate.published?.printerReachable,
  );

  group('which printers the answer is about', () {
    test('saved network printers that carry a role', () {
      final targets = savedPrinterProbeTargets(<SavedPrinterTarget>[
        (host: '192.168.10.100', port: 9100, hasRole: true),
        (host: '192.168.10.101', port: 9100, hasRole: false),
      ]);
      expect(targets, <({String host, int port})>[
        (host: '192.168.10.100', port: 9100),
      ]);
    });

    test('every saved network printer when no role is assigned yet', () {
      final targets = savedPrinterProbeTargets(<SavedPrinterTarget>[
        (host: '192.168.10.100', port: 9100, hasRole: false),
        (host: ' 192.168.10.100 ', port: 9100, hasRole: false),
        (host: '', port: 9100, hasRole: false),
      ]);
      expect(targets, hasLength(1));
    });

    test('nothing to ask gives no answer, never "reachable"', () async {
      var asked = 0;
      final verdict = await probeSavedPrinters(
        const <({String host, int port})>[],
        (_, _) async {
          asked += 1;
          return true;
        },
      );
      expect(verdict, isNull);
      expect(asked, 0);
    });

    test('a wrong printer address is unreachable', () async {
      final verdict = await probeSavedPrinters(
        const <({String host, int port})>[(host: '10.9.9.9', port: 9100)],
        (_, _) async => false,
        retryDelay: Duration.zero,
      );
      expect(verdict, isFalse);
    });

    test('one printer of two not answering is not "ready"', () async {
      final verdict = await probeSavedPrinters(
        const <({String host, int port})>[
          (host: 'a', port: 9100),
          (host: 'b', port: 9100),
        ],
        (host, _) async => host == 'a',
        retryDelay: Duration.zero,
      );
      expect(verdict, isFalse);
    });

    test('a first "no" on a quiet network is asked again', () async {
      var asked = 0;
      final verdict = await probeSavedPrinters(
        const <({String host, int port})>[(host: 'a', port: 9100)],
        (_, _) async => ++asked > 1,
        retryDelay: Duration.zero,
      );
      expect(verdict, isTrue);
      expect(asked, 2);
    });

    test('a probe that throws counts as no answer', () async {
      final verdict = await probeSavedPrinters(
        const <({String host, int port})>[(host: 'a', port: 9100)],
        (_, _) async => throw Exception('socket'),
        retryDelay: Duration.zero,
      );
      expect(verdict, isFalse);
    });
  });

  group('one answer for every screen', () {
    test('after a restart the chip is verified without the Garson page: the '
        'hub asked the saved printer', () {
      PhysicalPrintGate.observe(true);
      // Hub health check: the bridge has no "last printed address" yet.
      PhysicalPrintGate.noteSavedPrinters(true);
      PhysicalPrintGate.publish(bridgeUp: true, serviceEnabled: true);
      expect(chip().chipLabel, 'Yazıcı Hazır');
      expect(PhysicalPrintGate.published!.printerReachable, isTrue);
    });

    test('before the fix: no saved-printer answer leaves "doğrulanmadı"', () {
      PhysicalPrintGate.observe(true);
      PhysicalPrintGate.publish(bridgeUp: true, serviceEnabled: true);
      expect(chip().chipLabel, 'Yazıcı doğrulanmadı');
    });

    test('the Garson page probing another address cannot overrule the saved '
        'printer answer', () {
      PhysicalPrintGate.observe(true);
      PhysicalPrintGate.noteSavedPrinters(false);
      // Garson poll: the last address the bridge wrote to still answers.
      PhysicalPrintGate.publish(
        bridgeUp: true,
        serviceEnabled: true,
        printerReachable: true,
        probedPrinter: true,
      );
      final garsonBadge = PhysicalPrintGate.published!.label;
      expect(garsonBadge, 'Yazıcıya ulaşılamıyor');
      expect(chip().chipLabel, 'Yazıcıya ulaşılamıyor');
    });

    test('a printer that went away is not shown as ready from an old answer',
        () {
      final t0 = DateTime(2026, 11, 25, 12);
      PhysicalPrintGate.noteSavedPrinters(true, now: t0);
      expect(
        PhysicalPrintGate.freshSavedPrintersVerdict(
          now: t0.add(const Duration(minutes: 2)),
        ),
        isTrue,
      );
      expect(
        PhysicalPrintGate.freshSavedPrintersVerdict(
          now: t0.add(const Duration(minutes: 4)),
        ),
        isNull,
      );
    });

    test('service switched off is "kapalı", not a connection fault', () {
      PhysicalPrintGate.observe(false);
      PhysicalPrintGate.noteSavedPrinters(true);
      PhysicalPrintGate.publish(bridgeUp: true, serviceEnabled: false);
      expect(PhysicalPrintGate.published!.label, 'Yazıcı servisi kapalı');
      expect(chip().chipLabel, 'Yazıcı servisi kapalı');
      expect(PhysicalPrintGate.allowsSend, isFalse);
    });

    test('bridge down is a bridge fault, not "service off" and not ready', () {
      PhysicalPrintGate.observe(true);
      PhysicalPrintGate.noteSavedPrinters(true);
      PhysicalPrintGate.publish(bridgeUp: false, serviceEnabled: null);
      final down = describePrinterReadiness(
        bridge: ReadinessBridge.offline,
        registeredPrinters: 1,
        serviceEnabled: true,
        printerReachable: PhysicalPrintGate.published?.printerReachable,
      );
      expect(down.chipLabel, 'Yazıcı köprüsü kapalı');
      expect(down.isReady, isFalse);
    });

    test('a reachable printer is "ready" but never "printed"', () {
      PhysicalPrintGate.observe(true);
      PhysicalPrintGate.noteSavedPrinters(true);
      PhysicalPrintGate.publish(bridgeUp: true, serviceEnabled: true);
      expect(chip().physicallyVerified, isFalse);
      expect(chip().detail, contains('baskı henüz doğrulanmadı'));
      expect(
        PhysicalPrintGate.published!.detail,
        contains('fişin çıktığını kanıtlamaz'),
      );
    });
  });

  group('Garson badge colour follows its text', () {
    const green = Color(0xFF16A34A);
    const red = Color(0xFFDC2626);

    test('service open, saved printer not answering is red (real screen '
        '2026-11-25: the text said "Yazıcıya ulaşılamıyor" in green)', () {
      final shown = printerBadgeAvailability(
        serviceAvailable: true,
        printerReachable: false,
      );
      expect(printerServiceStatusColor(shown), red);
    });

    test('service open and printer answering is green', () {
      final shown = printerBadgeAvailability(
        serviceAvailable: true,
        printerReachable: true,
      );
      expect(printerServiceStatusColor(shown), green);
    });

    test('service off stays red whatever the printer says', () {
      final shown = printerBadgeAvailability(
        serviceAvailable: false,
        printerReachable: true,
      );
      expect(printerServiceStatusColor(shown), red);
    });

    test('a printer that was not asked does not turn an open service red', () {
      expect(
        printerBadgeAvailability(serviceAvailable: true, printerReachable: null),
        isTrue,
      );
    });
  });
}
