part of 'customer_authenticated_smoke_test.dart';

Future<Product> _openMarketplaceProduct(WidgetTester tester) async {
  await _until(tester, () => find.byType(ProductCard).evaluate().isNotEmpty);
  final seen = <String>{};
  for (var pass = 0; pass < 6; pass++) {
    final cards = tester.widgetList<ProductCard>(find.byType(ProductCard));
    for (final card in cards) {
      final product = card.product;
      final key = CartState.productKey(product);
      if (!seen.add(key) || !_marketplace(product)) continue;
      if (CartState().isInCart(product)) continue;
      final finder = find.byWidgetPredicate(
        (widget) =>
            widget is ProductCard &&
            CartState.productKey(widget.product) == key,
      );
      if (finder.evaluate().isEmpty) continue;
      await tester.ensureVisible(finder.first);
      await tester.tap(finder.first);
      await tester.pump();
      await _until(
        tester,
        () =>
            find.text('SEPETE EKLE').evaluate().isNotEmpty ||
            find.text('MEKANDA').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 20),
      );
      if (find.text('SEPETE EKLE').evaluate().isNotEmpty) return product;
      await _tapBack(tester);
      await _until(tester, () => find.byType(ProductCard).evaluate().isNotEmpty);
    }
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 400));
  }
  fail('no marketplace product card was available');
}

Future<void> _reopenProduct(WidgetTester tester, Product product) async {
  final key = CartState.productKey(product);
  Finder finder() => find.byWidgetPredicate(
    (widget) =>
        widget is ProductCard && CartState.productKey(widget.product) == key,
  );
  for (var pass = 0; pass < 6 && finder().evaluate().isEmpty; pass++) {
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.first, const Offset(0, -420));
    await tester.pump(const Duration(milliseconds: 400));
  }
  expect(finder(), findsWidgets);
  await tester.ensureVisible(finder().first);
  await tester.tap(finder().first);
  await tester.pump();
  await _until(
    tester,
    () =>
        find.text('SEPETE EKLE').evaluate().isNotEmpty ||
        find.text('SEPETTE').evaluate().isNotEmpty,
  );
}

Future<void> _tapBrowseCard(WidgetTester tester, String name) async {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is FavoriteBrowseProductCard && widget.product.name == name,
  );
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump();
}

Future<void> _openFavorites(WidgetTester tester) async {
  if (find.text('Beğendiklerim').evaluate().isEmpty) {
    await _tapNav(tester, 'mobile-nav-account');
    await _until(tester, () => find.text('Favorilerim').evaluate().isNotEmpty);
    await _tapText(tester, 'Favorilerim');
  }
  await _until(tester, () => find.text('Beğendiklerim').evaluate().isNotEmpty);
  _expectShellPath();
}

