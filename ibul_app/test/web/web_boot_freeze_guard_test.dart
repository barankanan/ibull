import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/auth_listener_guard.dart';
import 'package:ibul_app/core/auth/ibul_auth_context.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/core/home_snapshot_cache.dart';
import 'package:ibul_app/core/web_boot_step_profiler.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:shared_preferences/shared_preferences.dart';

DBProduct _sampleProduct({
  required String id,
  required String name,
}) {
  return DBProduct(
    id: id,
    name: name,
    brand: 'Brand',
    price: '10',
    rating: 4.5,
    reviewCount: 1,
    imageUrl: 'https://example.com/a.jpg',
    category: 'Elektronik',
    tags: '[]',
    isActive: true,
    approvalStatus: 'approved',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web boot freeze guards', () {
    test('AuthListenerGuard ignores duplicate user/context events', () {
      final guard = AuthListenerGuard();
      expect(
        guard.enter(userId: 'u1', context: IbulAuthContext.customer),
        isTrue,
      );
      guard.leave(
        userId: 'u1',
        context: IbulAuthContext.customer,
        stateChanged: true,
      );

      expect(
        guard.enter(userId: 'u1', context: IbulAuthContext.customer),
        isFalse,
      );
      expect(guard.isHandling, isFalse);
    });

    test('AuthListenerGuard blocks re-entrant handling', () {
      final guard = AuthListenerGuard();
      expect(
        guard.enter(userId: 'u2', context: IbulAuthContext.seller),
        isTrue,
      );
      expect(guard.isHandling, isTrue);
      expect(
        guard.enter(userId: 'u3', context: IbulAuthContext.customer),
        isFalse,
      );
      guard.leave(
        userId: 'u2',
        context: IbulAuthContext.seller,
        stateChanged: true,
      );
      expect(guard.isHandling, isFalse);
    });

    test('HomeSnapshot.fromJson returns null on corrupt products field', () {
      final snapshot = HomeSnapshot.fromJson({'products': 'not-a-list'});
      expect(snapshot, isNull);
    });

    test('oversized persisted snapshot is cleared and does not throw', () async {
      SharedPreferences.setMockInitialValues({
        homeSnapshotPrefsKey: 'x' * (homeSnapshotMaxRawBytes + 1),
      });

      final read = await HomeSnapshotCache.instance.readPersisted();
      expect(read, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(homeSnapshotPrefsKey), isNull);
    });

    test('corrupt persisted snapshot JSON is cleared', () async {
      SharedPreferences.setMockInitialValues({
        homeSnapshotPrefsKey: '{not valid json',
      });

      final read = await HomeSnapshotCache.instance.readPersisted();
      expect(read, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(homeSnapshotPrefsKey), isNull);
    });

    test('oversized snapshot products are clamped to safe limit', () {
      final products = List.generate(
        40,
        (index) => _sampleProduct(id: 'p$index', name: 'Product $index'),
      );
      final json = HomeSnapshot(products: products).toJson();
      final decoded = HomeSnapshot.fromJson(Map<String, dynamic>.from(json));

      expect(decoded, isNotNull);
      expect(decoded!.products.length, lessThanOrEqualTo(homeSnapshotProductsLimit));
    });

    test('safe boot mode defaults to false in tests', () {
      expect(AppRuntimeConfig.safeBootMode, isFalse);
    });

    test('WebBootStepProfiler step logging does not throw', () {
      expect(() {
        WebBootStepProfiler.start('test_step');
        WebBootStepProfiler.done('test_step');
        WebBootStepProfiler.slow('test_step', 600);
        WebBootStepProfiler.error('test_step', 'boom');
      }, returnsNormally);
    });

    test('popular products persisted corrupt JSON is cleared', () async {
      SharedPreferences.setMockInitialValues({
        homePopularProductsPrefsKey: '[]]broken',
      });

      final read =
          await HomeSnapshotCache.instance.readPopularProductsPersisted();
      expect(read, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(homePopularProductsPrefsKey), isNull);
    });

    test('legacy products cache limit constant is enforced in encode size', () {
      final products = List.generate(
        30,
        (index) => _sampleProduct(id: 'lp$index', name: 'Legacy $index'),
      );
      final encoded = jsonEncode(
        products
            .take(homeLegacyProductsCacheLimit)
            .map((product) => product.toMap())
            .toList(),
      );
      final decoded = (jsonDecode(encoded) as List).length;
      expect(decoded, homeLegacyProductsCacheLimit);
    });
  });
}
