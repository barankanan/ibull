import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';

// Real device, 2026-11-24, Teras 8: efe took the order on the iPhone, the cloud
// row says the restaurant owner. The center kept the device certificate
// fingerprint as "waiter" and the sync dropped it (not a UUID), so the server
// fell back to the signed-in owner. The verified, paired staff id must travel.
const efe = '2e2f1914-0d12-4459-846e-b17d5b1eb014';
const owner = '7264153b-f493-4508-8402-5fa8cfaabed8';
const stranger = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

RestaurantLocalOrderRecord _record({
  String waiterId = '35aa8b38590271e72a730cf384f2a5dbefe8dc95a9802b655d785516f18277e4',
  String staffId = '',
}) => RestaurantLocalOrderRecord(
  localOrderId: 'waiter-1',
  restaurantId: owner,
  tableId: '27',
  tableName: 'Teras 8',
  tableNumber: 27,
  waiterId: waiterId,
  waiterName: 'efe',
  staffId: staffId,
  items: const <Map<String, dynamic>>[],
  notes: '',
  total: 0,
  stationGroups: const <Map<String, dynamic>>[],
  printStatus: 'forwarded',
  syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
  createdAt: DateTime(2026, 11, 24),
  updatedAt: DateTime(2026, 11, 24),
);

void main() {
  group('which staff id the cloud order carries', () {
    test('a paired phone order sends the verified staff, not the device fingerprint', () {
      expect(lanOrderWaiterRef(_record(staffId: efe)), efe);
    });

    test('an order without a staff id (older record, Mac own order) keeps its UUID waiter', () {
      expect(lanOrderWaiterRef(_record(waiterId: owner)), owner);
    });

    test('a device fingerprint alone is never sent as the waiter', () {
      expect(lanOrderWaiterRef(_record()), isNull);
    });

    test('a staff id that is not a UUID is not sent and does not fall back to the device', () {
      expect(lanOrderWaiterRef(_record(staffId: 'staff-a')), isNull);
    });

    test('the staff id survives the journal round trip and a copy', () {
      final back = RestaurantLocalOrderRecord.fromJson(
        _record(staffId: efe).toJson(),
      );
      expect(back.staffId, efe);
      expect(back.copyWith(printStatus: 'printed').staffId, efe);
      // Journals written before this field existed still load.
      final legacy = _record().toJson()..remove('staff_id');
      expect(RestaurantLocalOrderRecord.fromJson(legacy).staffId, '');
    });
  });
}
