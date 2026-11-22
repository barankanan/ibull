import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/staff/staff_account_dialog.dart';
import 'package:ibul_app/features/seller/staff/staff_business_catalog.dart';
import 'package:ibul_app/features/seller/staff/staff_live_summary.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Future<void> Function(StaffAccountDraft) onSubmit,
  bool editing = true,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
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
            editing: editing ? _member() : null,
            onSubmit: onSubmit,
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
  await tester.scrollUntilVisible(finder, 200, scrollable: list);
  await tester.pumpAndSettle();
}

Future<void> _tapPage(WidgetTester tester, String page, String level) async {
  final finder = find.byKey(ValueKey('page-level-$page-$level'));
  await _scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ButtonStyleButton _button(WidgetTester tester, Finder inside) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(of: inside, matching: find.bySubtype<ButtonStyleButton>()),
    );

Future<void> _noop(StaffAccountDraft draft) async {}

void main() {
  group('düzen: taşma yok', () {
    final cases = <String, (Size, double)>{
      'masaüstü 1280x800': (const Size(1280, 800), 1.0),
      'tablet 800x900': (const Size(800, 900), 1.0),
      'mobil 390x844': (const Size(390, 844), 1.0),
      'mobil 390x844 yazı 1.3': (const Size(390, 844), 1.3),
      'dar 320x640 yazı 1.3': (const Size(320, 640), 1.3),
    };
    cases.forEach((name, spec) {
      for (final editing in [true, false]) {
        testWidgets('$name ${editing ? 'düzenleme' : 'yeni'}', (tester) async {
          await _pump(
            tester,
            size: spec.$1,
            onSubmit: _noop,
            editing: editing,
            textScale: spec.$2,
          );
          expect(tester.takeException(), isNull);
          expect(find.text('Personel bilgileri'), findsOneWidget);
          // Tüm form boyunca kaydır; hiçbir satır taşmamalı.
          final list = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(list, const Offset(0, -500));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Hata bandı dahil alt çubuk taşmamalı.
          await tester.tap(find.byKey(const ValueKey('staff-save-button')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    });

    testWidgets('masaüstü iki panel: özet sağda, alt çubuk sabit', (tester) async {
      await _pump(tester, size: const Size(1280, 800), onSubmit: _noop);
      expect(find.text('Canlı yetki özeti'), findsOneWidget);
      expect(find.text('Kullanabileceği sayfalar'), findsOneWidget);
      expect(find.text('Yapabileceği işlemler'), findsOneWidget);
      expect(find.text('Kullanamayacağı işlemler'), findsOneWidget);
      expect(find.text('Önemli güvenlik uyarıları'), findsOneWidget);
      final footer = tester.getRect(find.byKey(const ValueKey('staff-save-button')));
      final body = tester.getRect(find.byType(SingleChildScrollView).first);
      expect(body.bottom <= footer.top, isTrue);
      final dialog = tester.getSize(find.byKey(const ValueKey('staff-dialog-box')));
      expect(dialog.width <= 1120 && dialog.height <= 760, isTrue);
    });

    testWidgets('mobilde özet Önizleme alt sayfasında', (tester) async {
      await _pump(tester, size: const Size(390, 844), onSubmit: _noop);
      expect(find.text('Canlı yetki özeti'), findsNothing);
      await tester.tap(find.text('Önizleme'));
      await tester.pumpAndSettle();
      expect(find.text('Canlı yetki özeti'), findsOneWidget);
      expect(find.text('Kullanamayacağı işlemler'), findsOneWidget);
    });
  });

  group('gönderilen veri', () {
    testWidgets('Tam yönetim: sayfanın tüm işlem izinlerini gönderir', (tester) async {
      StaffAccountDraft? sent;
      await _pump(
        tester,
        size: const Size(1280, 800),
        onSubmit: (draft) async => sent = draft,
      );
      await _tapPage(tester, 'garson', 'full');
      await tester.tap(find.byKey(const ValueKey('staff-save-button')));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      final full = pageFullAccessOperations(SellerModule.garson);
      expect(sent!.permissions.toSet().containsAll(full), isTrue);
      expect(sent!.visibleModules, contains('garson'));
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Görüntüle: yalnız okuma izni, yönetim izni silinir', (tester) async {
      StaffAccountDraft? sent;
      await _pump(
        tester,
        size: const Size(390, 844),
        onSubmit: (draft) async => sent = draft,
      );
      await _tapPage(tester, 'orders', 'view');
      await _tapPage(tester, 'garson', 'none');
      await tester.tap(find.byKey(const ValueKey('staff-save-button')));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(sent!.permissions, contains(SellerPermission.viewOrders));
      expect(sent!.permissions, isNot(contains(SellerPermission.manageOrders)));
      expect(sent!.visibleModules, contains('orders'));
      expect(sent!.visibleModules, isNot(contains('garson')));
    });

    testWidgets('Erişim yok: sayfa listeden çıkar', (tester) async {
      StaffAccountDraft? sent;
      await _pump(
        tester,
        size: const Size(1280, 800),
        onSubmit: (draft) async => sent = draft,
      );
      await _tapPage(tester, 'orders', 'none');
      await tester.tap(find.byKey(const ValueKey('staff-save-button')));
      await tester.pumpAndSettle();
      expect(sent!.visibleModules, isNot(contains('orders')));
    });
  });

  group('canlı özet ve Geri Al', () {
    for (final size in const [Size(1280, 800), Size(390, 844)]) {
      testWidgets('izin açılınca özet ve uyarı değişir, Geri Al geri alır ${size.width.toInt()}', (
        tester,
      ) async {
        await _pump(tester, size: size, onSubmit: _noop);
        final wide = size.width >= 1000;
        Future<void> openSummary() async {
          if (!wide) {
            await tester.tap(find.text('Önizleme'));
            await tester.pumpAndSettle();
          }
        }

        Future<void> closeSummary() async {
          if (!wide) {
            await tester.tap(find.byTooltip('Kapat').last);
            await tester.pumpAndSettle();
          }
        }

        final revert = find.text('Geri Al');
        expect(_button(tester, revert).onPressed, isNull);
        await openSummary();
        expect(find.text('Masa kapatamaz'), findsOneWidget);
        expect(find.textContaining('Masa kapatma açık'), findsNothing);
        await closeSummary();

        final toggle = find.byKey(const ValueKey('perm-closeBill'));
        await _scrollTo(tester, toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yetkiyi ver'));
        await tester.pumpAndSettle();
        expect(_button(tester, revert).onPressed, isNotNull);
        expect(find.text('Kaydedilmemiş değişiklikler var'), findsOneWidget);
        await openSummary();
        expect(find.text('Masa kapatabilir'), findsOneWidget);
        expect(find.textContaining('Masa kapatma açık'), findsOneWidget);
        await closeSummary();

        await tester.tap(revert);
        await tester.pumpAndSettle();
        expect(_button(tester, revert).onPressed, isNull);
        expect(find.text('Kaydedilmemiş değişiklikler var'), findsNothing);
        await openSummary();
        expect(find.text('Masa kapatamaz'), findsOneWidget);
        expect(find.textContaining('Masa kapatma açık'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    test('uyarılar: hassas izinler ve sayfasızlık', () {
      expect(
        staffSecurityWarnings(selected: <SellerPermission>{}, hasPages: false),
        hasLength(1),
      );
      final warnings = staffSecurityWarnings(
        selected: <SellerPermission>{
          SellerPermission.manageStaff,
          SellerPermission.closeBill,
          SellerPermission.managePrintSettings,
        },
        hasPages: true,
      );
      expect(warnings, hasLength(3));
    });
  });

  group('kaydetme', () {
    testWidgets('hata: pencere açık kalır, satır içi hata görünür, form korunur', (
      tester,
    ) async {
      await _pump(
        tester,
        size: const Size(1280, 800),
        onSubmit: (_) async => throw Exception('Sunucu reddetti'),
      );
      await _tapPage(tester, 'garson', 'full');
      await tester.tap(find.byKey(const ValueKey('staff-save-button')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('staff-dialog-error')),
          matching: find.text('Sunucu reddetti'),
        ),
        findsOneWidget,
      );
      expect(
        _button(tester, find.text('Kaydet')).onPressed,
        isNotNull,
      );
      expect(find.text('Masa kapatabilir'), findsOneWidget);
    });

    testWidgets('işlem sürerken Kaydet pasif ve ilerleme görünür; onay gelince kapanır', (
      tester,
    ) async {
      final completer = Completer<void>();
      await _pump(
        tester,
        size: const Size(390, 844),
        onSubmit: (_) => completer.future,
      );
      await tester.tap(find.byKey(const ValueKey('staff-save-button')));
      await tester.pump();
      final save = tester.widget<FilledButton>(
        find.byKey(const ValueKey('staff-save-button')),
      );
      expect(save.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Kaydediliyor...'), findsOneWidget);
      expect(find.byType(Dialog), findsOneWidget);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    });
  });
}
