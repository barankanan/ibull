import 'table_payment_guard.dart';

const Set<String> tableMergeTerminalStatuses = <String>{
  'closed',
  'paid',
  'cancelled',
  'canceled',
  'completed',
  'complete',
  'completed_payment',
  'payment_completed',
  'archived',
  'delivered',
  'print_anchor',
};

bool isOpenTableBillStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return !tableMergeTerminalStatuses.contains(normalized);
}

List<Map<String, dynamic>> openTableBills(Iterable<Map<String, dynamic>> orders) {
  return orders
      .where((order) => isOpenTableBillStatus(order['status']?.toString()))
      .toList(growable: false);
}

List<String> openTableBillIds(Iterable<Map<String, dynamic>> orders) {
  return openTableBills(orders)
      .map((order) => order['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
}

/// Preview of the combined remaining bill. Payments are not copied; the
/// server moves the existing rows.
int mergedTableRemainingKurus({
  required Iterable<Map<String, dynamic>> sourceOrders,
  required Iterable<Map<String, dynamic>> targetOrders,
  required Iterable<RecordedTablePayment> sourcePayments,
  required Iterable<RecordedTablePayment> targetPayments,
}) {
  final sourceOpen = openTableBills(sourceOrders);
  final targetOpen = openTableBills(targetOrders);
  final bill = billKurusForOrders(sourceOpen) + billKurusForOrders(targetOpen);
  final sourceOpened = earliestOrderOpenedAt(sourceOpen);
  final targetOpened = earliestOrderOpenedAt(targetOpen);
  final now = DateTime.now().toUtc().add(const Duration(days: 1));
  final paid = paymentsInOpenBill(
        payments: sourcePayments.toList(growable: false),
        openedAt: sourceOpened,
        now: now,
        hasOpenOrders: sourceOpen.isNotEmpty,
      ).fold<int>(0, (sum, payment) => sum + payment.amountKurus) +
      paymentsInOpenBill(
        payments: targetPayments.toList(growable: false),
        openedAt: targetOpened,
        now: now,
        hasOpenOrders: targetOpen.isNotEmpty,
      ).fold<int>(0, (sum, payment) => sum + payment.amountKurus);
  final remaining = bill - paid;
  return remaining < 0 ? 0 : remaining;
}
