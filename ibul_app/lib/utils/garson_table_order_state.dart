import 'dart:convert';

import '../models/mixed_service_order.dart';
import 'table_labels.dart';

class GarsonVisibleOrderPreservation {
  const GarsonVisibleOrderPreservation({
    required this.table,
    required this.currentOrder,
    required this.incomingHasOrder,
  });

  final Map<String, dynamic>? table;
  final Map<String, dynamic> currentOrder;
  final bool incomingHasOrder;
}

class GarsonVisibleOrderMergeResult {
  const GarsonVisibleOrderMergeResult({
    required this.mergedOrders,
    required this.reason,
    this.preservedTables = const <GarsonVisibleOrderPreservation>[],
  });

  final List<Map<String, dynamic>> mergedOrders;
  final String reason;
  final List<GarsonVisibleOrderPreservation> preservedTables;
}

int _garsonTableNumberValue(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String _garsonText(dynamic raw) => (raw ?? '').toString().trim();

bool _garsonIsMissingBindingValue(dynamic raw) {
  if (raw == null) return true;
  if (raw is String) return raw.trim().isEmpty;
  if (raw is num) return raw <= 0;
  return false;
}

double? _garsonNumberValue(dynamic raw) {
  if (raw is num) return raw.toDouble();
  final text = _garsonText(raw).replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

bool _garsonIsMissingOrNonPositiveNumber(dynamic raw) {
  if (raw == null) return true;
  final parsed = _garsonNumberValue(raw);
  if (parsed != null) return parsed <= 0;
  if (raw is String) return raw.trim().isEmpty;
  return false;
}

bool _garsonIsPositiveNumber(dynamic raw) {
  final parsed = _garsonNumberValue(raw);
  return parsed != null && parsed > 0;
}

bool _garsonHasStableTableBinding(Map<String, dynamic> order) {
  final tableId = _garsonText(order['table_id']);
  final storeTableId = _garsonText(order['store_table_id']);
  if (tableId.isNotEmpty || storeTableId.isNotEmpty) return true;

  final areaName = _garsonText(
    order['area_name'] ?? order['table_area_name'] ?? order['table_area'],
  );
  final areaTableNumber = _firstPositiveBindingNumber(<dynamic>[
    order['area_table_number'],
    order['table_area_number'],
    order['area_table_no'],
  ]);
  if (areaName.isNotEmpty && areaTableNumber > 0) return true;

  final displayLabel = _garsonText(
    order['display_table_label'] ??
        order['table_display_name'] ??
        order['table_name'] ??
        order['display_label'],
  );
  return displayLabel.isNotEmpty;
}

int _firstPositiveBindingNumber(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = _garsonTableNumberValue(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

bool _garsonIsTerminalVisibilityStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  return normalized == 'closed' ||
      normalized == 'paid' ||
      normalized == 'cancelled' ||
      normalized == 'canceled' ||
      normalized == 'completed' ||
      normalized == 'complete' ||
      normalized == 'completed_payment' ||
      normalized == 'payment_completed';
}

Map<String, dynamic> _hydrateIncomingOrderWithVisibleBinding({
  required Map<String, dynamic> currentVisibleOrder,
  required Map<String, dynamic> incomingOrder,
  required List<Map<String, dynamic>> storeTables,
}) {
  final hydrated = Map<String, dynamic>.from(incomingOrder);
  final currentMatch = resolveStoreTableMatchForOrder(
    order: currentVisibleOrder,
    storeTables: storeTables,
  );
  final hydratedMatch = resolveStoreTableMatchForOrder(
    order: hydrated,
    storeTables: storeTables,
  );
  final currentHasStableBinding = _garsonHasStableTableBinding(
    currentVisibleOrder,
  );
  final incomingHasStableBinding = _garsonHasStableTableBinding(hydrated);
  final shouldCarryForwardBinding =
      currentHasStableBinding &&
      (!incomingHasStableBinding || hydratedMatch.table == null);

  const bindingKeys = <String>[
    'table_id',
    'store_table_id',
    'seller_id',
    'display_table_label',
    'table_display_name',
    'table_name',
    'display_label',
    'area_id',
    'area_name',
    'table_area_name',
    'table_area',
    'area_table_number',
    'table_area_number',
    'area_table_no',
  ];

  for (final key in bindingKeys) {
    if (!_garsonIsMissingBindingValue(hydrated[key])) continue;
    final currentValue = currentVisibleOrder[key];
    if (_garsonIsMissingBindingValue(currentValue)) continue;
    hydrated[key] = currentValue;
  }

  if (_garsonTableNumberValue(hydrated['table_number']) <= 0) {
    final currentTableNumber = _garsonTableNumberValue(
      currentVisibleOrder['table_number'],
    );
    if (currentTableNumber > 0) {
      hydrated['table_number'] = currentTableNumber;
    }
  }

  final incomingItems = garsonExtractOrderItems(hydrated['items']);
  final currentItems = garsonExtractOrderItems(currentVisibleOrder['items']);
  if (incomingItems.isEmpty && currentItems.isNotEmpty) {
    hydrated['items'] = currentItems;
  } else {
    hydrated['items'] = incomingItems;
  }

  const totalKeys = <String>[
    'total',
    'grand_total',
    'subtotal',
    'order_total',
    'total_amount',
    'amount',
    'line_total',
  ];
  for (final key in totalKeys) {
    final incomingTotal = hydrated[key];
    final currentTotal = currentVisibleOrder[key];
    if (!_garsonIsMissingOrNonPositiveNumber(incomingTotal)) continue;
    if (!_garsonIsPositiveNumber(currentTotal)) continue;
    hydrated[key] = currentTotal;
  }

  if (shouldCarryForwardBinding && currentMatch.table != null) {
    final currentTable = currentMatch.table!;
    hydrated['table_id'] = _garsonText(hydrated['table_id']).isNotEmpty
        ? hydrated['table_id']
        : (currentVisibleOrder['table_id'] ??
              currentVisibleOrder['store_table_id'] ??
              currentTable['id']);
    hydrated['store_table_id'] =
        _garsonText(hydrated['store_table_id']).isNotEmpty
        ? hydrated['store_table_id']
        : (currentVisibleOrder['store_table_id'] ??
              currentVisibleOrder['table_id'] ??
              currentTable['id']);
    hydrated['area_name'] = _garsonText(hydrated['area_name']).isNotEmpty
        ? hydrated['area_name']
        : (currentVisibleOrder['area_name'] ??
              currentVisibleOrder['table_area_name'] ??
              currentTable['area_name']);
    hydrated['table_area_name'] =
        _garsonText(hydrated['table_area_name']).isNotEmpty
        ? hydrated['table_area_name']
        : (currentVisibleOrder['table_area_name'] ??
              currentVisibleOrder['area_name'] ??
              currentTable['area_name']);
    final currentAreaTableNumber = _firstPositiveBindingNumber(<dynamic>[
      currentVisibleOrder['area_table_number'],
      currentVisibleOrder['table_area_number'],
      currentVisibleOrder['area_table_no'],
      currentTable['area_table_number'],
    ]);
    if (_firstPositiveBindingNumber(<dynamic>[
          hydrated['area_table_number'],
          hydrated['table_area_number'],
          hydrated['area_table_no'],
        ]) <=
        0) {
      if (currentAreaTableNumber > 0) {
        hydrated['area_table_number'] = currentAreaTableNumber;
      }
    }
    final currentDisplayLabel = _garsonText(
      currentVisibleOrder['display_table_label'] ??
          currentVisibleOrder['table_display_name'] ??
          currentVisibleOrder['table_name'] ??
          currentVisibleOrder['display_label'] ??
          currentTable['display_label'] ??
          currentTable['table_name'],
    );
    if (currentDisplayLabel.isNotEmpty) {
      hydrated['display_table_label'] =
          _garsonText(hydrated['display_table_label']).isNotEmpty
          ? hydrated['display_table_label']
          : currentDisplayLabel;
      hydrated['table_display_name'] =
          _garsonText(hydrated['table_display_name']).isNotEmpty
          ? hydrated['table_display_name']
          : currentDisplayLabel;
      hydrated['table_name'] = _garsonText(hydrated['table_name']).isNotEmpty
          ? hydrated['table_name']
          : currentDisplayLabel;
      hydrated['display_label'] =
          _garsonText(hydrated['display_label']).isNotEmpty
          ? hydrated['display_label']
          : currentDisplayLabel;
    }
  }

  return hydrated;
}

List<Map<String, dynamic>> _normalizeOrdersForVisibleMerge(
  List<Map<String, dynamic>> orders,
) {
  return mergeGarsonTableOrders(
    orders.map((order) => Map<String, dynamic>.from(order)),
    fallbackTableNumber: 0,
  );
}

Map<String, dynamic>? _storeTableByNumber(
  List<Map<String, dynamic>> storeTables,
  int tableNumber,
) {
  for (final table in storeTables) {
    if (_garsonTableNumberValue(table['table_number']) == tableNumber) {
      return table;
    }
  }
  return null;
}

int _resolvedTableNumberForOrder(
  Map<String, dynamic> order,
  List<Map<String, dynamic>> storeTables,
) {
  final tableMatch = resolveStoreTableMatchForOrder(
    order: order,
    storeTables: storeTables,
  );
  if (tableMatch.table != null) {
    final matched = _garsonTableNumberValue(tableMatch.table!['table_number']);
    if (matched > 0) return matched;
  }
  return _garsonTableNumberValue(order['table_number']);
}

List<Map<String, dynamic>> _ordersForTable(
  int tableNumber,
  List<Map<String, dynamic>> orders,
  List<Map<String, dynamic>> storeTables,
) {
  final table =
      _storeTableByNumber(storeTables, tableNumber) ??
      <String, dynamic>{'table_number': tableNumber};
  return orders
      .where((order) {
        final matchedBy = resolveOrderMatchKindForTable(
          table: table,
          order: order,
        );
        if (matchedBy != 'none') return true;
        return _resolvedTableNumberForOrder(order, storeTables) == tableNumber;
      })
      .toList(growable: false);
}

String _garsonMergeReason({
  required String source,
  required bool userInitiated,
  required bool hasNewerIncomingRevision,
  required List<GarsonVisibleOrderPreservation> preservedTables,
  required bool hasIncomingOrders,
}) {
  if (userInitiated && !hasIncomingOrders && preservedTables.isNotEmpty) {
    if (source == 'garson_order_submit' ||
        source.startsWith('garson_order_submit_') ||
        source == 'garson_table_route_popped' ||
        source.startsWith('garson_table_route_popped_')) {
      return 'user_action_preserve_visible_orders';
    }
    return 'manual_refresh';
  }
  if (userInitiated) return 'manual_refresh';
  if (!hasIncomingOrders) return 'incoming_empty';
  if (preservedTables.isNotEmpty) {
    return 'background_skip_preserve_visible_orders';
  }
  if (hasNewerIncomingRevision) return 'incoming_newer';
  switch (source) {
    case 'garson_order_submit':
    case 'garson_table_route_popped':
    case 'garson_local_table_action':
      return source;
    default:
      return 'apply_incoming';
  }
}

List<GarsonVisibleOrderPreservation> _collectGarsonPreservedTables({
  required List<Map<String, dynamic>> normalizedCurrent,
  required List<Map<String, dynamic>> normalizedIncoming,
  required List<Map<String, dynamic>> mergedOrders,
  required List<Map<String, dynamic>> storeTables,
}) {
  final tableNumbers = <int>{
    ...normalizedCurrent
        .map((order) => _resolvedTableNumberForOrder(order, storeTables))
        .where((tableNumber) => tableNumber > 0),
    ...normalizedIncoming
        .map((order) => _resolvedTableNumberForOrder(order, storeTables))
        .where((tableNumber) => tableNumber > 0),
  };

  final preservedTables = <GarsonVisibleOrderPreservation>[];
  for (final tableNumber in tableNumbers) {
    final table =
        _storeTableByNumber(storeTables, tableNumber) ??
        <String, dynamic>{'table_number': tableNumber};
    final currentTableOrders = _ordersForTable(
      tableNumber,
      normalizedCurrent,
      storeTables,
    );
    if (currentTableOrders.isEmpty) continue;
    final currentActive = resolveActiveOrderBindingForTable(
      table: table,
      activeOrders: currentTableOrders,
    ).order;
    if (currentActive == null) continue;

    final incomingTableOrders = _ordersForTable(
      tableNumber,
      normalizedIncoming,
      storeTables,
    );
    final incomingActive = resolveActiveOrderBindingForTable(
      table: table,
      activeOrders: incomingTableOrders,
    ).order;
    final mergedTableOrders = _ordersForTable(
      tableNumber,
      mergedOrders,
      storeTables,
    );
    final mergedActive = resolveActiveOrderBindingForTable(
      table: table,
      activeOrders: mergedTableOrders,
    ).order;
    if (incomingActive != null || mergedActive == null) continue;

    final currentIdentity = garsonTableOrderIdentity(
      currentActive,
      fallbackTableNumber: tableNumber,
    );
    final mergedIdentity = garsonTableOrderIdentity(
      mergedActive,
      fallbackTableNumber: tableNumber,
    );
    if (currentIdentity != mergedIdentity) continue;

    preservedTables.add(
      GarsonVisibleOrderPreservation(
        table: table,
        currentOrder: currentActive,
        incomingHasOrder: false,
      ),
    );
  }
  return preservedTables;
}

GarsonVisibleOrderMergeResult mergeGarsonVisibleOrdersSafely({
  required List<Map<String, dynamic>> currentVisibleOrders,
  required List<Map<String, dynamic>> incomingOrders,
  required List<Map<String, dynamic>> storeTables,
  required String source,
  required bool userInitiated,
}) {
  final normalizedCurrent = _normalizeOrdersForVisibleMerge(
    currentVisibleOrders,
  );
  final normalizedIncoming = _normalizeOrdersForVisibleMerge(incomingOrders);

  if (userInitiated) {
    final shouldPreserveVisibleUserState =
        normalizedIncoming.isEmpty &&
        normalizedCurrent.isNotEmpty &&
        (source == 'garson_order_submit' ||
            source.startsWith('garson_order_submit_') ||
            source == 'garson_table_route_popped' ||
            source.startsWith('garson_table_route_popped_'));
    if (shouldPreserveVisibleUserState) {
      final preservedTables = _collectGarsonPreservedTables(
        normalizedCurrent: normalizedCurrent,
        normalizedIncoming: normalizedIncoming,
        mergedOrders: normalizedCurrent,
        storeTables: storeTables,
      );
      return GarsonVisibleOrderMergeResult(
        mergedOrders: normalizedCurrent,
        reason: _garsonMergeReason(
          source: source,
          userInitiated: true,
          hasNewerIncomingRevision: false,
          preservedTables: preservedTables,
          hasIncomingOrders: false,
        ),
        preservedTables: preservedTables,
      );
    }
    return GarsonVisibleOrderMergeResult(
      mergedOrders: normalizedIncoming,
      reason: 'manual_refresh',
    );
  }

  var hasNewerIncomingRevision = false;
  for (final incoming in normalizedIncoming) {
    final fallbackTableNumber = _resolvedTableNumberForOrder(
      incoming,
      storeTables,
    );
    final incomingIdentity = garsonTableOrderIdentity(
      incoming,
      fallbackTableNumber: fallbackTableNumber,
    );
    final current = normalizedCurrent.cast<Map<String, dynamic>?>().firstWhere(
      (order) =>
          order != null &&
          garsonTableOrderIdentity(
                order,
                fallbackTableNumber: _resolvedTableNumberForOrder(
                  order,
                  storeTables,
                ),
              ) ==
              incomingIdentity,
      orElse: () => null,
    );
    if (current != null && isGarsonTableOrderNewer(incoming, current)) {
      hasNewerIncomingRevision = true;
      break;
    }
  }

  final currentByIdentity = <String, Map<String, dynamic>>{
    for (final order in normalizedCurrent)
      garsonTableOrderIdentity(
        order,
        fallbackTableNumber: _resolvedTableNumberForOrder(order, storeTables),
      ): Map<String, dynamic>.from(
        order,
      ),
  };
  final incomingByIdentity = <String, Map<String, dynamic>>{
    for (final order in normalizedIncoming)
      garsonTableOrderIdentity(
        order,
        fallbackTableNumber: _resolvedTableNumberForOrder(order, storeTables),
      ): Map<String, dynamic>.from(
        order,
      ),
  };

  final mergedOrders = <Map<String, dynamic>>[];
  final mergedIdentities = <String>{
    ...currentByIdentity.keys,
    ...incomingByIdentity.keys,
  };
  for (final identity in mergedIdentities) {
    final current = currentByIdentity[identity];
    final incoming = incomingByIdentity[identity];
    if (current == null && incoming != null) {
      mergedOrders.add(Map<String, dynamic>.from(incoming));
      continue;
    }
    if (incoming == null && current != null) {
      mergedOrders.add(Map<String, dynamic>.from(current));
      continue;
    }
    if (current == null || incoming == null) continue;

    final incomingTerminal = _garsonIsTerminalVisibilityStatus(
      incoming['status']?.toString(),
    );
    final currentNewer = isGarsonTableOrderNewer(current, incoming);
    final baseOrder = (!currentNewer || incomingTerminal) ? incoming : current;
    final fallbackOrder = identical(baseOrder, incoming) ? current : incoming;
    final hydratedBase = identical(baseOrder, incoming)
        ? _hydrateIncomingOrderWithVisibleBinding(
            currentVisibleOrder: current,
            incomingOrder: incoming,
            storeTables: storeTables,
          )
        : Map<String, dynamic>.from(baseOrder);
    final mergedOrder = Map<String, dynamic>.from(hydratedBase);
    if (_garsonText(mergedOrder['table_id']).isEmpty &&
        _garsonText(fallbackOrder['table_id']).isNotEmpty) {
      mergedOrder['table_id'] = fallbackOrder['table_id'];
    }
    if (_garsonText(mergedOrder['store_table_id']).isEmpty &&
        _garsonText(fallbackOrder['store_table_id']).isNotEmpty) {
      mergedOrder['store_table_id'] = fallbackOrder['store_table_id'];
    }
    mergedOrders.add(mergedOrder);
  }
  mergedOrders.sort((a, b) {
    final left =
        garsonOrderActivityAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right =
        garsonOrderActivityAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });

  final preservedTables = _collectGarsonPreservedTables(
    normalizedCurrent: normalizedCurrent,
    normalizedIncoming: normalizedIncoming,
    mergedOrders: mergedOrders,
    storeTables: storeTables,
  );

  return GarsonVisibleOrderMergeResult(
    mergedOrders: mergedOrders,
    reason: _garsonMergeReason(
      source: source,
      userInitiated: userInitiated,
      hasNewerIncomingRevision: hasNewerIncomingRevision,
      preservedTables: preservedTables,
      hasIncomingOrders: normalizedIncoming.isNotEmpty,
    ),
    preservedTables: preservedTables,
  );
}

/// Operational timestamp for garson order cards (revision / update, not first open).
DateTime? garsonOrderActivityAt(Map<String, dynamic> order) {
  const keys = <String>[
    'last_updated_at',
    'updated_at',
    'last_revision_at',
    'last_printed_at',
    'latest_order_event_at',
    'created_at',
  ];
  for (final key in keys) {
    final parsed = DateTime.tryParse(order[key]?.toString() ?? '');
    if (parsed != null) return parsed.toLocal();
  }
  return null;
}

String garsonOrderTimeAgoLabel(Map<String, dynamic> order) {
  final dt = garsonOrderActivityAt(order);
  if (dt == null) return '-';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  return '${diff.inDays} gün';
}

/// Suppresses a stale order row for a short period right after the user closes
/// the table locally.
///
/// This prevents the Garson board from re-opening a table with a lagging
/// backend snapshot while still allowing legitimately newer activity to appear.
bool shouldSuppressGarsonOrderForRecentlyClosedTable({
  required Map<String, dynamic> order,
  required DateTime closedAt,
  DateTime? now,
  Duration holdFor = const Duration(minutes: 2),
}) {
  final currentNow = (now ?? DateTime.now()).toLocal();
  final normalizedClosedAt = closedAt.toLocal();
  if (currentNow.isAfter(normalizedClosedAt.add(holdFor))) {
    return false;
  }
  final activityAt = garsonOrderActivityAt(order);
  if (activityAt == null) {
    return true;
  }
  return !activityAt.isAfter(normalizedClosedAt);
}

int garsonOrderRevision(Map<String, dynamic> order) {
  final parsed = order['revision'] is num
      ? (order['revision'] as num).toInt()
      : int.tryParse(order['revision']?.toString() ?? '');
  if (parsed == null || parsed <= 0) return 1;
  return parsed;
}

String garsonTableOrderIdentity(
  Map<String, dynamic> order, {
  required int fallbackTableNumber,
}) {
  final id = order['id']?.toString().trim() ?? '';
  if (id.isNotEmpty) return 'id:$id';
  final createdAt = order['created_at']?.toString().trim() ?? '';
  final status = order['status']?.toString().trim() ?? '';
  final tableNumber = order['table_number'] is int
      ? order['table_number'] as int
      : int.tryParse(order['table_number']?.toString() ?? '') ??
            fallbackTableNumber;
  final items = jsonEncode(garsonExtractOrderItems(order['items']));
  return 'fallback:$tableNumber|$createdAt|$status|$items';
}

List<Map<String, dynamic>> garsonExtractOrderItems(dynamic raw) {
  dynamic value = raw;
  if (value is String) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map(
        (entry) => MixedServiceOrder.normalizeOrderItem(
          Map<String, dynamic>.from(entry),
        ),
      )
      .toList(growable: false);
}

/// True when [candidate] should win over [incumbent] for the same order id.
bool isGarsonTableOrderNewer(
  Map<String, dynamic> candidate,
  Map<String, dynamic> incumbent,
) {
  final revisionDelta =
      garsonOrderRevision(candidate) - garsonOrderRevision(incumbent);
  if (revisionDelta != 0) return revisionDelta > 0;

  final candidateAt = garsonOrderActivityAt(candidate);
  final incumbentAt = garsonOrderActivityAt(incumbent);
  if (candidateAt != null && incumbentAt != null) {
    if (candidateAt.isAfter(incumbentAt)) return true;
    if (candidateAt.isBefore(incumbentAt)) return false;
  }

  final candidateItems = jsonEncode(
    garsonExtractOrderItems(candidate['items']),
  );
  final incumbentItems = jsonEncode(
    garsonExtractOrderItems(incumbent['items']),
  );
  return candidateItems != incumbentItems;
}

/// Merges order lists; newer revision / activity wins duplicate identities.
List<Map<String, dynamic>> mergeGarsonTableOrders(
  Iterable<Map<String, dynamic>> sources, {
  required int fallbackTableNumber,
}) {
  final byIdentity = <String, Map<String, dynamic>>{};
  for (final order in sources) {
    final normalized = Map<String, dynamic>.from(order);
    normalized['items'] = garsonExtractOrderItems(normalized['items']);
    normalized['revision'] = garsonOrderRevision(normalized);
    final identity = garsonTableOrderIdentity(
      normalized,
      fallbackTableNumber: fallbackTableNumber,
    );
    final existing = byIdentity[identity];
    if (existing == null || isGarsonTableOrderNewer(normalized, existing)) {
      byIdentity[identity] = normalized;
    }
  }
  final merged = byIdentity.values.toList(growable: false);
  merged.sort((a, b) {
    final left =
        garsonOrderActivityAt(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right =
        garsonOrderActivityAt(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  });
  return merged;
}

/// Applies a server snapshot while keeping newer optimistic rows.
({
  List<Map<String, dynamic>> hydrated,
  List<Map<String, dynamic>> optimisticRemaining,
})
reconcileGarsonTableOrdersAfterSnapshot({
  required List<Map<String, dynamic>> serverSnapshot,
  required List<Map<String, dynamic>> optimisticOrders,
  required int fallbackTableNumber,
}) {
  final normalizedSnapshot = serverSnapshot
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
  final optimisticRemaining = optimisticOrders
      .where((optimistic) {
        final identity = garsonTableOrderIdentity(
          optimistic,
          fallbackTableNumber: fallbackTableNumber,
        );
        final server = normalizedSnapshot
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (row) =>
                  garsonTableOrderIdentity(
                    row!,
                    fallbackTableNumber: fallbackTableNumber,
                  ) ==
                  identity,
              orElse: () => null,
            );
        if (server == null) return true;
        return isGarsonTableOrderNewer(optimistic, server);
      })
      .toList(growable: false);

  final hydrated = mergeGarsonTableOrders(<Map<String, dynamic>>[
    ...normalizedSnapshot,
    ...optimisticRemaining,
  ], fallbackTableNumber: fallbackTableNumber);
  return (hydrated: hydrated, optimisticRemaining: optimisticRemaining);
}

/// Ensures submitted payload items win over a stale DB row.
Map<String, dynamic> applyGarsonSubmittedOrderItems({
  required Map<String, dynamic> submittedOrder,
  required List<Map<String, dynamic>> items,
  required int revision,
  required String updatedAt,
}) {
  return <String, dynamic>{
    ...submittedOrder,
    'items': garsonExtractOrderItems(items),
    'revision': revision,
    'updated_at': updatedAt,
  };
}

/// Garson masa ızgarası: mock 1..N üretmez; store snapshot hazır değilse boş döner.
List<int> garsonTableNumbersForDisplay({
  required List<int> configuredTableNumbers,
  required List<int> lastGoodTableNumbers,
  required List<int> orderTableNumbers,
  required bool storeTablesReady,
}) {
  if (configuredTableNumbers.isNotEmpty) {
    return List<int>.from(configuredTableNumbers)..sort();
  }
  if (lastGoodTableNumbers.isNotEmpty) {
    return List<int>.from(lastGoodTableNumbers)..sort();
  }
  if (!storeTablesReady) return const <int>[];
  return orderTableNumbers.where((n) => n > 0).toSet().toList()..sort();
}
