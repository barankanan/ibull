import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/features/checkout/test_checkout_action.dart';
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/cart_page.dart';
import 'package:ibul_app/screens/checkout_page.dart';
import 'package:ibul_app/screens/order_confirmation_page.dart';
import 'package:ibul_app/utils/order_status_constants.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Product _product(String id) {
  return Product(
    productId: id,
    name: 'Urun $id',
    brand: 'Marka',
    price: '10',
    rating: 0,
    reviewCount: 0,
    tags: const [],
    images: const [],
    category: 'Elektronik',
    cartQuantity: 1,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.x',
    );
  });

  tearDown(() {
    AppRuntimeConfig.setEnableTestCheckoutOverrideForTest(null);
  });

  testWidgets('cart page and checkout keep the same three items', (tester) async {
    final appState = AppState();
    CartState()
      ..addOrReplace(_product('p1'))
      ..addOrReplace(_product('p2'))
      ..addOrReplace(_product('p3'));
    expect(appState.cart, hasLength(3));
    expect(identityHashCode(appState), identityHashCode(AppState()));

    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: ChangeNotifierProvider<CartState>.value(
          value: CartState(),
          child: const MaterialApp(home: CartPage()),
        ),
      ),
    );
    await tester.pump();

    expect(appState.cart, hasLength(3));
    expect(find.textContaining('3 Ürün'), findsWidgets);

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: CheckoutPage(
            totalPrice: 30,
            selectedProducts: appState.cart
                .map(
                  (product) => <String, dynamic>{
                    'productId': product.productId,
                    'name': product.name,
                    'quantity': 1,
                    'price': product.price,
                  },
                )
                .toList(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Güvenli Alışveriş'), findsOneWidget);
    expect(appState.cart, hasLength(3));
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('test checkout area follows the client flag and skips card guards', (
    tester,
  ) async {
    AppRuntimeConfig.setEnableTestCheckoutOverrideForTest(false);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TestCheckoutAction(visible: false, onPressed: _noop)),
      ),
    );
    expect(find.text('TEST ALIŞVERİŞİNİ TAMAMLA'), findsNothing);

    AppRuntimeConfig.setEnableTestCheckoutOverrideForTest(true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestCheckoutAction(visible: true, onPressed: () {}),
        ),
      ),
    );
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNotNull);
    expect(find.text('TEST ALIŞVERİŞİNİ TAMAMLA'), findsOneWidget);
  });

  test('food delivery stays in seller orders and table orders do not', () {
    expect(
      OrderStatusConstants.isTableSourcedSellerOrder(<String, dynamic>{
        'order_number': 'IBUL-FOOD-1',
        'delivery_type': 'fast',
        'order_type': null,
        'restaurant_id': 'seller-a',
        'is_table_order': false,
      }),
      isFalse,
    );
    expect(
      OrderStatusConstants.looksLikeTableOrder(<String, dynamic>{
        'order_number': 'IBUL-FOOD-1',
        'delivery_type': 'standard',
      }),
      isFalse,
    );
    expect(
      OrderStatusConstants.isTableSourcedSellerOrder(<String, dynamic>{
        'order_number': 'TBL-9',
        'order_type': 'table',
        'table_id': 'masa-1',
        'is_table_order': true,
      }),
      isTrue,
    );
    expect(
      OrderStatusConstants.looksLikeTableOrder(<String, dynamic>{
        'delivery_type': 'fast',
        'waiter_id': 'garson-1',
      }),
      isTrue,
    );
  });

  testWidgets('checkout stays readable at phone, tablet, and desktop widths', (
    tester,
  ) async {
    final appState = AppState();
    CartState().clear();
    for (final id in ['p1', 'p2', 'p3']) {
      CartState().addOrReplace(_product(id));
    }
    await appState.addDeliveryAddress(<String, String>{
      'title': 'Ev',
      'name': 'Test Kullanici',
      'detail': 'Deneme Mahallesi 1',
      'phone': '5550000000',
    });
    addTearDown(() async {
      if (appState.deliveryAddresses.isNotEmpty) {
        await appState.removeDeliveryAddress(0);
      }
      CartState().clear();
    });

    final lines = appState.cart
        .map(
          (product) => <String, dynamic>{
            'productId': product.productId,
            'name': product.name,
            'quantity': 1,
            'price': product.price,
          },
        )
        .toList();

    Future<void> pumpAt(Size size) async {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: CheckoutPage(totalPrice: 30, selectedProducts: lines),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pumpAt(const Size(320, 700));
    expect(find.text('Güvenli Alışveriş'), findsWidgets);
    expect(find.text('Teslim Adresim'), findsOneWidget);
    expect(find.text('Urun p1'), findsOneWidget);
    expect(find.text('Urun p2'), findsOneWidget);
    expect(find.text('Urun p3'), findsOneWidget);
    final mobilePay = find.text('Alışverişi Tamamla');
    await tester.ensureVisible(mobilePay);
    await tester.pump();
    expect(tester.getSize(mobilePay).height, greaterThan(0));
    expect(find.text('Ev'), findsWidgets);

    await pumpAt(const Size(800, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('Teslim Adresim'), findsOneWidget);
    expect(find.text('Urun p1'), findsOneWidget);

    await pumpAt(const Size(1280, 900));
    expect(find.text('Güvenli Alışveriş'), findsWidgets);
    expect(find.text('Teslimat Adresi'), findsOneWidget);
    expect(find.text('Ev'), findsWidgets);
    expect(find.text('Urun p1'), findsOneWidget);
    expect(find.text('Urun p2'), findsOneWidget);
    expect(find.text('Urun p3'), findsOneWidget);
    expect(find.text('Ön bilgilendirme formu'), findsOneWidget);
    expect(find.text('Mesafeli satış sözleşmesi'), findsOneWidget);
    final desktopPay = find.text('Siparişi Onayla ve Öde');
    await tester.ensureVisible(desktopPay);
    await tester.pump();
    expect(tester.getSize(desktopPay).height, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('order success returns home without leaving checkout on the stack', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CheckoutPage(
                        totalPrice: 10,
                        selectedProducts: [
                          {'name': 'Yemek', 'quantity': 1, 'price': 10},
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('open-checkout'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open-checkout'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutPage), findsOneWidget);

    final checkoutContext = tester.element(find.byType(CheckoutPage));
    Navigator.of(checkoutContext).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const OrderConfirmationPage(
          totalPrice: 10,
          orderData: {'order_number': 'IBUL-FOOD-1', 'status': 'confirmed'},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Sayfaya Dön'), findsOneWidget);
    expect(find.byType(CheckoutPage), findsNothing);

    await tester.tap(find.text('Ana Sayfaya Dön'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderConfirmationPage), findsNothing);
    expect(find.byType(CheckoutPage), findsNothing);
    expect(find.text('open-checkout'), findsOneWidget);
  });
}

void _noop() {}
