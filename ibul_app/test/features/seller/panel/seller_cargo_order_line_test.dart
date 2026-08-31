import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_order_line.dart';
import 'package:ibul_app/models/seller_product.dart';

void main() {
  SellerProduct product({
    required String id,
    required String name,
    String sku = '',
    double price = 100,
    double? discount,
    String? stationId,
    bool printerRoutingEnabled = true,
  }) {
    return SellerProduct(
      id: id,
      name: name,
      brand: 'Marka',
      mainCategory: 'Kategori',
      subCategory: '',
      price: price,
      discountPrice: discount,
      stock: 10,
      sku: sku,
      status: 'Aktif',
      createdAt: DateTime(2026, 1, 1),
      stationId: stationId,
      printerRoutingEnabled: printerRoutingEnabled,
    );
  }

  test('product search matches name and code', () {
    final products = [
      product(id: '1', name: 'Kırmızı Elbise', sku: 'KRM-1', price: 250),
      product(id: '2', name: 'Mavi Gömlek', sku: 'MAV-9', price: 180),
    ];
    expect(filterSellerCargoProducts(products, 'kirmizi').single.id, '1');
    expect(filterSellerCargoProducts(products, 'MAV-9').single.id, '2');
    expect(filterSellerCargoProducts(products, ''), hasLength(2));
    expect(filterSellerCargoProducts(products, 'yok'), isEmpty);
  });

  test('adding the same product increments quantity instead of a new line', () {
    final first = product(id: 'p1', name: 'Ürün A', sku: 'A-1', price: 250);
    var lines = addOrIncrementSellerCargoLine(const [], first);
    lines = addOrIncrementSellerCargoLine(lines, first);
    expect(lines, hasLength(1));
    expect(lines.single.quantity, 2);
    expect(lines.single.lineTotal, 500);
  });

  test('multiple products keep separate lines and subtotal', () {
    final a = product(id: 'p1', name: 'Ürün A', sku: 'A-1', price: 250);
    final b = product(id: 'p2', name: 'Ürün B', sku: 'B-1', price: 180);
    var lines = addOrIncrementSellerCargoLine(const [], a);
    lines = addOrIncrementSellerCargoLine(lines, a);
    lines = addOrIncrementSellerCargoLine(lines, b);
    expect(lines, hasLength(2));
    expect(sellerCargoLinesSubtotal(lines), 680);
    expect(lines.first.toServiceMap()['product_id'], 'p1');
    expect(lines.first.toServiceMap()['product_code'], 'A-1');
    expect(lines.first.toServiceMap()['quantity'], 2);
    expect(lines.first.toServiceMap()['unit_price'], 250);
    expect(lines.first.toServiceMap()['total_price'], 500);
  });

  test('unit price uses discount when present', () {
    final productWithDiscount = product(
      id: 'p3',
      name: 'İndirimli',
      sku: 'D-1',
      price: 200,
      discount: 150,
    );
    expect(sellerCargoUnitPrice(productWithDiscount), 150);
  });

  test('station_id is copied from the product when present', () {
    const stationId = '11111111-1111-1111-1111-111111111111';
    final withStation = product(
      id: 'p1',
      name: 'Ürün A',
      sku: 'A-1',
      price: 250,
      stationId: stationId,
    );
    final line = sellerCargoLineFromProduct(withStation);
    expect(line.toServiceMap()['station_id'], stationId);
    expect(
      sellerCargoLineFromProduct(
        product(id: 'p2', name: 'Ürün B', sku: 'B-1', price: 180),
      ).toServiceMap().containsKey('station_id'),
      isFalse,
    );
  });

  test('printer_routing_enabled is copied from the product', () {
    final disabled = product(
      id: 'p9',
      name: 'Sos',
      sku: 'S-1',
      printerRoutingEnabled: false,
    );
    expect(
      sellerCargoLineFromProduct(disabled).toServiceMap()['printer_routing_enabled'],
      isFalse,
    );
  });

  test('quantity update to zero removes the line', () {
    final a = product(id: 'p1', name: 'Ürün A', price: 250);
    final lines = addOrIncrementSellerCargoLine(const [], a);
    expect(updateSellerCargoLineQuantity(lines, 'p1', 0), isEmpty);
  });
}
