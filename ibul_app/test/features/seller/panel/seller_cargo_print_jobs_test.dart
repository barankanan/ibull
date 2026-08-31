import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_station_print_grouping.dart';
import 'package:ibul_app/services/seller_cargo_print_job_service.dart';

void main() {
  const ocakId = '11111111-1111-1111-1111-111111111111';
  const firinId = '22222222-2222-2222-2222-222222222222';
  const kasapId = '33333333-3333-3333-3333-333333333333';

  const stationNames = <String, String>{
    ocakId: 'Ocak',
    firinId: 'Fırın',
    kasapId: 'Kasap',
  };
  const stationCodes = <String, String>{
    ocakId: 'OCAK',
    firinId: 'FIRIN',
    kasapId: 'KASAP',
  };

  Map<String, dynamic> item({
    required String id,
    required String name,
    String? stationId,
    bool routingEnabled = true,
    int quantity = 1,
  }) {
    return <String, dynamic>{
      'id': 'item-$id',
      'product_id': id,
      'product_name': name,
      'name': name,
      'quantity': quantity,
      'unit_price': 10,
      'station_id': ?stationId,
      'printer_routing_enabled': routingEnabled,
    };
  }

  CargoKitchenPrintPlan plan(List<Map<String, dynamic>> items, {Set<String>? existing}) {
    return planCargoKitchenPrintJobs(
      orderItems: items,
      stationNamesById: stationNames,
      stationCodesById: stationCodes,
      existingActiveStationKeys: existing ?? const <String>{},
    );
  }

  test('TEST 1: two products on Ocak create one print group', () {
    final result = plan([
      item(id: 'a', name: 'Hamburger', stationId: ocakId, quantity: 2),
      item(id: 'b', name: 'Tost', stationId: ocakId),
    ]);
    expect(result.groupsToCreate, hasLength(1));
    expect(result.groupsToCreate.single.groupKey, ocakId);
    expect(result.groupsToCreate.single.items, hasLength(2));
  });

  test('TEST 2: three stations create three print groups', () {
    final result = plan([
      item(id: 'a', name: 'Hamburger', stationId: ocakId),
      item(id: 'b', name: 'Pizza', stationId: firinId),
      item(id: 'c', name: 'Et', stationId: kasapId),
    ]);
    expect(result.groupsToCreate, hasLength(3));
    expect(
      result.groupsToCreate.map((group) => group.groupKey).toSet(),
      {ocakId, firinId, kasapId},
    );
  });

  test('TEST 3: three Ocak products stay in one job with three items', () {
    final result = plan([
      item(id: 'a', name: 'Hamburger', stationId: ocakId),
      item(id: 'b', name: 'Tost', stationId: ocakId),
      item(id: 'c', name: 'Köfte', stationId: ocakId),
    ]);
    expect(result.groupsToCreate, hasLength(1));
    expect(result.groupsToCreate.single.items, hasLength(3));
  });

  test('TEST 4: null station uses Genel / __general__', () {
    final result = plan([
      item(id: 'cola', name: 'Kola', quantity: 2),
    ]);
    expect(result.groupsToCreate, hasLength(1));
    expect(result.groupsToCreate.single.groupKey, '__general__');
    expect(result.groupsToCreate.single.stationId, isEmpty);
    expect(
      result.groupsToCreate.single.stationName.toUpperCase(),
      'GENEL',
    );
  });

  test('TEST 5: printer_routing_enabled false is excluded from kitchen jobs', () {
    final result = plan([
      item(id: 'a', name: 'Hamburger', stationId: ocakId),
      item(id: 'skip', name: 'Sos', stationId: ocakId, routingEnabled: false),
    ]);
    expect(result.skippedRoutingDisabled, hasLength(1));
    expect(result.groupsToCreate, hasLength(1));
    expect(result.groupsToCreate.single.items, hasLength(1));
    expect(result.groupsToCreate.single.items.single['product_id'], 'a');
  });

  test('TEST 6: existing active station job is not created again', () {
    final result = plan(
      [
        item(id: 'a', name: 'Hamburger', stationId: ocakId),
        item(id: 'b', name: 'Pizza', stationId: firinId),
      ],
      existing: {ocakId},
    );
    expect(result.skippedExisting, hasLength(1));
    expect(result.skippedExisting.single.groupKey, ocakId);
    expect(result.groupsToCreate, hasLength(1));
    expect(result.groupsToCreate.single.groupKey, firinId);
  });

  test('TEST 7: cargo order with mixed stations plans one job per station group', () {
    final storedItems = [
      item(id: 'a', name: 'Ürün A', stationId: ocakId),
      item(id: 'b', name: 'Ürün B', stationId: firinId),
      item(id: 'c', name: 'Ürün C', stationId: kasapId),
      item(id: 'd', name: 'Ürün D', stationId: ocakId),
      item(id: 'e', name: 'Ürün E'),
    ];
    final result = plan(storedItems);
    expect(storedItems, hasLength(5));
    expect(result.groupsToCreate, hasLength(4));
    final byKey = {
      for (final group in result.groupsToCreate) group.groupKey: group,
    };
    expect(byKey[ocakId]!.items.map((row) => row['product_id']), ['a', 'd']);
    expect(byKey[firinId]!.items.single['product_id'], 'b');
    expect(byKey[kasapId]!.items.single['product_id'], 'c');
    expect(byKey['__general__']!.items.single['product_id'], 'e');
  });

  test('activeKitchenPrintStationKeys ignores failed jobs', () {
    final keys = activeKitchenPrintStationKeys([
      {'station_id': ocakId, 'status': 'pending'},
      {'station_id': firinId, 'status': 'failed'},
      {'station_id': null, 'status': 'completed'},
    ]);
    expect(keys, {ocakId, '__general__'});
  });

  test('cargo kitchen payload keeps existing kitchen job shape', () {
    final group = plan([
      item(id: 'a', name: 'Hamburger', stationId: ocakId, quantity: 2),
    ]).groupsToCreate.single;
    final payload = buildCargoKitchenJobPayload(
      restaurantId: 'rest-1',
      orderId: 'order-1',
      orderNumber: 'IBUL-EXT-1',
      group: group,
      stationCodesById: stationCodes,
      storeName: 'Test Restoran',
    );
    expect(payload['job_type'], 'new_order');
    expect(payload['document_type'], 'kitchen');
    expect(payload['table_name'], 'Kargo');
    expect(payload['order_no'], 'IBUL-EXT-1');
    expect(payload['station_id'], ocakId);
    expect(payload['items'], hasLength(1));
    expect(payload['items'].first['product_name'], 'Hamburger');
    expect(payload['items'].first['quantity'], 2);
    expect(payload['idempotency_key'], isNotEmpty);
  });
}
