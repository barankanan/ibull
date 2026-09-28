import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:ibul_app/screens/home/home_product_rail_groups.dart';

DBProduct _product({
  required String id,
  required String name,
  String category = 'Elektronik',
  String? subCategory,
  String price = '1000',
  String? oldPrice,
  String tags = '[]',
}) {
  return DBProduct(
    id: id,
    name: name,
    brand: 'Marka',
    price: price,
    oldPrice: oldPrice,
    rating: 4,
    reviewCount: 1,
    imageUrl: 'https://example.com/$id.jpg',
    category: category,
    subCategory: subCategory,
    tags: tags,
    isActive: true,
  );
}

void main() {
  test('home rails split deals, electronics, home and phones', () {
    final groups = HomeProductRailGroups.build([
      _product(
        id: 'deal',
        name: 'İndirimli Laptop',
        oldPrice: '2000',
        price: '1499',
      ),
      _product(id: 'tv', name: 'Samsung 55 inç CU7000'),
      _product(id: 'phone', name: 'Apple iPhone 15', subCategory: 'Telefonlar'),
      _product(
        id: 'sofa',
        name: 'Koltuk Takımı',
        category: 'Ev & Yaşam',
        subCategory: 'Mobilya',
      ),
      _product(id: 'food', name: 'Meze Tabağı', category: 'Yemek'),
    ]);

    final byId = {for (final g in groups) g.id: g};
    expect(
      byId.keys,
      containsAll(['deals', 'electronics', 'home', 'phones', 'other']),
    );
    expect(byId['deals']!.title, 'Fırsat Ürünleri');
    expect(byId['electronics']!.products.map((p) => p.id), contains('tv'));
    expect(
      byId['electronics']!.products.map((p) => p.id),
      isNot(contains('phone')),
    );
    expect(byId['phones']!.products.single.id, 'phone');
    expect(byId['home']!.products.single.id, 'sofa');
    expect(byId['other']!.products.single.id, 'food');
    expect(byId['deals']!.products.map((p) => p.id), contains('deal'));
  });

  test('empty pool yields no rails', () {
    expect(HomeProductRailGroups.build(const []), isEmpty);
  });
}
