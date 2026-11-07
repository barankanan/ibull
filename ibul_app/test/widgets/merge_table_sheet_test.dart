import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/garson/merge_table_sheet.dart';
import 'package:ibul_app/widgets/garson/transfer_table_modal.dart';

void main() {
  testWidgets('kaynak masa listede yoktur ve hedef seçilmeden birleşmez', (
    tester,
  ) async {
    MergeTableResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await MergeTableSheet.show(
                    context,
                    sourceTable: 2,
                    sourceLabel: 'Bahçe 2',
                    targets: const [
                      TransferTargetTable(
                        tableNumber: 2,
                        label: 'Bahçe 2',
                        isOccupied: true,
                      ),
                      TransferTargetTable(
                        tableNumber: 3,
                        label: 'Salon 1',
                        isOccupied: true,
                      ),
                      TransferTargetTable(tableNumber: 4, label: 'Teras 1'),
                    ],
                    sourceItemCount: 2,
                    sourcePaidLabel: '10,00 ₺',
                    remainingLabel: 'sunucuda hesaplanır',
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

    expect(find.text('Bahçe 2'), findsNothing);
    expect(find.text('Salon 1 · dolu'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Hesapları birleştir'),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.text('Salon 1 · dolu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hesapları birleştir'));
    await tester.pumpAndSettle();

    expect(result?.targetTable, 3);
    expect(result?.targetLabel, 'Salon 1');
  });
}
