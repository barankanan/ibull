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
        openVisitIds: _visitIds(sourceOpen),
      ).fold<int>(0, (sum, payment) => sum + payment.amountKurus) +
      paymentsInOpenBill(
        payments: targetPayments.toList(growable: false),
        openedAt: targetOpened,
        now: now,
        hasOpenOrders: targetOpen.isNotEmpty,
        openVisitIds: _visitIds(targetOpen),
      ).fold<int>(0, (sum, payment) => sum + payment.amountKurus);
  final remaining = bill - paid;
  return remaining < 0 ? 0 : remaining;
}

/// Server sentences the cashier should see unchanged. A 42501 from this RPC
/// is an authorization result, not a generic row-policy failure.
String? friendlyMergeTableBillMessage({
  required String? code,
  required String message,
  String? details,
}) {
  final text = '${message.toLowerCase()} ${(details ?? '').toLowerCase()}';
  if (text.contains('ziyareti belirsiz') ||
      text.contains('belirsiz ziyaret') ||
      text.contains('birden fazla')) {
    return 'Birleştirme yapılmadı. Ziyareti belirsiz veya birden fazla '
        'ziyaret var. Ödemeler taşınmadı.';
  }
  if (text.contains('masalar değişti')) {
    return 'Masalar değişti. Birleştirme yapılmadı.';
  }
  if (text.contains('masa aktarma yetkisi') ||
      text.contains('birleştirme yetkisi') ||
      text.contains('yetkisi doğrulanamadı') ||
      code == '42501') {
    return 'Bu restoran için masa birleştirme yetkiniz yok.';
  }
  if (code == 'PGRST202' ||
      code == '42883' ||
      (text.contains('merge_table_bills') &&
          (text.contains('could not find') ||
              text.contains('does not exist') ||
              text.contains('schema cache')))) {
    return 'Masalar birleştirilemedi. Sunucu güncellemesi eksik. '
        'İşlem durduruldu; hesaplar değiştirilmedi.';
  }
  return null;
}

Set<String> _visitIds(Iterable<Map<String, dynamic>> orders) {
  return orders
      .map((order) => order['visit_id']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
}
