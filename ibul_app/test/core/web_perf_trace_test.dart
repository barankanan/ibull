import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/web_perf_trace.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:ibul_app/models/home_product_preview.dart';
import 'package:ibul_app/models/product_model.dart';

void main() {
  tearDown(WebPerfTrace.resetForTests);

  group('WebPerfTrace', () {
    test('marks stages in order without throwing', () {
      WebPerfTrace.resetForTests();
      WebPerfTrace.markOrigin();
      final trace = WebPerfTrace.instance;
      expect(() => trace.mark(WebPerfTraceStage.flutterBootStarted), returnsNormally);
      expect(() => trace.mark(WebPerfTraceStage.firstFrame), returnsNormally);
      expect(() => trace.mark(WebPerfTraceStage.homeShellVisible), returnsNormally);
      expect(trace.snapshot.elapsedMs, greaterThanOrEqualTo(0));
    });

    test('records product counts and first card render once', () {
      WebPerfTrace.resetForTests();
      final trace = WebPerfTrace.instance;
      trace.setProductCounts(raw: 12, filtered: 10, render: 8);
      trace.markFirstProductCardRendered();
      trace.markFirstProductCardRendered();
      expect(trace.snapshot.productRawCount, 12);
      expect(trace.snapshot.firstProductRenderMs, isNotNull);
    });

    test('snapshot serializes required keys', () {
      WebPerfTrace.resetForTests();
      WebPerfTrace.instance.mark(WebPerfTraceStage.productFetchStarted);
      final json = WebPerfTrace.instance.snapshot.toJson();
      expect(json['stage'], WebPerfTraceStage.productFetchStarted);
      expect(json.containsKey('elapsedMs'), isTrue);
      expect(json.containsKey('total_boot_elapsed_ms'), isTrue);
    });
  });

  group('HomeProductPreview', () {
    test('fromDbProduct parses price and store', () {
      final preview = HomeProductPreview.fromDbProduct(
        DBProduct(
          id: 'p1',
          name: 'Test Ürün',
          brand: 'Marka',
          store: 'Mağaza A',
          price: '199.90',
          oldPrice: '149.90',
          imageUrl: 'https://example.com/img.jpg',
          category: 'Elektronik',
          rating: 4.5,
          reviewCount: 2,
          tags: '[]',
        ),
      );
      expect(preview.name, 'Test Ürün');
      expect(preview.storeName, 'Mağaza A');
      expect(preview.displayPrice, closeTo(149.90, 0.01));
      expect(preview.price, closeTo(199.90, 0.01));
      expect(preview.hasDiscount, isTrue);
    });

    test('fromDbProduct resolves the seller sale column for catalog products', () {
      final ipad = HomeProductPreview.fromDbProduct(
        DBProduct(
          id: 'ipad',
          name: 'Apple iPad',
          brand: 'Apple',
          store: 'Mağaza',
          price: '18999',
          oldPrice: '17999',
          imageUrl: 'https://example.com/img.jpg',
          category: 'Elektronik',
          rating: 0,
          reviewCount: 0,
          tags: '[]',
        ),
      );
      expect(ipad.displayPrice, closeTo(17999, 0.01));
      expect(ipad.price, closeTo(18999, 0.01));
      expect(ipad.hasDiscount, isTrue);

      final plain = HomeProductPreview.fromDbProduct(
        DBProduct(
          id: 'sandisk',
          name: 'SanDisk',
          brand: 'SanDisk',
          store: 'Mağaza',
          price: '1499',
          imageUrl: 'https://example.com/img.jpg',
          category: 'Elektronik',
          rating: 0,
          reviewCount: 0,
          tags: '[]',
        ),
      );
      expect(plain.displayPrice, closeTo(1499, 0.01));
      expect(plain.hasDiscount, isFalse);
    });

    test('customer product uses the seller current price for cart and detail', () {
      final product = Product.fromDBProduct({
        'id': 'ipad',
        'name': 'Apple iPad',
        'price': 18999,
        'discount_price': 17999,
      });
      expect(product.price, '17999 TL');
      expect(product.oldPrice, '18999 TL');

      final unchanged = Product.fromDBProduct({
        'id': 'sandisk',
        'name': 'SanDisk',
        'price': 1499,
      });
      expect(unchanged.price, '1499 TL');
      expect(unchanged.oldPrice, isNull);
    });
  });
}
