import 'package:flutter/foundation.dart';

import 'table_labels.dart';

String _t(dynamic v) => (v ?? '').toString().trim();

int _pi(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_t(v)) ?? 0;
}

/// How Garson area sections were resolved for the current render.
enum GarsonAreaGroupingMode {
  areaBased,
  areaNameFallback,
  blockedLoading,
}

class GarsonTableSectionItem {
  const GarsonTableSectionItem({
    required this.tableId,
    required this.storeTableId,
    required this.tableNumber,
    required this.areaId,
    required this.areaName,
    required this.displayLabel,
    this.activeOrder,
    required this.isOccupied,
  });

  final String tableId;
  final String storeTableId;
  final int tableNumber;
  final String areaId;
  final String areaName;
  final String displayLabel;
  final Map<String, dynamic>? activeOrder;
  final bool isOccupied;
}

class GarsonAreaSection {
  const GarsonAreaSection({
    required this.areaId,
    required this.areaName,
    required this.tables,
    required this.totalCount,
    required this.occupiedCount,
    required this.emptyCount,
    required this.sortOrder,
  });

  final String areaId;
  final String areaName;
  final List<GarsonTableSectionItem> tables;
  final int totalCount;
  final int occupiedCount;
  final int emptyCount;
  final int sortOrder;

  List<int> get tableNumbers =>
      tables.map((table) => table.tableNumber).where((n) => n > 0).toList(
        growable: false,
      );
}

class GarsonAreaSectionsResult {
  const GarsonAreaSectionsResult({
    required this.sections,
    required this.mode,
    required this.legacyMasaGroupDetected,
  });

  final List<GarsonAreaSection> sections;
  final GarsonAreaGroupingMode mode;
  final bool legacyMasaGroupDetected;

  bool get isLoading => mode == GarsonAreaGroupingMode.blockedLoading;
}

final RegExp _legacyMasaSectionLabelPattern = RegExp(
  r'^masa\s*\d+$',
  caseSensitive: false,
);

const Set<String> _forbiddenSectionLabels = <String>{
  'genel masa',
  'tables',
  'default',
  'diğer',
  'diger',
  'other',
};

bool isGarsonForbiddenSectionLabel(String? label) {
  final normalized = _t(label).toLowerCase();
  if (normalized.isEmpty) return true;
  if (_forbiddenSectionLabels.contains(normalized)) return true;
  return _legacyMasaSectionLabelPattern.hasMatch(normalized);
}

void logGarsonLegacyGroupingBlocked({required String badLabel, String? reason}) {
  debugPrint(
    '[GARSON_LEGACY_GROUPING_BLOCKED] '
    'reason=${reason ?? 'masa_number_section_is_not_allowed'} '
    'bad_label=$badLabel',
  );
}

void logGarsonAreaGroupingBlocked({required String reason}) {
  debugPrint(
    '[GARSON_AREA_GROUPING_BLOCKED] '
    'reason=$reason',
  );
}

void logGarsonAreaBootstrapStart({
  required String restaurantId,
  required int tablesCount,
  required int areasCount,
  required String source,
}) {
  debugPrint(
    '[GARSON_AREA_BOOTSTRAP_START] '
    'restaurant_id=$restaurantId '
    'tables_count=$tablesCount '
    'areas_count=$areasCount '
    'source=$source',
  );
}

void logGarsonAreaBootstrapResult({
  required String restaurantId,
  required int areasLoaded,
  required List<String> areaNames,
  required int tablesLoaded,
  String firstTableId = '-',
  int firstTableNumber = 0,
  String firstAreaId = '-',
  String firstAreaName = '-',
}) {
  debugPrint(
    '[GARSON_AREA_BOOTSTRAP_RESULT] '
    'restaurant_id=$restaurantId '
    'areas_loaded=$areasLoaded '
    'area_names=$areaNames '
    'tables_loaded=$tablesLoaded '
    'first_table_id=$firstTableId '
    'first_table_number=${firstTableNumber <= 0 ? '-' : firstTableNumber} '
    'first_area_id=$firstAreaId '
    'first_area_name=$firstAreaName',
  );
}

