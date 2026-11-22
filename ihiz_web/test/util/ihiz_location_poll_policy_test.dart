import 'package:flutter_test/flutter_test.dart';
import 'package:ihiz_web/src/util/ihiz_location_poll_policy.dart';

void main() {
  final t0 = DateTime(2026, 11, 17, 12);

  int pollsIn(
    Duration window, {
    required bool hasActiveDelivery,
    required bool courierOnline,
  }) {
    final policy = IhizLocationPollPolicy();
    var polls = 0;
    // Zamanlayıcı 5 sn'de bir tik atar.
    for (var s = 0; s < window.inSeconds; s += 5) {
      if (policy.shouldPoll(
        now: t0.add(Duration(seconds: s)),
        hasActiveDelivery: hasActiveDelivery,
        courierOnline: courierOnline,
      )) {
        polls += 1;
      }
    }
    return polls;
  }

  test('aktif teslimatta her tikte sorgu yapılır', () {
    expect(
      pollsIn(
        const Duration(minutes: 1),
        hasActiveDelivery: true,
        courierOnline: true,
      ),
      12,
    );
  });

  test('çevrimiçi ama boşta iken sorgu seyrekleşir', () {
    expect(
      pollsIn(
        const Duration(minutes: 1),
        hasActiveDelivery: false,
        courierOnline: true,
      ),
      4,
    );
  });

  test('çevrimdışı iken dakikada bir sorgu yapılır', () {
    expect(
      pollsIn(
        const Duration(minutes: 1),
        hasActiveDelivery: false,
        courierOnline: false,
      ),
      1,
    );
  });

  test('teslimat başlayınca sonraki tikte hemen sorgu yapılır', () {
    final policy = IhizLocationPollPolicy();
    expect(
      policy.shouldPoll(
        now: t0,
        hasActiveDelivery: false,
        courierOnline: false,
      ),
      isTrue,
    );
    expect(
      policy.shouldPoll(
        now: t0.add(const Duration(seconds: 5)),
        hasActiveDelivery: false,
        courierOnline: false,
      ),
      isFalse,
    );
    expect(
      policy.shouldPoll(
        now: t0.add(const Duration(seconds: 10)),
        hasActiveDelivery: true,
        courierOnline: true,
      ),
      isTrue,
    );
  });

  test('saat geri alınırsa sorgu engellenmez', () {
    final policy = IhizLocationPollPolicy();
    policy.shouldPoll(now: t0, hasActiveDelivery: false, courierOnline: false);
    expect(
      policy.shouldPoll(
        now: t0.subtract(const Duration(minutes: 5)),
        hasActiveDelivery: false,
        courierOnline: false,
      ),
      isTrue,
    );
  });

  test('art arda hatalar eşikte bir kez bayat bildirir, başarı sıfırlar', () {
    final policy = IhizLocationPollPolicy();
    expect(policy.recordFailure(), isFalse);
    expect(policy.recordFailure(), isFalse);
    expect(policy.isStale, isFalse);
    expect(policy.recordFailure(), isTrue);
    expect(policy.isStale, isTrue);
    expect(policy.recordFailure(), isFalse);
    expect(policy.isStale, isTrue);

    policy.recordSuccess();
    expect(policy.isStale, isFalse);
    expect(policy.consecutiveFailures, 0);
  });
}
