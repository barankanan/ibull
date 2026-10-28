class OrderStatusConstants {
  const OrderStatusConstants._();

  static const String ecommerceNew = 'new';
  static const String ecommerceConfirmed = 'confirmed';
  static const String ecommercePreparing = 'preparing';
  static const String ecommerceReadyToShip = 'ready_to_ship';
  static const String ecommerceShipped = 'shipped';
  static const String ecommerceTransfer = 'transfer';
  static const String ecommerceBranch = 'branch';
  static const String ecommerceOutForDelivery = 'out_for_delivery';
  static const String ecommerceDelivered = 'delivered';
  static const String ecommerceCancelled = 'cancelled';

  static const Set<String> terminalStatuses = <String>{
    ecommerceDelivered,
    ecommerceCancelled,
    'canceled',
    'closed',
    'paid',
    'completed',
    'complete',
    'completed_payment',
    'payment_completed',
    'archived',
  };

  static const Set<String> _cancelledStatuses = <String>{
    ecommerceCancelled,
    'canceled',
    'iptal',
    'rejected',
    'restaurant_cancelled',
    'return_cancelled',
  };

  static const Set<String> _ecommerceTerminalStatuses = <String>{
    ecommerceDelivered,
    ecommerceCancelled,
  };

  static String normalize(String? raw) {
    return (raw ?? '').trim().toLowerCase();
  }

  static bool isCancelledStatus(String? raw) {
    return _cancelledStatuses.contains(normalize(raw));
  }

  static bool isTerminalStatus(String? raw) {
    return terminalStatuses.contains(normalize(raw));
  }

  static bool isEcommerceTerminal(String? raw) {
    return _ecommerceTerminalStatuses.contains(normalize(raw));
  }

  static const Set<String> inTransitShipmentStatuses = <String>{
    ecommerceShipped,
    ecommerceTransfer,
    ecommerceBranch,
    ecommerceOutForDelivery,
  };

  static bool isInTransitShipmentStatus(String? raw) {
    return inTransitShipmentStatuses.contains(normalize(raw));
  }

  /// Online marketplace and food delivery stay in the seller Siparişler list.
  /// Only explicit table / waiter records are excluded for food stores.
  static bool isTableSourcedSellerOrder(Map<String, dynamic> order) {
    final explicit = order['is_table_order'];
    if (explicit is bool) return explicit;
    return looksLikeTableOrder(order);
  }

  static bool looksLikeTableOrder(Map<String, dynamic> order) {
    final orderNumber = (order['order_number'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (orderNumber.startsWith('TBL-')) return true;

    final orderType = normalize(order['order_type']?.toString());
    if (orderType == 'table' || orderType.startsWith('table_')) return true;

    final deliveryType = normalize(order['delivery_type']?.toString());
    if (deliveryType == 'table' ||
        deliveryType.startsWith('table_') ||
        deliveryType == 'masa' ||
        deliveryType.startsWith('masa_')) {
      return true;
    }

    final tableId = order['table_id']?.toString().trim() ?? '';
    if (tableId.isNotEmpty && tableId.toLowerCase() != 'null') return true;

    final waiterId = order['waiter_id']?.toString().trim() ?? '';
    return waiterId.isNotEmpty;
  }
}

class AdminApprovalStatusConstants {
  const AdminApprovalStatusConstants._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}
