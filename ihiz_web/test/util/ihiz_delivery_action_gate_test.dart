import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ihiz_web/src/util/ihiz_delivery_action_gate.dart';

void main() {
  test('süren aksiyon varken ikinci çağrı çalıştırılmaz', () async {
    final gate = IhizDeliveryActionGate();
    final pending = Completer<bool>();
    var runs = 0;

    final first = gate.runExclusive<bool>(() {
      runs++;
      return pending.future;
    });
    expect(gate.isBusy, isTrue);

    final second = await gate.runExclusive<bool>(() async {
      runs++;
      return true;
    });
    expect(second, isNull);
    expect(runs, 1);

    pending.complete(true);
    expect(await first, isTrue);
    expect(gate.isBusy, isFalse);
  });

  test('aksiyon hata verse de kilit serbest kalır', () async {
    final gate = IhizDeliveryActionGate();

    await expectLater(
      gate.runExclusive<bool>(() async => throw StateError('ağ hatası')),
      throwsStateError,
    );
    expect(gate.isBusy, isFalse);
    expect(await gate.runExclusive<bool>(() async => false), isFalse);
  });
}
