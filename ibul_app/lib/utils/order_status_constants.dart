// Centralized definitions for order statuses across the application.
// Keeping these synchronized prevents "ghost order" and "dashboard metric" bugs.

class OrderStatusConstants {
  const OrderStatusConstants._();

  // --- E-Commerce & Shipment Core Statuses ---
  static const String ecommerceNew = 'new';
  static const String ecommerceConfirmed = 'confirmed';
  static const String ecommercePreparing = 'preparing';
  static const String ecommerceReadyToShip = 'ready_to_ship';
  static const String ecommerceShipped = 'shipped';
  static const String ecommerceTransfer = 'transfer';
  static const String ecommerceBranch = 'branch';
  static const String ecommerceOutForDelivery = 'out_for_delivery';
  static const String ecommerceDelivered = 'delivered';
  static const String ecommerceReturns = 'returns';
  static const String ecommerceCancelled = 'cancelled';
  static const String unknown = 'unknown';

  /// A unified set of statuses that indicate an order (table or online)
  /// has reached a final, immutable state (either successfully or cancelled).
  static const Set<String> terminalStatuses = <String>{
    'closed',
    'paid',
    'cancelled',
    'canceled',
    'completed',
    'complete',
    'archived',
    'payment_completed',
    'completed_payment',
    'delivered',
    'teslim edildi',
    'iptal edildi',
    'refunded',
    'iade edildi',
  };

  /// Statuses that specifically mean the order was cancelled, refunded, or rejected.
  /// Used primarily to exclude these orders from revenue calculations.
  static const Set<String> cancelledStatuses = <String>{
    'cancelled',
    'canceled',
    'iptal edildi',
    'iptal',
    'refunded',
    'refund',
    'iade',
    'iade edildi',
    'returned',
    'rejected',
    'reddedildi',
    'void',
    'deleted',
  };

  /// Statuses that specifically mean the order was successfully completed or paid.
  static const Set<String> completedStatuses = <String>{
    'closed',
    'paid',
    'completed',
    'complete',
    'archived',
    'payment_completed',
    'completed_payment',
    'delivered',
    'teslim edildi',
  };

  /// Returns a comma-separated string of terminal statuses suitable for Supabase `.in` filters.
  static String get terminalStatusesForSql => terminalStatuses.join(',');

  /// Checks if a raw status string maps to a terminal status.
  static bool isTerminalStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return false;
    return terminalStatuses.contains(rawStatus.trim().toLowerCase());
  }

  /// Checks if a raw status string maps to a cancelled/refunded status.
  static bool isCancelledStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return false;
    final normalized = rawStatus.trim().toLowerCase();
    for (final cancelWord in cancelledStatuses) {
      if (normalized.contains(cancelWord)) return true;
    }
    return false;
  }

  /// Checks if a raw status string maps to an active e-commerce status.
  static bool isActiveEcommerce(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return false;
    final s = rawStatus.trim().toLowerCase();
    return s == ecommerceNew ||
        s == ecommerceConfirmed ||
        s == ecommercePreparing ||
        s == ecommerceReadyToShip ||
        s == ecommerceShipped ||
        s == ecommerceTransfer ||
        s == ecommerceBranch ||
        s == ecommerceOutForDelivery;
  }

  /// Checks if a raw status string maps to a terminal e-commerce status.
  static bool isEcommerceTerminal(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return false;
    final s = rawStatus.trim().toLowerCase();
    return s == ecommerceDelivered || s == ecommerceCancelled || s == ecommerceReturns;
  }
}

/// Constants and helpers for Admin, Store Application, and Ads approval states.
class AdminApprovalStatusConstants {
  const AdminApprovalStatusConstants._();

  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';

  /// Safely normalizes the raw status string. Returns 'pending' if null or empty.
  static String normalize(String? rawStatus) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return pending;
    final s = rawStatus.trim().toLowerCase();
    if (s == approved) return approved;
    if (s == rejected) return rejected;
    return pending;
  }

  /// Checks if the status is strictly pending (or fallback to pending).
  static bool isPending(String? rawStatus) => normalize(rawStatus) == pending;

  /// Checks if a final decision (approved or rejected) has been made.
  static bool isDecided(String? rawStatus) {
    final s = normalize(rawStatus);
    return s == approved || s == rejected;
  }

  /// Checks if the status is specifically approved.
  static bool isApproved(String? rawStatus) => normalize(rawStatus) == approved;

  /// Checks if the status is specifically rejected.
  static bool isRejected(String? rawStatus) => normalize(rawStatus) == rejected;
}
