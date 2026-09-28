import '../../core/home_quick_action.dart';
import '../../models/db_product.dart';
import '../../utils/category_product_filter.dart';
import '../../utils/text_normalizer.dart';

class HomeProductRailGroup {
  const HomeProductRailGroup({
    required this.id,
    required this.title,
    required this.products,
  });

  final String id;
  final String title;
  final List<DBProduct> products;
}

/// Splits the home product pool into horizontal category rails.
abstract final class HomeProductRailGroups {
  static const electronicsId = 'electronics';
  static const dealsId = 'deals';
  static const homeId = 'home';
  static const phonesId = 'phones';
  static const otherId = 'other';

  static List<HomeProductRailGroup> build(
    List<DBProduct> products, {
    int maxPerRail = 12,
  }) {
    if (products.isEmpty) return const [];

    final deals = <DBProduct>[];
    final phones = <DBProduct>[];
    final electronics = <DBProduct>[];
    final home = <DBProduct>[];
    final other = <DBProduct>[];

    for (final product in products) {
      final phone = isPhone(product);
      final electronic = isElectronics(product);
      final living = isHomeLiving(product);

      if (HomeQuickActionFilter.isDealProduct(product)) {
        deals.add(product);
      }
      if (phone) {
        phones.add(product);
      } else if (electronic) {
        electronics.add(product);
      } else if (living) {
        home.add(product);
      } else {
        other.add(product);
      }
    }

    return [
      _maybe(dealsId, 'Fırsat Ürünleri', deals, maxPerRail),
      _maybe(electronicsId, 'Elektronik', electronics, maxPerRail),
      _maybe(homeId, 'Ev Ürünleri', home, maxPerRail),
      _maybe(phonesId, 'Telefonlar', phones, maxPerRail),
      _maybe(otherId, 'Popüler Ürünler', other, maxPerRail),
    ].whereType<HomeProductRailGroup>().toList(growable: false);
  }

  static HomeProductRailGroup? _maybe(
    String id,
    String title,
    List<DBProduct> items,
    int maxPerRail,
  ) {
    if (items.isEmpty) return null;
    return HomeProductRailGroup(
      id: id,
      title: title,
      products: items.take(maxPerRail).toList(growable: false),
    );
  }

  static bool isPhone(DBProduct product) {
    if (CategoryProductFilter.productMatchesSelection(
      mainCategory: 'Elektronik',
      subCategory: 'Telefonlar',
      productMainCategory: product.category,
      productSubCategory: product.subCategory,
      productName: product.name,
    )) {
      return true;
    }

    final sub = TextNormalizer.normalize(product.subCategory);
    if (sub.contains('telefon') && !sub.contains('aksesuar')) return true;

    final name = TextNormalizer.normalize(product.name);
    if (name.contains('iphone') || name.contains('telefon')) return true;
    if (!name.contains('galaxy')) return false;
    return !name.contains('tab') &&
        !name.contains('watch') &&
        !name.contains('tv') &&
        !name.contains('buds');
  }

  static bool isElectronics(DBProduct product) {
    if (isPhone(product)) return true;
    final haystack = TextNormalizer.normalize(
      '${product.category} ${product.subCategory ?? ''} ${product.name}',
    );
    return haystack.contains('elektronik') ||
        haystack.contains('teknoloji') ||
        haystack.contains('laptop') ||
        haystack.contains('tablet') ||
        haystack.contains('televizyon') ||
        haystack.contains('ipad') ||
        haystack.contains('macbook');
  }

  static bool isHomeLiving(DBProduct product) {
    final haystack = TextNormalizer.normalize(
      '${product.category} ${product.subCategory ?? ''}',
    );
    return haystack.contains('ev & yasam') ||
        haystack.contains('ev yasam') ||
        haystack.contains('mobilya') ||
        haystack.contains('mutfak') ||
        haystack.contains('dekorasyon') ||
        haystack.contains('bahce') ||
        haystack.contains('yapi market');
  }
}
