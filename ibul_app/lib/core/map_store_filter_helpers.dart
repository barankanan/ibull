import 'map_loading_helpers.dart';

/// Whether the distance slider should narrow results.
bool shouldApplyMapDistanceFilter({
  required bool hasUserLocation,
  required bool userAppliedDistanceFilter,
}) {
  return hasUserLocation && userAppliedDistanceFilter;
}

/// Applies search/category/open-now/distance filters to map store indices.
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

    if (filterOpenNow && i % 5 == 0) continue;

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

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

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

  if (hasSearch || hasCategoryFilter || hasDistanceFilter) {
    return 'Filtreye uygun mağaza bulunamadı.';
  }
  return 'Gösterilecek mağaza bulunamadı.';
}
