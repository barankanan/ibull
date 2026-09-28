import '../domain/store_vertical.dart';

/// Vertical-specific labels for the shared public storefront shell.
/// Chrome (header, tabs, search, grids) stays the same; only copy changes.
class StorefrontCopy {
  const StorefrontCopy({
    required this.catalogTab,
    required this.featuredSection,
    required this.popularSection,
    required this.searchHint,
    required this.emptyCatalog,
    required this.emptyFiltered,
    required this.catalogCountLabel,
    required this.saleSection,
    required this.rentalSection,
    required this.emptyIcon,
  });

  final String catalogTab;
  final String featuredSection;
  final String popularSection;
  final String searchHint;
  final String emptyCatalog;
  final String emptyFiltered;
  final String catalogCountLabel;
  final String saleSection;
  final String rentalSection;
  final String emptyIcon;

  static const ecommerce = StorefrontCopy(
    catalogTab: 'Tüm Ürünler',
    featuredSection: 'Öne Çıkan Ürünler',
    popularSection: 'Popüler Ürünler',
    searchHint: 'Mağazada ara',
    emptyCatalog: 'Bu mağazada henüz ürün bulunmuyor',
    emptyFiltered: 'Bu kategoride ürün bulunamadı',
    catalogCountLabel: 'Ürün',
    saleSection: 'Satılık',
    rentalSection: 'Kiralık',
    emptyIcon: 'bag',
  );

  static const gallery = StorefrontCopy(
    catalogTab: 'Tüm Araçlar',
    featuredSection: 'Öne Çıkan Araçlar',
    popularSection: 'Öne Çıkan Araçlar',
    searchHint: 'Galeride ara',
    emptyCatalog: 'Bu mağazada henüz araç bulunmuyor',
    emptyFiltered: 'Aramanıza uygun araç bulunamadı',
    catalogCountLabel: 'Araç',
    saleSection: 'Satılık',
    rentalSection: 'Kiralık',
    emptyIcon: 'car',
  );

  static const realEstate = StorefrontCopy(
    catalogTab: 'Tüm İlanlar',
    featuredSection: 'Öne Çıkan İlanlar',
    popularSection: 'Öne Çıkan İlanlar',
    searchHint: 'Mağazada ara',
    emptyCatalog: 'Bu mağazada henüz ilan bulunmuyor',
    emptyFiltered: 'Aramanıza uygun ilan bulunamadı',
    catalogCountLabel: 'İlan',
    saleSection: 'Satılık',
    rentalSection: 'Kiralık',
    emptyIcon: 'home',
  );

  static StorefrontCopy of(StoreVertical vertical) {
    switch (vertical) {
      case StoreVertical.gallery:
        return gallery;
      case StoreVertical.realEstate:
        return realEstate;
      case StoreVertical.restaurant:
      case StoreVertical.ecommerce:
      case StoreVertical.unknown:
        return ecommerce;
    }
  }
}
