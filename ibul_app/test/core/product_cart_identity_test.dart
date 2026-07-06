import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/product_cart_identity.dart';
import 'package:ibul_app/models/product_model.dart';

const _canonicalUuid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

Product _product({String? productId}) {
  return Product(
    productId: productId,
    name: 'Apple iPad 10. Nesil',
    brand: 'Apple',
    price: '14999',
    rating: 0,
    reviewCount: 0,
    tags: const [],
    images: const [],
  );
}

void main() {
  group('ProductCartIdentity', () {
    test('resolve returns canonical UUID from productId', () {
      expect(ProductCartIdentity.resolve(_product(productId: _canonicalUuid)),
          _canonicalUuid);
    });

    test('resolve rejects preview and ad tokens', () {
      expect(
        ProductCartIdentity.resolve(_product(productId: 'preview-card-1')),
        isNull,
      );
      expect(
        ProductCartIdentity.resolve(_product(productId: 'ad-slot-12345678')),
        isNull,
      );
    });

    test('resolve rejects empty id', () {
      expect(ProductCartIdentity.resolve(_product()), isNull);
      expect(ProductCartIdentity.resolve(_product(productId: '   ')), isNull);
    });

    test('withCanonicalId normalizes product snapshot', () {
      final normalized = ProductCartIdentity.withCanonicalId(
        _product(productId: _canonicalUuid),
      );
      expect(normalized.productId, _canonicalUuid);
    });

    test('resolveFromMap reads id and product_id', () {
      expect(
        ProductCartIdentity.resolveFromMap({'id': _canonicalUuid}),
        _canonicalUuid,
      );
      expect(
        ProductCartIdentity.resolveFromMap({'product_id': _canonicalUuid}),
        _canonicalUuid,
      );
    });
  });
}