void logGarsonGroupingRenderSource({
  required GarsonAreaSectionsResult result,
  required int areasCount,
  required int tablesCount,
}) {
  final labels = result.sections
      .map((section) => section.areaName)
      .toList(growable: false);
  debugPrint(
    '[GARSON_GROUPING_RENDER_SOURCE] '
    'source=garson_area_sections '
    'areas_count=$areasCount '
    'tables_count=$tablesCount '
    'sections_count=${result.sections.length} '
    'grouping_mode=${result.mode.name} '
    'section_labels=$labels '
    'legacy_masa_group_detected=${result.legacyMasaGroupDetected}',
  );
}

bool _hasUsableAreas(List<Map<String, dynamic>> areas) {
  return areas.any((area) => _t(area['name']).isNotEmpty);
}

bool _hasTableAreaNames(List<Map<String, dynamic>> tables) {
  return tables.any((table) {
    final name = _t(table['area_name']);
    return name.isNotEmpty && !isGarsonForbiddenSectionLabel(name);
  });
}

bool _detectLegacyForbiddenAreaLabels(List<Map<String, dynamic>> tables) {
  var detected = false;
  for (final table in tables) {
    final name = _t(table['area_name']);
    if (name.isEmpty) continue;
    if (isGarsonForbiddenSectionLabel(name)) {
      detected = true;
      logGarsonLegacyGroupingBlocked(badLabel: name);
    }
  }
  return detected;
}

bool _hasResolvableAreaIds({
  required List<Map<String, dynamic>> areas,
  required List<Map<String, dynamic>> tables,
}) {
  if (!_hasUsableAreas(areas)) return false;
  return tables.any((table) {
    final areaId = _t(table['area_id']);
    if (areaId.isEmpty) return false;
    return areas.any((area) => _t(area['id']) == areaId);
  });
}

int _tableSortKey(Map<String, dynamic> table) {
  final areaNo = _pi(table['area_table_number']);
  if (areaNo > 0) return areaNo;
  return _pi(table['table_number']);
}

Map<String, dynamic>? _activeOrderForTable({
  required Map<String, dynamic> table,
  required List<Map<String, dynamic>> activeOrders,
}) {
  final binding = resolveActiveOrderBindingForTable(
    table: table,
    activeOrders: activeOrders,
  );
  return binding.order == null
      ? null
      : Map<String, dynamic>.from(binding.order!);
}

GarsonTableSectionItem _buildTableSectionItem({
  required Map<String, dynamic> table,
  required String areaId,
  required String areaName,
  required List<Map<String, dynamic>> activeOrders,
}) {
  final tableId = _t(table['id']);
  final tableNumber = _pi(table['table_number']);
  final displayLabel = resolveTableDisplayLabel(
    table: table,
    fallbackTableNumber: tableNumber,
  );
  final activeOrder = _activeOrderForTable(table: table, activeOrders: activeOrders);
  return GarsonTableSectionItem(
    tableId: tableId,
    storeTableId: tableId,
    tableNumber: tableNumber,
    areaId: areaId,
    areaName: areaName,
    displayLabel: displayLabel,
    activeOrder: activeOrder,
    isOccupied: activeOrder != null,
  );
}

String _normalizeAreaNameKey(String name) => _t(name).toLowerCase();

