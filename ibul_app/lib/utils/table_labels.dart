/// Shared helpers to resolve table/area labels across UI + print payloads.
///
/// Intentionally uses loose `Map<String, dynamic>` inputs because these rows
/// come from Supabase/PostgREST and can vary across migrations.
library;

String _t(dynamic v) => (v ?? '').toString().trim();

int _pi(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_t(v)) ?? 0;
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
  if (tableRow != null) {
    final display = _t(tableRow['display_label']);
    if (display.isNotEmpty) return display;
    final tableName = _t(tableRow['table_name']);
    if (tableName.isNotEmpty) return tableName;
    final areaName = _t(tableRow['area_name']);
    final n = _pi(tableRow['area_table_number']) > 0
        ? _pi(tableRow['area_table_number'])
        : _pi(tableRow['table_number']);
    if (areaName.isNotEmpty && n > 0) return '$areaName $n';
  }
  if (tableNumber > 0) return 'Masa $tableNumber';
  return 'Masa';
}

/// Resolves the print payload table label fields to keep receipt + kitchen in sync.
Map<String, dynamic> resolvePrintableTablePayloadFields({
  required Map<String, dynamic>? tableRow,
  required int tableNumber,
}) {
  final title = resolveTableCardTitle(tableRow: tableRow, tableNumber: tableNumber);
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
int nextAreaTableNumberSuggestion(List<Map<String, dynamic>> storeTables, String areaId) {
  final used = storeTables
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

