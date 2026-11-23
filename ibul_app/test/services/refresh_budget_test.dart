import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';

void main() {
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
