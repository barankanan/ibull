import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_account_dialog.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/models/sub_admin.dart';

SubAdmin _member() => SubAdmin(
      id: 'm1',
      email: 'a@b.co',
      displayName: 'Test Personel',
      staffRole: 'sub_admin',
      jobTitle: 'Alt Yönetici',
      branchId: 'branch-1',
      permissions: const [
        SellerPermission.viewOrders,
        SellerPermission.manageOrders,
      ],
      status: 'active',
      createdAt: DateTime(2026, 11, 1),
    );

Future<void> _open(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showStaffAccountDialog(
            context: context,
            kind: StaffBusinessKind.restaurant,
            isOwner: true,
            heldPermissions: const <String>{},
            branches: const [
              <String, dynamic>{'id': 'branch-1', 'name': 'Merkez'},
            ],
            editing: _member(),
            onSubmit: (_) async {},
          ),
          child: const Text('Aç'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable).first;
  // Önce en üste dön; sonra hedefe kadar aşağı kaydır.
  await tester.drag(list, const Offset(0, 6000));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder, 200, scrollable: list);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in const [Size(360, 740), Size(1280, 800)]) {
    testWidgets('personel yetki ekranı ${size.width.toInt()}px: başlık, özet, düzey, geri al', (
      tester,
    ) async {
      await _open(tester, size);
      // Detaylar
      expect(find.text('Test Personel'), findsAtLeastNWidgets(1));
      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Merkez'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Canlı özet: sipariş var, masa kapatma yok
      final summary = find.text('Masa kapatamaz');
      await _scrollTo(tester, summary);
      expect(find.text('Sipariş gönderebilir'), findsOneWidget);
      expect(find.text('Personel şifresi değiştiremez'), findsOneWidget);

      // Garson sayfası -> Tam yönetim: özet Masa kapatabilir olur
      final garsonFull = find.byKey(const ValueKey('page-level-garson-full'));
      await _scrollTo(tester, garsonFull);
      await tester.tap(garsonFull);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Masa kapatabilir'));
      expect(find.text('Masa kapatabilir'), findsOneWidget);
      expect(find.text('Masa aktarabilir'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Geri al: özet ilk durumuna döner
      await tester.tap(find.text('Geri al'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('Masa kapatamaz'));
      expect(find.text('Masa kapatabilir'), findsNothing);

      // Önizleme
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();
      expect(find.text('Sunucuya kaydedilecek yetkiler'), findsOneWidget);
      expect(find.textContaining('manageOrders'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
