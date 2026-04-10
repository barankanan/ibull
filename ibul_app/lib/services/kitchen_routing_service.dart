import '../models/mixed_service_order.dart';

class KitchenRoutingItem {
  const KitchenRoutingItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.stationId,
    this.itemNote,
  });

  final String? productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String? stationId;
  final String? itemNote;

  Map<String, dynamic> toPayloadMap() {
    return {
      'product_id': productId,
      'name': productName,
      'quantity': quantity,
      'price': unitPrice,
      'station_id': stationId,
      'notes': itemNote,
    };
  }
}

class KitchenRoutingService {
  const KitchenRoutingService();

  List<KitchenRoutingItem> normalizeItems(List<Map<String, dynamic>> rawItems) {
    return rawItems
        .map((item) {
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = _parsePrice(item['price']);
          final normalizedItem = MixedServiceOrder.normalizeOrderItem(item);
          final name = normalizedItem['item_name']?.toString().trim() ?? '';
          return KitchenRoutingItem(
            productId: normalizedItem['product_id']?.toString(),
            productName: name.isEmpty ? 'Ürün' : name,
            quantity: quantity <= 0 ? 1 : quantity,
            unitPrice: unitPrice,
            stationId: normalizedItem['station_id']?.toString(),
            itemNote: MixedServiceOrder.buildKitchenNote(normalizedItem),
          );
        })
        .toList(growable: false);
  }

  double _parsePrice(dynamic raw) {
    return MixedServiceOrder.parsePrice(raw);
  }
}
