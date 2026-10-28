import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/widgets/product_discount_price.dart';
import 'package:ibul_app/widgets/restaurant_order/food_product_card.dart';

void main() {
  Product food({
    required String price,
    String? oldPrice,
    String name = 'Izgara Köfte',
  }) {
    return Product(
      productId: name,
      name: name,
      brand: 'Mutfak',
      price: price,
      oldPrice: oldPrice,
      rating: 4.4,
      reviewCount: 12,
      tags: const [],
      images: const [],
      store: 'Lezzet Evi',
      category: 'Yemek',
    );
  }

  test('indirimsiz üründe eski fiyat ve etiket yok', () {
    final view = ProductDiscountView.resolve(price: '240 TL');
    expect(view.hasDiscount, isFalse);
    expect(view.currentLabel, '240 TL');
    expect(view.oldLabel, isNull);
  });

  test('indirimli üründe eski fiyat daha yüksekse etiket açılır', () {
    final view = ProductDiscountView.resolve(
      price: '180 TL',
      oldPrice: '240 TL',
    );
    expect(view.hasDiscount, isTrue);
    expect(view.currentLabel, '180 TL');
    expect(view.oldLabel, '240 TL');
  });

  test('eski fiyat güncelden büyük değilse indirim sayılmaz', () {
    final view = ProductDiscountView.resolve(
      price: '240 TL',
      oldPrice: '200 TL',
    );
    expect(view.hasDiscount, isFalse);
    expect(view.oldLabel, isNull);
  });

  test('sıfır güncel fiyat indirim göstermez', () {
    final view = ProductDiscountView.resolve(price: '0', oldPrice: '40 TL');
    expect(view.hasDiscount, isFalse);
  });

  testWidgets('indirimsiz yemek kartı yalnız güncel fiyatı gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodProductCard(
            product: food(price: '240 TL'),
            quantity: 0,
            onImageTap: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.text('₺240'), findsOneWidget);
    expect(find.text('İndirim'), findsNothing);
    expect(find.text('Lezzet Evi · Yemek · 4.4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('indirimli yemek kartı eski fiyat ve indirim etiketini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FoodProductCard(
            product: food(
              name: 'Çok Uzun Izgara Köfte Porsiyon Ürün Adı Satırı',
              price: '180 TL',
              oldPrice: '240 TL',
            ),
            quantity: 0,
            onImageTap: () {},
            onAdd: () {},
          ),
        ),
      ),
    );

    expect(find.text('240 TL'), findsOneWidget);
    expect(find.text('₺180'), findsOneWidget);
    expect(find.text('İndirim'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
