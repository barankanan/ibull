import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/services/cart_product_validation_cache.dart';
import 'package:ibul_app/services/cart_validation_service.dart';

void main() {
  final service = CartValidationService.instance;

  setUp(() {
    service.clearValidationCacheForTests();
    CartProductValidationCache.instance.clear();
  });

  group('CartValidationService.validateProductRowForCart', () {
    test('blocks non-public product', () {
      final error = service.validateProductRowForCart({
        'status': 'Aktif',
        'approval_status': 'pending',
        'stock': 5,
      });
      expect(error, CartValidationService.notForSaleMessage);
    });

    test('blocks pending_approval product', () {
      final error = service.validateProductRowForCart({
        'status': 'Aktif',
        'approval_status': 'pending_approval',
        'stock': 5,
      });
      expect(error, CartValidationService.notForSaleMessage);
    });

    test('blocks zero stock product', () {
      final error = service.validateProductRowForCart({
        'status': 'Aktif',
        'approval_status': 'approved',
        'stock': 0,
      });
      expect(error, CartValidationService.outOfStockMessage);
    });

    test('allows active approved in-stock product', () {
      final error = service.validateProductRowForCart({
        'status': 'Aktif',
        'approval_status': 'approved',
        'stock': 3,
      });
      expect(error, isNull);
    });

    test('allows admin_approval_status approved when approval_status null', () {
      final error = service.validateProductRowForCart({
        'status': 'Aktif',
        'approval_status': null,
        'admin_approval_status': 'approved',
        'stock': 5,
      });
      expect(error, isNull);
    });
  });

  Product trustedProduct({
    String productId = 'prod-fast',
    String approvalStatus = 'approved',
    String? adminApprovalStatus = 'approved',
    int stock = 5,
  }) {
    return Product(
      name: 'Test',
      brand: 'Brand',
      price: '99 TL',
      productId: productId,
      catalogStatus: 'Aktif',
      approvalStatus: approvalStatus,
      adminApprovalStatus: adminApprovalStatus,
      stock: stock,
      catalogDiscountPrice: 89,
      catalogUpdatedAt: DateTime.utc(2026, 1, 1),
      rating: 0,
      reviewCount: 0,
      tags: const [],
      images: const [],
    );
  }

  Product sampleProduct({
    String name = 'Test',
    String price = '10',
    String? productId,
  }) {
    return Product(
      name: name,
      brand: 'Brand',
      price: price,
      productId: productId,
      rating: 0,
      reviewCount: 0,
      tags: const [],
      images: const [],
    );
  }

  group('CartValidationService.tryFastPathValidation', () {
    test('allows trusted local approved snapshot without DB', () {
      final result = service.tryFastPathValidation(trustedProduct());
      expect(result, isNotNull);
      expect(result!.allowed, isTrue);
      expect(result.usedFastPath, isTrue);
    });

    test('blocks pending local snapshot without DB fallback', () {
      final result = service.tryFastPathValidation(
        trustedProduct(
          approvalStatus: 'pending_approval',
          adminApprovalStatus: null,
        ),
      );
      expect(result, isNotNull);
      expect(result!.allowed, isFalse);
      expect(result.message, CartValidationService.notForSaleMessage);
    });

    test('returns null when local snapshot incomplete', () {
      final result = service.tryFastPathValidation(
        sampleProduct(productId: 'prod-1', price: '99'),
      );
      expect(result, isNull);
    });
  });

  group('CartValidationService.validateForAdd fast path', () {
    test('does not call DB when trusted local snapshot is valid', () async {
      var dbCalled = false;
      service.fetchRowsOverride = (_) async {
        dbCalled = true;
        return {};
      };

      final result = await service.validateForAdd(
        trustedProduct(),
        variantSelectionComplete: true,
      );

      expect(result.allowed, isTrue);
      expect(result.usedFastPath, isTrue);
      expect(dbCalled, isFalse);
    });

    test('calls DB fallback when approval fields missing locally', () async {
      var dbCalled = false;
      service.fetchRowsOverride = (ids) async {
        dbCalled = true;
        return {
          ids.first: {
            'id': ids.first,
            'status': 'Aktif',
            'approval_status': 'approved',
            'stock': 5,
            'price': 99,
          },
        };
      };

      final result = await service.validateForAdd(
        sampleProduct(productId: 'prod-db', price: '99 TL'),
        variantSelectionComplete: true,
      );

      expect(result.allowed, isTrue);
      expect(dbCalled, isTrue);
    });

    test('blocks pending local snapshot without DB', () async {
      var dbCalled = false;
      service.fetchRowsOverride = (_) async {
        dbCalled = true;
        return {};
      };

      final result = await service.validateForAdd(
        trustedProduct(
          approvalStatus: 'pending_approval',
          adminApprovalStatus: null,
        ),
        variantSelectionComplete: true,
      );

      expect(result.allowed, isFalse);
      expect(result.message, CartValidationService.notForSaleMessage);
      expect(dbCalled, isFalse);
    });
  });

  group('CartValidationService validation cache', () {
    test('reuses cached DB row within TTL', () async {
      var fetchCount = 0;
      service.fetchRowsOverride = (ids) async {
        fetchCount++;
        return {
          ids.first: {
            'id': ids.first,
            'status': 'Aktif',
            'approval_status': 'approved',
            'stock': 5,
            'price': 99,
          },
        };
      };

      final product = sampleProduct(productId: 'prod-cache', price: '99 TL');
      final first = await service.validateForAdd(
        product,
        variantSelectionComplete: true,
      );
      final second = await service.validateForAdd(
        product,
        variantSelectionComplete: true,
      );

      expect(first.allowed, isTrue);
      expect(second.allowed, isTrue);
      expect(fetchCount, 1);
    });
  });

  group('CartValidationService.validateVariantSelection', () {
    test('requires variant when incomplete', () {
      final error = service.validateVariantSelection(
        product: sampleProduct(),
        variantSelectionComplete: false,
      );
      expect(error, CartValidationService.variantRequiredMessage);
    });
  });

  group('CartValidationService.validateFetchedRow', () {
    test('approved DB row passes cart row validation', () {
      final row = {
        'id': 'prod-1',
        'status': 'Aktif',
        'approval_status': 'approved',
        'admin_approval_status': 'approved',
        'stock': 5,
        'price': 99,
      };
      expect(service.validateProductRowForCart(row), isNull);
    });

    test('blocks pending DB row', () {
      final product = sampleProduct(productId: 'prod-2');
      final result = service.validateFetchedRow(product, {
        'id': 'prod-2',
        'status': 'Aktif',
        'approval_status': 'pending_approval',
        'stock': 5,
      });
      expect(result.allowed, isFalse);
      expect(result.message, CartValidationService.notForSaleMessage);
    });

    test('blocks approved product with zero stock', () {
      final product = sampleProduct(productId: 'prod-3');
      final result = service.validateFetchedRow(product, {
        'id': 'prod-3',
        'status': 'Aktif',
        'approval_status': 'approved',
        'stock': 0,
      });
      expect(result.allowed, isFalse);
      expect(result.message, CartValidationService.outOfStockMessage);
    });
  });

  group('CartValidationService.validateForAdd', () {
    test('blocks product without productId', () async {
      final product = sampleProduct(name: 'Legacy', price: '99');
      final result = await service.validateForAdd(
        product,
        variantSelectionComplete: true,
      );
      expect(result.allowed, isFalse);
      expect(result.message, CartValidationService.missingProductIdMessage);
    });
  });

  group('CartValidationService.revalidate', () {
    test('returns empty result for empty cart', () async {
      final result = await service.revalidate(const []);
      expect(result.updatedProducts, isEmpty);
      expect(result.removedProducts, isEmpty);
      expect(result.hasBlockingIssues, isFalse);
    });

    test('fast-path cart item still goes through DB revalidation', () async {
      service.fetchRowsOverride = (_) async => const {};

      final result = await service.revalidate([trustedProduct()]);
      expect(result.removedProducts, hasLength(1));
      expect(result.hasBlockingIssues, isTrue);
    });

    test('keeps legacy products without productId', () async {
      final product = sampleProduct(name: 'Legacy', price: '50');
      final result = await service.revalidate([product]);
      expect(result.updatedProducts, hasLength(1));
      expect(result.removedProducts, isEmpty);
    });
  });
}
