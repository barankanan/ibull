import 'map_loading_helpers.dart';

/// Diagnosis string when the map store list ends up empty.
String diagnoseMapStoresEmpty({
  required int storesTableCount,
  required int productSellerFallbackCount,
  required int syntheticFromProductsCount,
  required int activeProductsWithSeller,
  required int uniqueSellers,
  required int markerCount,
  String? lastError,
}) {
  if (markerCount > 0) return '';

  if (lastError != null && lastError.isNotEmpty) {
    final lower = lastError.toLowerCase();
    if (lower.contains('jwt') || lower.contains('permission denied')) {
      return 'RLS veya oturum izni mağaza sorgusunu engelliyor.';
    }
    if (lower.contains('could not find') && lower.contains('column')) {
      return 'stores tablosu şema uyumsuzluğu (eksik kolon).';
    }
    return 'Mağaza sorgusu hata verdi: ${lastError.split('\n').first}';
  }

  if (storesTableCount == 0 &&
      productSellerFallbackCount == 0 &&
      syntheticFromProductsCount == 0) {
    if (activeProductsWithSeller == 0) {
      return 'Aktif ürünlerde seller_id yok; mağaza üretilemedi.';
    }
    if (uniqueSellers > 0) {
      return 'stores tablosu boş veya RLS (is_store_open) satırları gizliyor.';
    }
    return 'Gösterilecek mağaza kaydı bulunamadı.';
  }

  if (storesTableCount > 0 && markerCount == 0) {
    return resolveMapStoresEmptyMessage(
      rawCount: storesTableCount,
      markerCount: markerCount,
    );
  }

  return 'Bilinmeyen neden — filtre veya koordinat sonrası liste boş.';
}

/// Build synthetic store rows from product seller metadata (no stores table row).
List<Map<String, dynamic>> buildSyntheticMapStoresFromProducts({
  required Iterable<({String sellerId, String storeName})> sellers,
}) {
  final rows = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final entry in sellers) {
    final sellerId = entry.sellerId.trim();
    if (sellerId.isEmpty || !seen.add(sellerId)) continue;
    final name = entry.storeName.trim();
    rows.add({
      'seller_id': sellerId,
      'business_name': name.isNotEmpty ? name : 'Mağaza',
      'city': 'Hatay',
      'district': 'Antakya',
      '_synthetic_from_products': true,
    });
  }
  return rows;
}
