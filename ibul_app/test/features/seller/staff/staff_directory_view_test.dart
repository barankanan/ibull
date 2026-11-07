import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_directory_view.dart';
import 'package:ibul_app/models/sub_admin.dart';

void main() {
  testWidgets('delete stays closed until the contact is typed', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaffDirectoryView(
            staff: [
              SubAdmin(
                id: '1',
                email: 'garson@ibul.test',
                permissions: const [SellerPermission.viewOrders],
                status: 'active',
              ),
            ],
            onInvite: () {},
            onEditPermissions: (_) {},
            onSetStatus: (_, __) async {},
            onDelete: (_) async {
              deleted = true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Güvenli sil'));
    await tester.pumpAndSettle();
    expect(find.text('Sil'), findsOneWidget);
    final deleteButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sil'),
    );
    expect(deleteButton.onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'garson@ibul.test');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
