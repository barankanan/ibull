import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/table_labels.dart';

/// Doğrulanmamış QR → garson onayı bekleyen masa istekleri (Supabase RPC).
class WaiterOrderRequestService {
  WaiterOrderRequestService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> submitRequest({
    required String sellerId,
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    String? customerNotes,
    Map<String, dynamic>? tableRow,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Garsona göndermek için giriş yapmalısınız.');
    }
    final payload = <String, dynamic>{
      ...resolvePrintableTablePayloadFields(
        tableRow: tableRow,
        tableNumber: tableNumber,
      ),
    };
    final res = await _client.rpc(
      'submit_waiter_order_request',
      params: {
        'p_seller_id': sellerId,
        'p_table_number': tableNumber,
        'p_items': items,
        'p_customer_notes': customerNotes,
        'p_table_payload': payload,
      },
    );
    if (res is String) return res;
    return '$res';
  }

  Future<void> rejectRequest({
    required String requestId,
    String? reason,
  }) async {
    await _client.rpc(
      'reject_waiter_order_request',
      params: {
        'p_request_id': requestId,
        'p_reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> approveRequest({
    required String requestId,
    List<Map<String, dynamic>>? editedItems,
  }) async {
    final params = <String, dynamic>{'p_request_id': requestId};
    if (editedItems != null) {
      params['p_edited_items'] = editedItems;
    }
    final res = await _client.rpc(
      'approve_waiter_order_request',
      params: params,
    );
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    return <String, dynamic>{};
  }

  Stream<List<Map<String, dynamic>>> pendingRequestsStream(String sellerId) {
    final sid = sellerId.trim();
    if (sid.isEmpty) {
      return Stream.value(const <Map<String, dynamic>>[]);
    }
    return _client
        .from('waiter_order_requests')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sid)
        .order('created_at', ascending: false)
        .map((rows) {
          final list = List<Map<String, dynamic>>.from(rows);
          return list
              .where(
                (r) =>
                    (r['status']?.toString() ?? '') ==
                    'pending_waiter_approval',
              )
              .toList(growable: false);
        });
  }
}
