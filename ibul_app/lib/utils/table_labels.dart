/// Shared helpers to resolve table/area labels across UI + print payloads.
///
/// Intentionally uses loose `Map<String, dynamic>` inputs because these rows
/// come from Supabase/PostgREST and can vary across migrations.
library;

import 'package:flutter/foundation.dart';

String _t(dynamic v) => (v ?? '').toString().trim();

int _pi(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_t(v)) ?? 0;
}

int _firstPositiveInt(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = _pi(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

Set<String> _normalizedLabels(Iterable<dynamic> values) {
  final out = <String>{};
  for (final value in values) {
    final label = _t(value).toLowerCase();
    if (label.isNotEmpty) out.add(label);
  }
  return out;
}

String resolveTableDisplayLabel({
  required Map<String, dynamic>? table,
  int fallbackTableNumber = 0,
}) {
  if (table != null) {
    final display = _t(table['display_label']);
    if (display.isNotEmpty) return display;
    final tableName = _t(table['table_name']);
    if (tableName.isNotEmpty) return tableName;
    final areaName = _t(table['area_name']);
    final n = _firstPositiveInt(<dynamic>[
      table['area_table_number'],
      table['table_area_number'],
      table['area_table_no'],
      table['table_number'],
      fallbackTableNumber,
    ]);
    if (areaName.isNotEmpty && n > 0) return '$areaName $n';
  }
  if (fallbackTableNumber > 0) return 'Masa $fallbackTableNumber';
  return 'Masa';
}

/// Resolves the label to show on table cards (e.g. "Bahçe 3").
///
/// Priority:
/// - `display_label`
/// - `table_name`
/// - `area_name + table_number`
/// - `Masa N`
/// - `Masa`
String resolveTableCardTitle({
  required Map<String, dynamic>? tableRow,
  required int tableNumber,
}) {
  return resolveTableDisplayLabel(
    table: tableRow,
    fallbackTableNumber: tableNumber,
  );
}

/// Resolves the print payload table label fields to keep receipt + kitchen in sync.
Map<String, dynamic> resolvePrintableTablePayloadFields({
  required Map<String, dynamic>? tableRow,
  required int tableNumber,
}) {
  final title = resolveTableCardTitle(
    tableRow: tableRow,
    tableNumber: tableNumber,
  );
  final areaName = tableRow == null ? '' : _t(tableRow['area_name']);
  final areaTableNumber = tableRow == null
      ? 0
      : (_pi(tableRow['area_table_number']) > 0
            ? _pi(tableRow['area_table_number'])
            : _pi(tableRow['table_number']));
  return <String, dynamic>{
    'table_number': tableNumber,
    'display_table_label': title,
    'table_display_name': title,
    'table_name': title,
    'table_area_name': areaName,
    // Keep a duplicate for legacy + easier server-side compatibility.
    'area_name': areaName,
    if (areaTableNumber > 0) 'area_table_number': areaTableNumber,
  };
}

bool matchesAreaFilter({
  required String filterKey,
  required Map<String, dynamic>? tableRow,
}) {
  final key = _t(filterKey);
  if (key.isEmpty || key == 'all') return true;
  if (tableRow == null) return false;
  if (key.startsWith('id:')) {
    final id = key.substring(3);
    return _t(tableRow['area_id']) == id;
  }
  if (key.startsWith('name:')) {
    final name = key.substring(5).toLowerCase();
    return _t(tableRow['area_name']).toLowerCase() == name;
  }
  return true;
}

/// Suggest next missing area-local table number (1..N).
int nextAreaTableNumberSuggestion(
  List<Map<String, dynamic>> storeTables,
  String areaId,
) {
  final used =
      storeTables
          .where((t) => _t(t['area_id']) == _t(areaId))
          .map((t) => _pi(t['area_table_number']))
          .where((n) => n > 0)
          .toSet()
          .toList(growable: false)
        ..sort();
  var expected = 1;
  for (final n in used) {
    if (n == expected) {
      expected++;
    } else if (n > expected) {
      break;
    }
  }
  return expected;
}

/// Resolves the active order for a given table from a list of orders.
/// Matches robustly by table_id, store_table_id, table_number, area/label.
Map<String, dynamic>? resolveActiveOrderForTable({
  required Map<String, dynamic>? table,
  required List<Map<String, dynamic>> activeOrders,
  List<Map<String, dynamic>>? optimisticOrders,
}) {
  return resolveActiveOrderBindingForTable(
    table: table,
    activeOrders: activeOrders,
    optimisticOrders: optimisticOrders,
  ).order;
}

String resolveOrderMatchKindForTable({
  required Map<String, dynamic>? table,
  required Map<String, dynamic> order,
}) {
  if (table == null) return 'none';

  final tableIds = <String>{
    _t(table['id']),
    _t(table['table_id']),
    _t(table['store_table_id']),
  }..removeWhere((value) => value.isEmpty);
  final orderTableId = _t(order['table_id']);
  final orderStoreTableId = _t(order['store_table_id']);
  if (orderTableId.isNotEmpty && tableIds.contains(orderTableId)) {
    return 'table_id';
  }
  if (orderStoreTableId.isNotEmpty && tableIds.contains(orderStoreTableId)) {
    return 'store_table_id';
  }

  final tableNumber = _pi(table['table_number']);
  final orderTableNumber = _pi(order['table_number']);
  if (tableNumber > 0 && orderTableNumber == tableNumber) {
    return 'table_number';
  }

  final tableAreaName = _t(table['area_name']).toLowerCase();
  final tableAreaTableNumber = _firstPositiveInt(<dynamic>[
    table['area_table_number'],
    table['table_area_number'],
    table['area_table_no'],
    table['table_number'],
  ]);
  final orderAreaName = _t(
    order['area_name'] ?? order['table_area_name'] ?? order['table_area'],
  ).toLowerCase();
  final orderAreaTableNumber = _firstPositiveInt(<dynamic>[
    order['area_table_number'],
    order['table_area_number'],
    order['area_table_no'],
  ]);
  if (tableAreaName.isNotEmpty &&
      tableAreaTableNumber > 0 &&
      orderAreaName == tableAreaName &&
      orderAreaTableNumber == tableAreaTableNumber) {
    return 'area_name+area_table_number';
  }

  final tableLabels = _normalizedLabels(<dynamic>[
    table['display_label'],
    table['table_name'],
    resolveTableDisplayLabel(table: table, fallbackTableNumber: tableNumber),
  ]);
  final orderLabels = _normalizedLabels(<dynamic>[
    order['display_table_label'],
    order['table_display_name'],
    order['table_name'],
    order['display_label'],
    resolveTableDisplayLabel(
      table: order,
      fallbackTableNumber: orderTableNumber,
    ),
  ]);
  if (tableLabels.intersection(orderLabels).isNotEmpty) {
    return 'display_label';
  }

  return 'none';
}

({Map<String, dynamic>? table, String matchedBy})
resolveStoreTableMatchForOrder({
  required Map<String, dynamic> order,
  required List<Map<String, dynamic>> storeTables,
}) {
  const priorities = <String>[
    'table_id',
    'store_table_id',
    'area_name+area_table_number',
    'display_label',
    'table_number',
  ];
  for (final priority in priorities) {
    for (final table in storeTables) {
      final matchedBy = resolveOrderMatchKindForTable(
        table: table,
        order: order,
      );
      if (matchedBy == priority) {
        return (table: table, matchedBy: matchedBy);
      }
    }
  }
  return (table: null, matchedBy: 'none');
}

({Map<String, dynamic>? order, String matchedBy, bool fromOptimistic})
resolveActiveOrderBindingForTable({
  required Map<String, dynamic>? table,
  required List<Map<String, dynamic>> activeOrders,
  List<Map<String, dynamic>>? optimisticOrders,
}) {
  bool isCompleted(Map<String, dynamic> order) {
    final normalized = (order['status']?.toString() ?? '').trim().toLowerCase();
    return normalized == 'closed' ||
        normalized == 'paid' ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'completed' ||
        normalized == 'complete' ||
        normalized == 'completed_payment' ||
        normalized == 'payment_completed';
  }

  ({Map<String, dynamic>? order, String matchedBy}) findMatch(
    List<Map<String, dynamic>> orders,
  ) {
    const priorities = <String>[
      'table_id',
      'store_table_id',
      'table_number',
      'area_name+area_table_number',
      'display_label',
    ];
    for (final priority in priorities) {
      for (final order in orders) {
        if (isCompleted(order)) continue;
        final matchedBy = resolveOrderMatchKindForTable(
          table: table,
          order: order,
        );
        if (matchedBy == priority) {
          return (order: order, matchedBy: matchedBy);
        }
      }
    }
    return (order: null, matchedBy: 'none');
  }

  final activeMatch = findMatch(activeOrders);
  if (activeMatch.order != null) {
    return (
      order: activeMatch.order,
      matchedBy: activeMatch.matchedBy,
      fromOptimistic: false,
    );
  }

  final optimistic = optimisticOrders;
  if (optimistic == null || optimistic.isEmpty) {
    return (order: null, matchedBy: 'none', fromOptimistic: false);
  }

  final optimisticMatch = findMatch(optimistic);
  return (
    order: optimisticMatch.order,
    matchedBy: optimisticMatch.matchedBy,
    fromOptimistic: optimisticMatch.order != null,
  );
}

enum GarsonTableLabelSource {
  sectionItem,
  tableDisplayLabel,
  orderDisplayLabel,
  areaNumber,
  fallback,
}

class GarsonDisplayTableLabelResult {
  const GarsonDisplayTableLabelResult({
    required this.label,
    required this.source,
    required this.usedFallback,
  });

  final String label;
  final GarsonTableLabelSource source;
  final bool usedFallback;
}

String _areaNumberLabel({
  required Map<String, dynamic>? row,
  required int fallbackTableNumber,
}) {
  if (row == null) return '';
  final areaName = _t(row['area_name']);
  final n = _firstPositiveInt(<dynamic>[
    row['area_table_number'],
    row['table_area_number'],
    row['area_table_no'],
  ]);
  if (areaName.isNotEmpty && n > 0) return '$areaName $n';
  if (areaName.isNotEmpty && fallbackTableNumber > 0) {
    return '$areaName $fallbackTableNumber';
  }
  return '';
}

void logGarsonTableLabelFallbackUsed({
  required String reason,
  String tableId = '-',
  String storeTableId = '-',
  int rawTableNumber = 0,
  required String resolvedLabel,
}) {
  debugPrint(
    '[GARSON_TABLE_LABEL_FALLBACK_USED] '
    'reason=$reason '
    'table_id=$tableId '
    'store_table_id=$storeTableId '
    'raw_table_number=${rawTableNumber <= 0 ? '-' : rawTableNumber} '
    'resolved_label=$resolvedLabel',
  );
}

void logGarsonCloseTableLabelResolve({
  required String tableId,
  required String storeTableId,
  required int rawTableNumber,
  required String areaName,
  required int areaTableNumber,
  required String displayTableLabel,
  required String sectionDisplayLabel,
  required String resolvedLabel,
  required String source,
}) {
  debugPrint(
    '[GARSON_CLOSE_TABLE_LABEL_RESOLVE] '
    'table_id=$tableId '
    'store_table_id=$storeTableId '
    'raw_table_number=${rawTableNumber <= 0 ? '-' : rawTableNumber} '
    'area_name=${areaName.isEmpty ? '-' : areaName} '
    'area_table_number=${areaTableNumber <= 0 ? '-' : areaTableNumber} '
    'display_table_label=${displayTableLabel.isEmpty ? '-' : displayTableLabel} '
    'section_display_label=${sectionDisplayLabel.isEmpty ? '-' : sectionDisplayLabel} '
    'resolved_label=$resolvedLabel '
    'source=$source',
  );
}

void logGarsonCloseDialogOpen({
  required String resolvedLabel,
  required String dialogTitle,
  required String tableId,
  required String orderId,
}) {
  debugPrint(
    '[GARSON_CLOSE_DIALOG_OPEN] '
    'resolved_label=$resolvedLabel '
    'dialog_title=$dialogTitle '
    'table_id=$tableId '
    'order_id=$orderId',
  );
}

void logGarsonCloseTableSuccess({
  required String resolvedLabel,
  required String tableId,
  required String orderId,
  required String snackbarText,
}) {
  debugPrint(
    '[GARSON_CLOSE_TABLE_SUCCESS] '
    'resolved_label=$resolvedLabel '
    'table_id=$tableId '
    'order_id=$orderId '
    'snackbar_text=$snackbarText',
  );
}

GarsonDisplayTableLabelResult resolveGarsonDisplayTableLabel({
  Map<String, dynamic>? table,
  Map<String, dynamic>? activeOrder,
  String? sectionDisplayLabel,
  int fallbackTableNumber = 0,
}) {
  final tableId = _t(table?['id']);
  final storeTableId = tableId;
  final rawTableNumber = _firstPositiveInt(<dynamic>[
    table?['table_number'],
    fallbackTableNumber,
  ]);

  final sectionLabel = _t(sectionDisplayLabel);
  if (sectionLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: sectionLabel,
      source: GarsonTableLabelSource.sectionItem,
      usedFallback: false,
    );
  }

  final tableDisplayTableLabel = _t(table?['display_table_label']);
  if (tableDisplayTableLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: tableDisplayTableLabel,
      source: GarsonTableLabelSource.tableDisplayLabel,
      usedFallback: false,
    );
  }

  final tableDisplayLabel = _t(table?['display_label']);
  if (tableDisplayLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: tableDisplayLabel,
      source: GarsonTableLabelSource.tableDisplayLabel,
      usedFallback: false,
    );
  }

  final orderDisplayTableLabel = _t(activeOrder?['display_table_label']);
  if (orderDisplayTableLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: orderDisplayTableLabel,
      source: GarsonTableLabelSource.orderDisplayLabel,
      usedFallback: false,
    );
  }

  final orderTableLabel = _t(activeOrder?['table_label']);
  if (orderTableLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: orderTableLabel,
      source: GarsonTableLabelSource.orderDisplayLabel,
      usedFallback: false,
    );
  }

  final areaLabel = _areaNumberLabel(
    row: table,
    fallbackTableNumber: rawTableNumber,
  );
  if (areaLabel.isEmpty && activeOrder != null) {
    final orderAreaLabel = _areaNumberLabel(
      row: <String, dynamic>{
        'area_name':
            activeOrder['area_name'] ??
            activeOrder['table_area_name'] ??
            activeOrder['table_area'],
        'area_table_number': activeOrder['area_table_number'],
        'table_area_number': activeOrder['table_area_number'],
        'area_table_no': activeOrder['area_table_no'],
      },
      fallbackTableNumber: _firstPositiveInt(<dynamic>[
        activeOrder['table_number'],
        fallbackTableNumber,
      ]),
    );
    if (orderAreaLabel.isNotEmpty) {
      return GarsonDisplayTableLabelResult(
        label: orderAreaLabel,
        source: GarsonTableLabelSource.areaNumber,
        usedFallback: false,
      );
    }
  }
  if (areaLabel.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: areaLabel,
      source: GarsonTableLabelSource.areaNumber,
      usedFallback: false,
    );
  }

  final tableName = _t(table?['table_name']);
  if (tableName.isNotEmpty) {
    return GarsonDisplayTableLabelResult(
      label: tableName,
      source: GarsonTableLabelSource.tableDisplayLabel,
      usedFallback: false,
    );
  }

  final fallbackLabel = rawTableNumber > 0 ? 'Masa $rawTableNumber' : 'Masa';
  logGarsonTableLabelFallbackUsed(
    reason: 'missing_display_label',
    tableId: tableId,
    storeTableId: storeTableId,
    rawTableNumber: rawTableNumber,
    resolvedLabel: fallbackLabel,
  );
  return GarsonDisplayTableLabelResult(
    label: fallbackLabel,
    source: GarsonTableLabelSource.fallback,
    usedFallback: true,
  );
}

