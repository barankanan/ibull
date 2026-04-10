import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('1. Boş masaya ilk sipariş gönder', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
    );

    expect(find.text('Siparişi Gönder'), findsOneWidget);
    expect(find.text('Ciğer Şiş'), findsOneWidget);
    expect(find.text('Kuzu Pirzola'), findsOneWidget);
    await _openProductsTabAndExpectNoSubmit(tester);
    await _openOrdersTab(tester);

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);

    expect(
      find.text('Bu masaya henüz müşteri siparişi düşmedi.'),
      findsNothing,
    );
    expect(
      find.text('Sipariş masaya yansıtıldı. Aktif siparişler aşağıda hazır.'),
      findsOneWidget,
    );
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);
    expect(find.text('Mutfağa İletildi'), findsOneWidget);
    expect(find.text('Siparişi Gönder'), findsNothing);
  });

  testWidgets('2. Aynı masaya ikinci sipariş ekle ve gönder', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
    );

    expect(find.text('Siparişi Ekle'), findsOneWidget);
    expect(find.textContaining('₺1.140,00'), findsOneWidget);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Toplam: ₺360,00'), findsOneWidget);
    await _openProductsTabAndExpectNoSubmit(tester);
    await _openOrdersTab(tester);

    await tester.tap(find.text('Siparişi Ekle'));
    await _settleGarson(tester);

    expect(
      find.text('Bu masaya henüz müşteri siparişi düşmedi.'),
      findsNothing,
    );
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Toplam: ₺360,00'), findsOneWidget);
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);
    expect(find.text('Mutfağa İletildi'), findsNWidgets(2));
  });

  testWidgets('3. Aktif sipariş varken draft düzenle', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
    );

    expect(find.textContaining('₺1.140,00'), findsOneWidget);
    await _openProductsTabAndExpectNoSubmit(tester);
    await _openOrdersTab(tester);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Toplam: ₺360,00'), findsOneWidget);
    await _scrollOrdersToTop(tester);

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await _settleGarson(tester);

    expect(find.textContaining('₺1.420,00'), findsOneWidget);
    expect(find.text('Ciğer Şiş'), findsWidgets);
    expect(find.text('Kuzu Pirzola'), findsWidgets);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Toplam: ₺360,00'), findsOneWidget);
    expect(find.text('Siparişi Ekle'), findsOneWidget);
  });

  testWidgets('4. Sipariş gönderip ekranı kapat-aç', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
      useHarness: true,
    );

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);

    await tester.tap(find.byKey(const ValueKey<String>('close-flow')));
    await _settleGarson(tester);
    expect(find.byKey(const ValueKey<String>('flow-closed')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('open-flow')));
    await _settleGarson(tester);

    expect(find.byKey(const ValueKey<String>('flow-closed')), findsNothing);
    expect(
      find.text('Bu masaya henüz müşteri siparişi düşmedi.'),
      findsNothing,
    );
    expect(find.text('Mutfağa İletildi'), findsOneWidget);
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);
  });

  testWidgets('5. İşlemler menüsünü açıp geri dön', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
    );

    _expectInlineSettlementActionsHidden();
    await tester.tap(find.widgetWithText(TextButton, 'İşlemler'));
    await _settleGarson(tester);

    expect(find.text('Ara Ödeme Al'), findsOneWidget);
    expect(find.text('Hesabı Böl'), findsOneWidget);
    expect(find.text('Hesabı Kes'), findsOneWidget);
    expect(find.text('Masa Aktar'), findsOneWidget);
    expect(find.text('Adisyon Yazdır'), findsOneWidget);
    expect(find.text('Mutfağa Yazdır'), findsOneWidget);
    expect(find.text('Müşteri Seç'), findsOneWidget);
    expect(find.text('Müşteri Sayısı'), findsOneWidget);

    await tester.tapAt(const Offset(200, 40));
    await _settleGarson(tester);

    expect(find.text('Ara Ödeme Al'), findsNothing);
    expect(find.text('Hesabı Böl'), findsNothing);
    expect(find.text('Hesabı Kes'), findsNothing);
  });

  testWidgets('6. Ürünler sekmesi canlı mini özeti gösterir', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.productsEmptyDraft,
      viewportSize: const Size(360, 780),
    );

    expect(find.text('Siparişi Gönder'), findsNothing);
    expect(find.text('Taslak boş'), findsOneWidget);
    expect(find.text('Ürün seçince burada görünür'), findsOneWidget);

    await tester.tap(find.text('Ekle').first);
    await _settleGarson(tester);

    expect(find.text('1 ürün'), findsOneWidget);
    expect(find.text('₺280,00'), findsOneWidget);

    await _openOrdersTab(tester);
    await _settleGarson(tester);

    expect(find.text('₺280,00'), findsWidgets);
    expect(find.text('Ciğer Şiş'), findsOneWidget);
    expect(find.text('Siparişi Gönder'), findsOneWidget);
  });

  testWidgets('7. Peş peşe iki hızlı submit denemesi', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
    );

    final submitButton = find.text('Siparişi Gönder');
    await tester.tap(submitButton);
    await tester.tap(submitButton);
    await _settleGarson(tester);

    expect(find.text('Mutfağa İletildi'), findsOneWidget);
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);
    expect(
      find.text('Bu masaya henüz müşteri siparişi düşmedi.'),
      findsNothing,
    );
  });

  testWidgets('8. Masa kartı özeti ile detay ekranı aynı veriyi gösteriyor', (
    tester,
  ) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
      useHarness: true,
      showTableSummary: true,
    );

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);
    await tester.tap(find.byKey(const ValueKey<String>('close-flow')));
    await _settleGarson(tester);
    await tester.tap(find.byKey(const ValueKey<String>('open-flow')));
    await _settleGarson(tester);

    final summaryCard = find.byKey(
      const ValueKey<String>('table-summary-card'),
    );
    expect(summaryCard, findsOneWidget);
    expect(
      find.descendant(of: summaryCard, matching: find.text('1 x Ciğer Şiş')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summaryCard, matching: find.text('1 x Kuzu Pirzola')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summaryCard,
        matching: find.text('2 x Tavuk Bonfile'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: summaryCard, matching: find.text('₺1.140,00')),
      findsOneWidget,
    );
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);
    expect(find.text('Ciğer Şiş'), findsOneWidget);
    expect(find.text('Kuzu Pirzola'), findsOneWidget);
    expect(find.text('Tavuk Bonfile'), findsOneWidget);
  });

  testWidgets('9. İletilmiş sipariş düzenlenir ve duplicate oluşmaz', (
    tester,
  ) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.postSubmitActiveOrder,
      useHarness: true,
    );

    expect(find.text('Mutfağa İletildi'), findsOneWidget);
    expect(find.text('Toplam: ₺1.140,00'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Düzenle'));
    await _settleGarson(tester);

    expect(find.text('Siparişi Düzenle'), findsOneWidget);
    expect(
      find.textContaining('Henüz değişiklik yok. Güncelleme yapmak için'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await _settleGarson(tester);

    expect(find.text('Değişiklik Özeti'), findsOneWidget);
    expect(find.text('1 x Ciğer Şiş eklendi'), findsOneWidget);
    expect(find.text('Siparişi Güncelle'), findsOneWidget);

    await tester.tap(find.text('Siparişi Güncelle'));
    await _settleGarson(tester);

    expect(
      find.text('Sipariş güncellendi ve mutfağa tekrar iletildi.'),
      findsOneWidget,
    );
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Mutfağa İletildi'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Düzenle'), findsOneWidget);
  });
}

