// Authenticated customer smoke. Uses Flutter finders, not coordinate clicks.
//
// Session must already be restored by the app process. This file does not
// embed credentials, create users, or mutate security/payment configuration.
//
//   flutter test integration_test/customer_authenticated_smoke_test.dart -d <simulator> \
//     --dart-define=IBUL_SUPABASE_URL=... --dart-define=IBUL_SUPABASE_ANON_KEY=...
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/ibul_router.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/core/auth/user_identity.dart';
import 'package:ibul_app/core/cart_state.dart';
import 'package:ibul_app/core/favorite_state.dart';
import 'package:ibul_app/main_customer.dart' as customer_app;
import 'package:ibul_app/models/product_model.dart';
import 'package:ibul_app/screens/checkout_page.dart';
import 'package:ibul_app/screens/favorites/favorite_browse_card.dart';
import 'package:ibul_app/widgets/product_card.dart';
import 'package:integration_test/integration_test.dart';

part 'customer_authenticated_smoke_harness.dart';

final _console = <String>[];
final _fatals = <FlutterErrorDetails>[];
var _booted = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated customer integration smoke', (tester) async {
    final previousDebugPrint = debugPrint;
    final previousFlutterError = FlutterError.onError;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) _console.add(message);
      previousDebugPrint(message, wrapWidth: wrapWidth);
    };
    FlutterError.onError = (details) {
      _fatals.add(details);
      previousFlutterError?.call(details);
    };

    try {
    await _boot(tester);
    await _requireCustomerSession(tester);
    await tester.pump(const Duration(seconds: 2));

    final favoritesBefore = _favoriteKeys();
    final cartBefore = _cartKeys();
    final listsBefore = _listIds();

    await _account(tester);
    await _favorites(tester);
    await _lists(tester);
    await _cartCheckoutAndCleanup(tester);

    expect(_favoriteKeys(), favoritesBefore, reason: 'CLEANUP favorite');
    expect(_cartKeys(), cartBefore, reason: 'CLEANUP cart');
    expect(_listIds(), listsBefore, reason: 'CLEANUP lists');
    expect(
      _console.where((line) => line.contains('create_marketplace_order')),
      isEmpty,
      reason: 'ORDER CREATED',
    );
    expect(_blockingConsole(), isEmpty, reason: 'CONSOLE FATAL');
    expect(_blockingFatals(), isEmpty, reason: 'Flutter fatal');
    debugPrint('[PHASE6D] CLEANUP PASS');
    debugPrint('[PHASE6D] ORDER CREATED NO');
    } finally {
      debugPrint = previousDebugPrint;
      FlutterError.onError = previousFlutterError;
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}

Future<void> _boot(WidgetTester tester) async {
  final logical = tester.view.physicalSize / tester.view.devicePixelRatio;
  if (logical.width > 700) {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(430, 932) * 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  if (!_booted) {
    customer_app.main();
    _booted = true;
  }
  await _until(
    tester,
    () => _nav('mobile-nav-home').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 70),
    reason: 'customer shell did not render',
  );
}

bool _customerReady() {
  final user = AppState().currentUser;
  return AppState().isLoggedIn && !UserIdentity.isGuest(user);
}

void _gate(String line) {
  debugPrint(line);
  stderr.writeln(line);
}

