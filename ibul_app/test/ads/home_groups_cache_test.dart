import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/simple_memory_ttl_cache.dart';

void main() {
  group('SimpleMemoryTtlCache (home ads groups cache davranışı)', () {
    test('write/read roundtrip works within TTL', () {
      final cache = SimpleMemoryTtlCache<List<String>>();
      cache.write('groups', ['ad-1']);
      expect(cache.read('groups'), ['ad-1']);
    });

    test('expired entries are dropped — empty result cannot stick forever',
        () async {
      final cache = SimpleMemoryTtlCache<List<String>>(
        defaultTtl: const Duration(milliseconds: 1),
      );
      cache.write('groups', const []);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(cache.read('groups'), isNull);
    });

    test('invalidate clears the key immediately (create sonrası refresh)', () {
      final cache = SimpleMemoryTtlCache<List<String>>();
      cache.write('groups', ['ad-1']);
      cache.invalidate('groups');
      expect(cache.read('groups'), isNull);
    });
  });
}
