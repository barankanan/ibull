import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/garson/garson_operation_feedback.dart';

void main() {
  test('lost close response does not show an empty card without history', () {
    expect(
      garsonCloseFailureShowsEmpty(
        ordersConfirmedClosed: true,
        historyVerified: false,
      ),
      isFalse,
    );
    expect(
      garsonCloseFailureShowsEmpty(
        ordersConfirmedClosed: true,
        historyVerified: true,
      ),
      isTrue,
    );
    expect(
      garsonCloseFailureShowsEmpty(
        ordersConfirmedClosed: false,
        historyVerified: false,
      ),
      isFalse,
    );
  });

  test('empty card never keeps the closing label', () {
    expect(
      garsonTableCardStatusLabel(
        closing: true,
        hasOrder: false,
        activeLabel: 'Mutfağa İletildi',
      ),
      'Boş Masa',
    );
    expect(
      garsonTableCardStatusLabel(
        closing: true,
        hasOrder: true,
        activeLabel: 'Mutfağa İletildi',
      ),
      'Masa kapatılıyor...',
    );
    expect(
      garsonTableCardStatusLabel(
        closing: false,
        hasOrder: false,
        activeLabel: 'Mutfağa İletildi',
      ),
      'Boş Masa',
    );
  });

  test('ten isolated close stages separate rpc, history and ui', () async {
    final samples = <({int rpcUs, int historyUs, int uiUs})>[];
    for (var i = 0; i < 10; i++) {
      var empty = false;
      var closing = true;
      final sample = await measureGarsonCloseStages(
        rpc: () async {},
        historyFallback: () async {},
        applyUi: () {
          closing = false;
          empty = garsonTableCardStatusLabel(
                closing: closing,
                hasOrder: false,
                activeLabel: 'Mutfağa İletildi',
              ) ==
              'Boş Masa';
        },
      );
      expect(empty, isTrue);
      expect(closing, isFalse);
      samples.add(sample);
    }
    int median(List<int> values) {
      final sorted = [...values]..sort();
      return sorted[sorted.length ~/ 2];
    }
    int p95(List<int> values) {
      final sorted = [...values]..sort();
      return sorted[((sorted.length - 1) * 0.95).round()];
    }
    final rpc = samples.map((s) => s.rpcUs).toList();
    final history = samples.map((s) => s.historyUs).toList();
    final ui = samples.map((s) => s.uiUs).toList();
    // ignore: avoid_print
    print(
      'CLOSE_STAGES rpc_median_us=${median(rpc)} rpc_p95_us=${p95(rpc)} '
      'history_median_us=${median(history)} history_p95_us=${p95(history)} '
      'ui_median_us=${median(ui)} ui_p95_us=${p95(ui)}',
    );
  });

  testWidgets('table card feedback names the closing table action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GarsonOperationFeedback(label: 'Masa kapatılıyor...'),
        ),
      ),
    );
    expect(find.text('Masa kapatılıyor...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('center busy mark names refresh and transfer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GarsonCenterBusy(label: 'Yenileniyor...'),
        ),
      ),
    );
    expect(find.text('Yenileniyor...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GarsonCenterBusy(label: 'Masa aktarılıyor...'),
        ),
      ),
    );
    expect(find.text('Masa aktarılıyor...'), findsOneWidget);
  });
}
