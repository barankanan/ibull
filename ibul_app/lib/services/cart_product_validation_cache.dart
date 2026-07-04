/// Kısa süreli sepete-ekle doğrulama satırı cache'i.
/// Checkout/revalidation bu cache'i kullanmaz.
class CartProductValidationCache {
  CartProductValidationCache._();
  static final CartProductValidationCache instance =
      CartProductValidationCache._();

  static const Duration defaultTtl = Duration(seconds: 60);

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  Duration ttl = defaultTtl;

  Map<String, dynamic>? get(String productId) {
    final key = productId.trim();
    if (key.isEmpty) return null;
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return Map<String, dynamic>.from(entry.row);
  }

  void put(String productId, Map<String, dynamic> row) {
    final key = productId.trim();
    if (key.isEmpty) return;
    _entries[key] = _CacheEntry(
      row: Map<String, dynamic>.from(row),
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void clear() => _entries.clear();
}

class _CacheEntry {
  const _CacheEntry({required this.row, required this.expiresAt});

  final Map<String, dynamic> row;
  final DateTime expiresAt;
}
