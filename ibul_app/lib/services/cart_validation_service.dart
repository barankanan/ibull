import '../models/product_model.dart';
import '../utils/product_visibility_helper.dart';
import 'cart_product_validation_cache.dart';
import 'supabase_service.dart';

class CartAddValidation {
  const CartAddValidation._({
    required this.allowed,
    this.message,
    this.product,
    this.usedFastPath = false,
  });

  final bool allowed;
  final String? message;
  final Product? product;
  final bool usedFastPath;

  factory CartAddValidation.allowed(
    Product product, {
    bool usedFastPath = false,
  }) =>
      CartAddValidation._(
        allowed: true,
        product: product,
        usedFastPath: usedFastPath,
      );

  factory CartAddValidation.blocked(String message) =>
      CartAddValidation._(allowed: false, message: message);
}

class CartRevalidationResult {
  const CartRevalidationResult({
    required this.updatedProducts,
    required this.removedProducts,
    required this.priceChanged,
    required this.hasBlockingIssues,
    this.summaryMessage,
  });

  final List<Product> updatedProducts;
  final List<Product> removedProducts;
  final bool priceChanged;
  final bool hasBlockingIssues;
  final String? summaryMessage;

  bool get isEmpty => updatedProducts.isEmpty;
}

class CartValidationService {
  CartValidationService._();
  static final CartValidationService instance = CartValidationService._();

  static const String notForSaleMessage = 'Bu ürün şu anda satışta değil.';
  static const String outOfStockMessage = 'Bu ürün şu anda stokta yok.';
  static const String variantRequiredMessage = 'Lütfen bir varyant seçin.';
  static const String missingProductIdMessage =
      'Ürün bilgisi eksik. Lütfen sayfayı yenileyin.';

  /// Test hook — DB fetch atlanıp atlanmadığını doğrulamak için.
  Future<Map<String, Map<String, dynamic>>> Function(List<String> ids)?
      fetchRowsOverride;

  final CartProductValidationCache _cache = CartProductValidationCache.instance;

  String? validateVariantSelection({
    required Product product,
    required bool variantSelectionComplete,
  }) {
    if (!variantSelectionComplete) {
      return variantRequiredMessage;
    }
    return null;
  }

  String? validateProductRowForCart(Map<String, dynamic> row) {
    if (!ProductVisibilityHelper.isPublicVisibleProductMap(row)) {
      return notForSaleMessage;
    }
    if (!ProductVisibilityHelper.isCustomerCartEligibleMap(row)) {
      return outOfStockMessage;
    }
    return null;
  }

  bool hasTrustedLocalSnapshot(Product product) {
    final id = product.productId?.trim() ?? '';
    if (id.isEmpty) return false;
    if ((product.catalogStatus ?? '').trim().isEmpty) return false;

    final hasApproval =
        (product.approvalStatus ?? '').trim().isNotEmpty ||
        (product.adminApprovalStatus ?? '').trim().isNotEmpty;
    if (!hasApproval) return false;

    if (product.stock == null) return false;
    if (product.toCartValidationMap()['price'] == null) return false;
    if (product.catalogUpdatedAt == null) return false;

    return true;
  }

  /// Yerel snapshot yeterliyse anında karar verir; aksi halde null (DB/cache fallback).
  CartAddValidation? tryFastPathValidation(Product product) {
    final map = product.toCartValidationMap();
    final partialError = validateProductRowForCart(map);
    if (partialError != null &&
        _hasAnyCatalogSnapshotField(product) &&
        !hasTrustedLocalSnapshot(product)) {
      return CartAddValidation.blocked(partialError);
    }

    if (!hasTrustedLocalSnapshot(product)) {
      return null;
    }

    final rowError = validateProductRowForCart(map);
    if (rowError != null) {
      return CartAddValidation.blocked(rowError);
    }

    return CartAddValidation.allowed(product, usedFastPath: true);
  }

  bool _hasAnyCatalogSnapshotField(Product product) {
    return (product.catalogStatus ?? '').trim().isNotEmpty ||
        (product.approvalStatus ?? '').trim().isNotEmpty ||
        (product.adminApprovalStatus ?? '').trim().isNotEmpty ||
        product.stock != null;
  }

