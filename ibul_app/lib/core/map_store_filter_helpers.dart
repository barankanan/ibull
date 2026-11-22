import '../features/mall/public/mall_public_format.dart'
    show mallHoursPresentation;
import '../utils/text_normalizer.dart';
import 'map_loading_helpers.dart';

/// Whether the distance slider should narrow results.
bool shouldApplyMapDistanceFilter({
  required bool hasUserLocation,
  required bool userAppliedDistanceFilter,
}) {
  return hasUserLocation && userAppliedDistanceFilter;
}

/// Mağazanın şu an açık olup olmadığını gerçek mağaza verisinden çözer.
///
/// `false`: satıcı mağazayı kapatmış ya da çalışma saatleri dışında.
/// `true`: açık olduğu biliniyor. `null`: veri yok / saat metni çözülemedi.
bool? resolveMapStoreOpenNow({
  required bool? isStoreOpen,
  required String? workingHours,
  DateTime? now,
}) {
  if (isStoreOpen == false) return false;
  final hours = workingHours?.trim() ?? '';
  if (hours.isEmpty) return isStoreOpen;
  if (RegExp(r'(^|\D)24\s*saat|7\s*/\s*24', caseSensitive: false)
      .hasMatch(hours)) {
    return true;
  }
  return mallHoursPresentation(hours, now: now)?.isOpen ?? isStoreOpen;
}

/// Applies search/category/open-now/distance filters to map store indices.
///
/// Açık filtresi yalnızca kapalı olduğu bilinen mağazaları gizler; açık/kapalı
/// bilgisi olmayan (`isOpenNowAt` → null) mağazalar listede kalır.
List<int> filterMapStoreIndices({
  required int businessCount,
  required String? Function(int index) businessNameAt,
  required String? Function(int index) categoryAt,
  required double? Function(int index) distanceKmAt,
  required String searchQuery,
  required List<String> filterCategories,
  required bool filterOpenNow,
  required double filterDistanceKm,
  required bool hasUserLocation,
  bool userAppliedDistanceFilter = false,
  Iterable<int>? candidateIndices,
  bool? Function(int index)? isOpenNowAt,
}) {
  if (businessCount == 0) return const [];

  final normalizedQuery = _normalize(searchQuery);
  final filteredIndices = <int>[];
  final indices = candidateIndices ?? Iterable.generate(businessCount, (i) => i);

  for (final i in indices) {
    if (i < 0 || i >= businessCount) continue;

    if (filterCategories.isNotEmpty) {
      final category = categoryAt(i) ?? 'other';
      final categoryMatch = filterCategories.any(
        (c) => c.toLowerCase() == category.toLowerCase(),
      );
      if (!categoryMatch) continue;
    }

    if (filterOpenNow && isOpenNowAt?.call(i) == false) continue;

    if (shouldApplyMapDistanceFilter(
      hasUserLocation: hasUserLocation,
      userAppliedDistanceFilter: userAppliedDistanceFilter,
    )) {
      final km = distanceKmAt(i);
      if (km == null || km > filterDistanceKm) continue;
    }

    if (normalizedQuery.isNotEmpty) {
      final name = _normalize(businessNameAt(i) ?? '');
      if (!name.contains(normalizedQuery)) continue;
    }

    filteredIndices.add(i);
  }

  return filteredIndices;
}

// Dart'ta "İ".toLowerCase() → "i̇" (i + birleştirici nokta); ortak
// normalizer bunu ve diğer Türkçe harfleri tek yerde ele alır.
String _normalize(String value) => TextNormalizer.normalize(value);

/// Horizontal store chip row message when no stores match current filters.
String resolveMapFilteredEmptyMessage({
  required int rawCount,
  required int markerCount,
  required int filteredCount,
  required String searchQuery,
  required List<String> filterCategories,
  required bool hasUserLocation,
  required double filterDistanceKm,
  bool userAppliedDistanceFilter = false,
  bool filterOpenNow = false,
}) {
  if (markerCount == 0) {
    return resolveMapStoresEmptyMessage(
      rawCount: rawCount,
      markerCount: markerCount,
    );
  }
  if (filteredCount > 0) return '';

  final hasSearch = searchQuery.trim().isNotEmpty;
  final hasCategoryFilter = filterCategories.isNotEmpty;
  final hasDistanceFilter = shouldApplyMapDistanceFilter(
    hasUserLocation: hasUserLocation,
    userAppliedDistanceFilter: userAppliedDistanceFilter,
  );

  if (hasSearch || hasCategoryFilter || hasDistanceFilter || filterOpenNow) {
    return 'Filtreye uygun mağaza bulunamadı.';
  }
  return 'Gösterilecek mağaza bulunamadı.';
}
