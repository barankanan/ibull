import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/checkout/checkout_line_identity.dart';
import 'package:ibul_app/models/product_model.dart';

Product _product({
  String? id,
  String name = 'Kulaklık',
  String brand = 'iBul',
  String? store,
  String? sellerId,
}) {
  return Product(
    name: name,
    brand: brand,
    price: '10',
    productId: id,
    store: store,
    sellerId: sellerId,
    rating: 0,
    reviewCount: 0,
    tags: const <String>[],
    images: const <String>[],
  );
}

void main() {
  test('reads productId from Product without dynamic cast', () {
    final identity = CheckoutLineIdentity.fromSource({
      'name': 'Kulaklık',
      'productObject': _product(id: 'p-1', sellerId: 's-1', store: 'Mağaza'),
    });

    expect(identity.productId, 'p-1');
    expect(identity.sellerId, 's-1');
    expect(identity.storeName, 'Mağaza');
    expect(identity.hasProductId, isTrue);
  });

  test('unknown productObject does not throw or invent an id', () {
    final identity = CheckoutLineIdentity.fromSource({
      'name': 'Kulaklık',
      'productObject': Object(),
    });

    expect(identity.product, isNull);
    expect(identity.hasProductId, isFalse);
  });

  test('missing productId is fail-closed', () {
    expect(
      CheckoutLineIdentity.hasMissingProductId([
        {'name': 'Kulaklık', 'brand': 'iBul'},
      ]),
      isTrue,
    );
    expect(
      CheckoutLineIdentity.hasMissingProductId([
        {'productId': 'p-1'},
      ]),
      isFalse,
    );
  });

  test('cart match fills productId by name and brand', () {
    final lines = CheckoutLineIdentity.attachIdsFromCart(
      lines: [
        {'name': 'Kulaklık', 'brand': 'iBul'},
      ],
      cart: [_product(id: 'cart-9', sellerId: 'seller-a', store: 'Mağaza')],
    );

    expect(lines.single['productId'], 'cart-9');
    expect(lines.single['sellerId'], 'seller-a');
    expect(
      CheckoutLineIdentity.hasMissingProductId(lines),
      isFalse,
    );
  });

  test('store mismatch does not steal another product id', () {
    final lines = CheckoutLineIdentity.attachIdsFromCart(
      lines: [
        {
          'name': 'Kulaklık',
          'brand': 'iBul',
          'storeName': 'Başka Mağaza',
        },
      ],
      cart: [_product(id: 'cart-9', store: 'Mağaza')],
    );

    expect(lines.single['productId'], isNull);
    expect(CheckoutLineIdentity.hasMissingProductId(lines), isTrue);
  });

  test('checkout money path no longer uses dynamic empty catch', () {
    final checkout = File('lib/screens/checkout_page.dart').readAsStringSync();
    expect(checkout, isNot(contains('as dynamic')));
    expect(checkout, isNot(contains('catch (_)')));
    expect(checkout, contains('CheckoutLineIdentity'));

    final orders = File('lib/services/order_service.dart').readAsStringSync();
    expect(orders, contains('CheckoutLineIdentity'));
    expect(orders, isNot(contains('as dynamic')));
  });
}