  Product applyRowToProduct(Product product, Map<String, dynamic> row) {
    final refreshed = Product.fromDBProduct(row);
    return product.copyWith(
      productId: refreshed.productId ?? product.productId,
      sellerId: refreshed.sellerId ?? product.sellerId,
      store: refreshed.store ?? product.store,
      category: refreshed.category ?? product.category,
      subCategory: refreshed.subCategory ?? product.subCategory,
      price: refreshed.price,
      oldPrice: refreshed.oldPrice ?? product.oldPrice,
      images: refreshed.images.isNotEmpty ? refreshed.images : product.images,
      variantOptions: refreshed.variantOptions ?? product.variantOptions,
      catalogStatus: refreshed.catalogStatus ?? product.catalogStatus,
      approvalStatus: refreshed.approvalStatus ?? product.approvalStatus,
      adminApprovalStatus:
          refreshed.adminApprovalStatus ?? product.adminApprovalStatus,
      stock: refreshed.stock ?? product.stock,
      catalogDiscountPrice:
          refreshed.catalogDiscountPrice ?? product.catalogDiscountPrice,
      catalogUpdatedAt: refreshed.catalogUpdatedAt ?? product.catalogUpdatedAt,
    );
  }

  CartAddValidation validateFetchedRow(
    Product product,
    Map<String, dynamic>? row,
  ) {
    if (row == null) {
      return CartAddValidation.blocked(notForSaleMessage);
    }

    final rowError = validateProductRowForCart(row);
    if (rowError != null) {
      return CartAddValidation.blocked(rowError);
    }

    return CartAddValidation.allowed(applyRowToProduct(product, row));
  }

  Future<Map<String, Map<String, dynamic>>> _fetchValidationRows(
    List<String> ids,
  ) async {
    final override = fetchRowsOverride;
    if (override != null) {
      return override(ids);
    }
    return SupabaseService.instance.getProductRowsForCartValidation(ids);
  }

  Future<CartAddValidation> validateForAdd(
    Product product, {
    required bool variantSelectionComplete,
  }) async {
    final variantError = validateVariantSelection(
      product: product,
      variantSelectionComplete: variantSelectionComplete,
    );
    if (variantError != null) {
      return CartAddValidation.blocked(variantError);
    }

    final productId = product.productId?.trim() ?? '';
    if (productId.isEmpty) {
      return CartAddValidation.blocked(missingProductIdMessage);
    }

    final fastPath = tryFastPathValidation(product);
    if (fastPath != null) {
      return fastPath;
    }

    final cachedRow = _cache.get(productId);
    if (cachedRow != null) {
      return validateFetchedRow(product, cachedRow);
    }

    final rows = await _fetchValidationRows([productId]);
    final row = rows[productId];
    if (row != null) {
      _cache.put(productId, row);
    }
    return validateFetchedRow(product, row);
  }

  Future<CartRevalidationResult> revalidate(List<Product> products) async {
    if (products.isEmpty) {
      return const CartRevalidationResult(
        updatedProducts: [],
        removedProducts: [],
        priceChanged: false,
        hasBlockingIssues: false,
      );
    }

    final ids = products
        .map((product) => product.productId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final rows = ids.isEmpty
        ? const <String, Map<String, dynamic>>{}
        : await _fetchValidationRows(ids);

    final updated = <Product>[];
    final removed = <Product>[];
    var priceChanged = false;
    final messages = <String>[];

    for (final product in products) {
      final productId = product.productId?.trim() ?? '';
      if (productId.isEmpty) {
        updated.add(product);
        continue;
      }

      final row = rows[productId];
      if (row == null) {
        removed.add(product);
        continue;
      }

      final rowError = validateProductRowForCart(row);
      if (rowError != null) {
        removed.add(product);
        continue;
      }

      final refreshed = applyRowToProduct(product, row);
      if (refreshed.price.trim() != product.price.trim()) {
        priceChanged = true;
      }
      updated.add(refreshed);
    }

    if (removed.isNotEmpty) {
      messages.add('Sepetindeki bazı ürünler artık satışta değil.');
    }
    if (priceChanged) {
      messages.add('Bazı ürünlerin fiyatı güncellendi.');
    }

    return CartRevalidationResult(
      updatedProducts: updated,
      removedProducts: removed,
      priceChanged: priceChanged,
      hasBlockingIssues: updated.isEmpty && products.isNotEmpty,
      summaryMessage: messages.isEmpty ? null : messages.join(' '),
    );
  }

  void clearValidationCacheForTests() {
    _cache.clear();
    fetchRowsOverride = null;
  }
}
