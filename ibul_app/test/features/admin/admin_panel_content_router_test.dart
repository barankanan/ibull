import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/admin/panel/routing/admin_panel_content_router.dart';
import 'package:ibul_app/features/admin/panel/widgets/admin_panel_state_widgets.dart';

void main() {
  testWidgets('Kampanya & İçerik uses system layout page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildAdminPanelContent(
          selectedMenu: 'Kampanya & İçerik',
          hasSelectedMenuAccess: true,
          systemLayoutPage: const Text('LAYOUT_SENTINEL'),
        ),
      ),
    );

    expect(find.text('LAYOUT_SENTINEL'), findsOneWidget);
  });

  testWidgets('İHIZ Finans shows preparing state instead of blank', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildIhizAdminPanelContent(selectedMenu: 'Finans'),
      ),
    );

    expect(find.textContaining('İHIZ Finans'), findsOneWidget);
    expect(find.textContaining('hazırlanıyor'), findsOneWidget);
  });

  testWidgets('access denied copy is Turkish', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: buildAdminPanelContent(
          selectedMenu: 'Finans',
          hasSelectedMenuAccess: false,
          systemLayoutPage: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Bu modül için erişiminiz yok'), findsOneWidget);
    expect(find.byType(AdminAccessDeniedState), findsOneWidget);
  });
}
