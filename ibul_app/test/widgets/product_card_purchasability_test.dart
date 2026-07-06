import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/constants.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/core/product_purchasability_helper.dart';
import 'package:ibul_app/core/review_state.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Product _product({
  required String catalogStatus,
  String? approvalStatus,
  int stock = 999,
  String category = 'Elektronik',
}) {
  return Product(
    productId: 'card-prod',
    name: 'Samsung Galaxy S24 256 GB Gri',
    brand: 'Samsung',
    price: '54999 TL',
    rating: 4.5,
    reviewCount: 10,
    tags: const [],
    images: const [],
    category: category,
    subCategory: 'Telefon',
    catalogStatus: catalogStatus,
    approvalStatus: approvalStatus,
    stock: stock,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  Widget buildCard(Product product) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: AppState()),
        ChangeNotifierProvider<CartState>.value(value: CartState()),
        ChangeNotifierProvider<FavoriteState>.value(value: FavoriteState()),
        ChangeNotifierProvider<ReviewState>.value(value: ReviewState()),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 320,
              child: ProductCard(product: product),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows disabled Satışta Değil button when not purchasable',
      (tester) async {
    await tester.pumpWidget(
      buildCard(_product(catalogStatus: 'Aktif', approvalStatus: 'pending')),
    );
    await tester.pump();

    expect(
      find.text(ProductPurchasabilityHelper.notForSaleLabel),
      findsOneWidget,
    );
    expect(find.text('Sepete Ekle'), findsNothing);

    final button = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('product-card-not-for-sale-button')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull);

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('shows Sepete Ekle button when purchasable', (tester) async {
    await tester.pumpWidget(
      buildCard(_product(catalogStatus: 'Aktif', approvalStatus: 'approved')),
    );
    await tester.pump();

    expect(find.text('Sepete Ekle'), findsOneWidget);
    expect(
      find.text(ProductPurchasabilityHelper.notForSaleLabel),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('Sepete Ekle tap responds and starts cart add flow',
      (tester) async {
    await tester.pumpWidget(
      buildCard(_product(catalogStatus: 'Aktif', approvalStatus: 'approved')),
    );
    await tester.pump();

    // Oturum yokken bile tap sessiz kalmamalı: login dialog açılmalı.
    await tester.tap(find.text('Sepete Ekle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Giriş Yap'), findsWidgets);

    await tester.tap(find.text('Vazgeç'));
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('keeps Sipariş Ver for food products regardless of approval',
      (tester) async {
    await tester.pumpWidget(
      buildCard(
        _product(
          catalogStatus: 'Aktif',
          approvalStatus: 'pending',
          category: 'Yemek',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sipariş Ver'), findsOneWidget);
    expect(
      find.text(ProductPurchasabilityHelper.notForSaleLabel),
      findsNothing,
    );

    await tester.pump(const Duration(seconds: 9));
  });
}
