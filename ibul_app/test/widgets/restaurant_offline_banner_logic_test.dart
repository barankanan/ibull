import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/restaurant_offline_banner.dart';

void main() {
  group('waiterPrinterNotice', () {
    test('no saved printer is stated, not hidden behind "Çevrimiçi"', () {
      expect(
        waiterPrinterNotice(savedPrinters: 0),
        'Yazıcı eklenmedi — Mutfak ve adisyon fişleri basılamaz.',
      );
    });

    test('a saved printer or an unknown count raises no alarm', () {
      expect(waiterPrinterNotice(savedPrinters: 1), isNull);
      expect(waiterPrinterNotice(savedPrinters: 3), isNull);
      // Unknown (cache not read yet) must never invent a warning.
      expect(waiterPrinterNotice(savedPrinters: null), isNull);
    });
  });

  group('resolveSavedPrinterCount', () {
    test('the database count wins over an empty or stale cache', () {
      expect(resolveSavedPrinterCount(remoteCount: 1, cachedCount: 0), 1);
      expect(resolveSavedPrinterCount(remoteCount: 0, cachedCount: 2), 0);
    });

    test('an empty cache alone never claims "no printer"', () {
      expect(resolveSavedPrinterCount(remoteCount: null, cachedCount: 0), isNull);
      expect(resolveSavedPrinterCount(remoteCount: null, cachedCount: null), isNull);
      expect(resolveSavedPrinterCount(remoteCount: null, cachedCount: 2), 2);
    });
  });

  group('waiterCloudLine', () {
    test('plain "Çevrimiçi" only when nothing is waiting to sync', () {
      expect(waiterCloudLine(pendingSync: 0), 'Çevrimiçi');
    });

    test('waiting orders are never reported as plain online', () {
      final line = waiterCloudLine(pendingSync: 3);
      expect(line, isNot('Çevrimiçi'));
      expect(line, contains('3 yerel sipariş'));
      expect(line, contains('eşitlenmedi'));
    });
  });
}
