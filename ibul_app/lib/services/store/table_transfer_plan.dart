import '../../utils/garson_active_orders_fetch.dart';

/// The live `transfer_table_orders` function is only used for a full move.
/// Partial and customer moves stay blocked until `transfer_table_orders_v2`
/// is proven on the server.
bool legacyFullTransferAllowed(String canonicalType) => canonicalType == 'full';

enum TransferTimeoutRead { sameAsBefore, changed, incomplete }

/// A timed-out transfer is never retried. The read only describes what is
/// visible now; it does not prove the server call failed.
TransferTimeoutRead classifyTransferTimeoutRead({
  required Set<String> sourceIdsBefore,
  required Set<String> sourceIdsAfter,
  required Set<String> destinationIdsAfter,
  required int? sourceCustomerBefore,
  required int? destinationCustomerBefore,
  required int? sourceCustomerAfter,
  required int? destinationCustomerAfter,
}) {
  if (sourceCustomerBefore == null ||
      destinationCustomerBefore == null ||
      sourceCustomerAfter == null ||
      destinationCustomerAfter == null) {
    return TransferTimeoutRead.incomplete;
  }
  final idsSame = sourceIdsBefore.length == sourceIdsAfter.length &&
      sourceIdsBefore.containsAll(sourceIdsAfter);
  final movedIds = sourceIdsBefore.intersection(destinationIdsAfter);
  final customersSame = sourceCustomerBefore == sourceCustomerAfter &&
      destinationCustomerBefore == destinationCustomerAfter;
  if (idsSame && movedIds.isEmpty && customersSame) {
    return TransferTimeoutRead.sameAsBefore;
  }
  return TransferTimeoutRead.changed;
}

bool shouldAutoRetryTransferAfterTimeout() => false;

String transferTimeoutUserMessage(TransferTimeoutRead read) {
  final observation = switch (read) {
    TransferTimeoutRead.sameAsBefore =>
      'Yeniden okumada açık kayıtlar aktarım öncesiyle aynı görünüyor.',
    TransferTimeoutRead.changed =>
      'Yeniden okumada kaynak veya hedef değişmiş görünüyor.',
    TransferTimeoutRead.incomplete =>
      'Kaynak ve hedef masa yeniden okunamadı.',
  };
  return 'Masa aktarımı yanıtı zaman aşımına uğradı. Sonuç belirsiz. '
      'Otomatik tekrar yapılmadı. $observation';
}

/// Canonical transfer type stored in `table_transfers_log`.
///
/// The UI enum name `customerBased` is not a valid log value. Callers may
/// pass either the enum name or [TableTransferType.value].
String canonicalTableTransferType(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'partial':
      return 'partial';
    case 'customer':
    case 'customerbased':
    case 'customer_based':
      return 'customer';
    default:
      return 'full';
  }
}

/// Stable id for one line inside a table order.
///
/// Existing `transfer_line_id` or `id` wins. Otherwise the id is
/// `orderId#itemIndex`, which stays aligned between the picker and the
/// stored JSON even when the line has no database id.
String transferLineId({
  required String orderId,
  required int itemIndex,
  required Map<dynamic, dynamic> item,
}) {
  final explicit = item['transfer_line_id']?.toString().trim() ?? '';
  if (explicit.isNotEmpty) return explicit;
  final id = item['id']?.toString().trim() ?? '';
  if (id.isNotEmpty) return id;
  return '${orderId.trim()}#$itemIndex';
}

/// Copies order lines and stamps [transfer_line_id] for the transfer picker.
List<Map<String, dynamic>> flattenOrdersForTransfer(
  List<Map<String, dynamic>> orders,
) {
  final flattened = <Map<String, dynamic>>[];
  for (final order in orders) {
    final orderId = order['id']?.toString() ?? '';
    final rawItems = order['items'];
    if (rawItems is! List) continue;
    for (var index = 0; index < rawItems.length; index++) {
      final raw = rawItems[index];
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      item['transfer_line_id'] = transferLineId(
        orderId: orderId,
        itemIndex: index,
        item: item,
      );
      flattened.add(item);
    }
  }
  return flattened;
}

