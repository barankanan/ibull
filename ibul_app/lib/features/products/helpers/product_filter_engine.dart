import '../../../models/category_attribute_filter_group.dart';
import '../../../models/product_model.dart';
import '../../../models/product_pricing.dart';
import '../../../services/category_attribute_service.dart';
import '../models/product_filter_models.dart';
import 'product_filter_attribute_extractor.dart';
import 'category_filter_config.dart';

class ProductFilterEngine {
  const ProductFilterEngine._();

  static List<ProductFilterGroup> buildFilterGroups({
    required List<Product> products,
    required String mainCategory,
    required String subCategory,
    List<CategoryAttributeFilterGroup> dbAttributeGroups = const [],
  }) {
    if (products.isEmpty) return const [];

    final groups = <ProductFilterGroup>[];

    final prices = products
        .map(_productPrice)
        .where((value) => value > 0)
        .toList();
    if (prices.isNotEmpty) {
      final min = prices.reduce((a, b) => a < b ? a : b);
      final max = prices.reduce((a, b) => a > b ? a : b);
      groups.add(
        ProductFilterGroup(
          id: 'price',
          title: 'Fiyat Aralığı',
          type: ProductFilterGroupType.priceRange,
          minPrice: min.floorToDouble(),
          maxPrice: max.ceilToDouble(),
          quickPriceChips: const [
            (min: 0, max: 500, label: '0-500'),
            (min: 500, max: 1000, label: '500-1000'),
            (min: 1000, max: 5000, label: '1000-5000'),
            (min: 5000, max: null, label: '5000+'),
          ],
        ),
      );
    }

    final brands = _uniqueSorted(
      products.map((product) => product.brand.trim()).where((v) => v.isNotEmpty),
    );
    if (brands.isNotEmpty) {
      groups.add(
        ProductFilterGroup(
          id: 'brand',
          title: CategoryFilterConfig.brandGroupTitle(mainCategory),
          type: ProductFilterGroupType.brand,
          options: brands
              .map((brand) => ProductFilterOption(id: brand, label: brand, value: brand))
              .toList(),
        ),
      );
    }

    final categories = _uniqueSorted(
      products
          .map((product) => (product.category ?? '').trim())
          .where((value) => value.isNotEmpty),
    );
    if (categories.length > 1) {
      groups.add(
        ProductFilterGroup(
          id: 'category',
          title: 'Kategori',
          type: ProductFilterGroupType.category,
          options: categories
              .map(
                (value) =>
                    ProductFilterOption(id: value, label: value, value: value),
              )
              .toList(),
        ),
      );
    }

    final subcategories = _uniqueSorted(
      products
          .map((product) => (product.subCategory ?? '').trim())
          .where((value) => value.isNotEmpty),
    );
    if (subcategories.length > 1) {
      groups.add(
        ProductFilterGroup(
          id: 'subcategory',
          title: CategoryFilterConfig.subCategoryGroupTitle(mainCategory),
          type: ProductFilterGroupType.subcategory,
          options: subcategories
              .map(
                (value) =>
                    ProductFilterOption(id: value, label: value, value: value),
              )
              .toList(),
        ),
      );
    }

    final sellers = <String, String>{};
    for (final product in products) {
      final store = (product.store ?? '').trim();
      final sellerId = (product.sellerId ?? '').trim();
      if (store.isEmpty) continue;
      sellers[store] = sellerId.isNotEmpty ? sellerId : store;
    }
    if (sellers.isNotEmpty) {
      groups.add(
        ProductFilterGroup(
          id: 'seller',
          title: CategoryFilterConfig.sellerGroupTitle(mainCategory),
          type: ProductFilterGroupType.seller,
          options: sellers.entries
              .map(
                (entry) => ProductFilterOption(
                  id: entry.value,
                  label: entry.key,
                  value: entry.value,
                ),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label)),
        ),
      );
    }

    groups.add(
      const ProductFilterGroup(
        id: 'rating',
        title: 'Puan',
        type: ProductFilterGroupType.rating,
        options: [
          ProductFilterOption(id: '4', label: '4 yıldız ve üzeri', value: '4'),
          ProductFilterOption(id: '3', label: '3 yıldız ve üzeri', value: '3'),
        ],
      ),
    );

