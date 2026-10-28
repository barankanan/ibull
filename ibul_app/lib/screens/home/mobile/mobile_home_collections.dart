import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/favorite_state.dart';
import '../../../models/product_model.dart';
import '../../../utils/text_normalizer.dart';
import 'mobile_home_catalog.dart';
import 'mobile_home_see_all_page.dart';

const mobileHomeFeaturedCount = 8;
const mobileHomeCollectionMax = 10;
const mobileHomeCollectionMin = 3;

class MobileHomeCollection {
  const MobileHomeCollection({required this.title, required this.products});

  final String title;
  final List<Product> products;
}

class MobileHomeCollectionPlan {
  const MobileHomeCollectionPlan({
    required this.deals,
    required this.collections,
  });

  final List<Product> deals;
  final List<MobileHomeCollection> collections;
}

class MobileHomeSmartCollections extends StatelessWidget {
  const MobileHomeSmartCollections({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final recent = context.select<AppState, List<Product>>(
      (state) => state.recentlyViewedProducts,
    );
    final liked = context.select<FavoriteState, List<Product>>(
      (state) => state.favorites,
    );
    final plan = planMobileHomeCollections(
      pool: products,
      personal: [...liked, ...recent],
    );
    if (plan.deals.isEmpty && plan.collections.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (plan.deals.isNotEmpty)
          MobileProductRail(
            title: 'Bugünün Fırsatları',
            products: plan.deals,
            onSeeAll: () => _openProducts(context, 'Bugünün Fırsatları', plan.deals),
          ),
        for (final collection in plan.collections)
          MobileProductRail(
            title: collection.title,
            products: collection.products,
            onSeeAll: () =>
                _openProducts(context, collection.title, collection.products),
          ),
      ],
    );
  }
}

void _openProducts(BuildContext context, String title, List<Product> products) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MobileHomeSeeAllPage.products(
        title: title,
        products: products,
      ),
    ),
  );
}

MobileHomeCollectionPlan planMobileHomeCollections({
  required List<Product> pool,
  List<Product> personal = const [],
}) {
  final seen = <String>{};
  for (final product in pool.take(mobileHomeFeaturedCount)) {
    seen.add(_productKey(product));
  }
  final freshDeals = _take(
    pool.where(productHasRecordedDiscount),
    seen,
    min: 1,
  );
  final deals = freshDeals.isNotEmpty
      ? freshDeals
      : pool.where(productHasRecordedDiscount).take(4).toList(growable: false);
  final built = <String, List<Product>>{};
  void add(String title, Iterable<Product> source) {
    final picked = _takeDiverse(source, seen);
    if (picked.length < mobileHomeCollectionMin) return;
    built[title] = picked;
  }

  add('Elektronik Dünyası', pool.where((product) => _is(product, _electronics)));
  add('Tarzına Uygun Kıyafetler', pool.where((product) => _is(product, _fashion)));
  add('Evini Yenile', pool.where((product) => _is(product, _home)));
  add('Hoşuna Gidebilecekler', [...personal, ..._byRating(pool)]);
  add('Senin İçin Seçtiklerimiz', pool);
  add('Popüler Seçimler', _byRating(pool));
  const order = [
    'Hoşuna Gidebilecekler',
    'Elektronik Dünyası',
    'Tarzına Uygun Kıyafetler',
    'Senin İçin Seçtiklerimiz',
    'Evini Yenile',
    'Popüler Seçimler',
  ];
  return MobileHomeCollectionPlan(
    deals: deals,
    collections: [
      for (final title in order)
        if (built[title] != null)
          MobileHomeCollection(title: title, products: built[title]!),
    ],
  );
}

const _electronics = [
  'elektronik',
  'telefon',
  'televizyon',
  'tablet',
  'laptop',
  'dizustu',
  'bilgisayar',
  'depolama',
  'kamera',
  'kulaklik',
];

const _fashion = [
  'giyim',
  'kiyafet',
  'ayakkabi',
  'canta',
  'moda',
  'elbise',
  'tekstil',
];

const _home = [
  'ev ',
  'dekor',
  'mobilya',
  'mutfak',
  'beyaz esya',
  'ev alet',
];

List<Product> _byRating(List<Product> pool) {
  final copy = [...pool];
  copy.sort((a, b) {
    final rating = b.rating.compareTo(a.rating);
    if (rating != 0) return rating;
    return b.reviewCount.compareTo(a.reviewCount);
  });
  return copy;
}

bool _is(Product product, List<String> keys) {
  final blob = TextNormalizer.normalize(
    '${product.category ?? ''} ${product.subCategory ?? ''} ${product.name} ${product.brand} ${product.tags.join(' ')}',
  );
  return keys.any(blob.contains);
}

String _productKey(Product product) {
  final id = product.productId?.trim() ?? '';
  if (id.isNotEmpty) return id;
  return product.name.trim().toLowerCase();
}

String _lane(Product product) {
  final sub = TextNormalizer.normalize(product.subCategory);
  if (sub.isNotEmpty) return sub;
  final main = TextNormalizer.normalize(product.category);
  return main.isEmpty ? 'diger' : main;
}

List<Product> _take(Iterable<Product> source, Set<String> seen, {int min = 2}) {
  final picked = <Product>[];
  for (final product in source) {
    final key = _productKey(product);
    if (key.isEmpty || !seen.add(key)) continue;
    picked.add(product);
    if (picked.length == mobileHomeCollectionMax) break;
  }
  if (picked.length < min) {
    for (final product in picked) {
      seen.remove(_productKey(product));
    }
    return const [];
  }
  return picked;
}

List<Product> _takeDiverse(Iterable<Product> source, Set<String> seen) {
  final lanes = <String, List<Product>>{};
  final order = <String>[];
  for (final product in source) {
    final key = _productKey(product);
    if (key.isEmpty || seen.contains(key)) continue;
    final lane = _lane(product);
    final bucket = lanes.putIfAbsent(lane, () {
      order.add(lane);
      return <Product>[];
    });
    if (bucket.any((item) => _productKey(item) == key)) continue;
    bucket.add(product);
  }
  final picked = <Product>[];
  var moved = true;
  while (picked.length < mobileHomeCollectionMax && moved) {
    moved = false;
    for (final lane in order) {
      final bucket = lanes[lane];
      if (bucket == null || bucket.isEmpty) continue;
      final product = bucket.removeAt(0);
      final key = _productKey(product);
      if (!seen.add(key)) continue;
      picked.add(product);
      moved = true;
      if (picked.length == mobileHomeCollectionMax) break;
    }
  }
  if (picked.length < mobileHomeCollectionMin) {
    for (final product in picked) {
      seen.remove(_productKey(product));
    }
    return const [];
  }
  return picked;
}
