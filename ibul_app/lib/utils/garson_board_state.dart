import 'package:flutter/foundation.dart';

import 'package:ibul_app/utils/garson_area_sections.dart';
import 'package:ibul_app/utils/table_labels.dart';

enum GarsonInitialLoadStatus { loading, loaded, empty, failed }

class GarsonBoardState {
  const GarsonBoardState({
    this.tables = const <Map<String, dynamic>>[],
    this.areas = const <Map<String, dynamic>>[],
    this.orders = const <Map<String, dynamic>>[],
    this.lastGoodTables = const <Map<String, dynamic>>[],
    this.lastGoodAreas = const <Map<String, dynamic>>[],
    this.lastGoodOrders = const <Map<String, dynamic>>[],
    this.lastGoodSections,
    this.pendingOrders = const <Map<String, dynamic>>[],
    this.pendingTables = const <Map<String, dynamic>>[],
    this.hasPendingRemoteChanges = false,
    this.hasEverLoadedTablesSuccessfully = false,
    this.hasEverRenderedBoardSuccessfully = false,
    this.initialLoadStatus = GarsonInitialLoadStatus.loading,
    this.lastAppliedSource = 'none',
    this.lastUpdateAt,
  });

  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> areas;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> lastGoodTables;
  final List<Map<String, dynamic>> lastGoodAreas;
  final List<Map<String, dynamic>> lastGoodOrders;
  final GarsonAreaSectionsResult? lastGoodSections;
  final List<Map<String, dynamic>> pendingOrders;
  final List<Map<String, dynamic>> pendingTables;
  final bool hasPendingRemoteChanges;
  final bool hasEverLoadedTablesSuccessfully;
  final bool hasEverRenderedBoardSuccessfully;
  final GarsonInitialLoadStatus initialLoadStatus;
  final String lastAppliedSource;
  final DateTime? lastUpdateAt;

  List<Map<String, dynamic>> get uiTables =>
      tables.isNotEmpty ? tables : lastGoodTables;

  List<Map<String, dynamic>> get uiAreas =>
      areas.isNotEmpty ? areas : lastGoodAreas;

  List<Map<String, dynamic>> get uiOrders =>
      orders.isNotEmpty ? orders : lastGoodOrders;

  String get tablesSource => tables.isNotEmpty
      ? 'visible'
      : (lastGoodTables.isNotEmpty ? 'last_good' : 'none');

  String get ordersSource => orders.isNotEmpty
      ? 'visible'
      : (lastGoodOrders.isNotEmpty ? 'last_good' : 'none');

  GarsonBoardState copyWith({
    List<Map<String, dynamic>>? tables,
    List<Map<String, dynamic>>? areas,
    List<Map<String, dynamic>>? orders,
    List<Map<String, dynamic>>? lastGoodTables,
    List<Map<String, dynamic>>? lastGoodAreas,
    List<Map<String, dynamic>>? lastGoodOrders,
    GarsonAreaSectionsResult? lastGoodSections,
    List<Map<String, dynamic>>? pendingOrders,
    List<Map<String, dynamic>>? pendingTables,
    bool? hasPendingRemoteChanges,
    bool? hasEverLoadedTablesSuccessfully,
    bool? hasEverRenderedBoardSuccessfully,
    GarsonInitialLoadStatus? initialLoadStatus,
    String? lastAppliedSource,
    DateTime? lastUpdateAt,
  }) {
    return GarsonBoardState(
      tables: _cloneRows(tables ?? this.tables),
      areas: _cloneRows(areas ?? this.areas),
      orders: _cloneRows(orders ?? this.orders),
      lastGoodTables: _cloneRows(lastGoodTables ?? this.lastGoodTables),
      lastGoodAreas: _cloneRows(lastGoodAreas ?? this.lastGoodAreas),
      lastGoodOrders: _cloneRows(lastGoodOrders ?? this.lastGoodOrders),
      lastGoodSections: lastGoodSections ?? this.lastGoodSections,
      pendingOrders: _cloneRows(pendingOrders ?? this.pendingOrders),
      pendingTables: _cloneRows(pendingTables ?? this.pendingTables),
      hasPendingRemoteChanges:
          hasPendingRemoteChanges ?? this.hasPendingRemoteChanges,
      hasEverLoadedTablesSuccessfully:
          hasEverLoadedTablesSuccessfully ??
          this.hasEverLoadedTablesSuccessfully,
      hasEverRenderedBoardSuccessfully:
          hasEverRenderedBoardSuccessfully ??
          this.hasEverRenderedBoardSuccessfully,
      initialLoadStatus: initialLoadStatus ?? this.initialLoadStatus,
      lastAppliedSource: lastAppliedSource ?? this.lastAppliedSource,
      lastUpdateAt: lastUpdateAt ?? this.lastUpdateAt,
    );
  }
}

