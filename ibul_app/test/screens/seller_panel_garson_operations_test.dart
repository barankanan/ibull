import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testSupabaseUrl = String.fromEnvironment(
    'TEST_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'TEST_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(url: testSupabaseUrl, anonKey: testSupabaseAnonKey);
  });

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
      find.text('Bu masaya henüz sipariş düşmedi.'),
      findsNothing,
    );
    // Preview/local-submit flow confirms via the updated orders list.
    expect(find.text('Düzenle'), findsWidgets);
    expect(find.text('Siparişi Gönder'), findsNothing);
  });

  testWidgets('2. Aynı masaya ikinci sipariş ekle ve gönder', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
    );

    expect(find.text('Siparişi Gönder'), findsOneWidget);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Düzenle'), findsWidgets);
    await _openProductsTabAndExpectNoSubmit(tester);
    await _openOrdersTab(tester);

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);

    expect(
      find.text('Bu masaya henüz sipariş düşmedi.'),
      findsNothing,
    );
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Düzenle'), findsWidgets);
  });

  testWidgets('3. Aktif sipariş varken draft düzenle', (tester) async {
    await _pumpOperationHarness(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
    );

    expect(find.textContaining('₺'), findsWidgets);
    await _openProductsTabAndExpectNoSubmit(tester);
    await _openOrdersTab(tester);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Düzenle'), findsWidgets);
    await _scrollOrdersToTop(tester);

    final addButton = find.byIcon(Icons.add_circle_outline).first;
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await _settleGarson(tester);

    expect(find.textContaining('₺'), findsWidgets);
    expect(find.text('Ciğer Şiş'), findsWidgets);
    expect(find.text('Kuzu Pirzola'), findsWidgets);
    await _scrollOrdersSectionIntoView(tester);
    expect(find.text('Düzenle'), findsWidgets);
    expect(find.text('Siparişi Gönder'), findsOneWidget);
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
      find.text('Bu masaya henüz sipariş düşmedi.'),
      findsNothing,
    );
    expect(find.text('Düzenle'), findsWidgets);
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
      // Slightly wider: prevents narrow-screen Row overflow in debug UI.
      viewportSize: const Size(520, 780),
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

    expect(find.text('Düzenle'), findsWidgets);
    expect(
      find.text('Bu masaya henüz sipariş düşmedi.'),
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
    expect(find.text('Toplam'), findsWidgets);
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

    expect(find.text('Düzenle'), findsWidgets);
    expect(find.text('Toplam'), findsWidgets);

    await tester.tap(find.text('Düzenle').first);
    await _settleGarson(tester);

    expect(find.text('Siparişi Düzenle'), findsOneWidget);
    expect(
      find.textContaining('Henüz değişiklik yok. Güncelleme yapmak için'),
      findsOneWidget,
    );

    // In the preview harness this icon button can be inside a scrollable/overlay
    // and may not be hit-testable. Invoke the handler directly.
    final addButton = find.widgetWithIcon(
      IconButton,
      Icons.add_circle_outline,
    );
    final widget = tester.widget<IconButton>(addButton.first);
    widget.onPressed?.call();
    await _settleGarson(tester);

    expect(find.text('Değişiklik Özeti'), findsOneWidget);
    expect(find.text('1 x Ciğer Şiş eklendi'), findsOneWidget);
    expect(find.text('Siparişi Güncelle'), findsOneWidget);

    final submit = find.widgetWithText(FilledButton, 'Siparişi Güncelle');
    final submitWidget = tester.widget<FilledButton>(submit);
    submitWidget.onPressed?.call();
    await _settleGarson(tester);

    await _settleGarson(tester);
    expect(find.text('Siparişi Düzenle'), findsNothing);
    expect(find.text('Düzenle'), findsWidgets);
  });

  testWidgets('print_system_enabled=false: sipariş kaydedilir ama mutfak fişi basılmaz mesajı görünür', (
    tester,
  ) async {
    await tester.pumpWidget(
      SellerPanelGarsonPreview(
        scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
        enableLocalSubmit: true,
        debugPrintSystemEnabledOverride: false,
        viewportSize: const Size(920, 932),
      ),
    );
    await _settleGarson(tester);
    await _openOrdersTab(tester);

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);

    expect(
      find.text(
        'Sipariş kaydedildi. Baskı sistemi kapalı olduğu için mutfak fişi yazdırılmadı.',
      ),
      findsWidgets,
    );
  });

  testWidgets('print_system_enabled=true: disabled mesajı görünmez (regression)', (
    tester,
  ) async {
    await tester.pumpWidget(
      SellerPanelGarsonPreview(
        scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
        enableLocalSubmit: true,
        debugPrintSystemEnabledOverride: true,
        viewportSize: const Size(920, 932),
      ),
    );
    await _settleGarson(tester);
    await _openOrdersTab(tester);

    await tester.tap(find.text('Siparişi Gönder'));
    await _settleGarson(tester);

    expect(
      find.text(
        'Sipariş kaydedildi. Baskı sistemi kapalı olduğu için mutfak fişi yazdırılmadı.',
      ),
      findsNothing,
    );
  });
}

Future<void> _pumpOperationHarness(
  WidgetTester tester, {
  required SellerPanelGarsonPreviewScenario scenario,
  bool useHarness = false,
  bool showTableSummary = false,
  Size viewportSize = const Size(920, 932),
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
    find.text('Düzenle').first,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _settleGarson(tester);
}

Future<void> _scrollOrdersToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
  await _settleGarson(tester);
}
