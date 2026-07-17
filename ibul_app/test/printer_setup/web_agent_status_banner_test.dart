import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/printer_ethernet_dialog.dart';

Future<void> pumpBanner(
  WidgetTester tester, {
  required bool? healthy,
  bool checking = false,
  VoidCallback? onRetry,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WebAgentStatusBanner(
          healthy: healthy,
          checking: checking,
          onRetry: onRetry ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('agent yokken uyarı + indir + tekrar dene görünür',
      (tester) async {
    await pumpBanner(tester, healthy: false);
    expect(
      find.textContaining('İBUL Satıcı Masaüstü uygulaması açık olmalı'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Web tarayıcı güvenliği nedeniyle yazıcıya doğrudan'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('web_agent_download_button')), findsOneWidget);
    expect(find.byKey(const Key('web_agent_retry_button')), findsOneWidget);
  });

  testWidgets('agent bağlıyken yeşil durum görünür, uyarı gizlenir',
      (tester) async {
    await pumpBanner(tester, healthy: true);
    expect(find.text('Masaüstü yazıcı yardımcısı bağlı'), findsOneWidget);
    expect(find.byKey(const Key('web_agent_download_button')), findsNothing);
    expect(find.byKey(const Key('web_agent_retry_button')), findsNothing);
  });

  testWidgets('tekrar dene onRetry callback\'ini çağırır', (tester) async {
    var retried = false;
    await pumpBanner(tester, healthy: false, onRetry: () => retried = true);
    await tester.tap(find.byKey(const Key('web_agent_retry_button')));
    expect(retried, isTrue);
  });

  testWidgets('kontrol sırasında tekrar dene devre dışı kalır',
      (tester) async {
    await pumpBanner(tester, healthy: false, checking: true);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Tekrar dene'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