Future<void> _tapFavorite(WidgetTester tester) async {
  final filled = find.byIcon(Icons.favorite);
  final empty = find.byIcon(Icons.favorite_border);
  final target = filled.evaluate().isNotEmpty ? filled : empty;
  expect(target, findsWidgets);
  await tester.tap(target.last);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _isolateSelection(WidgetTester tester, String name) async {
  final nameFinder = find.text(name);
  expect(nameFinder, findsWidgets);
  await tester.ensureVisible(nameFinder.first);
  final nameY = tester.getCenter(nameFinder.first).dy;
  for (var guard = 0; guard < 8; guard++) {
    final checks = find.byIcon(Icons.check);
    Finder? other;
    final count = checks.evaluate().length;
    for (var i = 0; i < count; i++) {
      final check = checks.at(i);
      if ((tester.getCenter(check).dy - nameY).abs() > 100) {
        other = check;
        break;
      }
    }
    if (other == null) return;
    await tester.tap(other);
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _nudgeQuantity(WidgetTester tester, Product product) async {
  final before = _quantity(product);
  await _tapIconNear(tester, Icons.add, product.name);
  await tester.pump(const Duration(milliseconds: 300));
  expect(_quantity(product), before + 1);
  await _tapIconNear(tester, Icons.remove, product.name);
  await tester.pump(const Duration(milliseconds: 300));
  expect(_quantity(product), before);
}

Future<void> _removeCartItem(WidgetTester tester, String name) async {
  final rounded = find.byIcon(Icons.delete_outline_rounded);
  final plain = find.byIcon(Icons.delete_outline);
  if (rounded.evaluate().isNotEmpty || plain.evaluate().isNotEmpty) {
    await _tapIconNear(
      tester,
      rounded.evaluate().isNotEmpty
          ? Icons.delete_outline_rounded
          : Icons.delete_outline,
      name,
    );
    return;
  }
  fail('CLEANUP cart delete control missing');
}

Future<void> _tapIconNear(
  WidgetTester tester,
  IconData icon,
  String name,
) async {
  final nameFinder = find.text(name);
  expect(nameFinder, findsWidgets);
  await tester.ensureVisible(nameFinder.first);
  final nameY = tester.getCenter(nameFinder.first).dy;
  final icons = find.byIcon(icon);
  Finder? best;
  var bestDy = 1000.0;
  final count = icons.evaluate().length;
  for (var i = 0; i < count; i++) {
    final candidate = icons.at(i);
    final dy = (tester.getCenter(candidate).dy - nameY).abs();
    if (dy < bestDy) {
      bestDy = dy;
      best = candidate;
    }
  }
  expect(best, isNotNull);
  expect(bestDy, lessThan(160));
  await tester.tap(best!);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _expectAddressesMatchState(WidgetTester tester) async {
  final addresses = AppState().deliveryAddresses;
  if (addresses.isEmpty) return;
  final title = (addresses.first['title'] ?? '').trim();
  if (title.isEmpty) return;
  await _reveal(tester, find.textContaining(title));
  expect(find.textContaining(title), findsWidgets);
}

bool _marketplace(Product product) {
  final category =
      '${product.category ?? ''} ${product.subCategory ?? ''}'.toLowerCase();
  return product.name.trim().isNotEmpty &&
      !category.contains('yemek') &&
      !category.contains('restoran') &&
      !category.contains('kafe') &&
      !category.contains('cafe');
}

List<FavoriteBrowseProductCard> _browseCards(String name) {
  return find
      .byType(FavoriteBrowseProductCard)
      .evaluate()
      .map((element) => element.widget as FavoriteBrowseProductCard)
      .where((card) => card.product.name == name)
      .toList();
}

int _favoriteCount(String key) {
  return FavoriteState()
      .favorites
      .where((product) => FavoriteState.productKey(product) == key)
      .length;
}

int _quantity(Product product) {
  final key = CartState.productKey(product);
  final match = AppState().cart.where(
    (item) => CartState.productKey(item) == key,
  );
  if (match.isEmpty) return 0;
  return match.first.cartQuantity ?? 1;
}

List<String> _favoriteKeys() => FavoriteState()
    .favorites
    .map(FavoriteState.productKey)
    .toList()
  ..sort();

List<String> _cartKeys() =>
    AppState().cart.map(CartState.productKey).toList()..sort();

List<String> _listIds() =>
    AppState().productLists.map((list) => list.id).toList()..sort();

String? _path() => IbulGoRouterBinding.instance?.state.uri.path;

void _expectShellPath() {
  final path = _path();
  expect(path, isNotNull);
  expect(path!.startsWith('/login'), isFalse);
  expect(path.startsWith('/register'), isFalse);
  expect(
    path == '/' ||
        path == '/home' ||
        path.startsWith('/hesabim') ||
        path.startsWith('/urun') ||
        path == '/sepet',
    isTrue,
    reason: 'route $path',
  );
}

Finder _nav(String id) {
  final active = find.byKey(ValueKey<String>('$id-active'));
  if (active.evaluate().isNotEmpty) return active;
  return find.byKey(ValueKey<String>(id));
}

Future<void> _tapNav(WidgetTester tester, String id) async {
  final finder = _nav(id);
  expect(finder, findsWidgets);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.last);
  await tester.tap(finder.last);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapBack(WidgetTester tester) async {
  final back = find.byIcon(Icons.arrow_back);
  expect(back, findsWidgets);
  await tester.tap(back.last);
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isNotEmpty) return;
  final scrollables = find.byType(Scrollable);
  final count = scrollables.evaluate().length;
  for (var i = 0; i < count; i++) {
    try {
      await tester.scrollUntilVisible(
        finder,
        280,
        scrollable: scrollables.at(i),
        maxScrolls: 10,
      );
      return;
    } catch (_) {}
  }
  expect(finder, findsWidgets);
}

Future<bool> _untilOrFalse(
  WidgetTester tester,
  bool Function() ready, {
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (ready()) return true;
  }
  return false;
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final readyNow = await _untilOrFalse(tester, ready, timeout: timeout);
  if (!readyNow) {
    fail(reason ?? 'timed out waiting for UI');
  }
}

List<String> _blockingConsole() {
  return _console.where((line) {
    return line.contains('42703') ||
        line.contains('Unable to load asset') ||
        line.contains('ProviderNotFoundException') ||
        line.contains('GoException');
  }).toList();
}

List<String> _blockingFatals() {
  return _fatals.map((details) => details.exceptionAsString()).where((line) {
    return line.contains('ProviderNotFoundException') ||
        line.contains('GoException') ||
        line.contains('Unable to load asset') ||
        line.contains('42703');
  }).toList();
}