GarsonAreaSectionsResult resolveGarsonAreaSections({
  required List<Map<String, dynamic>> areas,
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> activeOrders,
  Set<int>? tableNumbers,
}) {
  final filteredTables = tableNumbers == null || tableNumbers.isEmpty
      ? tables
      : tables
            .where((table) => tableNumbers.contains(_pi(table['table_number'])))
            .toList(growable: false);

  if (filteredTables.isEmpty) {
    return const GarsonAreaSectionsResult(
      sections: <GarsonAreaSection>[],
      mode: GarsonAreaGroupingMode.areaBased,
      legacyMasaGroupDetected: false,
    );
  }

  final hasAreas = _hasUsableAreas(areas);
  final hasTableAreaNames = _hasTableAreaNames(filteredTables);
  final hasResolvableAreaIds = _hasResolvableAreaIds(
    areas: areas,
    tables: filteredTables,
  );

  final legacyInTables = _detectLegacyForbiddenAreaLabels(filteredTables);

  if (!hasAreas && !hasTableAreaNames) {
    // BUG-FIX (Render Gap): Previously this branch returned `blockedLoading`
    // with zero sections — making "Toplam Masa: 0" appear on any deployment
    // that has `store_tables` rows but no `store_table_areas` AND no
    // `area_name` populated on the table rows.  Both conditions are valid
    // (legacy stores never set area_name; new ones without the migration
    // also have no areas).  Returning empty here causes the entire garson
    // board to disappear with 14+ physical tables in the catalog.
    //
    // Fix: synthesize a single "Salon" bucket containing every physical
    // table.  This is the same shape the `getTableAreas()` API uses as its
    // own implicit-area fallback (see store_table_service.dart:222-232).
    logGarsonAreaGroupingBlocked(
      reason: 'no_area_source_no_legacy_fallback_synthesizing_single_bucket',
    );
    return _resolveByImplicitSingleArea(
      tables: filteredTables,
      activeOrders: activeOrders,
      legacyDetected: legacyInTables,
    );
  }

  if (!hasAreas && hasTableAreaNames) {
    return _resolveByTableAreaNameFallback(
      tables: filteredTables,
      activeOrders: activeOrders,
    );
  }

  if (hasAreas && !hasResolvableAreaIds && !hasTableAreaNames) {
    // BUG-FIX (Render Gap): same problem as above — areas exist in the DB
    // but tables reference no `area_id` AND have no `area_name`.  Without
    // the synthesis, the board would render 0 sections + 14 invisible
    // tables.  Group everything under "Salon" so the user sees the grid.
    logGarsonAreaGroupingBlocked(
      reason: 'areas_loaded_but_table_area_metadata_missing_synthesizing',
    );
    return _resolveByImplicitSingleArea(
      tables: filteredTables,
      activeOrders: activeOrders,
      legacyDetected: legacyInTables,
    );
  }

  return _resolveByStoreTableAreas(
    areas: areas,
    tables: filteredTables,
    activeOrders: activeOrders,
  );
}

GarsonAreaSectionsResult _resolveByStoreTableAreas({
  required List<Map<String, dynamic>> areas,
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> activeOrders,
}) {
  final usableAreas = areas
      .where((area) => _t(area['name']).isNotEmpty)
      .map((area) => Map<String, dynamic>.from(area))
      .toList(growable: false)
    ..sort((a, b) {
      final orderCmp = _pi(a['sort_order']).compareTo(_pi(b['sort_order']));
      if (orderCmp != 0) return orderCmp;
      return _t(a['name']).toLowerCase().compareTo(_t(b['name']).toLowerCase());
    });

  final legacyDetected = false;
  final sections = <GarsonAreaSection>[];
  final assignedTableIds = <String>{};

  for (final area in usableAreas) {
    final areaId = _t(area['id']);
    final areaName = _t(area['name']);
    if (isGarsonForbiddenSectionLabel(areaName)) {
      logGarsonLegacyGroupingBlocked(badLabel: areaName);
      continue;
    }

    final areaTables = tables.where((table) {
      final tableId = _t(table['id']);
      if (tableId.isNotEmpty && assignedTableIds.contains(tableId)) {
        return false;
      }
      final tableAreaId = _t(table['area_id']);
      if (areaId.isNotEmpty && tableAreaId == areaId) return true;
      return _normalizeAreaNameKey(_t(table['area_name'])) ==
          _normalizeAreaNameKey(areaName);
    }).toList(growable: false)
      ..sort(
        (a, b) => _tableSortKey(a).compareTo(_tableSortKey(b)),
      );

    if (areaTables.isEmpty) continue;

    final items = <GarsonTableSectionItem>[];
    for (final table in areaTables) {
      final tableId = _t(table['id']);
      if (tableId.isNotEmpty) assignedTableIds.add(tableId);
      items.add(
        _buildTableSectionItem(
          table: table,
          areaId: areaId,
          areaName: areaName,
          activeOrders: activeOrders,
        ),
      );
    }

    final occupiedCount = items.where((item) => item.isOccupied).length;
    sections.add(
      GarsonAreaSection(
        areaId: areaId,
        areaName: areaName,
        tables: items,
        totalCount: items.length,
        occupiedCount: occupiedCount,
        emptyCount: items.length - occupiedCount,
        sortOrder: _pi(area['sort_order']),
      ),
    );
  }

  return GarsonAreaSectionsResult(
    sections: sections,
    mode: GarsonAreaGroupingMode.areaBased,
    legacyMasaGroupDetected: legacyDetected,
  );
}

