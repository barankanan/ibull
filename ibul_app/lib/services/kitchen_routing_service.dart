import '../models/mixed_service_order.dart';

class KitchenRoutingItem {
  const KitchenRoutingItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.stationId,
    this.itemNote,
    this.amountLabel,
    this.plates = const [],
    this.serviceChildren = const [],
  });

  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? stationId;
  /// Plain user note + merged attributes (no plate structure).
  final String? itemNote;
  /// Weight / portion label, e.g. "500 g".
  final String? amountLabel;
  /// Structured plate groupings for mixed-service items.
  final List<Map<String, dynamic>> plates;
  /// Flat child list for non-plate-grouped service items.
  final List<Map<String, dynamic>> serviceChildren;

  Map<String, dynamic> toPayloadMap() {
    final map = <String, dynamic>{
      'product_id': productId,
      'name': productName,
      'quantity': quantity,
      'price': unitPrice,
      'station_id': stationId,
      'notes': itemNote,
    };
    if (amountLabel != null && amountLabel!.isNotEmpty) {
      map['amount_label'] = amountLabel;
    }
    if (plates.isNotEmpty) {
      map['plates'] = plates;
    } else if (serviceChildren.isNotEmpty) {
      map['service_children'] = serviceChildren;
    }
    return map;
  }
}

class KitchenRoutingService {
  const KitchenRoutingService();

  List<KitchenRoutingItem> normalizeItems(List<Map<String, dynamic>> rawItems) {
    final results = <KitchenRoutingItem>[];
    for (final item in rawItems) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = _parsePrice(item['price']);
          final normalizedItem = MixedServiceOrder.normalizeOrderItem(item);
          final name = normalizedItem['item_name']?.toString().trim() ?? '';

          final amountLabel = (normalizedItem['amount_label'] ??
                  normalizedItem['gramaj'])
              ?.toString()
              .trim();

          final plates = MixedServiceOrder.buildKitchenPlates(normalizedItem);
          final serviceChildren = plates.isEmpty
              ? MixedServiceOrder.buildKitchenServiceChildren(normalizedItem)
              : const <Map<String, dynamic>>[];

          // Mixed-service items can contain children across multiple stations.
          // The SQL print RPC groups by station_id, so we must split such items
          // into per-station payload items, otherwise station_id=null will
          // produce no printer match (no kitchen ticket).
          if (MixedServiceOrder.isMixedService(normalizedItem)) {
            final children = MixedServiceOrder.normalizeChildItems(
              normalizedItem['child_items'],
            );
            final byStation = <String, List<Map<String, dynamic>>>{};
            for (final child in children) {
              final sid = (child['station_id']?.toString().trim() ?? '');
              byStation.putIfAbsent(sid, () => <Map<String, dynamic>>[]).add(child);
            }

            // If every child has the same non-empty station, keep as-is.
            final uniqueNonEmptyStations =
                byStation.keys.where((k) => k.isNotEmpty).toSet();
            if (uniqueNonEmptyStations.length == 1 && byStation.length == 1) {
              results.add(
                KitchenRoutingItem(
                  productId: normalizedItem['product_id']?.toString(),
                  productName: name.isEmpty ? 'Ürün' : name,
                  quantity: quantity <= 0 ? 1 : quantity,
                  unitPrice: unitPrice,
                  stationId: uniqueNonEmptyStations.first,
                  itemNote: MixedServiceOrder.buildKitchenNote(normalizedItem),
                  amountLabel: (amountLabel == null || amountLabel.isEmpty)
                      ? null
                      : amountLabel,
                  plates: plates,
                  serviceChildren: serviceChildren,
                ),
              );
              continue;
            }

            for (final entry in byStation.entries) {
              final stationId = entry.key.trim();
              final filteredItem = <String, dynamic>{
                ...normalizedItem,
                'station_id': stationId.isEmpty ? null : stationId,
                'child_items': entry.value,
              };
              final filteredPlates =
                  MixedServiceOrder.buildKitchenPlates(filteredItem);
              final filteredChildren = filteredPlates.isEmpty
                  ? MixedServiceOrder.buildKitchenServiceChildren(filteredItem)
                  : const <Map<String, dynamic>>[];
              results.add(
                KitchenRoutingItem(
                  productId: filteredItem['product_id']?.toString(),
                  productName: name.isEmpty ? 'Ürün' : name,
                  quantity: 1,
                  unitPrice: 0, // mixed service uses child structure; total is informational
                  stationId: stationId.isEmpty ? null : stationId,
                  itemNote: MixedServiceOrder.buildKitchenNote(filteredItem),
                  amountLabel: null,
                  plates: filteredPlates,
                  serviceChildren: filteredChildren,
                ),
              );
            }
            continue;
          }

          results.add(
            KitchenRoutingItem(
              productId: normalizedItem['product_id']?.toString(),
              productName: name.isEmpty ? 'Ürün' : name,
              quantity: quantity <= 0 ? 1 : quantity,
              unitPrice: unitPrice,
              stationId: normalizedItem['station_id']?.toString(),
              itemNote: MixedServiceOrder.buildKitchenNote(normalizedItem),
              amountLabel:
                  (amountLabel == null || amountLabel.isEmpty)
                      ? null
                      : amountLabel,
              plates: plates,
              serviceChildren: serviceChildren,
            ),
          );
        }
    return results;
  }

  double _parsePrice(dynamic raw) {
    return MixedServiceOrder.parsePrice(raw);
  }
}
