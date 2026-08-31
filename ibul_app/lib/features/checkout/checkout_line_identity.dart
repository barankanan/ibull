import '../../models/product_model.dart';

/// Checkout line identity without `dynamic` casts or empty catches.
class CheckoutLineIdentity {
  const CheckoutLineIdentity({
    this.productId,
    this.sellerId,
    this.storeName,
    this.category,
    this.name,
    this.brand,
    this.product,
  });

  final String? productId;
  final String? sellerId;
  final String? storeName;
  final String? category;
  final String? name;
  final String? brand;
  final Product? product;

  bool get hasProductId => (productId ?? '').trim().isNotEmpty;

  static Product? asProduct(Object? value) {
    if (value is Product) return value;
    return null;
  }

  factory CheckoutLineIdentity.fromSource(Map<String, dynamic> source) {
    final product = asProduct(source['productObject']);
    return CheckoutLineIdentity(
      productId: _firstNonEmpty([
        source['productId']?.toString(),
        product?.productId,
      ]),
      sellerId: _firstNonEmpty([
        source['sellerId']?.toString(),
        product?.sellerId,
      ]),
      storeName: _firstNonEmpty([
        source['storeName']?.toString(),
        source['store']?.toString(),
        product?.store,
      ]),
      category: _firstNonEmpty([
        source['category']?.toString(),
        product?.category,
      ]),
      name: _firstNonEmpty([source['name']?.toString(), product?.name]),
      brand: _firstNonEmpty([source['brand']?.toString(), product?.brand]),
      product: product,
    );
  }

  static bool hasMissingProductId(Iterable<Map<String, dynamic>> lines) {
    for (final line in lines) {
      if (!CheckoutLineIdentity.fromSource(line).hasProductId) return true;
    }
    return false;
  }

  static Set<String> collectProductIds(Iterable<Map<String, dynamic>> lines) {
    final ids = <String>{};
    for (final line in lines) {
      final id = CheckoutLineIdentity.fromSource(line).productId?.trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  static Set<String> collectSellerIds(Iterable<Map<String, dynamic>> lines) {
    final ids = <String>{};
    for (final line in lines) {
      final id = CheckoutLineIdentity.fromSource(line).sellerId?.trim();
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids;
  }

  static Set<String> collectStoreNames(Iterable<Map<String, dynamic>> lines) {
    final names = <String>{};
    for (final line in lines) {
      final name = CheckoutLineIdentity.fromSource(line).storeName?.trim();
      if (name != null && name.isNotEmpty) names.add(name);
    }
    return names;
  }

  /// Fills missing `productId` from cart by name+brand (+ optional store).
  static List<Map<String, dynamic>> attachIdsFromCart({
    required List<Map<String, dynamic>> lines,
    required List<Product> cart,
  }) {
    return [
      for (final source in lines) _attachIdFromCart(source, cart),
    ];
  }

  static Map<String, dynamic> _attachIdFromCart(
    Map<String, dynamic> source,
    List<Product> cart,
  ) {
    final line = Map<String, dynamic>.from(source);
    final identity = CheckoutLineIdentity.fromSource(line);
    if (identity.hasProductId) return line;

    final name = identity.name?.trim().toLowerCase();
    final brand = identity.brand?.trim().toLowerCase();
    if (name == null || name.isEmpty || brand == null || brand.isEmpty) {
      return line;
    }

    for (final cartItem in cart) {
      final cartId = cartItem.productId?.trim() ?? '';
      if (cartId.isEmpty) continue;
      if (cartItem.name.trim().toLowerCase() != name) continue;
      if (cartItem.brand.trim().toLowerCase() != brand) continue;
      final store = identity.storeName?.trim().toLowerCase();
      if (store != null &&
          store.isNotEmpty &&
          (cartItem.store ?? '').trim().toLowerCase() != store) {
        continue;
      }
      line['productId'] = cartId;
      line['sellerId'] ??= cartItem.sellerId;
      final existing = asProduct(line['productObject']);
      if (existing != null) {
        line['productObject'] = existing.copyWith(
          productId: cartId,
          sellerId: cartItem.sellerId,
          store: cartItem.store,
        );
      }
      break;
    }
    return line;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
