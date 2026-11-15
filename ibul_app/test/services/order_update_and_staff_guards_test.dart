import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/kitchen_routing_service.dart';
import 'package:ibul_app/services/order_print_job_service.dart';
import 'package:ibul_app/services/store_service.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';

void main() {
  test('same saved order edit keeps one revision key', () {
    const items = <Map<String, dynamic>>[
      {'product_id': 'soup', 'name': 'Çorba', 'quantity': 2},
    ];
    final first = OrderPrintJobService.stableOrderEditKey('order-1', items);
    final second = OrderPrintJobService.stableOrderEditKey('order-1', items);
    final changed = OrderPrintJobService.stableOrderEditKey('order-1', const [
      {'product_id': 'soup', 'name': 'Çorba', 'quantity': 3},
    ]);
    expect(first, second);
    expect(changed, isNot(first));
  });

  test('same product variants keep separate line ids and kitchen cancel data', () {
    const plainId = '11111111-1111-1111-1111-111111111111';
    const extraId = '22222222-2222-2222-2222-222222222222';
    const stationId = '50000000-0000-0000-0000-000000000001';
    final loaded = normalizeRestaurantOrderItems(const [
      {
        'id': plainId,
        'product_id': 'soup',
        'product_name': 'Çorba',
        'quantity': 1,
        'unit_price': 10,
        'item_note': 'az tuz',
        'station_id': stationId,
        'attributes': ['tuzsuz'],
      },
      {
        'id': extraId,
        'product_id': 'soup',
        'product_name': 'Çorba',
        'quantity': 1,
        'unit_price': 12,
        'item_note': 'ekstra peynir',
        'station_id': stationId,
        'attributes': ['peynir'],
      },
    ]);
    expect(loaded.map((item) => item['order_item_id']), [plainId, extraId]);
    expect(loaded.map((item) => item['notes']), ['az tuz', 'ekstra peynir']);
    final stamped = loaded
        .map(OrderPrintJobService.lineForRestaurantOrderUpdate)
        .toList();
    expect(stamped[0]['order_item_id'], plainId);
    expect(stamped[1]['order_item_id'], extraId);
    final productUuid = '33333333-3333-3333-3333-333333333333';
    final newLine = OrderPrintJobService.lineForRestaurantOrderUpdate({
      'id': productUuid,
      'product_id': productUuid,
      'name': 'Çorba',
      'quantity': 1,
    });
    expect(newLine.containsKey('order_item_id'), isFalse);
    final removed = {
      ...loaded.first,
      'quantity': 1,
    };
    expect(
      OrderPrintJobService.cancelTicketMatchesRemovedLine(
        removedLine: removed,
        ticketItem: {
          'order_item_id': plainId,
          'product_id': 'soup',
          'quantity': 1,
          'station_id': stationId,
        },
      ),
      isTrue,
    );
    expect(
      OrderPrintJobService.cancelTicketMatchesRemovedLine(
        removedLine: removed,
        ticketItem: {
          'order_item_id': extraId,
          'product_id': 'soup',
          'quantity': 1,
          'station_id': stationId,
          'notes': 'az tuz',
        },
      ),
      isFalse,
    );
    expect(
      OrderPrintJobService.cancelTicketMatchesRemovedLine(
        removedLine: removed,
        ticketItem: {
          'product_id': 'soup',
          'quantity': 2,
          'station_id': stationId,
          'notes': 'az tuz',
        },
      ),
      isFalse,
    );
  });

  test('two mixed services keep their own plates and price', () {
    const station = '50000000-0000-0000-0000-000000000001';
    final routed = const KitchenRoutingService().normalizeItems([
      {
        'item_type': 'mixed_service',
        'product_id': 'mix',
        'name': 'Karışık Servis',
        'quantity': 1,
        'price': 100,
        'station_id': station,
        'service_round_count': 0,
        'child_items': [
          {'product_name': 'Ciğer Dürüm', 'quantity': 1, 'service_round': 2, 'note': 'acı', 'station_id': station},
          {'product_name': 'Ciğer Servis', 'quantity': 1, 'service_round': 2, 'station_id': station},
        ],
      },
      {
        'item_type': 'mixed_service',
        'product_id': 'mix',
        'name': 'Karışık Servis',
        'quantity': 1,
        'price': 120,
        'station_id': station,
        'child_items': [
          {'product_name': 'Beyti Kebap', 'quantity': 1, 'service_round': 3, 'station_id': station},
          {'product_name': 'Ciğer Dürüm', 'quantity': 2, 'service_round': 3, 'note': 'soğansız', 'station_id': station},
        ],
      },
    ]).map((item) => item.toPayloadMap()).toList();
    expect(routed, hasLength(2));
    expect(routed[0]['price'], 100);
    expect(routed[1]['price'], 120);
    expect(routed[0]['plates'][0]['label'], 'Tabak 2');
    expect(routed[0]['plates'][0]['items'][0]['name'], 'Ciğer Dürüm');
    expect(routed[0]['plates'][0]['items'][0]['quantity'], 1);
    expect(routed[0]['plates'][0]['items'][0]['note'], 'acı');
    expect(routed[1]['plates'][0]['label'], 'Tabak 3');
    expect(routed[1]['plates'][0]['items'][1]['quantity'], 2);
    expect(routed[0]['child_items'], isNot(routed[1]['child_items']));
  });

  test('temporary staff password requires 8 characters and recommends 12', () {
    expect(
      staffTemporaryPasswordError('kisa'),
      'Geçici şifre en az 8 karakter olmalı.',
    );
    expect(staffTemporaryPasswordError('1234567'), isNotNull);
    expect(staffTemporaryPasswordError('12345678'), isNull);
    expect(staffTemporaryPasswordAdvice('12345678'), isNotNull);
    expect(staffTemporaryPasswordError('Aa1!p5-fixtur-9'), isNull);
    expect(staffTemporaryPasswordAdvice('Aa1!p5-fixtur-9'), isNull);
  });
}