/// Synthesizes a single implicit "Salon" bucket containing every physical
/// table.  Used when neither the areas table nor the per-table `area_name`
/// metadata is available — the only way to honor the "Toplam Masa kataloğu
/// asla 0 görmesin" invariant in those deployments.
GarsonAreaSectionsResult _resolveByImplicitSingleArea({
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> activeOrders,
  required bool legacyDetected,
}) {
  if (tables.isEmpty) {
    return GarsonAreaSectionsResult(
      sections: const <GarsonAreaSection>[],
      mode: GarsonAreaGroupingMode.blockedLoading,
      legacyMasaGroupDetected: legacyDetected,
    );
  }
  const implicitAreaId = 'implicit_salon';
  const implicitAreaName = 'Salon';
  final sorted = List<Map<String, dynamic>>.from(tables)
    ..sort((a, b) => _tableSortKey(a).compareTo(_tableSortKey(b)));
  final items = sorted
      .map(
        (table) => _buildTableSectionItem(
          table: table,
          areaId: implicitAreaId,
          areaName: implicitAreaName,
          activeOrders: activeOrders,
        ),
      )
      .toList(growable: false);
  final occupiedCount = items.where((item) => item.isOccupied).length;
  return GarsonAreaSectionsResult(
    sections: <GarsonAreaSection>[
      GarsonAreaSection(
        areaId: implicitAreaId,
        areaName: implicitAreaName,
        tables: items,
        totalCount: items.length,
        occupiedCount: occupiedCount,
        emptyCount: items.length - occupiedCount,
        sortOrder: 0,
      ),
    ],
    mode: GarsonAreaGroupingMode.areaNameFallback,
    legacyMasaGroupDetected: legacyDetected,
  );
}

GarsonAreaSectionsResult _resolveByTableAreaNameFallback({
  required List<Map<String, dynamic>> tables,
  required List<Map<String, dynamic>> activeOrders,
}) {
  final buckets = <String, List<Map<String, dynamic>>>{};
  final labels = <String, String>{};
  var legacyDetected = false;

  for (final table in tables) {
    final rawAreaName = _t(table['area_name']);
    if (rawAreaName.isEmpty) continue;
    if (isGarsonForbiddenSectionLabel(rawAreaName)) {
      legacyDetected = true;
      logGarsonLegacyGroupingBlocked(badLabel: rawAreaName);
      continue;
    }
    final key = _normalizeAreaNameKey(rawAreaName);
    labels[key] = rawAreaName;
    buckets.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(table);
  }

  if (buckets.isEmpty) {
    logGarsonAreaGroupingBlocked(reason: 'table_area_name_fallback_empty');
    return GarsonAreaSectionsResult(
      sections: const <GarsonAreaSection>[],
      mode: GarsonAreaGroupingMode.blockedLoading,
      legacyMasaGroupDetected: legacyDetected,
    );
  }

  final sections = <GarsonAreaSection>[];
  final sortedKeys = buckets.keys.toList(growable: false)
    ..sort((a, b) => labels[a]!.toLowerCase().compareTo(labels[b]!.toLowerCase()));

  var sortOrder = 0;
  for (final key in sortedKeys) {
    final areaName = labels[key] ?? key;
    final areaTables = List<Map<String, dynamic>>.from(buckets[key]!)
      ..sort((a, b) => _tableSortKey(a).compareTo(_tableSortKey(b)));
    final items = areaTables
        .map(
          (table) => _buildTableSectionItem(
            table: table,
            areaId: _t(table['area_id']),
            areaName: areaName,
            activeOrders: activeOrders,
          ),
        )
        .toList(growable: false);
    final occupiedCount = items.where((item) => item.isOccupied).length;
    sections.add(
      GarsonAreaSection(
        areaId: _t(areaTables.first['area_id']),
        areaName: areaName,
        tables: items,
        totalCount: items.length,
        occupiedCount: occupiedCount,
        emptyCount: items.length - occupiedCount,
        sortOrder: sortOrder++,
      ),
    );
  }

  return GarsonAreaSectionsResult(
    sections: sections,
    mode: GarsonAreaGroupingMode.areaNameFallback,
    legacyMasaGroupDetected: legacyDetected,
  );
}

