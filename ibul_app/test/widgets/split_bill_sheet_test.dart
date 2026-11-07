import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/split_bill_plan.dart';
import 'package:ibul_app/widgets/garson/split_bill_sheet.dart';

void main() {
  testWidgets('pay tahsil edilir, ikinci dokunuş aynı payı yeniden yazmaz', (
    tester,
  ) async {
    final calls = <SplitShare>[];
    final methods = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  SplitBillSheet.show(
                    context,
                    tableLabel: 'Bahçe 2',
                    billKurus: 10000,
                    paidKurus: 0,
                    idempotencyPrefix: 'split:test:01',
                    onCollect: (share, method) async {
                      calls.add(share);
                      methods.add(method);
                    },
                  );
                },
                child: const Text('Aç'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('50,00 ₺'), findsNWidgets(2));
    expect(find.textContaining('fiş basılmaz'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('split-people-inc')));
    await tester.pumpAndSettle();
    expect(find.text('33,33 ₺'), findsNWidgets(2));
    expect(find.text('33,34 ₺'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('split-collect-1')));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.amountKurus, 3333);
    expect(calls.single.idempotencyKey, 'split:test:01:1');
    expect(methods.single, 'cash');
    expect(find.text('Alındı'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('split-collect-1')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(1));

    final stepper = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('split-people-inc')),
    );
    expect(stepper.onPressed, isNull);
  });

  testWidgets('tahsilat hatası ekranda kalır ve pay alınmış sayılmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  SplitBillSheet.show(
                    context,
                    tableLabel: 'Masa 4',
                    billKurus: 2000,
                    paidKurus: 0,
                    idempotencyPrefix: 'split:test:02',
                    onCollect: (share, method) async {
                      throw Exception('Kalan tutardan fazla ödeme alınamaz.');
                    },
                  );
                },
                child: const Text('Aç'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('split-collect-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('split-error')), findsOneWidget);
    expect(find.text('Alındı'), findsNothing);
    expect(find.text('Tahsil et'), findsNWidgets(2));
  });

  testWidgets('kalan hesap yoksa tahsil düğmesi yoktur', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () {
                  SplitBillSheet.show(
                    context,
                    tableLabel: 'Masa 4',
                    billKurus: 1500,
                    paidKurus: 1500,
                    idempotencyPrefix: 'split:test:03',
                    onCollect: (share, method) async {},
                  );
                },
                child: const Text('Aç'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();

    expect(find.text('Bölünecek kalan hesap yok.'), findsOneWidget);
    expect(find.text('Tahsil et'), findsNothing);
  });
}