Future<void> _pumpOperationHarness(
  WidgetTester tester, {
  required SellerPanelGarsonPreviewScenario scenario,
  bool useHarness = false,
  bool showTableSummary = false,
  Size viewportSize = const Size(430, 932),
}) async {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1;

  await tester.pumpWidget(
    useHarness
        ? SellerPanelGarsonOperationHarness(
            scenario: scenario,
            showTableSummary: showTableSummary,
            viewportSize: viewportSize,
          )
        : SellerPanelGarsonPreview(
            scenario: scenario,
            enableLocalSubmit: true,
            viewportSize: viewportSize,
          ),
  );
  await _settleGarson(tester);
}

Future<void> _settleGarson(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  _assertNoRenderException(tester);
}

void _assertNoRenderException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Operation render exception: $exception');
  }
}

Future<void> _openProductsTabAndExpectNoSubmit(WidgetTester tester) async {
  final productsTab = find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text('Ürünler'),
  );
  await tester.tap(productsTab);
  await _settleGarson(tester);
  _expectNoSubmitAction();
}

Future<void> _openOrdersTab(WidgetTester tester) async {
  final ordersTab = find.descendant(
    of: find.byType(BottomNavigationBar),
    matching: find.text('Sipariş'),
  );
  await tester.tap(ordersTab);
  await _settleGarson(tester);
}

void _expectNoSubmitAction() {
  expect(find.text('Siparişi Gönder'), findsNothing);
  expect(find.text('Siparişi Ekle'), findsNothing);
  expect(find.text('Siparişi Güncelle'), findsNothing);
}

void _expectInlineSettlementActionsHidden() {
  expect(find.text('Ara Ödeme Al'), findsNothing);
  expect(find.text('Hesabı Böl'), findsNothing);
  expect(find.text('Hesabı Kes'), findsNothing);
}

Future<void> _scrollOrdersSectionIntoView(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Masaya Düşen Siparişler'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _settleGarson(tester);
}

Future<void> _scrollOrdersToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
  await _settleGarson(tester);
}