class GarsonSectionsRenderDecision {
  const GarsonSectionsRenderDecision({
    required this.sectionsResult,
    required this.willShowGrid,
    required this.willShowEmpty,
    required this.reason,
  });

  final GarsonAreaSectionsResult sectionsResult;
  final bool willShowGrid;
  final bool willShowEmpty;
  final String reason;
}

void logGarsonSectionsRenderDecision({
  required GarsonSectionsRenderDecision decision,
  required int currentSectionsCount,
  required int lastGoodSectionsCount,
  required int tablesCount,
  required int areasCount,
  required int ordersCount,
  required bool hasEverRenderedBoard,
}) {
  debugPrint(
    '[GARSON_SECTIONS_RENDER_DECISION] '
    'current_sections_count=$currentSectionsCount '
    'last_good_sections_count=$lastGoodSectionsCount '
    'tables_count=$tablesCount '
    'areas_count=$areasCount '
    'orders_count=$ordersCount '
    'has_ever_rendered_board=$hasEverRenderedBoard '
    'will_show_grid=${decision.willShowGrid} '
    'will_show_empty=${decision.willShowEmpty} '
    'reason=${decision.reason}',
  );
}

void logGarsonBoardEmptyStateBlocked({
  required String reason,
  required int currentSectionsCount,
  required int lastGoodSectionsCount,
}) {
  debugPrint(
    '[GARSON_EMPTY_STATE_BLOCKED] '
    'reason=$reason '
    'current_sections_count=$currentSectionsCount '
    'last_good_sections_count=$lastGoodSectionsCount',
  );
}

GarsonSectionsRenderDecision decideGarsonSectionsRender({
  required GarsonAreaSectionsResult currentSections,
  GarsonAreaSectionsResult? lastGoodSections,
  required int uiTablesCount,
  required bool hasEverRenderedBoard,
  required bool initialBootstrapFinished,
  bool isRefreshing = false,
}) {
  final currentCount = currentSections.sections.length;
  final lastGoodCount = lastGoodSections?.sections.length ?? 0;

  if (currentCount > 0 && !currentSections.isLoading) {
    return GarsonSectionsRenderDecision(
      sectionsResult: currentSections,
      willShowGrid: true,
      willShowEmpty: false,
      reason: 'current_sections_available',
    );
  }

  if (lastGoodCount > 0) {
    logGarsonBoardEmptyStateBlocked(
      reason: 'last_good_sections_available_or_tables_available',
      currentSectionsCount: currentCount,
      lastGoodSectionsCount: lastGoodCount,
    );
    return GarsonSectionsRenderDecision(
      sectionsResult: lastGoodSections!,
      willShowGrid: true,
      willShowEmpty: false,
      reason: isRefreshing
          ? 'refresh_last_good_sections_fallback'
          : 'last_good_sections_fallback',
    );
  }

  if (isRefreshing && uiTablesCount > 0) {
    return GarsonSectionsRenderDecision(
      sectionsResult: currentSections,
      willShowGrid: false,
      willShowEmpty: false,
      reason: 'refresh_waiting_for_sections_without_last_good',
    );
  }

  if (uiTablesCount > 0 &&
      (currentSections.isLoading || hasEverRenderedBoard)) {
    return GarsonSectionsRenderDecision(
      sectionsResult: currentSections,
      willShowGrid: false,
      willShowEmpty: false,
      reason: 'tables_available_sections_loading',
    );
  }

  final showEmpty = !hasEverRenderedBoard &&
      initialBootstrapFinished &&
      uiTablesCount == 0 &&
      currentCount == 0 &&
      lastGoodCount == 0;

  return GarsonSectionsRenderDecision(
    sectionsResult: currentSections,
    willShowGrid: false,
    willShowEmpty: showEmpty,
    reason: showEmpty ? 'true_empty_after_bootstrap' : 'waiting_for_data',
  );
}