void logGarsonRouteChangeState({
  required String fromModule,
  required String toModule,
  required int boardTablesCount,
  required int boardAreasCount,
  required int boardOrdersCount,
  required int lastGoodSectionsCount,
  required bool willResetBoard,
  required String reason,
}) {
  debugPrint(
    '[GARSON_ROUTE_CHANGE_STATE] '
    'from_module=$fromModule '
    'to_module=$toModule '
    'board_tables_count=$boardTablesCount '
    'board_areas_count=$boardAreasCount '
    'board_orders_count=$boardOrdersCount '
    'last_good_sections_count=$lastGoodSectionsCount '
    'will_reset_board=$willResetBoard '
    'reason=$reason',
  );
}

void logGarsonBoardBootstrapOnReturn({
  required String source,
  required int tablesCount,
  required int areasCount,
  required int ordersCount,
  required bool willKeepLastGood,
}) {
  debugPrint(
    '[GARSON_BOARD_BOOTSTRAP_ON_RETURN] '
    'source=$source '
    'tables_count=$tablesCount '
    'areas_count=$areasCount '
    'orders_count=$ordersCount '
    'will_keep_last_good=$willKeepLastGood',
  );
}

void logGarsonRefreshKeepingBoard({
  required String reason,
  required int lastGoodSectionsCount,
}) {
  debugPrint(
    '[GARSON_REFRESH_KEEPING_BOARD] '
    'reason=$reason '
    'last_good_sections_count=$lastGoodSectionsCount',
  );
}

List<Map<String, dynamic>> _cloneRows(List<Map<String, dynamic>> rows) {
  return rows
      .map((row) => Map<String, dynamic>.from(row))
      .toList(growable: false);
}

GarsonBoardState applyInitialBootstrap({
  required GarsonBoardState current,
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> areas,
  required List<Map<String, dynamic>> orders,
  required String source,
}) {
  final nextTables = _cloneRows(tables);
  final nextAreas = _cloneRows(areas);
  final nextOrders = _cloneRows(orders);
  return current.copyWith(
    tables: nextTables,
    areas: nextAreas,
    orders: nextOrders,
    lastGoodTables: nextTables,
    lastGoodAreas: nextAreas,
    lastGoodOrders: nextOrders,
    pendingTables: const <Map<String, dynamic>>[],
    pendingOrders: const <Map<String, dynamic>>[],
    hasPendingRemoteChanges: false,
    hasEverLoadedTablesSuccessfully:
        current.hasEverLoadedTablesSuccessfully || nextTables.isNotEmpty,
    hasEverRenderedBoardSuccessfully:
        current.hasEverRenderedBoardSuccessfully || nextTables.isNotEmpty,
    initialLoadStatus: nextTables.isEmpty
        ? GarsonInitialLoadStatus.empty
        : GarsonInitialLoadStatus.loaded,
    lastAppliedSource: source,
    lastUpdateAt: DateTime.now(),
  );
}

GarsonBoardState applyUserSubmit({
  required GarsonBoardState current,
  required List<Map<String, dynamic>> orders,
  required String source,
}) {
  final nextOrders = _cloneRows(orders);
  return current.copyWith(
    orders: nextOrders,
    lastGoodOrders: nextOrders,
    hasPendingRemoteChanges: false,
    initialLoadStatus: current.uiTables.isEmpty
        ? current.initialLoadStatus
        : GarsonInitialLoadStatus.loaded,
    lastAppliedSource: source,
    lastUpdateAt: DateTime.now(),
  );
}