String garsonCloseTableDialogTitle(String label) => '$label kapatılsın mı?';

String garsonCloseTableSnackbarText(String label) => '$label kapatıldı.';

String garsonCloseTableAlreadyEmptySnackbarText(String label) =>
    '$label zaten boş.';

bool garsonCloseStatusIsTerminal(String? raw) {
  final normalized = (raw ?? '').trim().toLowerCase();
  return normalized == 'closed' ||
      normalized == 'paid' ||
      normalized == 'cancelled' ||
      normalized == 'canceled' ||
      normalized == 'completed' ||
      normalized == 'complete' ||
      normalized == 'completed_payment' ||
      normalized == 'payment_completed' ||
      normalized == 'archived' ||
      normalized == 'print_anchor';
}

/// How a row was tied to one physical table.
///
/// [tableId] and [areaLabel] are strong enough to move `table_number`.
/// [canonicalNumber] only means the row is already stored on that number.
enum GarsonTableProof { tableId, areaLabel, canonicalNumber, none }

GarsonTableProof garsonTableProof({
  required Map<String, dynamic>? table,
  required int canonicalTableNumber,
  required Map<String, dynamic> order,
  String? sellerId,
}) {
  if (garsonCloseStatusIsTerminal(order['status']?.toString())) {
    return GarsonTableProof.none;
  }
  final source = _t(order['_garson_source_table']);
  if (source == 'table_order_history') return GarsonTableProof.none;
  final orderSeller = _t(order['seller_id'] ?? order['restaurant_id']);
  final expectedSeller = _t(sellerId ?? table?['seller_id']);
  if (orderSeller.isNotEmpty &&
      expectedSeller.isNotEmpty &&
      orderSeller != expectedSeller) {
    return GarsonTableProof.none;
  }
  if (table == null) return GarsonTableProof.none;
  // A bill whose stored number is another physical table was transferred.
  // Bahçe 1 stored as its area index (1) while canonical is 11 is not a move.
  if (_storedTableNumberBelongsToAnotherTable(
    table: table,
    canonicalTableNumber: canonicalTableNumber,
    order: order,
  )) {
    return GarsonTableProof.none;
  }
  final tableId = _t(table['id']);
  final orderTableId = _t(order['table_id']);
  final orderStoreTableId = _t(order['store_table_id']);
  if (tableId.isNotEmpty &&
      (orderTableId.isNotEmpty || orderStoreTableId.isNotEmpty)) {
    if (orderTableId == tableId || orderStoreTableId == tableId) {
      return GarsonTableProof.tableId;
    }
    return GarsonTableProof.none;
  }

  final tableArea = _t(table['area_name']).toLowerCase();
  final orderArea = _t(
    order['area_name'] ?? order['table_area_name'] ?? order['table_area'],
  ).toLowerCase();
  final tableAreaNo = _pi(table['area_table_number']);
  final orderAreaNo = _firstPositiveInt(<dynamic>[
    order['area_table_number'],
    order['table_area_number'],
    order['area_table_no'],
  ]);
  final tableLabel = _t(table['display_label'] ?? table['table_name']);
  final orderLabel = _t(
    order['display_table_label'] ??
        order['table_display_name'] ??
        order['display_label'] ??
        order['table_name'],
  );
  final areaComplete = tableArea.isNotEmpty &&
      orderArea.isNotEmpty &&
      tableArea == orderArea &&
      tableAreaNo > 0 &&
      orderAreaNo > 0 &&
      tableAreaNo == orderAreaNo &&
      tableLabel.isNotEmpty &&
      orderLabel.isNotEmpty &&
      tableLabel.toLowerCase() == orderLabel.toLowerCase();
  if (areaComplete) return GarsonTableProof.areaLabel;

  final orderHasPartialArea = orderArea.isNotEmpty || orderAreaNo > 0;
  if (orderHasPartialArea) return GarsonTableProof.none;

  final tableNumber = _pi(table['table_number']);
  final orderNumber = _pi(order['table_number']);
  if (canonicalTableNumber > 0 &&
      tableNumber == canonicalTableNumber &&
      orderNumber == canonicalTableNumber &&
      (orderLabel.isEmpty ||
          tableLabel.isEmpty ||
          orderLabel.toLowerCase() == tableLabel.toLowerCase())) {
    return GarsonTableProof.canonicalNumber;
  }
  return GarsonTableProof.none;
}

