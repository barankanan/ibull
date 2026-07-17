import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/models/product_quick_view_content.dart';
import 'package:ibul_app/widgets/ecommerce_product_quick_info_sheet.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

Product buildProduct({
  String name = 'Test Ürünü',
  String brand = 'Test Marka',
  String price = '₺199,90',
  String? oldPrice,
  double rating = 0,
  int reviewCount = 0,
  String? description,
  String? shortDescription,
  String? specifications,
  String? store,
  String? category,
  int? stock,
  List<String>? features,
  List<String>? attributes,
  List<String> images = const [],
}) {
  return Product(
    name: name,
    brand: brand,
    price: price,
    oldPrice: oldPrice,
    rating: rating,
    reviewCount: reviewCount,
    tags: const [],
    images: images,
    store: store,
    category: category,
    description: description,
    shortDescription: shortDescription,
    specifications: specifications,
    features: features,
    attributes: attributes,
    stock: stock,
  );
}

Future<void> pumpSheet(
  WidgetTester tester,
  Product product, {
  VoidCallback? onAddToCart,
  VoidCallback? onViewDetails,
  Future<Product?> Function()? enrich,
  Duration? enrichTimeout,
}) async {
  // İçerik lazy ListView; alt bölümlerin finder'da görünmesi için uzun viewport.
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EcommerceProductQuickInfoSheet(
          product: product,
          onAddToCart: onAddToCart,
          onViewDetails: onViewDetails,
          enrich: enrich,
          enrichTimeout:
              enrichTimeout ?? const Duration(milliseconds: 1000),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ProductQuickViewContent.parseSpecificationsField', () {
    test('JSON map parse edilir', () {
      final specs = ProductQuickViewContent.parseSpecificationsField(
        '{"RAM": "8GB", "Ekran": "6.7 inç", "boş": ""}',
      );
      expect(specs.map((s) => s.toString()), [
        'RAM: 8GB',
        'Ekran: 6.7 inç',
      ]);
    });

    test('JSON array parse edilir', () {
      final specs = ProductQuickViewContent.parseSpecificationsField(
        '["Renk: Mavi", "Hafıza: 64 GB", "geçersiz satır"]',
      );
      expect(specs.map((s) => s.toString()), [
        'Renk: Mavi',
        'Hafıza: 64 GB',
      ]);
    });

    test('"Key: Value" satır metni parse edilir', () {
      final specs = ProductQuickViewContent.parseSpecificationsField(
        'Ekran: 10.9 inç\nHafıza: 64 GB\nBağlantı: Wi-Fi',
      );
      expect(specs.length, 3);
      expect(specs.first.label, 'Ekran');
      expect(specs.first.value, '10.9 inç');
    });

    test('boş/null/undefined değerler atlanır', () {
      expect(ProductQuickViewContent.parseSpecificationsField(null), isEmpty);
      expect(ProductQuickViewContent.parseSpecificationsField(''), isEmpty);
      expect(
        ProductQuickViewContent.parseSpecificationsField('Renk: null'),
        isEmpty,
      );
    });
  });

  group('ProductQuickViewContent.buildQuickSpecs', () {
    test('specifications + attributes birleşir, tekrar label temizlenir', () {
      final product = buildProduct(
        specifications: 'Renk: Mavi\nEkran: 10.9 inç',
        attributes: ['Renk: Kırmızı', 'Garanti: 2 Yıl'],
      );
      final specs = ProductQuickViewContent.buildQuickSpecs(product);
      final labels = specs.map((s) => s.label).toList();
      expect(labels.where((l) => l == 'Renk').length, 1);
      // İlk kaynak (specifications) kazanır.
      expect(specs.firstWhere((s) => s.label == 'Renk').value, 'Mavi');
      expect(labels, contains('Garanti'));
    });

    test('öncelikli alanlar (hafıza, ekran) öne sıralanır', () {
      final product = buildProduct(
        specifications: 'Menşei: Türkiye\nHafıza: 64 GB\nEkran: 10.9 inç',
      );
      final specs = ProductQuickViewContent.buildQuickSpecs(product);
      expect(specs.first.label, 'Hafıza');
      expect(specs[1].label, 'Ekran');
      expect(specs.last.label, 'Menşei');
    });

    test('düz metin özellikler chip listesine gider', () {
      final product = buildProduct(
        features: ['Su geçirmez', 'Renk: Mavi'],
        attributes: ['su geçirmez', 'Bluetooth 5.0'],
      );
      final chips = ProductQuickViewContent.plainFeatures(product);
      expect(chips, ['Su geçirmez', 'Bluetooth 5.0']);
    });
  });

  group('ProductQuickViewContent.resolveDescription', () {
    test('description öncelikli', () {
      final product = buildProduct(
        description: 'Gerçek açıklama',
        shortDescription: 'Kısa',
      );
      expect(
        ProductQuickViewContent.resolveDescription(product),
        'Gerçek açıklama',
      );
    });

    test('description yoksa shortDescription', () {
      final product = buildProduct(shortDescription: 'Kısa açıklama');
      expect(
        ProductQuickViewContent.resolveDescription(product),
        'Kısa açıklama',
      );
    });

    test('specifications JSON içindeki açıklama anahtarı okunur', () {
      final product = buildProduct(
        specifications: '{"description": "Spec içi açıklama"}',
      );
      expect(
        ProductQuickViewContent.resolveDescription(product),
        'Spec içi açıklama',
      );
    });

    test('hiçbiri yoksa null (fallback UI metni)', () {
      expect(ProductQuickViewContent.resolveDescription(buildProduct()),
          isNull);
    });
  });

  group('EcommerceProductQuickInfoSheet içerik', () {
    testWidgets('ürün görseli popup içinde render edilmez', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(images: const ['https://example.com/img.jpg']),
      );
      expect(find.byType(OptimizedImage), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('ürün adı, marka·mağaza ve fiyat görünür', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(store: 'Örnek Mağaza'),
      );
      expect(find.text('Test Ürünü'), findsOneWidget);
      expect(find.text('Test Marka · Örnek Mağaza'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('açıklama varsa gösterilir', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(description: 'Bu harika bir ürün.'),
      );
      expect(find.text('Bu harika bir ürün.'), findsOneWidget);
      expect(find.text('Bu ürün için açıklama eklenmemiş.'), findsNothing);
    });

    testWidgets('açıklama yoksa fallback gösterilir', (tester) async {
      await pumpSheet(tester, buildProduct());
      expect(find.text('Bu ürün için açıklama eklenmemiş.'), findsOneWidget);
    });

    testWidgets('özellikler key/value satırları olarak görünür',
        (tester) async {
      await pumpSheet(
        tester,
        buildProduct(
          specifications: 'Ekran: 10.9 inç\nHafıza: 64 GB\nBağlantı: Wi-Fi',
        ),
      );
      expect(find.text('Öne Çıkan Özellikler'), findsOneWidget);
      expect(find.text('Ekran'), findsOneWidget);
      expect(find.text('10.9 inç'), findsOneWidget);
      expect(find.text('Hafıza'), findsOneWidget);
    });

    testWidgets('8+ özellikte "+N özellik daha" görünür ve açılır',
        (tester) async {
      final specLines = [
        for (var i = 1; i <= 11; i++) 'Özellik $i: Değer $i',
      ].join('\n');
      await pumpSheet(tester, buildProduct(specifications: specLines));
      expect(find.text('+3 özellik daha'), findsOneWidget);
      expect(find.text('Özellik 11'), findsNothing);
      await tester.tap(find.text('+3 özellik daha'));
      await tester.pump();
      expect(find.text('Özellik 11'), findsOneWidget);
    });

    testWidgets('özellik yoksa bölüm tamamen gizlenir', (tester) async {
      await pumpSheet(tester, buildProduct());
      expect(find.text('Öne Çıkan Özellikler'), findsNothing);
    });

    testWidgets('eski fiyat varsa indirim chip\'i görünür', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(price: '₺100,00', oldPrice: '₺200,00'),
      );
      expect(find.text('%50'), findsOneWidget);
      expect(find.textContaining('₺200'), findsOneWidget);
    });

    testWidgets('eski fiyat yoksa indirim gizlenir', (tester) async {
      await pumpSheet(tester, buildProduct());
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('puan 0 ise puan alanı gizlenir', (tester) async {
      await pumpSheet(tester, buildProduct(rating: 0));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('puan varsa yıldız ve yorum sayısı görünür', (tester) async {
      await pumpSheet(tester, buildProduct(rating: 4.5, reviewCount: 12));
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('(12 değerlendirme)'), findsOneWidget);
    });

    testWidgets('stok varsa "Stokta var" görünür', (tester) async {
      await pumpSheet(tester, buildProduct(stock: 5));
      expect(find.text('Stokta var'), findsWidgets);
    });

    testWidgets('stok 0 ise "Stokta yok" görünür', (tester) async {
      await pumpSheet(tester, buildProduct(stock: 0));
      expect(find.text('Stokta yok'), findsWidgets);
    });

    testWidgets('stok null ise stok alanı gizlenir', (tester) async {
      await pumpSheet(tester, buildProduct());
      expect(find.text('Stokta var'), findsNothing);
      expect(find.text('Stokta yok'), findsNothing);
    });

    testWidgets('uzun açıklamada "Devamını oku" çalışır', (tester) async {
      final longText = 'Çok uzun açıklama. ' * 30;
      await pumpSheet(tester, buildProduct(description: longText));
      expect(find.text('Devamını oku'), findsOneWidget);
      await tester.tap(find.text('Devamını oku'));
      await tester.pump();
      expect(find.text('Devamını oku'), findsNothing);
    });
  });

  group('EcommerceProductQuickInfoSheet aksiyonlar', () {
    testWidgets('Sepete Ekle ve Detayları Gör callbackleri çalışır',
        (tester) async {
      var added = false;
      var viewed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => EcommerceProductQuickInfoSheet(
                      product: buildProduct(),
                      onAddToCart: () => added = true,
                      onViewDetails: () => viewed = true,
                    ),
                  );
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Sepete Ekle'), findsOneWidget);
      expect(find.text('Detayları Gör'), findsOneWidget);
      await tester.tap(find.text('Sepete Ekle'));
      await tester.pumpAndSettle();
      expect(added, isTrue);
      expect(viewed, isFalse);
    });

    testWidgets('callback yokken aksiyon barı gizlenir', (tester) async {
      await pumpSheet(tester, buildProduct());
      expect(find.text('Sepete Ekle'), findsNothing);
      expect(find.text('Detayları Gör'), findsNothing);
    });
  });

  group('EcommerceProductQuickInfoSheet enrich', () {
    testWidgets('enrich gelince açıklama ve özellikler tazelenir',
        (tester) async {
      await pumpSheet(
        tester,
        buildProduct(),
        enrich: () => Future<Product?>.delayed(
          const Duration(milliseconds: 50),
          () => buildProduct(
            description: 'Zengin açıklama metni',
            specifications: 'Renk: Mavi',
          ),
        ),
      );
      expect(find.text('Bu ürün için açıklama eklenmemiş.'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Zengin açıklama metni'), findsOneWidget);
      expect(find.text('Öne Çıkan Özellikler'), findsOneWidget);
    });

    testWidgets('enrich timeout popup\'ı çökertmez', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(),
        enrichTimeout: const Duration(milliseconds: 100),
        enrich: () => Future<Product?>.delayed(
          const Duration(seconds: 5),
          () => buildProduct(description: 'Geç gelen veri'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Bu ürün için açıklama eklenmemiş.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Geç gelen veri'), findsNothing);
    });

    testWidgets('enrich karttaki puanı silmez (merge)', (tester) async {
      await pumpSheet(
        tester,
        buildProduct(rating: 4.7, reviewCount: 30),
        enrich: () => Future<Product?>.delayed(
          const Duration(milliseconds: 50),
          () => buildProduct(rating: 0, reviewCount: 0, description: 'A'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('4.7'), findsOneWidget);
    });
  });

  group('EcommerceProductQuickInfoSheet küçük ekran', () {
    testWidgets('320x568 ekranda taşma olmaz', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EcommerceProductQuickInfoSheet(
              product: buildProduct(
                name: 'Çok Uzun Ürün Adı ' * 4,
                brand: 'Uzun Marka Adı Serisi Profesyonel',
                store: 'Çok Uzun Mağaza Adı Ticaret Limited Şirketi',
                category: 'Elektronik & Aksesuar',
                oldPrice: '₺2.499,90',
                price: '₺1.999,90',
                rating: 4.8,
                reviewCount: 1500,
                stock: 3,
                specifications:
                    'Ekran: 10.9 inç Liquid Retina Ultra Geniş\n'
                    'Hafıza: 64 GB\nBağlantı: Wi-Fi 6E + Bluetooth 5.3',
                description: 'Uzun açıklama metni. ' * 20,
              ),
              onAddToCart: () {},
              onViewDetails: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