GarsonBoardState applyRoutePopped({
  required GarsonBoardState current,
  required List<Map<String, dynamic>> orders,
  required String source,
}) {
  return applyUserSubmit(current: current, orders: orders, source: source);
}

GarsonBoardState applyManualRefresh({
  required GarsonBoardState current,
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> areas,
  required List<Map<String, dynamic>> orders,
  required String source,
}) {
  final nextTables = _cloneRows(tables);
  final nextAreas = _cloneRows(areas);
  final nextOrders = _cloneRows(orders);

  final resolvedTables = nextTables.isNotEmpty ? nextTables : current.tables;
  final resolvedAreas = nextAreas.isNotEmpty ? nextAreas : current.areas;
  final nextLastGoodTables = nextTables.isNotEmpty
      ? nextTables
      : current.lastGoodTables;
  final nextLastGoodAreas = nextAreas.isNotEmpty
      ? nextAreas
      : current.lastGoodAreas;
  final nextLastGoodOrders = nextOrders.isNotEmpty
      ? nextOrders
      : current.lastGoodOrders;
  final hasTables = current.uiTables.isNotEmpty || nextTables.isNotEmpty;

  return current.copyWith(
    tables: resolvedTables,
    areas: resolvedAreas,
    orders: nextOrders,
    lastGoodTables: nextLastGoodTables,
    lastGoodAreas: nextLastGoodAreas,
    lastGoodOrders: nextLastGoodOrders,
    pendingTables: const <Map<String, dynamic>>[],
    pendingOrders: const <Map<String, dynamic>>[],
    hasPendingRemoteChanges: false,
    hasEverLoadedTablesSuccessfully:
        current.hasEverLoadedTablesSuccessfully || hasTables,
    hasEverRenderedBoardSuccessfully:
        current.hasEverRenderedBoardSuccessfully || hasTables,
    initialLoadStatus: hasTables
        ? GarsonInitialLoadStatus.loaded
        : GarsonInitialLoadStatus.empty,
    lastAppliedSource: source,
    lastUpdateAt: DateTime.now(),
  );
}

GarsonBoardState applyBackgroundUpdate({
  required GarsonBoardState current,
  required List<Map<String, dynamic>> incomingTables,
  required List<Map<String, dynamic>> incomingOrders,
  required String source,
}) {
  return current.copyWith(
    pendingTables: incomingTables,
    pendingOrders: incomingOrders,
    hasPendingRemoteChanges: true,
    lastAppliedSource: source,
    lastUpdateAt: DateTime.now(),
  );
}

GarsonBoardState closeTable({
  required GarsonBoardState current,
  required int tableNumber,
  required String source,
}) {
  final nextOrders = current.orders
      .where((order) => _tableNumber(order) != tableNumber)
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
  final nextLastGoodOrders = current.lastGoodOrders
      .where((order) => _tableNumber(order) != tableNumber)
      .map((order) => Map<String, dynamic>.from(order))
      .toList(growable: false);
  return current.copyWith(
    orders: nextOrders,
    lastGoodOrders: nextLastGoodOrders,
    hasPendingRemoteChanges: false,
    lastAppliedSource: source,
    lastUpdateAt: DateTime.now(),
  );
}

({Map<String, dynamic>? order, String matchedBy, bool fromOptimistic})
resolveGarsonBoardActiveOrderForTable({
  required GarsonBoardState state,
  required Map<String, dynamic>? table,
  List<Map<String, dynamic>>? optimisticOrders,
}) {
  return resolveActiveOrderBindingForTable(
    table: table,
    activeOrders: state.uiOrders,
    optimisticOrders: optimisticOrders,
  );
}

bool shouldShowEmptyState({required GarsonBoardState state}) {
  if (state.hasEverRenderedBoardSuccessfully) return false;
  return state.hasEverLoadedTablesSuccessfully == false &&
      (state.initialLoadStatus == GarsonInitialLoadStatus.failed ||
          state.initialLoadStatus == GarsonInitialLoadStatus.empty) &&
      state.tables.isEmpty &&
      state.lastGoodTables.isEmpty;
}

