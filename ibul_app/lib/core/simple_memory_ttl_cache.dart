/// Basit bellek içi TTL önbelleği.
class SimpleMemoryTtlCache<T> {
  SimpleMemoryTtlCache({this.defaultTtl = const Duration(minutes: 3)});

  final Duration defaultTtl;
  final Map<String, _TtlEntry<T>> _entries = {};

  T? read(String key, {Duration? ttl}) {
    final entry = _entries[key.trim()];
    if (entry == null) return null;
    final maxAge = ttl ?? defaultTtl;
    if (DateTime.now().difference(entry.cachedAt) > maxAge) {
      _entries.remove(key.trim());
      return null;
    }
    return entry.value;
  }

  void write(String key, T value) {
    final normalized = key.trim();
    if (normalized.isEmpty) return;
    _entries[normalized] = _TtlEntry(value: value, cachedAt: DateTime.now());
  }

  void invalidate(String key) => _entries.remove(key.trim());

  void clear() => _entries.clear();
}

class _TtlEntry<T> {
  const _TtlEntry({required this.value, required this.cachedAt});

  final T value;
  final DateTime cachedAt;
}
