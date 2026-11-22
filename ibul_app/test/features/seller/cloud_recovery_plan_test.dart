import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/offline_page_policy.dart';

void main() {
  final t0 = DateTime(2026, 11, 22, 12);
  CloudRecoveryPlan plan({
    bool cloudUp = true,
    bool wasCloudUp = true,
    bool offlineStart = false,
    bool inFlight = false,
    bool boardError = false,
    DateTime? last,
    DateTime? now,
  }) => decideCloudRecovery(
    cloudUp: cloudUp,
    wasCloudUp: wasCloudUp,
    offlineStartActive: offlineStart,
    recoveryInFlight: inFlight,
    boardShowsCloudError: boardError,
    lastAttemptAt: last,
    now: now ?? t0,
  );

  group('bulut geri dönüş kararı', () {
    test('bulut kapalıyken hiçbir yükleme başlamaz', () {
      final p = plan(cloudUp: false, wasCloudUp: false, offlineStart: true);
      expect(p.retryProfile, isFalse);
      expect(p.refreshBoards, isFalse);
      expect(p.rebuild, isFalse);
    });

    test('bulut düşünce menü yeniden çizilir', () {
      expect(plan(cloudUp: false, wasCloudUp: true).rebuild, isTrue);
    });

    test('çevrimdışı açılıştan sonra bulut gelince profil yüklenir', () {
      final p = plan(wasCloudUp: false, offlineStart: true);
      expect(p.retryProfile, isTrue);
      expect(p.rebuild, isTrue);
    });

    test('ilk deneme başarısızsa bayrak kalıcı kalmaz, deneme yinelenir', () {
      // Bağlantı modu değişmedi (wasCloudUp=true), bayrak hâlâ açık.
      final early = plan(
        offlineStart: true,
        last: t0,
        now: t0.add(const Duration(seconds: 6)),
      );
      expect(early.retryProfile, isFalse);
      final later = plan(
        offlineStart: true,
        last: t0,
        now: t0.add(const Duration(seconds: 12)),
      );
      expect(later.retryProfile, isTrue);
    });

    test('süren bir deneme varken ikincisi başlamaz', () {
      expect(plan(offlineStart: true, inFlight: true).retryProfile, isFalse);
    });

    test('panel açıkken bulut gidip gelince panolar yenilenir', () {
      final p = plan(wasCloudUp: false);
      expect(p.retryProfile, isFalse);
      expect(p.refreshBoards, isTrue);
    });

    test('eski bulut hatası ekranda kaldıysa aralıklı yenilenir', () {
      expect(plan(boardError: true).refreshBoards, isTrue);
      expect(
        plan(
          boardError: true,
          last: t0,
          now: t0.add(const Duration(seconds: 3)),
        ).refreshBoards,
        isFalse,
      );
    });

    test('her şey yolundayken sürekli yenileme yapılmaz', () {
      final p = plan();
      expect(p.retryProfile, isFalse);
      expect(p.refreshBoards, isFalse);
      expect(p.rebuild, isFalse);
    });
  });
}
