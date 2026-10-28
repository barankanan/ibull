import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/favorites/favorite_browse_card.dart';
import 'package:ibul_app/widgets/product_discount_price.dart';

Product _product({
  required String name,
  required String price,
  String? oldPrice,
}) {
  return Product(
    name: name,
    brand: 'Marka',
    price: price,
    oldPrice: oldPrice,
    rating: 4,
    reviewCount: 12,
    tags: const ['Elektronik'],
    images: const [],
    category: 'Elektronik',
  );
}

void main() {
  const widths = [360.0, 375.0, 390.0, 412.0, 430.0];

  test('grid extent is image plus the measured discount info block', () {
    const scaler = TextScaler.noScaling;
    for (final width in widths) {
      final tile = (width - 24 - 10) / 2;
      final image = FavoriteBrowseCardLayout.imageHeightFor(tile);
      final info = FavoriteBrowseCardLayout.infoBlockHeight(scaler);
      final extent = FavoriteBrowseCardLayout.extent(
        tileWidth: tile,
        textScaler: scaler,
      );
      expect(image, lessThan(tile), reason: 'image should be shorter than square');
      expect(image / tile, closeTo(1 / 1.25, 0.001));
      expect(extent, greaterThanOrEqualTo(image + info));
      expect(
        info,
        FavoriteBrowseCardLayout.chipHeight(scaler) +
            FavoriteBrowseCardLayout.chipGap +
            FavoriteBrowseCardLayout.titleHeight(scaler) +
            FavoriteBrowseCardLayout.titleGap +
            FavoriteBrowseCardLayout.ratingHeight(scaler) +
            FavoriteBrowseCardLayout.ratingGap +
            FavoriteBrowseCardLayout.priceSlotHeight(scaler) +
            FavoriteBrowseCardLayout.contentPadding.vertical,
      );
    }
  });

  testWidgets('price block matches its measured height', (tester) async {
    const scaler = TextScaler.noScaling;
    Future<double> pump({String? oldPrice}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 160,
              child: ProductDiscountPrice(
                price: '1399 TL',
                oldPrice: oldPrice,
                currentFontSize: FavoriteBrowseCardLayout.currentFontSize,
                oldFontSize: FavoriteBrowseCardLayout.oldFontSize,
                compact: true,
              ),
            ),
          ),
        ),
      );
      return tester.getSize(find.byType(ProductDiscountPrice)).height;
    }

    final plain = await pump();
    final discount = await pump(oldPrice: '1499 TL');
    expect(
      plain,
      lessThanOrEqualTo(
        ProductDiscountPrice.blockHeight(
          hasDiscount: false,
          textScaler: scaler,
          currentFontSize: FavoriteBrowseCardLayout.currentFontSize,
          oldFontSize: FavoriteBrowseCardLayout.oldFontSize,
          compact: true,
        ),
      ),
    );
    expect(
      discount,
      lessThanOrEqualTo(
        ProductDiscountPrice.blockHeight(
          hasDiscount: true,
          textScaler: scaler,
          currentFontSize: FavoriteBrowseCardLayout.currentFontSize,
          oldFontSize: FavoriteBrowseCardLayout.oldFontSize,
          compact: true,
        ),
      ),
    );
    expect(discount, greaterThan(plain));
  });

  testWidgets('browse cards do not overflow at mobile widths', (tester) async {
    final products = [
      _product(
        name: 'SanDisk Extreme Pro 128 GB SDXC UHS-I Memory Card',
        price: '1399 TL',
      ),
      _product(
        name: 'SanDisk Extreme Pro 128 GB SDXC UHS-I Memory Card',
        price: '1399 TL',
        oldPrice: '1499 TL',
      ),
      _product(name: 'iPhone', price: '23999 TL', oldPrice: '25999 TL'),
      _product(name: 'iPhone', price: '23999 TL'),
    ];
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('overflowed')) overflows.add(message);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    for (final width in [360.0, 390.0, 430.0]) {
      final tile = (width - 24 - 10) / 2;
      final extent = FavoriteBrowseCardLayout.extent(
        tileWidth: tile,
        textScaler: TextScaler.noScaling,
      );
      for (final product in products) {
        overflows.clear();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: tile,
                  height: extent,
                  child: FavoriteBrowseProductCard(
                    product: product,
                    isFavorite: false,
                    onTap: () {},
                    onQuickView: () {},
                    onToggleFavorite: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          overflows,
          isEmpty,
          reason: '${product.name} / discount=${product.oldPrice} / $width',
        );
      }
    }
  });
}