/// Bahçe 1 is store table 11 and area index 1. A row is not chosen from
/// `table_number` alone when area data is missing or only partly filled.
bool garsonOrderBelongsToCloseTable({
  required Map<String, dynamic>? table,
  required int canonicalTableNumber,
  required Map<String, dynamic> order,
  String? sellerId,
}) {
  return garsonTableProof(
        table: table,
        canonicalTableNumber: canonicalTableNumber,
        order: order,
        sellerId: sellerId,
      ) !=
      GarsonTableProof.none;
}

bool _storedTableNumberBelongsToAnotherTable({
  required Map<String, dynamic> table,
  required int canonicalTableNumber,
  required Map<String, dynamic> order,
}) {
  final stored = garsonStoredTableNumber(order);
  if (stored <= 0) return false;
  final canonical = canonicalTableNumber > 0
      ? canonicalTableNumber
      : _pi(table['table_number']);
  if (canonical <= 0 || stored == canonical) return false;
  final areaNo = _pi(table['area_table_number']);
  // Bahçe 1 is stored as its area index. A full transfer onto Salon 1 writes
  // only table_number and leaves this area label, so the two rows match.
  // Keep this exception until a persisted field can tell them apart.
  if (areaNo > 0 && stored == areaNo) return false;
  return true;
}

