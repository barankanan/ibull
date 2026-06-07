import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/utils/garson_active_orders_fetch.dart';
import 'package:ibul_app/utils/garson_board_state.dart';
import 'package:ibul_app/utils/table_labels.dart';

void main() {
  group('garson active orders fetch', () {
    test('canlı active status listesi aktif sayılır', () {
      for (final status in const <String>[
        'new',
        'open',
        'pending',
        'kitchen_sent',
        'preparing',
        'in_progress',
        'waiting',
        'served',
        'active',
        'mutfaga_iletildi',
        'mutfakta',
        'hazirlaniyor',
        'sent',
        'confirmed',
      ]) {
        expect(
          isGarsonActiveOrderStatus(status),
          isTrue,
          reason: status,
        );
      }
    });

    test('terminal statuses are excluded', () {
      for (final status in const <String>[
        'closed',
        'paid',
        'cancelled',
        'completed_payment',
        'archived',
      ]) {
        expect(
          isGarsonActiveOrderStatus(status),
          isFalse,
          reason: status,
        );
      }
    });

    test('orders table row maps order_status sent for active fetch', () {
      final normalized = normalizeRestaurantOrderToGarsonTableOrder(
        order: const <String, dynamic>{
          'id': 'order-1',
          'restaurant_id': 'rest-1',
          'table_id': 'table-bahce-1',
          'order_status': 'sent',
          'status': 'confirmed',
          'order_type': 'table',
          'total_amount': 280,
          'created_at': '2026-06-05T10:00:00Z',
          'updated_at': '2026-06-05T10:00:00Z',
        },
        items: const <Map<String, dynamic>>[
          {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
        ],
        storeTable: const <String, dynamic>{
          'id': 'table-bahce-1',
          'table_number': 12,
          'area_name': 'Bahçe',
          'area_table_number': 1,
          'display_label': 'Bahçe 1',
        },
      );

      expect(normalized, isNotNull);
      expect(normalized!['order_id'], 'order-1');
      expect(normalized['id'], 'order-1');
      expect(normalized['status'], 'sent');
      expect(normalized['restaurant_id'], 'rest-1');
      expect(normalized['table_id'], 'table-bahce-1');
      expect(normalized['store_table_id'], 'table-bahce-1');
      expect(normalized['table_number'], 12);
      expect(normalized['area_name'], 'Bahçe');
      expect(normalized['area_table_number'], 1);
      expect(normalized['display_table_label'], 'Bahçe 1');
      expect(normalized['items'], hasLength(1));
      expect(normalized['total'], 280);
      expect(normalized['created_at'], isNotNull);
      expect(normalized['updated_at'], isNotNull);
    });

    test('table_orders kaynağı canonical board modeline normalize edilir', () {
      final normalized = normalizeTableOrderToGarsonBoardOrder(
        order: const <String, dynamic>{
          'id': 'table-order-1',
          'seller_id': 'rest-1',
          'table_number': 12,
          'status': 'sent',
          'items': <Map<String, dynamic>>[
            {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
          ],
          'total': 280,
          'created_at': '2026-06-05T10:00:00Z',
          'updated_at': '2026-06-05T10:05:00Z',
        },
        storeTable: const <String, dynamic>{
          'id': 'table-bahce-1',
          'table_number': 12,
          'area_name': 'Bahçe',
          'area_table_number': 1,
          'display_label': 'Bahçe 1',
        },
      );

      expect(normalized, isNotNull);
      expect(normalized!['order_id'], 'table-order-1');
      expect(normalized['restaurant_id'], 'rest-1');
      expect(normalized['table_id'], 'table-bahce-1');
      expect(normalized['display_table_label'], 'Bahçe 1');
    });

    test('restaurant_id order is merged when table_orders is empty', () {
      final restaurantOrder = normalizeRestaurantOrderToGarsonTableOrder(
        order: const <String, dynamic>{
          'id': 'order-bahce-1',
          'restaurant_id': '7264153b-f493-4508-8402-5fa8cfaabed8',
          'table_id': 'table-bahce-1',
          'order_status': 'sent',
          'status': 'confirmed',
          'order_type': 'table',
          'total_amount': 280,
        },
        items: const <Map<String, dynamic>>[
          {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
        ],
        storeTable: const <String, dynamic>{
          'id': 'table-bahce-1',
          'table_number': 12,
          'area_name': 'Bahçe',
          'area_table_number': 1,
          'display_label': 'Bahçe 1',
        },
      );
      expect(restaurantOrder, isNotNull);

      final merged = mergeGarsonActiveOrderSources(
        tableOrders: const <Map<String, dynamic>>[],
        restaurantOrders: <Map<String, dynamic>>[restaurantOrder!],
      );

      expect(merged, hasLength(1));
      expect(merged.first['id'], 'order-bahce-1');
      expect(
        merged.first['restaurant_id'],
        '7264153b-f493-4508-8402-5fa8cfaabed8',
      );
    });

    test('Bahçe 1 order binds to Bahçe 1 table card', () {
      final bahce1 = const <String, dynamic>{
        'id': 'table-bahce-1',
        'table_number': 12,
        'area_name': 'Bahçe',
        'area_table_number': 1,
        'display_label': 'Bahçe 1',
      };
      final order = normalizeRestaurantOrderToGarsonTableOrder(
        order: const <String, dynamic>{
          'id': 'order-bahce-1',
          'restaurant_id': 'rest-1',
          'table_id': 'table-bahce-1',
          'order_status': 'sent',
          'order_type': 'table',
        },
        items: const <Map<String, dynamic>>[
          {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
        ],
        storeTable: bahce1,
      );

      final binding = resolveActiveOrderBindingForTable(
        table: bahce1,
        activeOrders: <Map<String, dynamic>>[order!],
      );

      expect(binding.order?['id'], 'order-bahce-1');
      expect(binding.matchedBy, isNot('none'));
    });

    test('table_orders_stream_error source auto-applies fallback fetch', () {
      expect(
        shouldAutoApplyGarsonVisibleSnapshot(source: 'table_orders_stream_error'),
        isTrue,
      );
      expect(
        shouldBlockGarsonBackgroundPublish(
          selectedModule: SellerModule.garson,
          manualRefreshInProgress: false,
          hasPublishedData: true,
          source: 'table_orders_stream_error',
        ),
        isFalse,
      );
    });

    test('submit DB result ile active fetch aynı orderı bulur', () {
      final bahce1 = const <String, dynamic>{
        'id': 'table-bahce-1',
        'table_number': 12,
        'area_name': 'Bahçe',
        'area_table_number': 1,
        'display_label': 'Bahçe 1',
      };
      final submitResult = normalizeRestaurantOrderToGarsonTableOrder(
        order: const <String, dynamic>{
          'id': 'order-live-1',
          'restaurant_id': '7264153b-f493-4508-8402-5fa8cfaabed8',
          'table_id': 'table-bahce-1',
          'order_status': 'sent',
          'status': 'confirmed',
          'order_type': 'table',
          'total_amount': 280,
        },
        items: const <Map<String, dynamic>>[
          {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
        ],
        storeTable: bahce1,
      );
      expect(submitResult, isNotNull);
      expect(resolveGarsonOrderStatusField(submitResult!), 'sent');
      expect(isGarsonActiveOrderStatus(resolveGarsonOrderStatusField(submitResult)), isTrue);

      final fetched = mergeGarsonActiveOrderSources(
        tableOrders: const <Map<String, dynamic>>[],
        restaurantOrders: <Map<String, dynamic>>[submitResult],
      );
      expect(fetched.any((order) => order['id'] == 'order-live-1'), isTrue);
    });

    test('fallback fetch board state orders_count > 0 yapar', () {
      const bahce1 = <String, dynamic>{
        'id': 'table-bahce-1',
        'table_number': 12,
        'area_name': 'Bahçe',
        'area_table_number': 1,
        'display_label': 'Bahçe 1',
      };
      const activeOrder = <String, dynamic>{
        'id': 'order-bahce-1',
        'table_id': 'table-bahce-1',
        'store_table_id': 'table-bahce-1',
        'table_number': 12,
        'area_name': 'Bahçe',
        'area_table_number': 1,
        'status': 'sent',
        'items': <Map<String, dynamic>>[
          {'name': 'Ciğer Şiş', 'quantity': 1, 'line_total': 280},
        ],
      };
      final next = applyManualRefresh(
        current: const GarsonBoardState(
          tables: <Map<String, dynamic>>[bahce1],
          areas: <Map<String, dynamic>>[
            {'id': 'area-1', 'name': 'Bahçe'},
          ],
        ),
        tables: <Map<String, dynamic>>[bahce1],
        areas: <Map<String, dynamic>>[
          {'id': 'area-1', 'name': 'Bahçe'},
        ],
        orders: <Map<String, dynamic>>[activeOrder],
        source: 'table_orders_stream_error',
      );

      expect(next.ordersSource, 'visible');
      expect(next.uiOrders, hasLength(1));
      expect(
        resolveActiveOrderBindingForTable(
          table: bahce1,
          activeOrders: next.uiOrders,
        ).order?['id'],
        'order-bahce-1',
      );
    });
  });
}
