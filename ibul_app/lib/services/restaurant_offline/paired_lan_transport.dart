import 'restaurant_lan_host.dart';
import 'restaurant_offline_models.dart';

/// Phone-side sender. The host must confirm the SQLite write.
class PairedLanTransport implements RestaurantLanOrderTransport {
  PairedLanTransport(this._send);

  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, Object?> body,
  ) _send;

  static PairedLanTransport fromClient(RestaurantLanClient client) {
    return PairedLanTransport(client.postAuthorized);
  }

  String? _lastPrintStatus;

  /// Print status the order center reported for the last accepted order
  /// ('forwarded', 'uncertain', 'failed', 'not_sent'), or null when unknown.
  String? get lastPrintStatus => _lastPrintStatus;

  @override
  Future<bool> submit(RestaurantLocalOrderRecord order) async {
    _lastPrintStatus = null;
    final response = await _send('/lan/orders', <String, Object?>{
      'local_order_id': order.localOrderId,
      'restaurant_id': order.restaurantId,
      'table_number': order.tableNumber,
      'table_name': order.tableName,
      'waiter_name': order.waiterName,
      'notes': order.notes,
      'revision': '1',
      'items': order.items,
    });
    final status = response['status'];
    if (status == 401 || status == 403) {
      throw StateError(
        response['error']?.toString() ??
            'Cihaz eşleşmesi yok veya iptal edildi.',
      );
    }
    final printStatus = response['print_status']?.toString().trim() ?? '';
    _lastPrintStatus = printStatus.isEmpty ? null : printStatus;
    return response['saved'] == true;
  }
}
