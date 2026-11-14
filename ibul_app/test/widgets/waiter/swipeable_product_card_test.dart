import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/waiter/swipeable_product_card.dart';

void main() {
  testWidgets('swipe schedules edit after the card snaps back', (tester) async {
    var edits = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwipeableProductCard(
            productKey: 'cay',
            onEdit: () => edits++,
            onQuickRemove: () {},
            child: const SizedBox(
              key: Key('card'),
              height: 72,
              width: 320,
              child: Text('Ekle'),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(const Key('card')), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(edits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused product sheet pops after the field releases dependents', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (sheetContext) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const TextField(autofocus: true),
                            TextButton(
                              onPressed: () =>
                                  popGarsonProductSheet(sheetContext, 'ok'),
                              child: const Text('Onayla'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
                child: const Text('Aç'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Onayla'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
