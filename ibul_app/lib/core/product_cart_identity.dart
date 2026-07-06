import '../models/product_model.dart';

/// Sepete ekleme ve cart validation için tek canonical `products.id` çözümü.
abstract final class ProductCartIdentity {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// [Product] üzerinden sepete ekleme için kullanılacak gerçek `products.id`.
  ///
  /// Boş, preview/ad/demo token veya geçersiz id döndürmez.
  static String? resolve(Product product) {
    return resolveFromCandidates(
      product.productId,
      product.toCartValidationMap()['id']?.toString(),
    );
  }

  /// Ham Supabase satırı / map üzerinden canonical id.
  static String? resolveFromMap(Map<String, dynamic> map) {
    return resolveFromCandidates(
      map['id']?.toString(),
      map['product_id']?.toString(),
      map['productId']?.toString(),
    );
  }

  /// [product] kopyasını canonical id ile normalize eder.
  static Product withCanonicalId(Product product) {
    final canonicalId = resolve(product);
    if (canonicalId == null) return product;
    if (product.productId?.trim() == canonicalId) return product;
    return product.copyWith(productId: canonicalId);
  }

  static String? resolveFromCandidates(
    String? primary,
    String? secondary, [
    String? tertiary,
  ]) {
    for (final raw in [primary, secondary, tertiary]) {
      final id = raw?.trim() ?? '';
      if (id.isEmpty) continue;
      if (_isBlockedCartId(id)) continue;
      if (_looksLikeProductRowId(id)) return id;
    }
    return null;
  }

  static bool _isBlockedCartId(String id) {
    final lower = id.toLowerCase();
    const blockedPrefixes = [
      'preview-',
      'ad-',
      'demo-',
      'fake-',
      'temp-',
      'placeholder-',
    ];
    for (final prefix in blockedPrefixes) {
      if (lower.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Supabase `products.id` genelde UUID; kısa/sentetik token'ları reddeder.
  static bool _looksLikeProductRowId(String id) {
    if (id.length < 8) return false;
    if (_uuidPattern.hasMatch(id)) return true;
    // UUID dışı ama gerçek satır id'si olabilecek alfanumerik değerler.
    return RegExp(r'^[0-9a-zA-Z_-]{8,}$').hasMatch(id);
  }
}
