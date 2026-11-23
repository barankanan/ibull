import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_panel_shell.dart';

Widget _bar({VoidCallback? onRefresh, bool busy = false}) => MaterialApp(
  home: Scaffold(
    body: SellerPanelTopBar(
      title: 'Ürünler',
      storeLabel: 'Mağaza',
      sellerIdLabel: 'ID',
      onRefresh: onRefresh,
      refreshBusy: busy,
    ),
  ),
);

void main() {
  const refreshKey = ValueKey('seller-top-bar-refresh');

  testWidgets('onRefresh verilmezse Yenile düğmesi çizilmez', (tester) async {
    await tester.pumpWidget(_bar());
    expect(find.byKey(refreshKey), findsNothing);
  });

  testWidgets('Yenile düğmesi tek dokunuşla geri çağırır', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_bar(onRefresh: () => taps++));
    await tester.tap(find.byKey(refreshKey));
    expect(taps, 1);
    expect(find.byTooltip('Yenile'), findsOneWidget);
  });

  testWidgets('yenileme sürerken düğme pasif ve ikinci dokunuş yok sayılır', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_bar(onRefresh: () => taps++, busy: true));
    await tester.tap(find.byKey(refreshKey), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
