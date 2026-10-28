import 'visual_search_models.dart';

/// Token overlap matcher. Scores are 0–1 and map later to pgvector cosine
/// similarity without changing [ProductMatch].
class VisualCatalogMatcher {
  const VisualCatalogMatcher();

  List<ProductMatch> match({
    required String hint,
    required List<VisualCatalogItem> catalog,
    int limit = 6,
  }) {
    final hintTokens = _tokens(hint);
    if (hintTokens.isEmpty || catalog.isEmpty) return const [];

    final scored = <ProductMatch>[];
    for (final item in catalog) {
      final haystack = _tokens(
        '${item.name} ${item.brand} ${item.category} ${item.description}',
      );
      if (haystack.isEmpty) continue;
      final overlap = hintTokens.where(haystack.contains).length;
      if (overlap == 0) continue;
      final union = {...hintTokens, ...haystack}.length;
      final score = overlap / union;
      scored.add(
        ProductMatch(
          id: newVisualSearchId(),
          productId: item.id,
          name: item.name,
          brand: item.brand,
          store: item.store,
          price: item.price,
          category: item.category,
          imageUrl: item.imageUrl,
          similarityScore: double.parse(score.toStringAsFixed(2)),
          matchType: _typeFor(score),
          rating: item.rating,
          reviewCount: item.reviewCount,
        ),
      );
    }
    scored.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    if (scored.length <= limit) return scored;
    return scored.sublist(0, limit);
  }

  ProductMatchType _typeFor(double score) {
    if (score >= 0.55) return ProductMatchType.exact;
    if (score >= 0.25) return ProductMatchType.similar;
    return ProductMatchType.alternative;
  }

  Set<String> _tokens(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return normalized
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toSet();
  }
}