int garsonStoredTableNumber(Map<String, dynamic> order) {
  final stored = _pi(order['_stored_table_number']);
  if (stored > 0) return stored;
  return _pi(order['table_number']);
}

bool garsonTableOrderNeedsRealign({
  required Map<String, dynamic> order,
  required Map<String, dynamic> table,
  required int canonicalTableNumber,
  required String sellerId,
}) {
  if ((order['_garson_source_table'] ?? '').toString() != 'table_orders') {
    return false;
  }
  final proof = garsonTableProof(
    table: table,
    canonicalTableNumber: canonicalTableNumber,
    order: order,
    sellerId: sellerId,
  );
  if (proof != GarsonTableProof.tableId &&
      proof != GarsonTableProof.areaLabel) {
    return false;
  }
  final stored = garsonStoredTableNumber(order);
  return stored > 0 &&
      canonicalTableNumber > 0 &&
      stored != canonicalTableNumber;
}

List<Map<String, dynamic>> garsonRowsForTableClose({
  required Map<String, dynamic>? table,
  required int canonicalTableNumber,
  required String sellerId,
  required List<Map<String, dynamic>> candidates,
}) {
  return <Map<String, dynamic>>[
    for (final order in candidates)
      if (garsonOrderBelongsToCloseTable(
        table: table,
        canonicalTableNumber: canonicalTableNumber,
        order: order,
        sellerId: sellerId,
      ))
        order,
  ];
}

