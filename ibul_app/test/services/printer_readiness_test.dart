import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart' show Color;
import 'package:ibul_app/services/printer_readiness.dart';
import 'package:ibul_app/widgets/desktop_print_status_bar.dart';

PrinterReadiness _all({
  ReadinessBridge bridge = ReadinessBridge.online,
  int? printers = 1,
  bool? service = true,
  bool? center = true,
  bool? reachable = true,
  int? stations = 2,
  bool verified = false,
  int pending = 0,
}) => describePrinterReadiness(
  bridge: bridge,
  registeredPrinters: printers,
  serviceEnabled: service,
  isPrintCenter: center,
  printerReachable: reachable,
  stationAssignments: stations,
  physicallyVerified: verified,
  pendingJobs: pending,
);

void main() {
  test('every prerequisite verified is the only way to "Yazıcı Hazır"', () {
    final ready = _all();
    expect(ready.level, PrinterReadinessLevel.ready);
    expect(ready.isReady, isTrue);
    expect(ready.chipLabel, 'Yazıcı Hazır');
    expect(ready.blocksPhysicalPrint, isFalse);
  });

  test('zero saved printers never reads as ready, even with a green bridge', () {
    final shown = _all(printers: 0);
    expect(shown.isReady, isFalse);
    expect(shown.level, PrinterReadinessLevel.noPrinter);
    expect(
      shown.headline,
      'Yazıcı eklenmedi — Mutfak ve adisyon fişleri basılamaz',
    );
    expect(shown.blocksPhysicalPrint, isTrue);
  });

  test('a bridge that does not answer blocks printing and names the bridge', () {
    for (final bridge in <ReadinessBridge>[
      ReadinessBridge.offline,
      ReadinessBridge.unknown,
      ReadinessBridge.error,
    ]) {
      final shown = _all(bridge: bridge);
      expect(shown.level, PrinterReadinessLevel.bridgeDown, reason: '$bridge');
      expect(shown.blocksPhysicalPrint, isTrue, reason: '$bridge');
      expect(shown.isReady, isFalse, reason: '$bridge');
    }
  });

  test('a bridge being checked is shown as checking, not ready or dead', () {
    final shown = _all(bridge: ReadinessBridge.checking);
    expect(shown.level, PrinterReadinessLevel.checking);
    expect(shown.chipLabel, 'Kontrol…');
    expect(shown.isReady, isFalse);
  });

  test('the master print permission gates printing: unknown and off both block', () {
    expect(_all(service: null).level, PrinterReadinessLevel.serviceUnknown);
    expect(_all(service: null).blocksPhysicalPrint, isTrue);
    expect(_all(service: false).level, PrinterReadinessLevel.serviceOff);
    expect(_all(service: false).blocksPhysicalPrint, isTrue);
  });

  test('a device that only sends orders cannot print physically', () {
    final shown = _all(center: false);
    expect(shown.level, PrinterReadinessLevel.notPrintCenter);
    expect(shown.headline, 'Bu cihaz yalnızca sipariş gönderir');
    expect(shown.blocksPhysicalPrint, isTrue);
    expect(shown.isReady, isFalse);
  });

  test('connection and printing are judged separately', () {
    expect(_all(reachable: false).level, PrinterReadinessLevel.unreachable);
    expect(_all(reachable: null).level, PrinterReadinessLevel.unverified);
    final ready = _all(verified: false);
    expect(ready.detail, contains('baskı henüz doğrulanmadı'));
    expect(ready.physicallyVerified, isFalse);
    final proven = _all(verified: true);
    expect(proven.detail, contains('fiziksel baskı doğrulandı'));
    expect(proven.physicallyVerified, isTrue);
  });

  test('a printer with no kitchen or receipt role is not ready', () {
    final shown = _all(stations: 0);
    expect(shown.level, PrinterReadinessLevel.noStation);
    expect(shown.isReady, isFalse);
  });

  test('unknown inputs never invent a green state', () {
    final shown = _all(printers: null, reachable: null, stations: null);
    expect(shown.isReady, isFalse);
  });

  test('queued jobs are reported without changing the verdict', () {
    final shown = _all(service: false, pending: 3);
    expect(shown.level, PrinterReadinessLevel.serviceOff);
    expect(shown.detail, contains('Kuyrukta bekleyen: 3'));
  });

  test('a saved printer without a role says the role is missing, not "unverified"', () {
    // Registration, connection and role are three separate facts: a printer
    // that is saved but has no kitchen/receipt role must not read as
    // "Yazıcı eklenmedi" nor hide behind an unprobed address.
    final shown = _all(printers: 1, stations: 0, reachable: null);
    expect(shown.level, PrinterReadinessLevel.noStation);
    expect(shown.headline, 'Mutfak/adisyon yazıcısı atanmadı');
    expect(shown.headline, isNot(contains('eklenmedi')));
    expect(shown.isReady, isFalse);
    // Zero records is still the only way to "Yazıcı eklenmedi".
    expect(_all(printers: 0, stations: 0).level, PrinterReadinessLevel.noPrinter);
  });

  test('the chip text and colour come from the verdict, not from the bridge', () {
    final (readyColor, readyText) = _Chip.of(_all());
    expect(readyText, 'Yazıcı Hazır');
    expect(readyColor, const Color(0xFF10B981));
    // Zero printers: a green bridge no longer produces a green chip.
    final (emptyColor, emptyText) = _Chip.of(_all(printers: 0));
    expect(emptyText, 'Yazıcı eklenmedi');
    expect(emptyColor, isNot(const Color(0xFF10B981)));
    final (downColor, downText) = _Chip.of(_all(bridge: ReadinessBridge.offline));
    expect(downText, 'Yazıcı köprüsü kapalı');
    expect(downColor, const Color(0xFFEF4444));
  });
}

class _Chip {
  static (Color, String) of(PrinterReadiness r) =>
      printerChipStyle(r);
}
