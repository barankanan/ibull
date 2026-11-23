import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/features/seller/staff/staff_team_panel.dart';
import 'package:ibul_app/models/sub_admin.dart';

SubAdmin _member(String id, String name, {String status = 'active'}) =>
    SubAdmin(
      id: id,
      displayName: name,
      email: '$id@example.test',
      permissions: const <SellerPermission>[],
      status: status,
    );

Future<List<String>> _pump(
  WidgetTester tester, {
  required Size size,
  bool isOwner = true,
  bool canManage = true,
  List<SubAdmin>? members,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: StaffTeamPanel(
            kind: StaffBusinessKind.restaurant,
            members: members ??
                <SubAdmin>[
                  _member('a', 'Ayşe Yılmaz'),
                  _member('b', 'Mehmet Kaya', status: 'inactive'),
                ],
            isOwner: isOwner,
            heldPermissions: const <String>{},
            loadBranches: () async => const <Map<String, dynamic>>[],
            onCreate: (_) async {},
            onEdit: (_, _) async {},
            onDeactivate: (m) async => calls.add('deactivate:${m.id}'),
            onDelete: (m) async => calls.add('delete:${m.id}'),
            onActivate: (m) async => calls.add('activate:${m.id}'),
            canDelete: (_) => null,
            canManage: canManage,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('kart: ad, durum rozeti ve tek "Yetkileri düzenle" düğmesi', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 900));
    expect(find.text('Ayşe Yılmaz'), findsOneWidget);
    expect(find.text('Aktif'), findsWidgets);
    expect(find.text('Pasif'), findsWidgets);
    expect(find.text('Yetkileri düzenle'), findsNWidgets(2));
    // Eski mükerrer düğmeler artık yok.
    expect(find.text('Düzenle'), findsNothing);
    expect(find.text('Yetkiler'), findsNothing);
  });

  testWidgets('telefon genişliğinde taşma yok', (tester) async {
    await _pump(tester, size: const Size(360, 740));
    expect(tester.takeException(), isNull);
  });

  testWidgets('menü: sahip için Pasifleştir çalışır, aktif olmayan için pasif', (
    tester,
  ) async {
    final calls = await _pump(tester, size: const Size(1200, 900));
    await tester.tap(find.byTooltip('Diğer işlemler').first);
    await tester.pumpAndSettle();
    expect(find.text('Aktifleştir'), findsOneWidget);
    expect(find.text('Sil'), findsOneWidget);
    await tester.tap(find.text('Pasifleştir'));
    await tester.pumpAndSettle();
    expect(calls, <String>['deactivate:a']);
  });

  testWidgets('sahip değilse Aktifleştir ve Şifre belirle hiç gösterilmez', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 900), isOwner: false);
    await tester.tap(find.byTooltip('Diğer işlemler').first);
    await tester.pumpAndSettle();
    expect(find.text('Aktifleştir'), findsNothing);
    expect(find.text('Şifre belirle'), findsNothing);
  });

  testWidgets('yönetim yetkisi yoksa düzenleme ve menü kapalı (fail-closed)', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1200, 900), canManage: false);
    final edit = tester.widget<FilledButton>(find.byType(FilledButton).first);
    expect(edit.onPressed, isNull);
    final menu = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>).first,
    );
    expect(menu.enabled, isFalse);
  });

  for (final size in const [Size(360, 740), Size(820, 1100), Size(1400, 900)]) {
    testWidgets('yetki editörü ${size.width.toInt()}px genişlikte açılır, taşma yok', (
      tester,
    ) async {
      await _pump(tester, size: size);
      await tester.tap(find.text('Yetkileri düzenle').first);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
