import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_order_builder.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_order_line.dart';
import 'package:ibul_app/features/seller/panel/cargo/seller_cargo_product_picker.dart';
import 'package:ibul_app/models/seller_product.dart';

void main() {
  String money(double value) => '₺${value.toStringAsFixed(0)}';

  testWidgets('product lines add and increment quantity', (tester) async {
    var lines = <SellerCargoOrderLine>[
      const SellerCargoOrderLine(
        productId: 'p1',
        productName: 'Ürün A',
        productCode: 'A-1',
        quantity: 2,
        unitPrice: 250,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SellerCargoProductLinesSection(
                lines: lines,
                currencyFormat: money,
                onAdd: () {},
                onQuantityChanged: (id, qty) {
                  setState(() {
                    lines = updateSellerCargoLineQuantity(lines, id, qty);
                  });
                },
                onRemove: (_) {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Ürün Ekle'), findsOneWidget);
    expect(find.text('Ürün A'), findsOneWidget);
    expect(find.textContaining('2 x ₺250'), findsOneWidget);
    expect(find.text('₺500'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('order summary shows customer address products and totals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellerCargoOrderSummary(
            customerName: 'Ayşe Yılmaz',
            customerPhone: '05551234567',
            addressText: 'Moda Cad. 12, Kadıköy, İstanbul',
            shippingAmount: 0,
            currencyFormat: money,
            lines: const [
              SellerCargoOrderLine(
                productId: 'p1',
                productName: 'Ürün A',
                quantity: 2,
                unitPrice: 250,
              ),
              SellerCargoOrderLine(
                productId: 'p2',
                productName: 'Ürün B',
                quantity: 1,
                unitPrice: 180,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Sipariş Özeti'), findsOneWidget);
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('05551234567'), findsOneWidget);
    expect(find.textContaining('Moda Cad. 12'), findsOneWidget);
    expect(find.text('- Ürün A x 2'), findsOneWidget);
    expect(find.text('- Ürün B x 1'), findsOneWidget);
    expect(find.text('₺680'), findsWidgets);
    expect(find.text('₺0'), findsOneWidget);
  });

  testWidgets('product picker searches by name and returns selection', (
    tester,
  ) async {
    SellerProduct? picked;
    final products = [
      SellerProduct(
        id: 'p1',
        name: 'Kırmızı Elbise',
        brand: '',
        mainCategory: '',
        subCategory: '',
        price: 250,
        stock: 3,
        sku: 'KRM-1',
        status: 'Aktif',
        createdAt: DateTime(2026),
      ),
      SellerProduct(
        id: 'p2',
        name: 'Mavi Gömlek',
        brand: '',
        mainCategory: '',
        subCategory: '',
        price: 180,
        stock: 3,
        sku: 'MAV-9',
        status: 'Aktif',
        createdAt: DateTime(2026),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  picked = await showSellerCargoProductPicker(
                    context: context,
                    products: products,
                  );
                },
                child: const Text('Aç'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Ürün Seç'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('seller_cargo_product_search')),
      'mav-9',
    );
    await tester.pump();
    expect(find.text('Mavi Gömlek'), findsOneWidget);
    expect(find.text('Kırmızı Elbise'), findsNothing);
    await tester.tap(find.byKey(const Key('seller_cargo_product_p2')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'p2');
  });
}
