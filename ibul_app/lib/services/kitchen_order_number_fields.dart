import 'kitchen_print_trace_log.dart';

/// Mutfak fişi sipariş numarası — günlük sıra öncelikli; garson adı karışmaz.
String resolveKitchenPrintedOrderNo(Map<String, dynamic> payload) {
  final waiterName = payload['waiter_name']?.toString().trim() ?? '';

  for (final key in <String>[
    'daily_order_no',
    'kitchen_order_no',
    'printed_order_no',
  ]) {
    final value = _positiveOrderNumber(payload[key]);
    if (value != null) return value;
  }

  for (final key in <String>['order_no', 'order_number']) {
    final raw = payload[key]?.toString().trim() ?? '';
    if (raw.isEmpty || raw == '-') continue;
    if (_looksLikeWaiterLabel(raw, waiterName)) continue;
    return raw;
  }

  return '-';
}

String? _positiveOrderNumber(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    final n = raw.toInt();
    return n > 0 ? '$n' : null;
  }
  final text = raw.toString().trim();
  if (text.isEmpty || text == '-') return null;
  final parsed = int.tryParse(text);
  if (parsed != null && parsed > 0) return '$parsed';
  return text;
}

bool _looksLikeWaiterLabel(String candidate, String waiterName) {
  if (waiterName.isNotEmpty && candidate == waiterName) return true;
  final lower = candidate.toLowerCase();
  return lower == 'garson' || lower.startsWith('garson ');
}

void stampKitchenOrderNumberFields(Map<String, dynamic> payload) {
  final printed = resolveKitchenPrintedOrderNo(payload);
  if (printed != '-') {
    payload['order_no'] = printed;
    payload['printed_order_no'] = printed;
  }
  logKitchenOrderNumberFields(payload: payload, printedOrderNo: printed);
}
