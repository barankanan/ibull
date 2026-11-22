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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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

bool _wide(Size size) => size.width >= 1000;

/// Geniş ekranda özet sağ panelde hazırdır; dar ekranda Önizleme alt sayfası açılır.
Future<void> _showSummary(WidgetTester tester, Size size) async {
  if (_wide(size)) return;
  await tester.tap(find.text('Önizleme'));
  await tester.pumpAndSettle();
}

Future<void> _hideSummary(WidgetTester tester, Size size) async {
  if (_wide(size)) return;
  await tester.tap(find.byTooltip('Kapat').last);
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
      await _showSummary(tester, size);
      expect(find.text('Masa kapatamaz'), findsOneWidget);
      expect(find.text('Sipariş gönderebilir'), findsOneWidget);
      expect(find.text('Personel şifresi değiştiremez'), findsOneWidget);
      await _hideSummary(tester, size);

      // Garson sayfası -> Tam yönetim: özet Masa kapatabilir olur
      final garsonFull = find.byKey(const ValueKey('page-level-garson-full'));
      await _scrollTo(tester, garsonFull);
      await tester.tap(garsonFull);
      await tester.pumpAndSettle();
      await _showSummary(tester, size);
      expect(find.text('Masa kapatabilir'), findsOneWidget);
      expect(find.text('Masa aktarabilir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _hideSummary(tester, size);

      // Geri Al: özet ilk durumuna döner
      await tester.tap(find.text('Geri Al'));
      await tester.pumpAndSettle();
      await _showSummary(tester, size);
      expect(find.text('Masa kapatamaz'), findsOneWidget);
      expect(find.text('Masa kapatabilir'), findsNothing);
      await _hideSummary(tester, size);

      // Önizleme: sunucuya gidecek yetkiler görünür
      await _showSummary(tester, size);
      if (_wide(size)) await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();
      expect(find.text('Sunucuya kaydedilecek yetkiler'), findsOneWidget);
      expect(find.textContaining('manageOrders'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
