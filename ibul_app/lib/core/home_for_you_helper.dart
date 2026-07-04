import '../models/db_product.dart';
import 'home_snapshot_cache.dart';

/// Pure selection logic for the "Sana özel" home rail — testable without UI.
List<DBProduct> selectForYouProducts({
  required List<DBProduct> personalizedCache,
  required List<DBProduct> popularCache,
  required List<DBProduct> mainProducts,
  int limit = homePersonalizedProductsLimit,
}) {
  if (personalizedCache.isNotEmpty) {
    return personalizedCache.take(limit).toList(growable: false);
  }
  final fromPopular =
      computeForYouFeaturedSliceWithFallback(popularCache, limit: limit);
  if (fromPopular.isNotEmpty) return fromPopular;
  return computeForYouFeaturedSliceWithFallback(mainProducts, limit: limit);
}

/// Featured slice with immediate active-product fallback (no image gate).
List<DBProduct> computeForYouFeaturedSliceWithFallback(
  List<DBProduct> source, {
  int limit = homePersonalizedProductsLimit,
}) {
  final featured = computeForYouFeaturedSlice(source, limit: limit);
  if (featured.isNotEmpty) return featured;
  return source
      .where((p) => p.isActive)
      .take(limit)
      .toList(growable: false);
}

/// Client-side featured slice for the ForYou rail (no network).
List<DBProduct> computeForYouFeaturedSlice(
  List<DBProduct> source, {
  int limit = homePersonalizedProductsLimit,
}) {
  var productsWithImages = source
      .where((p) => p.isActive && p.imageUrl.isNotEmpty)
      .toList(growable: false);

  productsWithImages = productsWithImages
      .where((p) {
        final nameLower = p.name.toLowerCase();
        final brandLower = p.brand.toLowerCase();
        final isArcelikVacuum =
            brandLower.contains('arçelik') &&
            (nameLower.contains('ct-z3') ||
                nameLower.contains('infinity') ||
                nameLower.contains('2300'));
        return !isArcelikVacuum;
      })
      .toList(growable: false);

  final reordered = List<DBProduct>.from(productsWithImages);
  final haylouIndex = reordered.indexWhere((p) {
    final nameLower = p.name.toLowerCase();
    final brandLower = p.brand.toLowerCase();
    return brandLower.contains('haylou') && nameLower.contains('solar');
  });

  if (haylouIndex != -1) {
    final haylouProduct = reordered.removeAt(haylouIndex);
    reordered.add(haylouProduct);
  }

  return reordered.take(limit).toList(growable: false);
}