class TableTransferMutation {
  const TableTransferMutation({
    required this.orderId,
    required this.previousItems,
    required this.previousTableNumber,
    required this.nextItems,
    this.nextTableNumber,
    this.destinationItems,
    this.destinationStatus = 'sent',
  });

  final String orderId;
  final List<Map<String, dynamic>> previousItems;
  final int previousTableNumber;
  final List<Map<String, dynamic>> nextItems;
  final int? nextTableNumber;
  final List<Map<String, dynamic>>? destinationItems;
  final String destinationStatus;

  bool get splitsOrder =>
      destinationItems != null && destinationItems!.isNotEmpty;
}

class TableTransferPlan {
  const TableTransferPlan({
    required this.transferType,
    required this.mutations,
    required this.movedLineIds,
  });

  final String transferType;
  final List<TableTransferMutation> mutations;
  final List<String> movedLineIds;

  bool get hasChanges => mutations.isNotEmpty;
}

/// Plans a table move without writing.
///
/// Full transfer changes `table_number` on every active order.
/// Partial and customer transfers move only the selected lines. When every
/// line of an order is selected, the existing row moves. Otherwise the source
/// row keeps the remaining lines and the moved lines become one new order.
/// Unmatched ids and terminal orders produce no mutation.
TableTransferPlan planTableTransfer({
  required List<Map<String, dynamic>> orders,
  required int toTable,
  required String transferType,
  List<String> selectedLineIds = const <String>[],
}) {
  final canonical = canonicalTableTransferType(transferType);
  final selected = selectedLineIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  final mutations = <TableTransferMutation>[];
  final movedLineIds = <String>[];

  for (final order in orders) {
    if (isGarsonTerminalOrderStatus(order['status']?.toString())) continue;
    final orderId = order['id']?.toString().trim() ?? '';
    if (orderId.isEmpty) continue;
    final fromTable = _tableNumber(order['table_number']);
    final items = _stampItems(orderId, order['items']);
    if (items.isEmpty && canonical != 'full') continue;

    if (canonical == 'full') {
      mutations.add(
        TableTransferMutation(
          orderId: orderId,
          previousItems: items,
          previousTableNumber: fromTable,
          nextItems: items,
          nextTableNumber: toTable,
        ),
      );
      movedLineIds.addAll(
        items.map((item) => item['transfer_line_id'].toString()),
      );
      continue;
    }

    if (selected.isEmpty) continue;
    final kept = <Map<String, dynamic>>[];
    final moving = <Map<String, dynamic>>[];
    for (final item in items) {
      final lineId = item['transfer_line_id'].toString();
      if (selected.contains(lineId)) {
        moving.add(item);
        movedLineIds.add(lineId);
      } else {
        kept.add(item);
      }
    }
    if (moving.isEmpty) continue;

    final status = order['status']?.toString().trim() ?? '';
    if (kept.isEmpty) {
      mutations.add(
        TableTransferMutation(
          orderId: orderId,
          previousItems: items,
          previousTableNumber: fromTable,
          nextItems: moving,
          nextTableNumber: toTable,
        ),
      );
    } else {
      mutations.add(
        TableTransferMutation(
          orderId: orderId,
          previousItems: items,
          previousTableNumber: fromTable,
          nextItems: kept,
          destinationItems: moving,
          destinationStatus: status.isEmpty ? 'sent' : status,
        ),
      );
    }
  }

  return TableTransferPlan(
    transferType: canonical,
    mutations: mutations,
    movedLineIds: movedLineIds,
  );
}

List<Map<String, dynamic>> _stampItems(String orderId, dynamic rawItems) {
  if (rawItems is! List) return const <Map<String, dynamic>>[];
  final items = <Map<String, dynamic>>[];
  for (var index = 0; index < rawItems.length; index++) {
    final raw = rawItems[index];
    if (raw is! Map) continue;
    final item = Map<String, dynamic>.from(raw);
    item['transfer_line_id'] = transferLineId(
      orderId: orderId,
      itemIndex: index,
      item: item,
    );
    items.add(item);
  }
  return items;
}

int _tableNumber(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
