import 'package:flutter_test/flutter_test.dart';
import 'package:ihiz_web/src/util/ihiz_pickup_sync_outcome.dart';

void main() {
  test('sunucu reddi yerel aktif teslimatı geri aldırır', () {
    final outcome = resolveFailedPickupOutcome(
      serverRejected: true,
      isReturnPickup: false,
      verifiedStatus: 'out_for_delivery',
    );
    expect(outcome, IhizPickupSyncOutcome.notApplied);
    expect(outcome.keepsActiveDelivery, isFalse);
  });

  test('ağ hatası sonrası durum değişmemişse teslimat geri alınır', () {
    final outcome = resolveFailedPickupOutcome(
      serverRejected: false,
      isReturnPickup: false,
      verifiedStatus: 'ready_to_ship',
    );
    expect(outcome, IhizPickupSyncOutcome.notApplied);
    expect(outcome.keepsActiveDelivery, isFalse);
  });

  test('ağ hatasına rağmen yazım uygulanmışsa teslimat korunur', () {
    expect(
      resolveFailedPickupOutcome(
        serverRejected: false,
        isReturnPickup: false,
        verifiedStatus: ' Out_For_Delivery ',
      ),
      IhizPickupSyncOutcome.committed,
    );
    expect(
      resolveFailedPickupOutcome(
        serverRejected: false,
        isReturnPickup: true,
        verifiedStatus: 'return_shipped_back',
      ),
      IhizPickupSyncOutcome.committed,
    );
  });

  test('iade alımında normal teslimat durumu uygulanmış sayılmaz', () {
    expect(
      resolveFailedPickupOutcome(
        serverRejected: false,
        isReturnPickup: true,
        verifiedStatus: 'out_for_delivery',
      ),
      IhizPickupSyncOutcome.notApplied,
    );
  });

  test('doğrulanamayan yazımda teslimat korunur (paket sahipsiz kalmasın)', () {
    for (final status in <String?>[null, '', '  ']) {
      final outcome = resolveFailedPickupOutcome(
        serverRejected: false,
        isReturnPickup: false,
        verifiedStatus: status,
      );
      expect(outcome, IhizPickupSyncOutcome.unverified);
      expect(outcome.keepsActiveDelivery, isTrue);
    }
  });

  test(
    'koşullu teslim alma: durum değişmişse paket başkasına gitmiş sayılır',
    () {
      for (final status in const [
        'out_for_delivery',
        ' Out_For_Delivery ',
        'delivered',
        'cancelled',
        'preparing',
      ]) {
        expect(isPickupLostToStatusChange(status), isTrue, reason: status);
      }
    },
  );

  test('koşullu teslim alma: durum hâlâ hazırsa veya okunamadıysa çakışma '
      'sayılmaz (yetki reddi olabilir)', () {
    for (final status in <String?>[
      null,
      '',
      '  ',
      'ready_to_ship',
      'READY_TO_SHIP ',
    ]) {
      expect(isPickupLostToStatusChange(status), isFalse, reason: '$status');
    }
    expect(ihizPickupReadyStatus, 'ready_to_ship');
  });

  test('yalnızca notApplied aktif teslimatı düşürür', () {
    expect(IhizPickupSyncOutcome.localOnly.keepsActiveDelivery, isTrue);
    expect(IhizPickupSyncOutcome.committed.keepsActiveDelivery, isTrue);
  });
}
