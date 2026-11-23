import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';

void main() {
  offlineReceiptTests();
  test('bulut yanıtsızsa yenileme bütçede kesilir, sonsuz beklemez', () async {
    final never = Future<void>.delayed(const Duration(hours: 1));
    final sw = Stopwatch()..start();
    final ok = await awaitWithinRefreshBudget(
      never,
      budget: const Duration(milliseconds: 50),
    );
    expect(ok, isFalse);
    expect(sw.elapsedMilliseconds, lessThan(1000));
  });

  test('hızlı yenileme true döner', () async {
    expect(await awaitWithinRefreshBudget(Future<void>.value()), isTrue);
  });

  test('hata iletilir (sessiz yutulmaz)', () async {
    expect(
      awaitWithinRefreshBudget(Future<void>.error(StateError('x'))),
      throwsStateError,
    );
  });
}

void offlineReceiptTests() {
  group('çevrimdışı adisyon notu', () {
    test('bulut yoksa not eklenir, mevcut alt not korunur', () {
      expect(
        receiptFooterForConnectivity(existingFooter: 'Afiyet olsun', cloudReachable: false),
        'Afiyet olsun\n$kOfflineReceiptNote',
      );
      expect(
        receiptFooterForConnectivity(existingFooter: '', cloudReachable: false),
        kOfflineReceiptNote,
      );
    });
    test('bulut varsa fiş değişmez; not iki kez eklenmez', () {
      expect(receiptFooterForConnectivity(existingFooter: 'x', cloudReachable: true), 'x');
      final once = receiptFooterForConnectivity(existingFooter: '', cloudReachable: false);
      expect(receiptFooterForConnectivity(existingFooter: once, cloudReachable: false), once);
    });
  });
}