    groups.add(
      const ProductFilterGroup(
        id: 'discount',
        title: 'İndirim',
        type: ProductFilterGroupType.discount,
        options: [
          ProductFilterOption(
            id: 'discounted',
            label: 'İndirimli ürünler',
            value: 'true',
          ),
        ],
      ),
    );

    groups.add(
      const ProductFilterGroup(
        id: 'stock',
        title: 'Stok',
        type: ProductFilterGroupType.stock,
        options: [
          ProductFilterOption(
            id: 'in_stock',
            label: 'Stokta olanlar',
            value: 'true',
          ),
        ],
      ),
    );

    final dbNames = dbAttributeGroups.map((group) => group.attributeName).toList();
    final dynamicAttributes =
        ProductFilterAttributeExtractor.extractDynamicAttributes(
      products: products,
      mainCategory: mainCategory,
      subCategory: subCategory,
      dbAttributeNames: dbNames,
    );

    for (final dbGroup in dbAttributeGroups) {
      final extracted = dynamicAttributes.remove(dbGroup.attributeName);
      final values = <String>{
        ...dbGroup.values,
        ...?extracted,
      };
      if (values.isEmpty) continue;
      groups.add(_dynamicGroup(dbGroup.attributeName, values.toList()..sort()));
    }

    for (final entry in dynamicAttributes.entries) {
      groups.add(
        _dynamicGroup(entry.key, entry.value.toList()..sort()),
      );
    }

