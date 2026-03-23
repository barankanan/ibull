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
          final name = item['name']?.toString().trim() ?? '';
          return KitchenRoutingItem(
            productId: item['product_id']?.toString(),
            productName: name.isEmpty ? 'Ürün' : name,
            quantity: quantity <= 0 ? 1 : quantity,
            unitPrice: unitPrice,
            stationId: item['station_id']?.toString(),
            itemNote: item['notes']?.toString(),
          );
        })
        .toList(growable: false);
  }

  double _parsePrice(dynamic raw) {
    if (raw is num) return raw.toDouble();
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return 0;

    var normalized = text.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.isEmpty) return 0;
    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');

    if (hasComma && hasDot) {
      if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (hasComma) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalized) ?? 0;
  }
}
