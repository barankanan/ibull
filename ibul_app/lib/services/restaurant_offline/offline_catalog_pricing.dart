/// Çevrimdışı sipariş kalemlerinin güvenilir yerel kataloga göre fiyatlanması.
///
/// Tek sözleşme: LAN merkezine gelen cihaz siparişleri, merkezin kendi çevrimdışı
/// siparişleri ve operatör siparişi AYNI fonksiyonla doğrulanır. İstemcinin gönderdiği
/// fiyat asla güvenilmez; katalogda olmayan veya fiyatı doğrulanamayan ürün satılmaz.
class PricedOfflineItems {
  const PricedOfflineItems({
    required this.items,
    required this.total,
    this.error,
  });

  final List<Map<String, dynamic>> items;
  final double total;
  final String? error;
}

PricedOfflineItems pricedOfflineItems({
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> catalog,
  required String requestStationId,
}) {
  if (items.isEmpty) {
    return const PricedOfflineItems(
      items: <Map<String, dynamic>>[],
      total: 0,
      error: 'Sipariş kalemi yok.',
    );
  }
  final priced = <Map<String, dynamic>>[];
  var total = 0.0;
  for (final item in items) {
    final name = item['name']?.toString().trim() ?? '';
    final productId = item['product_id']?.toString().trim() ?? '';
    Map<String, dynamic>? product;
    for (final row in catalog) {
      final rowId = row['id']?.toString().trim() ?? '';
      final rowName = row['name']?.toString().trim() ?? '';
      if (productId.isNotEmpty && rowId == productId) {
        product = row;
        break;
      }
      if (name.isNotEmpty && rowName == name) {
        product = row;
        break;
      }
    }
    if (product == null) {
      return PricedOfflineItems(
        items: const <Map<String, dynamic>>[],
        total: 0,
        error: 'Ürün yerel katalogda yok: $name',
      );
    }
    final catalogPrice = product['price'];
    if (catalogPrice is! num) {
      return const PricedOfflineItems(
        items: <Map<String, dynamic>>[],
        total: 0,
        error: 'Ürün fiyatı yerel katalogda doğrulanamadı.',
      );
    }
    final offered = item['price'];
    if (offered is num && (offered - catalogPrice).abs() > 0.009) {
      return const PricedOfflineItems(
        items: <Map<String, dynamic>>[],
        total: 0,
        error: 'Ürün fiyatı yerel katalogla uyuşmuyor.',
      );
    }
    final productStation = product['station_id']?.toString().trim() ?? '';
    final itemStation = item['station_id']?.toString().trim() ?? '';
    if (itemStation.isNotEmpty &&
        productStation.isNotEmpty &&
        itemStation != productStation) {
      return const PricedOfflineItems(
        items: <Map<String, dynamic>>[],
        total: 0,
        error: 'Ürün bu istasyona ait değil.',
      );
    }
    final station = itemStation.isNotEmpty
        ? itemStation
        : (productStation.isNotEmpty ? productStation : requestStationId);
    final qty = (item['quantity'] as num?)?.toDouble() ?? 1;
    if (qty <= 0) {
      return const PricedOfflineItems(
        items: <Map<String, dynamic>>[],
        total: 0,
        error: 'Ürün adedi geçersiz.',
      );
    }
    final copy = Map<String, dynamic>.from(item);
    copy['price'] = catalogPrice;
    copy['line_total'] = double.parse(
      (catalogPrice.toDouble() * qty).toStringAsFixed(2),
    );
    if (station.isNotEmpty) copy['station_id'] = station;
    total += catalogPrice.toDouble() * qty;
    priced.add(copy);
  }
  return PricedOfflineItems(items: priced, total: total);
}