class GarsonRenderBundle {
  const GarsonRenderBundle({
    required this.decision,
    required this.renderSections,
    required this.sectionsResult,
    required this.totalTableCount,
    required this.occupiedTableCount,
    required this.willShowGrid,
    required this.willShowLoading,
    required this.willShowEmpty,
    required this.reason,
  });

  final GarsonSectionsRenderDecision decision;
  final List<GarsonAreaSection> renderSections;
  final GarsonAreaSectionsResult sectionsResult;
  final int totalTableCount;
  final int occupiedTableCount;
  final bool willShowGrid;
  final bool willShowLoading;
  final bool willShowEmpty;
  final String reason;
}

String _normalizeAreaFilterKey(String filterKey) {
  final key = _t(filterKey).toLowerCase();
  if (key.isEmpty || key == 'all' || key == 'tüm alanlar' || key == 'tum alanlar') {
    return 'all';
  }
  return filterKey.trim();
}

({String areaId, String areaName}) _parseAreaFilterKey(String filterKey) {
  final normalized = _normalizeAreaFilterKey(filterKey);
  if (normalized == 'all') {
    return (areaId: '', areaName: '');
  }
  if (normalized.startsWith('id:')) {
    return (areaId: normalized.substring(3), areaName: '');
  }
  if (normalized.startsWith('name:')) {
    return (areaId: '', areaName: normalized.substring(5));
  }
  return (areaId: '', areaName: normalized);
}

void logGarsonAreaFilterDecision({
  required String selectedArea,
  required String selectedAreaId,
  required String selectedAreaName,
  required int beforeSectionsCount,
  required int afterSectionsCount,
  required String matchedBy,
}) {
  debugPrint(
    '[GARSON_AREA_FILTER_DECISION] '
    'selected_area=$selectedArea '
    'selected_area_id=${selectedAreaId.isEmpty ? '-' : selectedAreaId} '
    'selected_area_name=${selectedAreaName.isEmpty ? '-' : selectedAreaName} '
    'before_sections_count=$beforeSectionsCount '
    'after_sections_count=$afterSectionsCount '
    'matched_by=$matchedBy',
  );
}

void logGarsonRefreshRenderGapDiagnosis({
  required String selectedArea,
  required String areaFilter,
  required int totalChipCount,
  required int occupiedChipCount,
  required int boardTablesCount,
  required int boardAreasCount,
  required int boardOrdersCount,
  required int currentSectionsCount,
  required int lastGoodSectionsCount,
  required int renderSectionsCount,
  required bool willShowGrid,
  required bool willShowLoading,
  required bool willShowEmpty,
  required bool isRefreshing,
  required bool initialLoading,
  required bool storeTablesReady,
  required String reason,
}) {
  debugPrint(
    '[GARSON_REFRESH_RENDER_GAP_DIAGNOSIS] '
    'selected_area=$selectedArea '
    'area_filter=$areaFilter '
    'total_chip_count=$totalChipCount '
    'occupied_chip_count=$occupiedChipCount '
    'board_tables_count=$boardTablesCount '
    'board_areas_count=$boardAreasCount '
    'board_orders_count=$boardOrdersCount '
    'current_sections_count=$currentSectionsCount '
    'last_good_sections_count=$lastGoodSectionsCount '
    'render_sections_count=$renderSectionsCount '
    'will_show_grid=$willShowGrid '
    'will_show_loading=$willShowLoading '
    'will_show_empty=$willShowEmpty '
    'is_refreshing=$isRefreshing '
    'initial_loading=$initialLoading '
    'store_tables_ready=$storeTablesReady '
    'reason=$reason',
  );
}

void logGarsonBlankBodyGuardTriggered({
  required String reason,
  required int totalChipCount,
  required int occupiedChipCount,
  required int lastGoodSectionsCount,
}) {
  debugPrint(
    '[GARSON_BLANK_BODY_GUARD_TRIGGERED] '
    'reason=$reason '
    'total_chip_count=$totalChipCount '
    'occupied_chip_count=$occupiedChipCount '
    'last_good_sections_count=$lastGoodSectionsCount',
  );
}

