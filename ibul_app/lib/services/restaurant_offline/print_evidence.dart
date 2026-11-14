/// Canonical print evidence. The LAN host signs this with its evidence key.
/// WebCrypto verifies the same bytes. A shared cloud secret is not included.
String lanPrintEvidenceCanonical({
  required String restaurantId,
  required String branchId,
  required String localOrderId,
  required String jobType,
  required String outcome,
  required String revision,
  required String eventId,
  required String keyId,
  required String serverFingerprint,
  required Iterable<Map<String, dynamic>> items,
}) {
  final stations = items
      .map((item) => item['station_id']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList(growable: false)
    ..sort();
  final lines = items.map(lanPrintEvidenceItemLine).toList(growable: false)
    ..sort();
  return <String>[
    'v2',
    restaurantId.trim(),
    branchId.trim(),
    localOrderId.trim(),
    jobType.trim(),
    outcome.trim(),
    revision.trim(),
    stations.join(','),
    eventId.trim(),
    keyId.trim(),
    serverFingerprint.trim(),
    lines.join('\n'),
  ].join('|');
}

String lanPrintEvidenceItemLine(Map<String, dynamic> item) {
  final product = item['product_id']?.toString().trim() ?? '';
  final name = item['name']?.toString().trim() ?? '';
  final quantity = item['quantity'];
  final parsedQuantity = quantity is num
      ? quantity.round()
      : int.tryParse(quantity?.toString() ?? '') ?? 1;
  final price = item['price'];
  final parsedPrice = price is num
      ? price.toDouble()
      : double.tryParse(price?.toString() ?? '') ?? 0;
  final station = item['station_id']?.toString().trim() ?? '';
  final notes = (item['notes'] ?? item['item_note'])?.toString().trim() ?? '';
  return <String>[
    product.isEmpty ? '-' : product,
    name.isEmpty ? 'Ürün' : name,
    (parsedQuantity < 1 ? 1 : parsedQuantity).toString(),
    parsedPrice.toStringAsFixed(2),
    station.isEmpty ? '-' : station,
    notes.isEmpty ? '-' : notes,
  ].join('|');
}

Map<String, dynamic> createTableOrderRpcParams({
  required String restaurantId,
  required int tableNumber,
  required List<Map<String, dynamic>> items,
  String? waiterId,
  String? waiterName,
  String? notes,
  String jobType = 'new_order',
  String? localOrderId,
  String? localPrintEvidence,
}) {
  final localId = localOrderId?.trim() ?? '';
  final evidence = localPrintEvidence?.trim() ?? '';
  return <String, dynamic>{
    'p_restaurant_id': restaurantId,
    'p_table_number': tableNumber,
    'p_items': items,
    'p_waiter_id': (waiterId == null || waiterId.isEmpty) ? null : waiterId,
    'p_waiter_name': waiterName,
    'p_notes': notes,
    'p_job_type': jobType,
    'p_order_type': 'table',
    if (localId.isNotEmpty) 'p_local_order_id': localId,
    if (evidence.isNotEmpty) 'p_local_print_evidence': evidence,
  };
}