Future<void> _requireCustomerSession(WidgetTester tester) async {
  if (_customerReady()) {
    _gate('AUTH SESSION PASS');
    return;
  }

  _gate('AUTHENTICATED SESSION REQUIRED');
  _gate('Waiting for manual login...');
  await _tapNav(tester, 'mobile-nav-account');
  await _until(
    tester,
    () => find.text('Giriş Yap').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 25),
    reason: 'login entry did not appear',
  );
  await _tapText(tester, 'Giriş Yap');
  await _until(
    tester,
    () => find.text('E-posta veya Telefon').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 25),
    reason: 'login form did not appear',
  );
  _gate('=======================================');
  _gate('MANUAL LOGIN NOW — SIMULATOR\'E GEÇ');
  _gate('5 DAKİKA İÇİNDE GİRİŞİ TAMAMLA');
  _gate('=======================================');
  _gate('AUTHENTICATED SESSION REQUIRED');
  _gate('MANUAL LOGIN NOW');
  _gate('Waiting for manual login...');

  const window = Duration(seconds: 300);
  final end = DateTime.now().add(window);
  var nextBeat = DateTime.now();
  while (DateTime.now().isBefore(end)) {
    if (!DateTime.now().isBefore(nextBeat)) {
      final remaining = end.difference(DateTime.now()).inSeconds.clamp(0, 300);
      _gate('remaining=${remaining}s');
      nextBeat = DateTime.now().add(const Duration(seconds: 5));
    }
    if (_customerReady()) {
      await _returnToShell(tester);
      _gate('AUTH SESSION PASS');
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
  fail('AUTH SESSION NOT VERIFIED reason=MANUAL_LOGIN_NOT_COMPLETED');
}

Future<void> _returnToShell(WidgetTester tester) async {
  for (var attempt = 0; attempt < 4; attempt++) {
    if (_nav('mobile-nav-home').hitTestable().evaluate().isNotEmpty) return;
    final back = find.byIcon(Icons.arrow_back);
    if (back.evaluate().isEmpty) return;
    await tester.tap(back.last);
    await tester.pump(const Duration(milliseconds: 300));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Future<void> _account(WidgetTester tester) async {
  await _tapNav(tester, 'mobile-nav-account');
  await _until(
    tester,
    () => find.text('Hesabım', skipOffstage: false).evaluate().isNotEmpty,
  );
  final logout = find.text('Çıkış Yap', skipOffstage: false);
  if (logout.hitTestable().evaluate().isEmpty) {
    await _reveal(tester, logout);
  }
  expect(find.text('Hesabım'), findsWidgets);
  expect(find.text('Favorilerim'), findsWidgets);
  expect(find.text('Siparişlerim'), findsWidgets);
  expect(find.text('Adreslerim'), findsWidgets);
  expect(find.text('Giriş Yap'), findsNothing);
  expect(find.text('Üye Ol'), findsNothing);
  expect(find.text('İBUL hesabınıza giriş yapın'), findsNothing);
  _expectShellPath();
  await _tapNav(tester, 'mobile-nav-home');
  await _until(tester, () => find.byType(ProductCard).evaluate().isNotEmpty);
  debugPrint('[PHASE6D] ACCOUNT PASS path=${_path()}');
}

Future<void> _favorites(WidgetTester tester) async {
  final product = await _openMarketplaceProduct(tester);
  final key = CartState.productKey(product);
  final wasFavorite = AppState().isFavorite(product);
  if (!wasFavorite) {
    await _tapFavorite(tester);
  }
  expect(AppState().isFavorite(product), isTrue);
  expect(_favoriteCount(key), 1);
  await _tapBack(tester);

  await _openFavorites(tester);
  expect(_browseCards(product.name), isNotEmpty);
  expect(_browseCards(product.name).every((card) => card.isFavorite), isTrue);
  await _tapBrowseCard(tester, product.name);
  await _until(
    tester,
    () =>
        find.text('SEPETE EKLE').evaluate().isNotEmpty ||
        find.text('SEPETTE').evaluate().isNotEmpty,
  );
  await _tapFavorite(tester);
  expect(AppState().isFavorite(product), isFalse);
  expect(_favoriteCount(key), 0);
  await _tapBack(tester);
  await _until(tester, () => find.text('Beğendiklerim').evaluate().isNotEmpty);
  expect(_browseCards(product.name), isEmpty);

  if (wasFavorite) {
    await _tapBack(tester);
    await _tapNav(tester, 'mobile-nav-home');
    await _reopenProduct(tester, product);
    await _tapFavorite(tester);
    expect(AppState().isFavorite(product), isTrue);
    await _tapBack(tester);
  } else {
    await _tapBack(tester);
  }
  await _until(tester, () => find.text('Çıkış Yap', skipOffstage: false).evaluate().isNotEmpty);
  await _tapNav(tester, 'mobile-nav-home');
  debugPrint('[PHASE6D] FAVORITES PASS');
}

Future<void> _lists(WidgetTester tester) async {
  final listsBefore = _listIds();
  await _openFavorites(tester);
  await _tapText(tester, 'Listelerim');
  await _until(
    tester,
    () =>
        find.text('Henüz listen yok').evaluate().isNotEmpty ||
        find.text('Listelerde ara').evaluate().isNotEmpty,
  );
  final lists = AppState().userLists;
  if (lists.isEmpty) {
    expect(find.text('Henüz listen yok'), findsWidgets);
  } else {
    final name = lists.first['name']?.toString() ?? '';
    expect(name, isNotEmpty);
    await _reveal(tester, find.text(name));
    expect(find.text(name), findsWidgets);
  }
  await _tapBack(tester);
  await _until(tester, () => find.text('Çıkış Yap', skipOffstage: false).evaluate().isNotEmpty);
  _expectShellPath();
  expect(_listIds(), listsBefore);
  await _tapNav(tester, 'mobile-nav-home');
  debugPrint('[PHASE6D] LISTS PASS');
}

Future<void> _cartCheckoutAndCleanup(WidgetTester tester) async {
  final cartBefore = _cartKeys();
  final product = await _openMarketplaceProduct(tester);
  final key = CartState.productKey(product);
  final beforeCount = AppState().cartCountNotifier.value;
  expect(find.text('SEPETE EKLE'), findsWidgets);
  await _tapText(tester, 'SEPETE EKLE');
  await _until(
    tester,
    () =>
        find.text('SEPETTE').evaluate().isNotEmpty ||
        _cartKeys().contains(key),
  );
  expect(_cartKeys().where((item) => item == key).length, 1);
  expect(AppState().cartCountNotifier.value, beforeCount + 1);

  await _tapKey(tester, const ValueKey<String>('product-detail-open-cart'));
  await _until(tester, () => find.text('Sepeti Onayla').evaluate().isNotEmpty);
  await _reveal(tester, find.text(product.name));
  expect(find.text(product.name), findsWidgets);
  expect(find.text('Toplam'), findsWidgets);
  await _isolateSelection(tester, product.name);
  await _nudgeQuantity(tester, product);
  expect(find.text('Sepeti Onayla'), findsWidgets);
  _expectShellPath();

  await _tapText(tester, 'Sepeti Onayla');
  await _until(tester, () => find.byType(CheckoutPage).evaluate().isNotEmpty);
  expect(find.text('Güvenli Alışveriş'), findsWidgets);
  await _reveal(tester, find.text('Teslim Adresim'));
  expect(find.text('Teslim Adresim'), findsWidgets);
  await _reveal(
    tester,
    find.text('Fatura adresim teslimat adresimle aynı olsun'),
  );
  expect(
    find.text('Fatura adresim teslimat adresimle aynı olsun'),
    findsWidgets,
  );
  await _reveal(tester, find.text('Ödeme Seçenekleri'));
  expect(find.text('Ödeme Seçenekleri'), findsWidgets);
  expect(find.text('Toplam:'), findsWidgets);
  await _expectAddressesMatchState(tester);
  debugPrint('[PHASE6D] CHECKOUT ENTRY PASS');
  debugPrint('[PHASE6D] ADDRESS PASS');

  await _reveal(tester, find.text('Alışverişi Tamamla'));
  await _tapText(tester, 'Alışverişi Tamamla');
  await _until(
    tester,
    () => find
        .textContaining('Kart ile ödeme henüz aktif değil')
        .evaluate()
        .isNotEmpty,
  );
  expect(find.byType(CheckoutPage), findsWidgets);
  expect(
    _console.where((line) => line.contains('create_marketplace_order')),
    isEmpty,
  );
  debugPrint('[PHASE6D] PAYMENT FAIL-CLOSED UI PASS');

  await _tapBack(tester);
  await _until(tester, () => find.text('Sepeti Onayla').evaluate().isNotEmpty);
  await _removeCartItem(tester, product.name);
  await _until(tester, () => !_cartKeys().contains(key));
  expect(_cartKeys(), cartBefore);
  await _tapNav(tester, 'mobile-nav-home');
  debugPrint('[PHASE6D] CART PASS');
}

