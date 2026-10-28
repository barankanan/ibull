import '../../models/product_model.dart';

class FavoriteBrowseQuery {
  const FavoriteBrowseQuery({this.query = '', this.category = 'Tümü'});

  final String query;
  final String category;
}

List<String> favoriteCategoriesOf(Iterable<Product> products) {
  final names = <String>{};
  for (final product in products) {
    final category = (product.category ?? '').trim();
    if (category.isNotEmpty) names.add(category);
  }
  final sorted = names.toList()..sort();
  return ['Tümü', ...sorted];
}

List<Product> filterFavoriteProducts(
  List<Product> products,
  FavoriteBrowseQuery query,
) {
  final needle = query.query.trim().toLowerCase();
  return products.where((product) {
    final category = (product.category ?? '').trim();
    if (query.category != 'Tümü' && category != query.category) {
      return false;
    }
    if (needle.isEmpty) return true;
    final haystack = '${product.name} ${product.brand} $category'.toLowerCase();
    return haystack.contains(needle);
  }).toList();
}

int favoriteCategoryCount(Iterable<Product> products) {
  return favoriteCategoriesOf(products).length - 1;
}

const recommendationChips = <String>[
  'Sana Göre',
  'Trend',
  'Elektronik',
  'Yemek',
  'Moda',
  'Ev & Yaşam',
  'Yeni',
];

List<Product> rankRecommendedProducts({
  required List<Product> catalog,
  required Iterable<Product> favorites,
  required Iterable<Product> recentlyViewed,
  required String chip,
  String query = '',
}) {
  final favoriteIds = favorites
      .map((product) => product.productId?.trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
  final favoriteCategories = favorites
      .map((product) => (product.category ?? '').trim().toLowerCase())
      .where((category) => category.isNotEmpty)
      .toSet();
  final recentCategories = recentlyViewed
      .map((product) => (product.category ?? '').trim().toLowerCase())
      .where((category) => category.isNotEmpty)
      .toSet();
  final needle = query.trim().toLowerCase();

  final scored = <({Product product, int score})>[];
  for (final product in catalog) {
    final id = product.productId?.trim() ?? '';
    if (id.isNotEmpty && favoriteIds.contains(id)) continue;
    final category = (product.category ?? '').trim().toLowerCase();
    final haystack =
        '${product.name} ${product.brand} ${product.store ?? ''} $category'
            .toLowerCase();
    if (needle.isNotEmpty && !haystack.contains(needle)) continue;
    if (!_matchesChip(category, chip)) continue;

    var score = 0;
    if (favoriteCategories.contains(category)) score += 3;
    if (recentCategories.contains(category)) score += 2;
    if ((product.oldPrice ?? '').trim().isNotEmpty) score += 1;
    score += product.reviewCount > 20 ? 1 : 0;
    scored.add((product: product, score: score));
  }

  if (chip == 'Yeni') {
    scored.sort((a, b) {
      final left = a.product.catalogUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.product.catalogUpdatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
  } else if (chip == 'Trend') {
    scored.sort((a, b) => b.product.reviewCount.compareTo(a.product.reviewCount));
  } else {
    scored.sort((a, b) => b.score.compareTo(a.score));
  }
  return scored.map((entry) => entry.product).toList();
}

bool _matchesChip(String category, String chip) {
  switch (chip) {
    case 'Elektronik':
      return category.contains('elektronik');
    case 'Yemek':
      return category.contains('yemek') || category.contains('restoran');
    case 'Moda':
      return category.contains('moda') || category.contains('giyim');
    case 'Ev & Yaşam':
      return category.contains('ev') || category.contains('yaşam') || category.contains('yasam');
    case 'Sana Göre':
    case 'Trend':
    case 'Yeni':
      return true;
    default:
      return category == chip.toLowerCase();
  }
}
