import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/garson/adisyon_line_edit.dart';

void main() {
  test('quantity up keeps the unit price and total', () {
    final edit = planAdisyonQuantityOrPrice(
      currentQuantity: 2,
      currentUnitPrice: 120,
      nextQuantity: 3,
      nextUnitPrice: 120,
      canChangeQuantity: true,
      canChangePrice: false,
      linePaid: false,
      otherLinesTotal: 0,
      paidAmount: 0,
    );
    expect(edit.quantity, 3);
    expect(edit.lineTotal, 360);
    expect(edit.priceChanged, isFalse);
  });

  test('quantity down and invalid quantity are rejected', () {
    final lowered = planAdisyonQuantityOrPrice(
      currentQuantity: 3,
      currentUnitPrice: 120,
      nextQuantity: 1,
      nextUnitPrice: 120,
      canChangeQuantity: true,
      canChangePrice: false,
      linePaid: false,
      otherLinesTotal: 0,
      paidAmount: 0,
    );
    expect(lowered.quantity, 1);
    expect(
      () => planAdisyonQuantityOrPrice(
        currentQuantity: 2,
        currentUnitPrice: 10,
        nextQuantity: 0,
        nextUnitPrice: 10,
        canChangeQuantity: true,
        canChangePrice: true,
        linePaid: false,
        otherLinesTotal: 0,
        paidAmount: 0,
      ),
      throwsA(isA<AdisyonLineDenial>()),
    );
  });

  test('negative price and unauthorized price change are rejected', () {
    expect(parseTurkishMoney('-5'), isNull);
    expect(parseTurkishMoney('120,50'), 120.50);
    expect(parseTurkishMoney('1.200,50'), 1200.50);
    expect(
      () => planAdisyonQuantityOrPrice(
        currentQuantity: 1,
        currentUnitPrice: 120,
        nextQuantity: 1,
        nextUnitPrice: 90,
        canChangeQuantity: true,
        canChangePrice: false,
        linePaid: false,
        otherLinesTotal: 0,
        paidAmount: 0,
      ),
      throwsA(
        predicate((error) => error.toString().contains('Fiyat değiştirme')),
      ),
    );
  });

  test('paid line and partial payment cannot be removed under the paid amount', () {
    expect(
      () => planAdisyonLineRemoval(
        linePaid: true,
        canRemove: true,
        lineTotal: 50,
        billTotal: 100,
        paidAmount: 40,
      ),
      throwsA(predicate((error) => error.toString().contains('Ödemesi alınmış'))),
    );
    expect(
      () => planAdisyonLineRemoval(
        linePaid: false,
        canRemove: true,
        lineTotal: 80,
        billTotal: 100,
        paidAmount: 40,
      ),
      throwsA(predicate((error) => error.toString().contains('alınmış ödemenin'))),
    );
  });

  test('turkish lira formatting uses comma decimals', () {
    expect(formatTurkishLira(360), '₺360,00');
    expect(formatTurkishLira(1200.5), '₺1.200,50');
  });

  testWidgets('line editor updates the quantity and the new total', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                showAdisyonLineEditor(
                  context: context,
                  productName: 'Çay',
                  quantity: 1,
                  unitPrice: 40,
                  canChangePrice: false,
                );
              },
              child: const Text('Aç'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    expect(find.text('Ürünü düzenle'), findsOneWidget);
    expect(find.text('Çay'), findsOneWidget);
    expect(find.byTooltip('Artır'), findsOneWidget);
    expect(find.text('Birim fiyat (değiştirilemez)'), findsOneWidget);
    await tester.tap(find.byTooltip('Artır'));
    await tester.pump();
    expect(find.textContaining('Yeni satır toplamı: ₺80,00'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('Ürünü düzenle'), findsNothing);
  });

  testWidgets('delete asks for confirmation before removing a line', (
    tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                answer = await confirmAdisyonLineRemoval(context);
              },
              child: const Text('Sil'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(find.text('Bu ürünü adisyondan kaldırmak istiyor musunuz?'), findsOneWidget);
    await tester.tap(find.text('Ürünü Kaldır'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
