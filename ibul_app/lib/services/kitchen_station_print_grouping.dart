import 'kitchen_print_trace_log.dart';
import 'kitchen_routing_service.dart';

/// One kitchen ticket group: same production station, one or more items.
class KitchenStationPrintGroup {
  const KitchenStationPrintGroup({
    required this.stationId,
    required this.stationName,
    required this.items,
  });

  final String stationId;
  final String stationName;
  final List<Map<String, dynamic>> items;

  String get groupKey => stationId.isEmpty ? '__general__' : stationId;
}

/// Shared Garson / cargo grouping. Empty [station_id] becomes Genel (`__general__`).
///
/// When [item.station_id] is empty, falls back to [productStationByProductId]
/// the same way Garson `_groupItemsByProductionStation` does.
List<KitchenStationPrintGroup> groupItemsByProductionStation(
  List<Map<String, dynamic>> items, {
  required Map<String, String> stationNamesById,
  Map<String, String>? stationCodesById,
  Map<String, ProductStationMapping>? productStationByProductId,
}) {
  final grouped = <String, KitchenStationPrintGroup>{};
  for (final item in items) {
    logKitchenRoutingGroupInput(item);
    var stationId = item['station_id']?.toString().trim() ?? '';
    final productId = item['product_id']?.toString().trim() ?? '';
    final mapping = productId.isEmpty
        ? null
        : productStationByProductId?[productId];
    if (stationId.isEmpty && mapping != null && mapping.stationId.isNotEmpty) {
      stationId = mapping.stationId;
      item['station_id'] = stationId;
    }
    if (mapping != null && mapping.stationCode.isNotEmpty) {
      item['station_code'] = mapping.stationCode;
    } else if (stationId.isNotEmpty &&
        (stationCodesById?[stationId] ?? '').isNotEmpty) {
      item['station_code'] = stationCodesById![stationId]!;
    }
    final key = stationId.isEmpty ? '__general__' : stationId;
    final stationName =
        KitchenTicketHeaderResolver.resolveProductionHeaderForItem(
          item: item,
          stationNamesById: stationNamesById,
          stationCodesById: stationCodesById,
          productStationByProductId: productStationByProductId,
        );
    grouped
        .putIfAbsent(
          key,
          () => KitchenStationPrintGroup(
            stationId: stationId,
            stationName: stationName,
            items: <Map<String, dynamic>>[],
          ),
        )
        .items
        .add(item);
    logKitchenRoutingGroupCreated(
      groupKey: key,
      stationId: stationId,
      stationName: stationName,
      stationCode: item['station_code']?.toString() ?? '',
      itemCount: grouped[key]!.items.length,
    );
  }
  if (grouped.isEmpty) {
    return <KitchenStationPrintGroup>[
      KitchenStationPrintGroup(
        stationId: '',
        stationName: kKitchenGeneralStationLabel,
        items: items,
      ),
    ];
  }
  return grouped.values.toList(growable: false);
}

bool isKitchenPrinterRoutingEnabled(Map<String, dynamic> item) {
  final raw = item['printer_routing_enabled'];
  if (raw == false) return false;
  if (raw is String && raw.trim().toLowerCase() == 'false') return false;
  return true;
}

List<Map<String, dynamic>> filterKitchenRoutableItems(
  List<Map<String, dynamic>> items,
) {
  return items
      .where(isKitchenPrinterRoutingEnabled)
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String kitchenPrintStationGroupKey(String? stationId) {
  final normalized = (stationId ?? '').trim();
  return normalized.isEmpty ? '__general__' : normalized;
}

Set<String> activeKitchenPrintStationKeys(
  Iterable<Map<String, dynamic>> existingJobs,
) {
  const activeStatuses = <String>{
    'pending',
    'claimed',
    'printing',
    'completed',
    'paused_by_operator',
  };
  final keys = <String>{};
  for (final job in existingJobs) {
    final status = (job['status'] ?? '').toString().trim().toLowerCase();
    if (!activeStatuses.contains(status)) continue;
    keys.add(kitchenPrintStationGroupKey(job['station_id']?.toString()));
  }
  return keys;
}
