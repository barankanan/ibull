import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/models/db_product.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/viewmodels/product_detail_viewmodel.dart';
import 'package:ibul_app/widgets/product_detail/product_variant_selector_mobile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  Product createTestProduct({
    required String name,
    required String brand,
    required String price,
    List<dynamic>? variants,
    List<String>? images,
  }) {
    return Product(
      productId: 'test-1',
      name: name,
      brand: brand,
      price: price,
      rating: 4.8,
      reviewCount: 25,
      tags: const [],
      images: images ?? const [],
      category: 'Elektronik',
      variants: variants,
    );
  }

  group('Product Variant Deserialization & Model Layer', () {
    test('DBProduct.fromMap correctly parses variants from JSON string and variants_json', () {
      final dbProduct = DBProduct.fromMap({
        'name': 'Soundcore Life Q30',
        'brand': 'Anker',
        'price': '1.999 TL',
        'rating': 4.8,
        'variants_json': '[{"color":"Gümüş","colorHex":"#C0C0C0","stock":10,"priceDifference":0},{"color":"Kırmızı","colorHex":"#E11D48","stock":5,"priceDifference":50}]',
      });

      expect(dbProduct.variants, isA<List>());
      final list = dbProduct.variants as List;
      expect(list.length, 2);
      expect(list[0]['color'], 'Gümüş');
      expect(list[1]['color'], 'Kırmızı');
    });

    test('Product.fromDBProduct parses variants List and dynamic options', () {
      final dbProduct = DBProduct.fromMap({
        'name': 'Soundcore Life Q30',
        'brand': 'Anker',
        'price': '1.999 TL',
        'variants': [
          {
            'color': 'Gümüş',
            'colorHex': '#C0C0C0',
            'stock': 10,
            'priceDifference': 0,
            'options': {'Bağlantı': 'Bluetooth 5.0'},
          },
          {
            'color': 'Kırmızı',
            'colorHex': '#E11D48',
            'stock': 0,
            'priceDifference': 50,
            'options': {'Bağlantı': 'Bluetooth 5.0'},
          },
        ],
      });

      final product = Product.fromDBProduct(dbProduct);
      expect(product.variants, isNotNull);
      final variants = product.variants as List;
      expect(variants.length, 2);
      expect(variants[0]['color'], 'Gümüş');
      expect(variants[0]['options']['Bağlantı'], 'Bluetooth 5.0');
    });
  });

  group('ProductDetailViewModel Variant System', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('selectVariant updates selectedVariants, price diff and totalPrice', () {
      final product = createTestProduct(
        name: 'Soundcore Life Q30',
        brand: 'Anker',
        price: '1.999 TL',
        variants: [
          {
            'color': 'Gümüş',
            'colorHex': '#C0C0C0',
            'stock': 10,
            'priceDifference': 0,
            'imageUrl': 'https://example.com/gumus.jpg',
          },
          {
            'color': 'Kırmızı',
            'colorHex': '#E11D48',
            'stock': 5,
            'priceDifference': 50,
            'imageUrl': 'https://example.com/kirmizi.jpg',
          },
        ],
        images: [
          'https://example.com/gumus.jpg',
          'https://example.com/kirmizi.jpg',
        ],
      );

      final viewModel = ProductDetailViewModel(
        initialProduct: product,
        appState: appState,
        catalogMode: true,
      );

      expect(viewModel.hasVariants, isTrue);
      expect(viewModel.variantMaps.length, 2);

      // Initial in-stock variant should be selected
      expect(viewModel.selectedVariants['color'], 'Gümüş');
      expect(viewModel.currentVariantPriceDifference, 0);

      // Select Kırmızı (+50 TL)
      final redVariant = viewModel.variantMaps[1];
      viewModel.selectVariant(redVariant);

      expect(viewModel.selectedVariants['color'], 'Kırmızı');
      expect(viewModel.currentVariantPriceDifference, 50.0);
      expect(viewModel.totalPrice, '2.049 TL');
      expect(viewModel.currentImageIndex, 1);
    });
  });

  group('ProductVariantSelectorMobile Widget Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    testWidgets('renders 72x88 cards for Gümüş and Kırmızı with checkmark and Tükendi', (tester) async {
      final product = createTestProduct(
        name: 'Soundcore Life Q30',
        brand: 'Anker',
        price: '1.999 TL',
        variants: [
          {
            'color': 'Gümüş',
            'colorHex': '#C0C0C0',
            'stock': 10,
            'priceDifference': 0,
          },
          {
            'color': 'Kırmızı',
            'colorHex': '#E11D48',
            'stock': 0, // out of stock
            'priceDifference': 50,
          },
        ],
      );

      final viewModel = ProductDetailViewModel(
        initialProduct: product,
        appState: appState,
        catalogMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProductDetailViewModel>.value(
              value: viewModel,
              child: const ProductVariantSelectorMobile(),
            ),
          ),
        ),
      );

      // Check text is rendered (one in "Renk: Gümüş", one on card "Gümüş")
      expect(find.text('Gümüş'), findsNWidgets(2));
      expect(find.text('Kırmızı'), findsOneWidget);

      // Check price diff badge (+50 ₺) for Kırmızı
      expect(find.text('+50 ₺'), findsOneWidget);

      // Check checkmark on Gümüş (selected)
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Check out of stock "Tükendi" badge on Kırmızı
      expect(find.text('Tükendi'), findsOneWidget);
    });

    testWidgets('renders pill chips for secondary options', (tester) async {
      final product = createTestProduct(
        name: 'Soundcore Life Q30',
        brand: 'Anker',
        price: '1.999 TL',
        variants: [
          {
            'color': 'Gümüş',
            'stock': 10,
            'priceDifference': 0,
            'options': {'Kapasite': '128 GB'},
          },
          {
            'color': 'Gümüş',
            'stock': 10,
            'priceDifference': 100,
            'options': {'Kapasite': '256 GB'},
          },
        ],
      );

      final viewModel = ProductDetailViewModel(
        initialProduct: product,
        appState: appState,
        catalogMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProductDetailViewModel>.value(
              value: viewModel,
              child: const ProductVariantSelectorMobile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // One in title "Kapasite: 128 GB", one on pill chip "128 GB"
      expect(find.text('128 GB'), findsNWidgets(2));
      // 256 GB has price difference 100 ₺ -> formatted as '256 GB (+100 ₺)'
      expect(find.text('256 GB (+100 ₺)'), findsOneWidget);
    });

    testWidgets('TV dimensions (55 inç, 65 inç) render as option pill chips, not color circles', (tester) async {
      final product = createTestProduct(
        name: 'LG OLED 4K Smart TV',
        brand: 'LG',
        price: '45.000 TL',
        variants: [
          {
            'size': '55 inç',
            'optionType': 'Ekran Boyutu',
            'stock': 10,
            'priceDifference': -15000,
          },
          {
            'size': '65 inç',
            'optionType': 'Ekran Boyutu',
            'stock': 8,
            'priceDifference': 0,
          },
        ],
      );

      final viewModel = ProductDetailViewModel(
        initialProduct: product,
        appState: appState,
        catalogMode: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<ProductDetailViewModel>.value(
              value: viewModel,
              child: const ProductVariantSelectorMobile(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No "Renk:" header should appear
      expect(find.text('Renk:'), findsNothing);

      // Pill chips with price differences should appear
      expect(find.text('55 inç (-15000 ₺)'), findsOneWidget);
      expect(find.text('65 inç'), findsOneWidget);

      // Tap 65 inç to select it
      await tester.tap(find.text('65 inç'));
      await tester.pumpAndSettle();

      // Now 65 inç is selected (appears in header title and on chip)
      expect(find.text('65 inç'), findsNWidgets(2));
      expect(viewModel.currentVariantPriceDifference, 0.0);
    });

    test('Base variant is automatically prepended at index 0 with 0 TL diff if missing from variants', () {
      final product = Product(
        productId: 'test-tv',
        name: 'Samsung Galaxy S24',
        brand: 'Samsung',
        price: '39.999 TL',
        color: 'Siyah',
        colorHex: '#000000',
        rating: 4.9,
        reviewCount: 120,
        tags: const [],
        images: const ['https://example.com/siyah.jpg'],
        variants: [
          {
            'color': 'Mavi',
            'colorHex': '#0000FF',
            'stock': 5,
            'priceDifference': 7000,
            'imageUrl': 'https://example.com/mavi.jpg',
          },
        ],
      );

      final viewModel = ProductDetailViewModel(
        initialProduct: product,
        appState: appState,
        catalogMode: true,
      );

      // Verify that Siyah base variant was prepended at index 0
      expect(viewModel.variantMaps.length, 2);
      expect(viewModel.variantMaps[0]['color'], 'Siyah');
      expect(viewModel.variantMaps[0]['isBaseProduct'], isTrue);
      expect(viewModel.variantMaps[0]['priceDifference'], 0.0);
      expect(viewModel.variantMaps[1]['color'], 'Mavi');
      expect(viewModel.variantMaps[1]['priceDifference'], 7000);

      // Initial selection should be Siyah with 0 price difference
      expect(viewModel.selectedVariants['color'], 'Siyah');
      expect(viewModel.currentVariantPriceDifference, 0.0);
      expect(viewModel.totalPrice, '39.999 TL');

      // Selecting Mavi adds +7.000 TL
      viewModel.selectVariant(viewModel.variantMaps[1]);
      expect(viewModel.selectedVariants['color'], 'Mavi');
      expect(viewModel.currentVariantPriceDifference, 7000.0);
      expect(viewModel.totalPrice, '46.999 TL');

      // Selecting Siyah reverts to base price
      viewModel.selectVariant(viewModel.variantMaps[0]);
      expect(viewModel.selectedVariants['color'], 'Siyah');
      expect(viewModel.currentVariantPriceDifference, 0.0);
      expect(viewModel.totalPrice, '39.999 TL');
    });
  });
}
