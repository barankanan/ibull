/// Resolves the primary display image for catalog/product cards.
class ProductImageResolver {
  const ProductImageResolver._();

  static String? primaryUrl({
    String? imageUrl,
    Iterable<String>? imageUrls,
    Iterable<String>? images,
  }) {
    final primary = imageUrl?.trim() ?? '';
    if (primary.isNotEmpty) return primary;

    for (final candidate in imageUrls ?? const <String>[]) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }

    for (final candidate in images ?? const <String>[]) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }

    return null;
  }

  static String? fromProductMap(Map<String, dynamic> map) {
    final urls = map['image_urls'];
    final listUrls = urls is List
        ? urls.map((e) => e.toString()).toList(growable: false)
        : null;
    return primaryUrl(
      imageUrl: map['image_url']?.toString(),
      imageUrls: listUrls,
    );
  }
}
