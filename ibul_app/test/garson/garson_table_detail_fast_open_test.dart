import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_flow_cache.dart';

List<Map<String, dynamic>> simulateDisplayTableOrders({
  required List<Map<String, dynamic>> serverOrders,
  required List<Map<String, dynamic>> seededOrders,
}) {
  final baseOrders = serverOrders.isNotEmpty ? serverOrders : seededOrders;
  return List<Map<String, dynamic>>.from(baseOrders);
}

void main() {
  group('garson table detail fast open', () {
    final seededOrder = <String, dynamic>{
      'id': 'order-seed-7',
      'table_number': 7,
      'status': 'sent',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Çorba', 'quantity': 1},
      ],
    };

    test('cache varsa active order items ilk renderda görünür', () {
      final visible = simulateDisplayTableOrders(
        serverOrders: const <Map<String, dynamic>>[],
        seededOrders: <Map<String, dynamic>>[seededOrder],
      );
      expect(visible, isNotEmpty);
      expect(visible.first['id'], 'order-seed-7');
    });

    test('boş seed + boş stream blank kalır', () {
      final visible = simulateDisplayTableOrders(
        serverOrders: const <Map<String, dynamic>>[],
        seededOrders: const <Map<String, dynamic>>[],
      );
      expect(visible, isEmpty);
    });

    test('stream doluysa seed yerine stream kazanır', () {
      final streamOrder = <String, dynamic>{
        'id': 'order-stream-7',
        'table_number': 7,
      };
      final visible = simulateDisplayTableOrders(
        serverOrders: <Map<String, dynamic>>[streamOrder],
        seededOrders: <Map<String, dynamic>>[seededOrder],
      );
      expect(visible.first['id'], 'order-stream-7');
    });

    test('garsonOrdersForTableNumber board seed üretir', () {
      final boardOrders = <Map<String, dynamic>>[
        seededOrder,
        <String, dynamic>{'id': 'other', 'table_number': 2},
      ];
      final tableOrders = garsonOrdersForTableNumber(
        orders: boardOrders,
        tableNumber: 7,
      );
      expect(tableOrders, hasLength(1));
    });
  });
}