    return groups.where((group) => !group.isEmpty).toList(growable: false);
  }

  static ProductFilterGroup _dynamicGroup(String title, List<String> values) {
    return ProductFilterGroup(
      id: 'attr::$title',
      title: title,
      type: ProductFilterGroupType.dynamicAttribute,
      options: values
          .map(
            (value) => ProductFilterOption(
              id: '$title::$value',
              label: value,
              value: value,
            ),
          )
          .toList(),
    );
  }

  static List<Product> applyFilters({
    required List<Product> products,
    required ProductFilterState state,
    Map<String, ProductFilterMeta>? metaByProductId,
    String? searchQuery,
  }) {
    final query = (searchQuery ?? '').trim().toLowerCase();
    return products.where((product) {
      if (query.isNotEmpty) {
        final matchesSearch = product.name.toLowerCase().contains(query) ||
            product.brand.toLowerCase().contains(query);
        if (!matchesSearch) return false;
      }

      if (state.selectedBrands.isNotEmpty &&
          !state.selectedBrands.contains(product.brand.trim())) {
        return false;
      }

      if (state.selectedCategories.isNotEmpty &&
          !state.selectedCategories.contains((product.category ?? '').trim())) {
        return false;
      }

      if (state.selectedSubcategories.isNotEmpty &&
          !state.selectedSubcategories
              .contains((product.subCategory ?? '').trim())) {
        return false;
      }

      final price = _productPrice(product);
      if (state.priceMin != null && price < state.priceMin!) return false;
      if (state.priceMax != null && price > state.priceMax!) return false;

      if (state.selectedRatings.isNotEmpty) {
        final minRequired = state.selectedRatings.reduce(
          (current, next) => current > next ? current : next,
        );
        if (product.rating < minRequired) return false;
      }

      if (state.onlyDiscounted && !_isDiscounted(product)) return false;

      if (state.onlyInStock) {
        final stock = _productStock(product, metaByProductId);
        if (stock != null && stock <= 0) return false;
      }

      if (state.selectedSellerIds.isNotEmpty) {
        final sellerId = (product.sellerId ?? '').trim();
        final store = (product.store ?? '').trim();
        final matchesSeller = state.selectedSellerIds.contains(sellerId) ||
            state.selectedSellerIds.contains(store);
        if (!matchesSeller) return false;
      }

      if (state.selectedDynamicAttributes.isNotEmpty) {
        final attributeMap =
            ProductFilterAttributeExtractor.attributeMapForProduct(product);
        for (final entry in state.selectedDynamicAttributes.entries) {
          if (entry.value.isEmpty) continue;
          final current = (attributeMap[entry.key] ?? '').trim();
          if (!entry.value.contains(current)) {
            return false;
          }
        }
      }

      return true;
    }).toList(growable: false);
  }

  static List<Product> applySort({
    required List<Product> products,
    required ProductSortOption sortOption,
    Map<String, ProductFilterMeta>? metaByProductId,
  }) {
    if (sortOption == ProductSortOption.recommended || products.length < 2) {
      return List<Product>.from(products);
    }

    final sorted = List<Product>.from(products);
    int compare<T extends Comparable<T>>(T a, T b) => a.compareTo(b);

    sorted.sort((a, b) {
      switch (sortOption) {
        case ProductSortOption.priceAsc:
          return compare(_productPrice(a), _productPrice(b));
        case ProductSortOption.priceDesc:
          return compare(_productPrice(b), _productPrice(a));
        case ProductSortOption.newest:
          return compare(
            _productCreatedAt(b, metaByProductId),
            _productCreatedAt(a, metaByProductId),
          );
        case ProductSortOption.mostReviewed:
          return compare(b.reviewCount, a.reviewCount);
        case ProductSortOption.highestRating:
          return compare(b.rating, a.rating);
        case ProductSortOption.highestDiscount:
          return compare(_discountPercent(b), _discountPercent(a));
        case ProductSortOption.nameAsc:
          return compare(a.name.toLowerCase(), b.name.toLowerCase());
        case ProductSortOption.nameDesc:
          return compare(b.name.toLowerCase(), a.name.toLowerCase());
        case ProductSortOption.recommended:
          return 0;
      }
    });
    return sorted;
  }

  static List<Product> resolveProducts({
    required List<Product> products,
    required ProductFilterState state,
    Map<String, ProductFilterMeta>? metaByProductId,
    String? searchQuery,
  }) {
    final filtered = applyFilters(
      products: products,
      state: state,
      metaByProductId: metaByProductId,
      searchQuery: searchQuery,
    );
    return applySort(
      products: filtered,
      sortOption: state.sortOption,
      metaByProductId: metaByProductId,
    );
  }

  static Future<List<CategoryAttributeFilterGroup>> loadDbAttributeGroups({
    required String mainCategory,
    required String subCategory,
    required List<Product> products,
  }) {
    return CategoryAttributeService.instance.buildFilterGroupsForProducts(
      mainCategory: mainCategory,
      subCategory: subCategory,
      products: products,
    );
  }

  static List<String> _uniqueSorted(Iterable<String> values) {
    return values.toSet().toList()..sort((a, b) => a.compareTo(b));
  }

  static double _productPrice(Product product) {
    return ProductPriceCalculator.parsePriceValue(product.price);
  }

  static bool _isDiscounted(Product product) {
    final current = _productPrice(product);
    final old = ProductPriceCalculator.parsePriceValue(product.oldPrice ?? '');
    if (old > current && current > 0) return true;
    return product.tags.any(
      (tag) => tag.toLowerCase().contains('indirim'),
    );
  }

  static double _discountPercent(Product product) {
    final current = _productPrice(product);
    final old = ProductPriceCalculator.parsePriceValue(product.oldPrice ?? '');
    if (old <= current || old <= 0 || current <= 0) return 0;
    return ((old - current) / old) * 100;
  }

  static int? _productStock(
    Product product,
    Map<String, ProductFilterMeta>? metaByProductId,
  ) {
    final productId = product.productId?.trim();
    if (productId != null &&
        productId.isNotEmpty &&
        metaByProductId != null &&
        metaByProductId.containsKey(productId)) {
      return metaByProductId[productId]!.stock;
    }
    return null;
  }

  static DateTime _productCreatedAt(
    Product product,
    Map<String, ProductFilterMeta>? metaByProductId,
  ) {
    final productId = product.productId?.trim();
    if (productId != null &&
        productId.isNotEmpty &&
        metaByProductId != null) {
      final createdAt = metaByProductId[productId]?.createdAt;
      if (createdAt != null) return createdAt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