/// Bahçe 1 is canonical table 11. A card titled Bahçe 1 must not use Salon 1.
int canonicalStoreTableNumber({
  required int requestedNumber,
  required String? displayLabel,
  required List<Map<String, dynamic>> tables,
}) {
  final label = displayLabel?.trim() ?? '';
  if (label.isNotEmpty) {
    for (final row in tables) {
      final stored = (row['display_label'] ?? row['display_table_label'] ?? '')
          .toString()
          .trim();
      if (stored != label) continue;
      final number = _firstPositiveInt(<dynamic>[row['table_number']]);
      if (number > 0) return number;
    }
  }
  return requestedNumber > 0 ? requestedNumber : 0;
}

/// Completeness needs a successful fetch, a count under the cap, and the
/// raw row count equal to the server count. Rows removed by normalization
/// or filtering are counted apart and do not replace that comparison.
bool openOrderReadIsComplete({
  required bool tableFetchFailed,
  required bool restaurantFetchFailed,
  required int? openTableOrders,
  required int? openCustomerOrders,
  required int? rawTableOrders,
  required int? rawCustomerOrders,
  int removedByNormalization = 0,
  int removedByFilter = 0,
  int restaurantFetchCap = 200,
  int tableFetchCap = 1000,
}) {
  if (tableFetchFailed || restaurantFetchFailed) return false;
  if (openTableOrders == null ||
      openCustomerOrders == null ||
      rawTableOrders == null ||
      rawCustomerOrders == null) {
    return false;
  }
  if (openTableOrders >= tableFetchCap ||
      openCustomerOrders >= restaurantFetchCap) {
    return false;
  }
  if (rawTableOrders != openTableOrders ||
      rawCustomerOrders != openCustomerOrders) {
    return false;
  }
  if (removedByNormalization < 0 || removedByFilter < 0) return false;
  if (removedByNormalization + removedByFilter >
      rawTableOrders + rawCustomerOrders) {
    return false;
  }
  return true;
}

