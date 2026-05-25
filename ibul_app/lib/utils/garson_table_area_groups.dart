/// Garson masa ekranı — alan başlıklarına göre gruplama (yalnızca UI).
library;

String _t(dynamic v) => (v ?? '').toString().trim();

int _pi(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(_t(v)) ?? 0;
}

/// Tek alan grubu: başlık + sıralı masa numaraları.
class GarsonTableAreaGroup {
  const GarsonTableAreaGroup({
    required this.areaKey,
    required this.areaName,
    required this.sortOrder,
    required this.tableNumbers,
  });

  /// `id:<uuid>` veya `name:<normalized>`.
  final String areaKey;
  final String areaName;
  final int sortOrder;
  final List<int> tableNumbers;
}

/// Masa satırından alan adı (area_name veya area_id → areas lookup).
String garsonAreaNameForTableRow({
  required Map<String, dynamic>? tableRow,
  required List<Map<String, dynamic>> storeTableAreas,
}) {
  if (tableRow == null) return '';
  final direct = _t(tableRow['area_name']);
  if (direct.isNotEmpty) return direct;
  final areaId = _t(tableRow['area_id']);
  if (areaId.isEmpty) return '';
  for (final area in storeTableAreas) {
    if (_t(area['id']) == areaId) {
      return _t(area['name']);
    }
  }
  return '';
}

int _areaSortOrder({
  required String areaKey,
  required List<Map<String, dynamic>> storeTableAreas,
}) {
  if (areaKey == kGarsonOtherAreaKey) {
    return 999999;
  }
  if (areaKey.startsWith('id:')) {
    final id = areaKey.substring(3);
    for (final area in storeTableAreas) {
      if (_t(area['id']) == id) {
        return _pi(area['sort_order']);
      }
    }
  }
  if (areaKey.startsWith('name:')) {
    final norm = areaKey.substring(5);
    for (final area in storeTableAreas) {
      if (_t(area['name']).toLowerCase() == norm) {
        return _pi(area['sort_order']);
      }
    }
  }
  return 0;
}

String _areaKeyForRow({
  required Map<String, dynamic>? tableRow,
  required String areaName,
}) {
  if (tableRow != null) {
    final areaId = _t(tableRow['area_id']);
    if (areaId.isNotEmpty) return 'id:$areaId';
  }
  if (areaName.isEmpty) return kGarsonOtherAreaKey;
  return 'name:${areaName.toLowerCase()}';
}

int _tableSortKey(Map<String, dynamic>? row, int tableNumber) {
  if (row != null) {
    final areaNo = _pi(row['area_table_number']);
    if (areaNo > 0) return areaNo;
    final n = _pi(row['table_number']);
    if (n > 0) return n;
  }
  return tableNumber > 0 ? tableNumber : 0;
}

const String kGarsonOtherAreaKey = 'other';
const String kGarsonOtherAreaLabel = 'Diğer';

/// [tableNumbers] listesini alan başlıklarına göre gruplar ve sıralar.
List<GarsonTableAreaGroup> groupGarsonTablesByArea({
  required List<int> tableNumbers,
  required List<Map<String, dynamic>> storeTables,
  required List<Map<String, dynamic>> storeTableAreas,
  Map<String, dynamic>? Function(int tableNumber)? tableRowForNumber,
}) {
  if (tableNumbers.isEmpty) return const <GarsonTableAreaGroup>[];

  final rowByNumber = <int, Map<String, dynamic>>{};
  if (tableRowForNumber != null) {
    for (final n in tableNumbers) {
      final row = tableRowForNumber(n);
      if (row != null) rowByNumber[n] = row;
    }
  } else {
    for (final row in storeTables) {
      final n = _pi(row['table_number']);
      if (n > 0) rowByNumber[n] = row;
    }
  }

  final buckets = <String, List<int>>{};
  final names = <String, String>{};

  for (final tableNumber in tableNumbers) {
    if (tableNumber <= 0) continue;
    final row = rowByNumber[tableNumber];
    var areaName = garsonAreaNameForTableRow(
      tableRow: row,
      storeTableAreas: storeTableAreas,
    );
    if (areaName.isEmpty) areaName = kGarsonOtherAreaLabel;
    final key = _areaKeyForRow(tableRow: row, areaName: areaName);
    names[key] = areaName;
    buckets.putIfAbsent(key, () => <int>[]).add(tableNumber);
  }

  final groups = <GarsonTableAreaGroup>[];
  for (final entry in buckets.entries) {
    final numbers = List<int>.from(entry.value)
      ..sort((a, b) {
        final left = _tableSortKey(rowByNumber[a], a);
        final right = _tableSortKey(rowByNumber[b], b);
        final cmp = left.compareTo(right);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });
    groups.add(
      GarsonTableAreaGroup(
        areaKey: entry.key,
        areaName: names[entry.key] ?? kGarsonOtherAreaLabel,
        sortOrder: _areaSortOrder(
          areaKey: entry.key,
          storeTableAreas: storeTableAreas,
        ),
        tableNumbers: numbers,
      ),
    );
  }

  groups.sort((a, b) {
    final orderCmp = a.sortOrder.compareTo(b.sortOrder);
    if (orderCmp != 0) return orderCmp;
    return a.areaName.toLowerCase().compareTo(b.areaName.toLowerCase());
  });
  return groups;
}
