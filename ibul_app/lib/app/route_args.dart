/// Shared route argument types for map deep links.
class MapRouteArguments {
  const MapRouteArguments({
    this.targetStoreName,
    this.initialStoreProductQuery,
  });

  final String? targetStoreName;
  final String? initialStoreProductQuery;
}

MapRouteArguments parseMapRouteArguments(dynamic args) {
  String? targetStoreName;
  String? initialStoreProductQuery;

  if (args is Map && args['targetStoreName'] != null) {
    targetStoreName = args['targetStoreName'].toString();
  }

  if (args is Map && args['initialStoreProductQuery'] != null) {
    initialStoreProductQuery = args['initialStoreProductQuery'].toString();
  }

  return MapRouteArguments(
    targetStoreName: targetStoreName,
    initialStoreProductQuery: initialStoreProductQuery,
  );
}
