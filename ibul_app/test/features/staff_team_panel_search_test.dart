import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/features/seller/staff/staff_team_panel.dart';
import 'package:ibul_app/models/sub_admin.dart';
import 'package:ibul_app/utils/text_normalizer.dart';

SubAdmin _member(String id, String name) => SubAdmin(
  id: id,
  displayName: name,
  email: '$id@example.test',
  permissions: const <SellerPermission>[],
  status: 'active',
);

Future<void> _pumpPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: StaffTeamPanel(
            kind: StaffBusinessKind.restaurant,
            members: <SubAdmin>[
              _member('a', 'İsmail Işık'),
              _member('b', 'Çağla Öztürk'),
            ],
            isOwner: true,
            heldPermissions: const <String>{},
            loadBranches: () async => const <Map<String, dynamic>>[],
            onCreate: (_) async {},
            onEdit: (_, _) async {},
            onDeactivate: (_) async {},
            onDelete: (_) async {},
            onActivate: (_) async {},
            canDelete: (_) => null,
            canManage: true,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('plain lowercasing cannot match Turkish dotless i', () {
    // Kök neden kanıtı: Dart "I" harfini "i" yapar (Türkçe "ı" değil), bu
    // yüzden Türkçe klavyeyle yazılan "ışık" / "ızgara" sorguları "Işık" /
    // "IZGARA" adlarını bulamaz.
    expect('Işık'.toLowerCase().contains('ışık'), isFalse);
    expect('IZGARA'.toLowerCase().contains('ızgara'), isFalse);
    String n(String v) => TextNormalizer.normalize(v);
    expect(n('Işık').contains(n('ışık')), isTrue);
    expect(n('IZGARA').contains(n('ızgara')), isTrue);
    expect(n('İsmail').contains(n('ismail')), isTrue);
  });

  testWidgets('staff search finds Turkish names typed in plain lowercase', (
    tester,
  ) async {
    await _pumpPanel(tester);
    expect(find.text('İsmail Işık'), findsOneWidget);
    expect(find.text('Çağla Öztürk'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ışık');
    await tester.pumpAndSettle();
    expect(find.text('İsmail Işık'), findsOneWidget);
    expect(find.text('Çağla Öztürk'), findsNothing);

    await tester.enterText(find.byType(TextField), 'ismail');
    await tester.pumpAndSettle();
    expect(find.text('İsmail Işık'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ISIK');
    await tester.pumpAndSettle();
    expect(find.text('İsmail Işık'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cagla');
    await tester.pumpAndSettle();
    expect(find.text('Çağla Öztürk'), findsOneWidget);
    expect(find.text('İsmail Işık'), findsNothing);
  });
}