List<GarsonAreaSection> filterGarsonSectionsByArea({
  required List<GarsonAreaSection> sections,
  required String areaFilterKey,
}) {
  final parsed = _parseAreaFilterKey(areaFilterKey);
  if (_normalizeAreaFilterKey(areaFilterKey) == 'all') {
    return sections;
  }
  if (parsed.areaId.isNotEmpty) {
    return sections
        .where((section) => _t(section.areaId) == parsed.areaId)
        .toList(growable: false);
  }
  final targetName = parsed.areaName.toLowerCase();
  return sections
      .where(
        (section) => _t(section.areaName).toLowerCase() == targetName,
      )
      .toList(growable: false);
}

GarsonAreaSectionsResult _sectionsResultFromList(
  List<GarsonAreaSection> sections, {
  GarsonAreaGroupingMode mode = GarsonAreaGroupingMode.areaBased,
}) {
  return GarsonAreaSectionsResult(
    sections: sections,
    mode: sections.isEmpty ? GarsonAreaGroupingMode.blockedLoading : mode,
    legacyMasaGroupDetected: false,
  );
}

GarsonRenderBundle resolveGarsonRenderBundle({
  required GarsonAreaSectionsResult currentSections,
  GarsonAreaSectionsResult? lastGoodSections,
  required List<Map<String, dynamic>> fallbackAreas,
  required List<Map<String, dynamic>> fallbackTables,
  required List<Map<String, dynamic>> fallbackOrders,
  required Set<int> tableNumbers,
  required String areaFilterKey,
  required int uiTablesCount,
  required bool hasEverRenderedBoard,
  required bool initialBootstrapFinished,
  required bool isRefreshing,
  required bool initialLoading,
  required bool storeTablesReady,
}) {
  final decision = decideGarsonSectionsRender(
    currentSections: currentSections,
    lastGoodSections: lastGoodSections,
    uiTablesCount: uiTablesCount,
    hasEverRenderedBoard: hasEverRenderedBoard,
    initialBootstrapFinished: initialBootstrapFinished,
    isRefreshing: isRefreshing,
  );

  final parsedFilter = _parseAreaFilterKey(areaFilterKey);
  final beforeFilterCount = decision.sectionsResult.sections.length;
  var renderSections = filterGarsonSectionsByArea(
    sections: decision.sectionsResult.sections,
    areaFilterKey: areaFilterKey,
  );
  logGarsonAreaFilterDecision(
    selectedArea: areaFilterKey,
    selectedAreaId: parsedFilter.areaId,
    selectedAreaName: parsedFilter.areaName,
    beforeSectionsCount: beforeFilterCount,
    afterSectionsCount: renderSections.length,
    matchedBy: _normalizeAreaFilterKey(areaFilterKey) == 'all'
        ? 'all'
        : (parsedFilter.areaId.isNotEmpty ? 'id' : 'name'),
  );

  if (renderSections.isEmpty &&
      (lastGoodSections?.sections.isNotEmpty ?? false)) {
    renderSections = filterGarsonSectionsByArea(
      sections: lastGoodSections!.sections,
      areaFilterKey: areaFilterKey,
    );
  }

  if (renderSections.isEmpty && uiTablesCount > 0) {
    final rebuilt = resolveGarsonAreaSections(
      areas: fallbackAreas,
      tables: fallbackTables,
      activeOrders: fallbackOrders,
      tableNumbers: tableNumbers,
    );
    if (rebuilt.sections.isNotEmpty) {
      renderSections = filterGarsonSectionsByArea(
        sections: rebuilt.sections,
        areaFilterKey: areaFilterKey,
      );
    }
  }

  var totalTableCount =
      renderSections.fold<int>(0, (sum, s) => sum + s.totalCount);
  var occupiedTableCount =
      renderSections.fold<int>(0, (sum, s) => sum + s.occupiedCount);

  if (totalTableCount == 0 &&
      (lastGoodSections?.sections.isNotEmpty ?? false)) {
    logGarsonBlankBodyGuardTriggered(
      reason: 'count_exists_but_sections_empty',
      totalChipCount: uiTablesCount,
      occupiedChipCount: occupiedTableCount,
      lastGoodSectionsCount: lastGoodSections!.sections.length,
    );
    renderSections = filterGarsonSectionsByArea(
      sections: lastGoodSections.sections,
      areaFilterKey: areaFilterKey,
    );
    totalTableCount =
        renderSections.fold<int>(0, (sum, s) => sum + s.totalCount);
    occupiedTableCount =
        renderSections.fold<int>(0, (sum, s) => sum + s.occupiedCount);
  }

  // ── Physical-table fallback guard ──────────────────────────────────────────
  // If every other strategy produced 0 tables but physical table rows exist,
  // build sections directly from the catalog data with empty orders. This
  // ensures "Toplam Masa: 0" can NEVER appear when store tables are present —
  // all tables render as empty cards instead of a blank screen.
  if (totalTableCount == 0 && fallbackTables.isNotEmpty) {
    final physicalSections = resolveGarsonAreaSections(
      areas: fallbackAreas,
      tables: fallbackTables,
      activeOrders: const <Map<String, dynamic>>[],
      tableNumbers: tableNumbers,
    );
    if (physicalSections.sections.isNotEmpty) {
      debugPrint(
        '[GARSON_PHYSICAL_TABLE_FALLBACK] '
        'sections=${physicalSections.sections.length} '
        'tables=${fallbackTables.length} '
        'reason=orders_empty_but_tables_exist',
      );
      renderSections = filterGarsonSectionsByArea(
        sections: physicalSections.sections,
        areaFilterKey: areaFilterKey,
      );
      totalTableCount =
          renderSections.fold<int>(0, (sum, s) => sum + s.totalCount);
      occupiedTableCount =
          renderSections.fold<int>(0, (sum, s) => sum + s.occupiedCount);
    }
  }

  final willShowGrid = totalTableCount > 0 ||
      occupiedTableCount > 0 ||
      renderSections.isNotEmpty ||
      uiTablesCount > 0 ||
      (lastGoodSections?.sections.isNotEmpty ?? false);

  final willShowLoading = (!initialBootstrapFinished &&
          !hasEverRenderedBoard &&
          uiTablesCount == 0 &&
          (lastGoodSections?.sections.isEmpty ?? true)) ||
      (renderSections.isEmpty &&
          !willShowGrid &&
          currentSections.isLoading &&
          !(isRefreshing && (lastGoodSections?.sections.isNotEmpty ?? false)) &&
          initialLoading);

  final willShowEmpty = !willShowGrid &&
      !willShowLoading &&
      decision.willShowEmpty;

  final sectionsResult = _sectionsResultFromList(
    renderSections,
    mode: renderSections.isNotEmpty
        ? GarsonAreaGroupingMode.areaBased
        : decision.sectionsResult.mode,
  );

  final reason = renderSections.isNotEmpty
      ? decision.reason
      : (willShowLoading
            ? 'sections_loading'
            : (willShowEmpty ? 'true_empty' : decision.reason));

  logGarsonRefreshRenderGapDiagnosis(
    selectedArea: areaFilterKey,
    areaFilter: _normalizeAreaFilterKey(areaFilterKey),
    totalChipCount: totalTableCount,
    occupiedChipCount: occupiedTableCount,
    boardTablesCount: fallbackTables.length,
    boardAreasCount: fallbackAreas.length,
    boardOrdersCount: fallbackOrders.length,
    currentSectionsCount: currentSections.sections.length,
    lastGoodSectionsCount: lastGoodSections?.sections.length ?? 0,
    renderSectionsCount: renderSections.length,
    willShowGrid: willShowGrid,
    willShowLoading: willShowLoading,
    willShowEmpty: willShowEmpty,
    isRefreshing: isRefreshing,
    initialLoading: initialLoading,
    storeTablesReady: storeTablesReady,
    reason: reason,
  );

  return GarsonRenderBundle(
    decision: decision,
    renderSections: renderSections,
    sectionsResult: sectionsResult,
    totalTableCount: totalTableCount,
    occupiedTableCount: occupiedTableCount,
    willShowGrid: willShowGrid,
    willShowLoading: willShowLoading,
    willShowEmpty: willShowEmpty,
    reason: reason,
  );
}
