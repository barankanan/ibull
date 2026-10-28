import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/compare_features_page.dart';
import 'package:ibul_app/screens/compare_images_page.dart';
import 'package:ibul_app/screens/compare_products_page.dart';
import 'package:ibul_app/screens/compare_reviews_page.dart';
import 'package:provider/provider.dart';

Product _product({
  required String id,
  required String name,
  required String category,
  String brand = 'Marka',
  String price = '100 TL',
  List<String> images = const [],
}) {
  return Product(
    productId: id,
    name: name,
    brand: brand,
    price: price,
    rating: 0,
    reviewCount: 0,
    tags: const [],
    images: images,
    category: category,
  );
}

Map<String, dynamic> _map(Product product) => {
  'name': product.name,
  'product': product,
  'selected': true,
};

void main() {
  testWidgets('özellik karşılaştırması 360 390 430 taşmaz', (tester) async {
    final products = [
      _map(_product(id: 'a', name: 'Telefon', category: 'Elektronik', brand: 'Apple', price: '1000 TL')),
      _map(_product(id: 'b', name: 'Laptop', category: 'Elektronik', brand: 'Apple', price: '2000 TL')),
    ];
    for (final width in [360.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await tester.pumpWidget(
        MaterialApp(
          home: CompareFeaturesPage(products: products),
        ),
      );
      await tester.pump();
      expect(find.text('Telefon'), findsWidgets);
      expect(find.text('Laptop'), findsWidgets);
      expect(find.text('Apple'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('görsel karşılaştırması gerçek görselleri ve doğru başlığı kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final a = _product(
      id: 'a',
      name: 'Telefon',
      category: 'Elektronik',
      images: const [
        'https://cdn.example/a1.jpg',
        'https://cdn.example/a2.jpg',
        'https://cdn.example/a3.jpg',
      ],
    );
    final b = _product(
      id: 'b',
      name: 'Laptop',
      category: 'Elektronik',
      images: const ['https://cdn.example/b1.jpg'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CompareImagesPage(products: [_map(a), _map(b)]),
      ),
    );
    await tester.pump();
    expect(find.text('Ürün Görselleri'), findsOneWidget);
    expect(find.text('Ürün Yorumları'), findsNothing);
    expect(find.byKey(const ValueKey('compare-image-a-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-image-a-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-image-a-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-image-b-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('compare-image-b-1')), findsNothing);
    expect(find.textContaining('Kurulumu basit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yorum karşılaştırması yalnız verilen gerçek yorumları gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final a = _product(id: 'a', name: 'Telefon', category: 'Elektronik');
    final b = _product(id: 'b', name: 'Laptop', category: 'Elektronik');
    await tester.pumpWidget(
      MaterialApp(
        home: CompareReviewsPage(
          products: [_map(a), _map(b)],
          loadReviews: (product) async {
            if (product.productId == 'a') {
              return const [
                {'userName': 'Ayşe', 'rating': 5, 'comment': 'Gerçek yorum bir'},
                {'userName': 'Ali', 'rating': 4, 'comment': 'Gerçek yorum iki'},
              ];
            }
            return const [];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Ürün Yorumları'), findsOneWidget);
    expect(find.text('Gerçek yorum bir'), findsOneWidget);
    expect(find.text('Gerçek yorum iki'), findsOneWidget);
    expect(find.text('Bu ürün için henüz yorum yok.'), findsOneWidget);
    expect(find.textContaining('Kurulumu basit'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobilde üçüncü ürün seçimi engellenir', (tester) async {
    FavoriteState().clear();
    addTearDown(FavoriteState().clear);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final name in ['Bir', 'Iki', 'Uc', 'Dort']) {
      FavoriteState().toggleFavorite(
        _product(id: name, name: name, category: 'Elektronik'),
      );
    }
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(390, 844)),
            child: CompareProductsPage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Bir'));
    await tester.pump();
    await tester.tap(find.text('Iki'));
    await tester.pump();
    await tester.tap(find.text('Uc'));
    await tester.pump();
    expect(
      find.text('Mobilde en fazla 2 ürün karşılaştırabilirsiniz.'),
      findsOneWidget,
    );
  });

  testWidgets('aynı isimli ürünler productId ile karışmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Product phone(String id, String store) => Product(
      productId: id,
      name: 'iPhone 17',
      brand: 'Apple',
      store: store,
      price: '100 TL',
      rating: 0,
      reviewCount: 0,
      tags: const [],
      images: const [],
      category: 'Elektronik',
    );
    const mixed = [
      {
        'productId': 'A',
        'productName': 'iPhone 17',
        'storeName': 'Teknosa',
        'userName': 'Ayşe',
        'rating': 5,
        'comment': 'Yalnız A yorumu',
      },
    ];
    Future<List<Map<String, dynamic>>> loader(Product product) async => mixed;

    await tester.pumpWidget(
      MaterialApp(
        home: CompareReviewsPage(
          products: [
            {
              'name': 'iPhone 17',
              'product': phone('A', 'Teknosa'),
              'selected': true,
            },
            {
              'name': 'iPhone 17',
              'product': phone('B', 'Başka'),
              'selected': true,
            },
          ],
          loadReviews: loader,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Yalnız A yorumu'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CompareReviewsPage(
          products: [
            {
              'name': 'iPhone 17',
              'product': phone('C', 'Teknosa'),
              'selected': true,
            },
            {
              'name': 'iPhone 17',
              'product': phone('B', 'Başka'),
              'selected': true,
            },
          ],
          loadReviews: loader,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Yalnız A yorumu'), findsNothing);
    expect(find.text('Bu ürün için henüz yorum yok.'), findsWidgets);
  });

  testWidgets('web 1100 üzerinde en fazla 4 ürün çizilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final products = [
      for (var i = 1; i <= 5; i++)
        _map(_product(id: 'p$i', name: 'Ürün $i', category: 'Elektronik')),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 900)),
          child: CompareFeaturesPage(products: products),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Ürün 1'), findsWidgets);
    expect(find.text('Ürün 4'), findsWidgets);
    expect(find.text('Ürün 5'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('görseli olmayan ürün standart placeholder kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bare = _product(id: 'bare', name: 'Boş', category: 'Elektronik');
    await tester.pumpWidget(
      MaterialApp(home: CompareImagesPage(products: [_map(bare)])),
    );
    await tester.pump();
    expect(find.text('Ürün Görselleri'), findsOneWidget);
    expect(find.byIcon(Icons.image), findsWidgets);
    expect(find.byKey(const ValueKey('compare-image-bare-0')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