bool shouldShowGarsonNoTableOrderEmptyState({
  required List<int> tableNumbers,
  required GarsonAreaSectionsResult sectionsResult,
  required GarsonBoardState state,
  required bool initialBootstrapFinished,
}) {
  if (tableNumbers.isNotEmpty) return false;
  if (sectionsResult.sections.isNotEmpty) return false;
  if (state.uiTables.isNotEmpty) return false;
  if (state.lastGoodSections != null &&
      state.lastGoodSections!.sections.isNotEmpty) {
    return false;
  }
  if (state.hasEverRenderedBoardSuccessfully) return false;
  if (!initialBootstrapFinished) return false;
  return state.uiTables.isEmpty &&
      state.lastGoodTables.isEmpty &&
      (state.initialLoadStatus == GarsonInitialLoadStatus.empty ||
          state.initialLoadStatus == GarsonInitialLoadStatus.failed);
}

enum GarsonRouteBranchRender { board, tableDetail, empty }

int _garsonBoardTableNumber(Map<String, dynamic> row) {
  final value = row['table_number'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool isGarsonSelectedTableContextValid({
  required int? selectedTableNumber,
  required GarsonBoardState state,
}) {
  if (selectedTableNumber == null || selectedTableNumber <= 0) return false;
  for (final row in state.uiTables) {
    if (_garsonBoardTableNumber(row) == selectedTableNumber) return true;
  }
  for (final row in state.lastGoodTables) {
    if (_garsonBoardTableNumber(row) == selectedTableNumber) return true;
  }
  return false;
}

bool shouldClearStaleGarsonTableRoute({
  required bool isGarsonModule,
  required bool isTableRouteOpen,
  required int? selectedTableNumber,
  required bool selectedTableValid,
  required int boardSectionsCount,
  required int boardTablesCount,
}) {
  if (!isGarsonModule) return false;
  if (boardSectionsCount == 0 && boardTablesCount == 0) return false;
  if (!isTableRouteOpen && selectedTableNumber != null) return true;
  if (isTableRouteOpen &&
      selectedTableNumber != null &&
      !selectedTableValid) {
    return true;
  }
  return false;
}

GarsonRouteBranchRender decideGarsonRouteBranchRender({
  required bool isGarsonModule,
  required bool isTableRouteOpen,
  required int? selectedTableNumber,
  required bool selectedTableValid,
  required bool willShowNoOrderEmpty,
  required bool willShowGrid,
  required int boardSectionsCount,
  required int boardTablesCount,
}) {
  if (!isGarsonModule) return GarsonRouteBranchRender.board;
  if (shouldClearStaleGarsonTableRoute(
    isGarsonModule: isGarsonModule,
    isTableRouteOpen: isTableRouteOpen,
    selectedTableNumber: selectedTableNumber,
    selectedTableValid: selectedTableValid,
    boardSectionsCount: boardSectionsCount,
    boardTablesCount: boardTablesCount,
  )) {
    return GarsonRouteBranchRender.board;
  }
  if (isTableRouteOpen && selectedTableValid) {
    return GarsonRouteBranchRender.tableDetail;
  }
  if (willShowNoOrderEmpty && !willShowGrid) {
    return GarsonRouteBranchRender.empty;
  }
  return GarsonRouteBranchRender.board;
}

bool shouldShowGarsonNoOrderEmptyOnBoard({
  required bool isGarsonTableRouteOpen,
  required bool selectedTableContextValid,
  required GarsonRenderBundle renderBundle,
  required GarsonBoardState state,
  required List<int> allTableNumbers,
  required bool initialBootstrapFinished,
}) {
  final boardSectionsCount = renderBundle.renderSections.isNotEmpty
      ? renderBundle.renderSections.length
      : (state.lastGoodSections?.sections.length ?? 0);
  final boardTablesCount = state.uiTables.length;

  if (renderBundle.willShowGrid) {
    logGarsonNoTableOrderEmptyDecision(
      isGarsonTableRouteOpen: isGarsonTableRouteOpen,
      selectedTableValid: selectedTableContextValid,
      boardSectionsCount: boardSectionsCount,
      boardTablesCount: boardTablesCount,
      willShowNoOrderEmpty: false,
      reason: 'board_has_grid',
    );
    return false;
  }
  if (allTableNumbers.isNotEmpty) {
    logGarsonNoTableOrderEmptyDecision(
      isGarsonTableRouteOpen: isGarsonTableRouteOpen,
      selectedTableValid: selectedTableContextValid,
      boardSectionsCount: boardSectionsCount,
      boardTablesCount: boardTablesCount,
      willShowNoOrderEmpty: false,
      reason: 'configured_tables_exist',
    );
    return false;
  }
  if (boardSectionsCount > 0 || boardTablesCount > 0) {
    logGarsonNoTableOrderEmptyDecision(
      isGarsonTableRouteOpen: isGarsonTableRouteOpen,
      selectedTableValid: selectedTableContextValid,
      boardSectionsCount: boardSectionsCount,
      boardTablesCount: boardTablesCount,
      willShowNoOrderEmpty: false,
      reason: 'board_sections_or_tables_exist',
    );
    return false;
  }
  if (state.hasEverRenderedBoardSuccessfully) {
    logGarsonNoTableOrderEmptyDecision(
      isGarsonTableRouteOpen: isGarsonTableRouteOpen,
      selectedTableValid: selectedTableContextValid,
      boardSectionsCount: boardSectionsCount,
      boardTablesCount: boardTablesCount,
      willShowNoOrderEmpty: false,
      reason: 'board_previously_rendered',
    );
    return false;
  }

  final willShow = isGarsonTableRouteOpen &&
      selectedTableContextValid &&
      shouldShowGarsonNoTableOrderEmptyState(
        tableNumbers: allTableNumbers,
        sectionsResult: renderBundle.sectionsResult,
        state: state,
        initialBootstrapFinished: initialBootstrapFinished,
      );

  logGarsonNoTableOrderEmptyDecision(
    isGarsonTableRouteOpen: isGarsonTableRouteOpen,
    selectedTableValid: selectedTableContextValid,
    boardSectionsCount: boardSectionsCount,
    boardTablesCount: boardTablesCount,
    willShowNoOrderEmpty: willShow,
    reason: willShow ? 'table_detail_empty' : 'board_branch_forbidden',
  );
  return willShow;
}

void logGarsonRouteBranchDecision({
  required String selectedModule,
  required bool isGarsonTableRouteOpen,
  required int? selectedTableNumber,
  required String? selectedTableId,
  required String? selectedOrderId,
  required int boardSectionsCount,
  required int boardTablesCount,
  required GarsonRouteBranchRender willRender,
  required String reason,
}) {
  debugPrint(
    '[GARSON_ROUTE_BRANCH_DECISION] '
    'selectedModule=$selectedModule '
    'isGarsonTableRouteOpen=$isGarsonTableRouteOpen '
    'selectedTableNumber=${selectedTableNumber ?? '-'} '
    'selectedTableId=${selectedTableId ?? '-'} '
    'selectedOrderId=${selectedOrderId ?? '-'} '
    'boardSectionsCount=$boardSectionsCount '
    'boardTablesCount=$boardTablesCount '
    'willRender=${willRender.name} '
    'reason=$reason',
  );
}

void logGarsonCloseTableRouteCleanup({
  required String closedLabel,
  required int tableNumber,
  required String tableId,
  required String orderId,
  required bool beforeIsTableRouteOpen,
  required bool afterIsTableRouteOpen,
  required bool selectedCleared,
}) {
  debugPrint(
    '[GARSON_CLOSE_TABLE_ROUTE_CLEANUP] '
    'closedLabel=$closedLabel '
    'tableNumber=$tableNumber '
    'tableId=$tableId '
    'orderId=$orderId '
    'before_isTableRouteOpen=$beforeIsTableRouteOpen '
    'after_isTableRouteOpen=$afterIsTableRouteOpen '
    'selectedCleared=$selectedCleared',
  );
}

void logGarsonStaleTableRouteCleared({
  required String reason,
  required int? selectedTableNumber,
  required String? selectedTableId,
  required int boardSectionsCount,
}) {
  debugPrint(
    '[GARSON_STALE_TABLE_ROUTE_CLEARED] '
    'reason=$reason '
    'selectedTableNumber=${selectedTableNumber ?? '-'} '
    'selectedTableId=${selectedTableId ?? '-'} '
    'boardSectionsCount=$boardSectionsCount '
    'willRender=board',
  );
}

void logGarsonNoTableOrderEmptyDecision({
  required bool isGarsonTableRouteOpen,
  required bool selectedTableValid,
  required int boardSectionsCount,
  required int boardTablesCount,
  required bool willShowNoOrderEmpty,
  required String reason,
}) {
  debugPrint(
    '[GARSON_NO_TABLE_ORDER_EMPTY_DECISION] '
    'isGarsonTableRouteOpen=$isGarsonTableRouteOpen '
    'selectedTableValid=$selectedTableValid '
    'boardSectionsCount=$boardSectionsCount '
    'boardTablesCount=$boardTablesCount '
    'willShowNoOrderEmpty=$willShowNoOrderEmpty '
    'reason=$reason',
  );
}

GarsonBoardState cacheGarsonLastGoodSections({
  required GarsonBoardState current,
  required GarsonAreaSectionsResult sectionsResult,
}) {
  if (sectionsResult.sections.isEmpty || sectionsResult.isLoading) {
    return current;
  }
  return current.copyWith(
    lastGoodSections: sectionsResult,
    hasEverRenderedBoardSuccessfully: true,
    hasEverLoadedTablesSuccessfully: true,
    initialLoadStatus: GarsonInitialLoadStatus.loaded,
    lastUpdateAt: DateTime.now(),
  );
}

int _tableNumber(Map<String, dynamic> row) {
  final value = row['table_number'];
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

void logGarsonAfterCloseBoardState({
  required String closedLabel,
  required int closedTableNumber,
  required String closedOrderId,
  required int boardTablesCount,
  required int lastGoodTablesCount,
  required int boardOrdersCount,
  required int lastGoodOrdersCount,
  required int sectionsCount,
  required int lastGoodSectionsCount,
  required int totalChipCount,
  required int occupiedChipCount,
}) {
  debugPrint(
    '[GARSON_AFTER_CLOSE_BOARD_STATE] '
    'closed_label=$closedLabel '
    'closed_table_number=$closedTableNumber '
    'closed_order_id=$closedOrderId '
    'board_tables_count=$boardTablesCount '
    'last_good_tables_count=$lastGoodTablesCount '
    'board_orders_count=$boardOrdersCount '
    'last_good_orders_count=$lastGoodOrdersCount '
    'sections_count=$sectionsCount '
    'last_good_sections_count=$lastGoodSectionsCount '
    'total_chip_count=$totalChipCount '
    'occupied_chip_count=$occupiedChipCount',
  );
}

void logGarsonTableSourceDecision({
  required String source,
  required int configuredTablesCount,
  required int lastGoodTablesCount,
  required int activeOrdersCount,
  required int tableNumbersCount,
  required bool willUseConfiguredTables,
  required String reason,
}) {
  debugPrint(
    '[GARSON_TABLE_SOURCE_DECISION] '
    'source=$source '
    'configured_tables_count=$configuredTablesCount '
    'last_good_tables_count=$lastGoodTablesCount '
    'active_orders_count=$activeOrdersCount '
    'table_numbers_count=$tableNumbersCount '
    'will_use_configured_tables=$willUseConfiguredTables '
    'reason=$reason',
  );
}

void logGarsonAllOrdersClosedKeepTables({
  required int ordersCount,
  required int tablesCount,
  required int sectionsCount,
  required bool willRenderEmptyTables,
}) {
  debugPrint(
    '[GARSON_ALL_ORDERS_CLOSED_KEEP_TABLES] '
    'orders_count=$ordersCount '
    'tables_count=$tablesCount '
    'sections_count=$sectionsCount '
    'will_render_empty_tables=$willRenderEmptyTables',
  );
}

/// Whether to surface the "müşteri siparişleri kapatılamadı (orders=0)"
/// warning to the user after a close.
///
/// `orders_closed == 0` is the NORMAL outcome for garson-only tables: the
/// waiter's orders live in `table_orders`, not the customer `orders` table, so
/// there is simply nothing to close there.  Surfacing the warning whenever
/// `ordersClosed == 0 && hadTableOrders` turned every ordinary close into a
/// scary "kapatılamadı" message.  The warning is only meaningful when the
/// close could have *silently failed* at the DB layer — i.e. when the
/// authenticated user's id does not match the resolved seller id (the
/// sub-admin / waiter RLS scenario).  Identity-matched owners closing a garson
/// table must see a clean success.
bool shouldWarnGarsonOrdersUntouched({
  required int ordersClosed,
  required bool hadTableOrders,
  required bool identityMatches,
}) {
  if (ordersClosed != 0) return false;
  if (!hadTableOrders) return false;
  return !identityMatches;
}

/// Outcome of the garson empty-state self-heal decision.
enum GarsonEmptyStateSelfHealAction {
  /// A recovery is already in flight (or throttled) — caller should render a
  /// loading placeholder but must NOT schedule another reload.
  showLoading,

  /// Caller should schedule a forced catalog re-fetch and render loading.
  scheduleReload,

  /// No recovery possible/appropriate — caller should render the real empty
  /// state (genuinely empty store, or budget exhausted, or not on garson).
  showEmpty,
}

/// Pure decision for the empty-table self-heal.
///
/// The garson board keeps several last-good layers, but a close→pop race can
/// momentarily collapse all of them at once and surface a dead-end "no tables"
/// screen even though the store genuinely has tables.  Rather than trusting an
/// in-memory "we had tables" flag (which resets if the State is recreated
/// during navigation), we attempt a forced catalog re-fetch up to
/// [maxAttempts] times.  A transient collapse recovers on the first attempt; a
/// genuinely empty store exhausts the budget and then shows the real empty
/// state.  A [throttle] guarantees we can never spin into a tight reload loop.
GarsonEmptyStateSelfHealAction decideGarsonEmptyStateSelfHeal({
  required bool isGarsonVisible,
  required bool isTableRouteOpen,
  required bool isLoading,
  required int attempts,
  required int maxAttempts,
  required DateTime? lastHealAt,
  required DateTime now,
  Duration throttle = const Duration(seconds: 3),
}) {
  if (!isGarsonVisible && !isTableRouteOpen) {
    return GarsonEmptyStateSelfHealAction.showEmpty;
  }
  if (isLoading) return GarsonEmptyStateSelfHealAction.showLoading;
  if (attempts >= maxAttempts) {
    return GarsonEmptyStateSelfHealAction.showEmpty;
  }
  if (lastHealAt != null && now.difference(lastHealAt) < throttle) {
    return GarsonEmptyStateSelfHealAction.showLoading;
  }
  return GarsonEmptyStateSelfHealAction.scheduleReload;
}

/// Removes all orders belonging to [tableNumber] from board state orders and
/// lastGoodOrders. Tables and areas are never touched.
GarsonBoardState removeClosedTableOrdersFromBoardState({
  required GarsonBoardState current,
  required int tableNumber,
  required String closedOrderId,
}) {
  if (tableNumber <= 0) return current;
  bool matchesTable(Map<String, dynamic> order) {
    final n = order['table_number'];
    final parsed = n is num ? n.toInt() : int.tryParse(n?.toString() ?? '') ?? 0;
    return parsed == tableNumber;
  }

  final nextOrders =
      current.orders.where((o) => !matchesTable(o)).toList(growable: false);
  final nextLastGood = current.lastGoodOrders
      .where((o) => !matchesTable(o))
      .toList(growable: false);

  if (nextOrders.length == current.orders.length &&
      nextLastGood.length == current.lastGoodOrders.length) {
    return current;
  }
  return current.copyWith(
    orders: nextOrders,
    lastGoodOrders: nextLastGood,
    lastAppliedSource: 'close_table_remove_orders',
    lastUpdateAt: DateTime.now(),
  );
}
