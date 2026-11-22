import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/paired_lan_transport.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';

RestaurantLocalOrderRecord _order() => RestaurantLocalOrderRecord(
  localOrderId: 'o-1',
  restaurantId: 'r-1',
  tableId: '1',
  tableName: 'Masa 1',
  tableNumber: 1,
  waiterId: 'w',
  waiterName: 'W',
  items: const <Map<String, dynamic>>[],
  notes: '',
  total: 0,
  stationGroups: const <Map<String, dynamic>>[],
  printStatus: 'pending',
  syncStatus: RestaurantLocalOrderSyncStatus.pendingSync,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('the transport keeps the print status the center reported', () async {
    var body = <String, dynamic>{'saved': true, 'print_status': 'forwarded'};
    final transport = PairedLanTransport((path, _) async => body);
    expect(transport.lastPrintStatus, isNull);
    expect(await transport.submit(_order()), isTrue);
    expect(transport.lastPrintStatus, 'forwarded');

    body = <String, dynamic>{'saved': true};
    expect(await transport.submit(_order()), isTrue);
    expect(transport.lastPrintStatus, isNull);
  });
}
