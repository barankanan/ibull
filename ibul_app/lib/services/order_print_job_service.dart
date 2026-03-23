import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kitchen_routing_service.dart';

class OrderPrintJobDispatchResult {
  const OrderPrintJobDispatchResult({
    required this.orderId,
    required this.orderNumber,
    required this.printJobCount,
    required this.raw,
  });

  final String? orderId;
  final String? orderNumber;
  final int printJobCount;
  final Map<String, dynamic> raw;
}

class OrderPrintJobService {
  OrderPrintJobService({
    SupabaseClient? client,
    KitchenRoutingService? routingService,
  }) : _client = client ?? Supabase.instance.client,
       _routingService = routingService ?? const KitchenRoutingService();

  final SupabaseClient _client;
  final KitchenRoutingService _routingService;

  Future<OrderPrintJobDispatchResult> dispatchNewOrder({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
    String jobType = 'new_order',
  }) async {
    final normalized = _routingService
        .normalizeItems(items)
        .map((item) => item.toPayloadMap())
        .toList(growable: false);

    if (normalized.isEmpty) {
      throw Exception('Print job oluşturmak için sipariş kalemi bulunamadı.');
    }

    // TODO: Optional next step is invoking an Edge Function/webhook worker that
    // consumes pending print_jobs and forwards them to a local print agent.
    final response = await _client.rpc(
      'create_table_order_with_print_jobs',
      params: {
        'p_restaurant_id': restaurantId,
        'p_table_number': tableNumber,
        'p_items': normalized,
        'p_waiter_id': (waiterId == null || waiterId.isEmpty) ? null : waiterId,
        'p_waiter_name': waiterName,
        'p_notes': notes,
        'p_job_type': jobType,
        'p_order_type': 'table',
      },
    );

    final data = response is Map<String, dynamic>
        ? response
        : (response is Map
              ? Map<String, dynamic>.from(response)
              : <String, dynamic>{});

    return OrderPrintJobDispatchResult(
      orderId: data['order_id']?.toString(),
      orderNumber: data['order_number']?.toString(),
      printJobCount: (data['print_job_count'] as num?)?.toInt() ?? 0,
      raw: data,
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchAddItem({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'add_item',
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchCancelItem({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'cancel_item',
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchReprint({
    required String restaurantId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? waiterId,
    String? waiterName,
    String? notes,
  }) {
    return dispatchNewOrder(
      restaurantId: restaurantId,
      tableNumber: tableNumber,
      items: items,
      waiterId: waiterId,
      waiterName: waiterName,
      notes: notes,
      jobType: 'reprint',
    );
  }

  Future<OrderPrintJobDispatchResult> dispatchNewOrderFromTableOrder({
    required String tableOrderId,
    String? waiterName,
  }) async {
    final row = await _client
        .from('table_orders')
        .select('id, seller_id, table_number, items')
        .eq('id', tableOrderId)
        .single();
    final map = Map<String, dynamic>.from(row as Map);
    final sellerId = map['seller_id']?.toString() ?? '';
    final tableNumber = (map['table_number'] as num?)?.toInt() ?? 0;
    final rawItems = map['items'] is List
        ? List<Map<String, dynamic>>.from(
            (map['items'] as List).whereType<Map>().map(
              (item) => Map<String, dynamic>.from(item),
            ),
          )
        : <Map<String, dynamic>>[];

    if (sellerId.isEmpty || tableNumber <= 0) {
      throw Exception('table_orders kaydı print routing için uygun değil.');
    }

    return dispatchNewOrder(
      restaurantId: sellerId,
      tableNumber: tableNumber,
      items: rawItems,
      waiterName: waiterName,
    );
  }

  String? safeUserDisplayName(User? user) {
    if (user == null) return null;
    final metadata = user.userMetadata;
    final fromDisplayName = metadata?['display_name']?.toString().trim();
    if (fromDisplayName != null && fromDisplayName.isNotEmpty) {
      return fromDisplayName;
    }
    final fromName = metadata?['name']?.toString().trim();
    if (fromName != null && fromName.isNotEmpty) {
      return fromName;
    }
    return user.email;
  }

  void debugLogResult(OrderPrintJobDispatchResult result) {
    debugPrint(
      'OrderPrintJobService: order=${result.orderId} printJobs=${result.printJobCount}',
    );
  }
}
