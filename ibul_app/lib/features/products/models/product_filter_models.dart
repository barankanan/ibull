enum ProductSortOption {
  recommended,
  priceAsc,
  priceDesc,
  newest,
  mostReviewed,
  highestRating,
  highestDiscount,
  nameAsc,
  nameDesc,
}

extension ProductSortOptionX on ProductSortOption {
  String get label {
    switch (this) {
      case ProductSortOption.recommended:
        return 'Önerilen sıralama';
      case ProductSortOption.priceAsc:
        return 'En düşük fiyat';
      case ProductSortOption.priceDesc:
        return 'En yüksek fiyat';
      case ProductSortOption.newest:
        return 'En yeni ürünler';
      case ProductSortOption.mostReviewed:
        return 'En çok değerlendirilenler';
      case ProductSortOption.highestRating:
        return 'En yüksek puan';
      case ProductSortOption.highestDiscount:
        return 'En çok indirimli';
      case ProductSortOption.nameAsc:
        return 'A-Z';
      case ProductSortOption.nameDesc:
        return 'Z-A';
    }
  }

  static const List<ProductSortOption> selectable = [
    ProductSortOption.recommended,
    ProductSortOption.priceAsc,
    ProductSortOption.priceDesc,
    ProductSortOption.newest,
    ProductSortOption.mostReviewed,
    ProductSortOption.highestRating,
    ProductSortOption.highestDiscount,
    ProductSortOption.nameAsc,
    ProductSortOption.nameDesc,
  ];
}

enum ProductFilterGroupType {
  priceRange,
  brand,
  category,
  subcategory,
  seller,
  rating,
  discount,
  stock,
  dynamicAttribute,
  toggle,
}

class ProductFilterOption {
  const ProductFilterOption({
    required this.id,
    required this.label,
    this.value,
  });

  final String id;
  final String label;
  final String? value;
}

class ProductFilterGroup {
  const ProductFilterGroup({
    required this.id,
    required this.title,
    required this.type,
    this.options = const [],
    this.minPrice,
    this.maxPrice,
    this.quickPriceChips = const [],
  });

  final String id;
  final String title;
  final ProductFilterGroupType type;
  final List<ProductFilterOption> options;
  final double? minPrice;
  final double? maxPrice;
  final List<({double min, double? max, String label})> quickPriceChips;

  bool get isEmpty {
    switch (type) {
      case ProductFilterGroupType.priceRange:
        return minPrice == null && maxPrice == null;
      case ProductFilterGroupType.discount:
      case ProductFilterGroupType.stock:
        return false;
      default:
        return options.isEmpty;
    }
  }
}

class ProductFilterState {
  const ProductFilterState({
    this.selectedBrands = const {},
    this.selectedCategories = const {},
    this.selectedSubcategories = const {},
    this.priceMin,
    this.priceMax,
    this.selectedRatings = const {},
    this.onlyDiscounted = false,
    this.onlyInStock = false,
    this.selectedDynamicAttributes = const {},
    this.selectedSellerIds = const {},
    this.sortOption = ProductSortOption.recommended,
  });

  final Set<String> selectedBrands;
  final Set<String> selectedCategories;
  final Set<String> selectedSubcategories;
  final double? priceMin;
  final double? priceMax;
  final Set<int> selectedRatings;
  final bool onlyDiscounted;
  final bool onlyInStock;
  final Map<String, Set<String>> selectedDynamicAttributes;
  final Set<String> selectedSellerIds;
  final ProductSortOption sortOption;

  bool get hasActiveFilters =>
      selectedBrands.isNotEmpty ||
      selectedCategories.isNotEmpty ||
      selectedSubcategories.isNotEmpty ||
      priceMin != null ||
      priceMax != null ||
      selectedRatings.isNotEmpty ||
      onlyDiscounted ||
      onlyInStock ||
      selectedDynamicAttributes.isNotEmpty ||
      selectedSellerIds.isNotEmpty;

  int get activeFilterCount {
    var count = 0;
    count += selectedBrands.length;
    count += selectedCategories.length;
    count += selectedSubcategories.length;
    if (priceMin != null || priceMax != null) count++;
    count += selectedRatings.length;
    if (onlyDiscounted) count++;
    if (onlyInStock) count++;
    count += selectedSellerIds.length;
    for (final values in selectedDynamicAttributes.values) {
      count += values.length;
    }
    return count;
  }

  ProductFilterState copyWith({
    Set<String>? selectedBrands,
    Set<String>? selectedCategories,
    Set<String>? selectedSubcategories,
    double? priceMin,
    double? priceMax,
    bool clearPriceMin = false,
    bool clearPriceMax = false,
    Set<int>? selectedRatings,
    bool? onlyDiscounted,
    bool? onlyInStock,
    Map<String, Set<String>>? selectedDynamicAttributes,
    Set<String>? selectedSellerIds,
    ProductSortOption? sortOption,
  }) {
    return ProductFilterState(
      selectedBrands: selectedBrands ?? this.selectedBrands,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      selectedSubcategories:
          selectedSubcategories ?? this.selectedSubcategories,
      priceMin: clearPriceMin ? null : (priceMin ?? this.priceMin),
      priceMax: clearPriceMax ? null : (priceMax ?? this.priceMax),
      selectedRatings: selectedRatings ?? this.selectedRatings,
      onlyDiscounted: onlyDiscounted ?? this.onlyDiscounted,
      onlyInStock: onlyInStock ?? this.onlyInStock,
      selectedDynamicAttributes:
          selectedDynamicAttributes ?? this.selectedDynamicAttributes,
      selectedSellerIds: selectedSellerIds ?? this.selectedSellerIds,
      sortOption: sortOption ?? this.sortOption,
    );
  }

  static ProductFilterState cleared({ProductSortOption? sortOption}) {
    return ProductFilterState(sortOption: sortOption ?? ProductSortOption.recommended);
  }
}

class ProductFilterMeta {
  const ProductFilterMeta({this.stock, this.createdAt});

  final int? stock;
  final DateTime? createdAt;
}
