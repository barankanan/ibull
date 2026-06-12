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
}

class AdminApprovalStatusConstants {
  const AdminApprovalStatusConstants._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}