/// An empty close list is trustworthy only after every target-table read
/// succeeded and the physical table id is known.
bool closeSessionMayTreatAsEmpty({
  required bool snapshotFailed,
  required bool areaReadFailed,
  required bool ordersReadFailed,
  required bool visibleIdsReadFailed,
  required bool tableIdentityKnown,
  required bool tableIdKnown,
}) {
  if (!tableIdentityKnown || !tableIdKnown) return false;
  if (snapshotFailed ||
      areaReadFailed ||
      ordersReadFailed ||
      visibleIdsReadFailed) {
    return false;
  }
  return true;
}

class GarsonVisibleTableCard {
  const GarsonVisibleTableCard({
    required this.orders,
    required this.draftItems,
  });

  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> draftItems;
}

/// A failed or incomplete server read leaves the card and its draft in place.
GarsonVisibleTableCard garsonCardAfterServerRead({
  required GarsonVisibleTableCard current,
  required bool readSucceeded,
  required bool readComplete,
  required bool verifiedEmptyClose,
}) {
  if (!readSucceeded || !readComplete || !verifiedEmptyClose) return current;
  return GarsonVisibleTableCard(
    orders: const <Map<String, dynamic>>[],
    draftItems: current.draftItems,
  );
}

class GarsonOpenOrderRead {
  const GarsonOpenOrderRead({
    required this.orders,
    required this.succeeded,
    required this.complete,
    this.withheldServerIds = const <String>{},
  });

  final List<Map<String, dynamic>> orders;
  final bool succeeded;
  final bool complete;

  /// Server rows removed by normalization or filtering. They are still open.
  final Set<String> withheldServerIds;
}

/// Cache is cleared only after a successful read whose row count matched
/// the server count. A short list is not treated as complete by itself.
List<Map<String, dynamic>> dropCachedBillsMissingFromOpenSnapshot({
  required List<Map<String, dynamic>> visibleOrders,
  required GarsonOpenOrderRead serverRead,
}) {
  if (!serverRead.succeeded || !serverRead.complete) return visibleOrders;
  final openIds = <String>{
    for (final order in serverRead.orders)
      if (_t(order['id']).isNotEmpty) _t(order['id']),
    ...serverRead.withheldServerIds,
  };
  return <Map<String, dynamic>>[
    for (final order in visibleOrders)
      if (_cachedBillStillOpen(order, openIds)) order,
  ];
}

bool _cachedBillStillOpen(Map<String, dynamic> order, Set<String> openIds) {
  final status = _t(order['status']).toLowerCase();
  if (status == 'draft') return true;
  final id = _t(order['id']);
  if (id.isEmpty) return false;
  return openIds.contains(id);
}
