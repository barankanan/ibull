import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/seller/seller_mall_models.dart';
import 'package:ibul_app/features/mall/seller/seller_onboarding_location.dart';
import 'package:ibul_app/features/seller/onboarding/seller_onboarding_chrome.dart';
import 'package:ibul_app/screens/become_seller_page.dart';

const _floors = [
  SellerMallFloorOption(id: 'f-2', name: 'Otopark -2', levelNumber: -2),
  SellerMallFloorOption(id: 'f-1', name: 'Otopark / B1', levelNumber: -1),
  SellerMallFloorOption(id: 'f0', name: 'Zemin Kat', levelNumber: 0),
  SellerMallFloorOption(id: 'f1', name: '1. Kat', levelNumber: 1),
  SellerMallFloorOption(id: 'f2', name: '2. Kat', levelNumber: 2),
  SellerMallFloorOption(id: 'f3', name: '3. Kat', levelNumber: 3),
];

const _primall = SellerMallOption(
  id: 'm1',
  name: 'Primall new',
  city: 'Hatay',
  district: 'İskenderun',
  isVerified: true,
  status: 'active',
  floors: [],
);

const _other = SellerMallOption(
  id: 'm2',
  name: 'XYZ AVM',
  city: 'Hatay',
  district: 'İskenderun',
  isVerified: true,
  status: 'active',
  floors: [SellerMallFloorOption(id: 'x1', name: 'Zemin', levelNumber: 0)],
);

Widget _locationApp({
  SellerOnboardingLocationKind? kind,
  String city = '',
  String district = '',
  SellerAreaMallLoader? listMalls,
  SellerMallFloorLoader? listFloors,
  ValueChanged<SellerOnboardingLocationKind>? onKind,
  ValueChanged<SellerOnboardingMallDraft?>? onMallDraft,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SellerOnboardingLocationStep(
          kind: kind,
          onKind: onKind ?? (_) {},
          standalone: const Text('standalone-map'),
          city: city,
          district: district,
          onPickCityDistrict: () {},
          onMallDraft: onMallDraft,
          listMalls: listMalls ??
              (selectedCity, selectedDistrict) async =>
                  selectedCity.toLowerCase().contains('hatay') &&
                          selectedDistrict.toLowerCase().contains('skenderun')
                      ? const [_primall, _other]
                      : const [],
          listFloors: listFloors ??
              (mallId, _) async => mallId == 'm1' ? _floors : mallId == 'm2' ? _other.floors : const [],
        ),
      ),
    ),
  );
}

Future<void> _fillBusinessStep(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'İşletme Adı *'), 'Tech Store');
  await tester.ensureVisible(find.text('İşletme Türü *'));
  await tester.tap(find.text('İşletme Türü *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Limited Şirket').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextFormField, 'Vergi Numarası *'), '1234567890');
  await tester.ensureVisible(find.text('Ana Ürün Kategorisi *'));
  await tester.tap(find.text('Ana Ürün Kategorisi *'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Elektronik').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Devam Et'));
  await tester.tap(find.text('Devam Et'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('TEST A AVM manager card is gone', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BecomeSellerPage()));
    await tester.pump();

    expect(find.text('AVM yöneticisi misiniz?'), findsNothing);
    expect(find.text('AVM Başvurusu Yap'), findsNothing);
    expect(find.byKey(const ValueKey('seller-mall-manager-card')), findsNothing);
    expect(find.text('İşletme Adı *'), findsOneWidget);
    expect(find.byKey(const ValueKey('seller-onboard-hero')), findsOneWidget);
  });

  testWidgets('TEST B C password mismatch then match', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BecomeSellerPage()));
    await tester.pump();
    await _fillBusinessStep(tester);

    expect(find.byKey(const ValueKey('seller-onboard-password')), findsOneWidget);
    expect(find.byKey(const ValueKey('seller-onboard-password-confirm')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('seller-onboard-password')), 'Test1234');
    await tester.enterText(find.byKey(const ValueKey('seller-onboard-password-confirm')), 'Test123');
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    expect(find.text('2. İletişim Bilgileri'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('seller-onboard-password-confirm')), 'Test1234');
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    expect(find.text('Şifreler eşleşmiyor.'), findsNothing);
  });

  testWidgets('TEST D password visibility toggles independently', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: BecomeSellerPage()));
    await tester.pump();
    await _fillBusinessStep(tester);

    expect(find.descendant(of: find.byKey(const ValueKey('seller-onboard-password-toggle')), matching: find.byIcon(Icons.visibility_off)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('seller-onboard-password-confirm-toggle')), matching: find.byIcon(Icons.visibility_off)), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('seller-onboard-password-toggle')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const ValueKey('seller-onboard-password-toggle')), matching: find.byIcon(Icons.visibility)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('seller-onboard-password-confirm-toggle')), matching: find.byIcon(Icons.visibility_off)), findsOneWidget);
  });

  testWidgets('TEST E F floors load from selected mall id', (tester) async {
    String? loadedId;
    await tester.pumpWidget(_locationApp(
      kind: SellerOnboardingLocationKind.mall,
      city: 'Hatay',
      district: 'İskenderun',
      listFloors: (mallId, _) async {
        loadedId = mallId;
        return mallId == 'm1' ? _floors : const [];
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Seç').first);
    await tester.pumpAndSettle();
    expect(loadedId, 'm1');
    expect(find.byKey(const ValueKey('seller-onboard-floor')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seller-onboard-floor')));
    await tester.pumpAndSettle();
    expect(find.text('Otopark -2').hitTestable(), findsWidgets);
    expect(find.text('1. Kat').hitTestable(), findsWidgets);
    expect(find.text('3. Kat').hitTestable(), findsWidgets);
  });

  testWidgets('TEST G summary updates when floor is chosen', (tester) async {
    SellerOnboardingMallDraft? draft;
    await tester.pumpWidget(_locationApp(
      kind: SellerOnboardingLocationKind.mall,
      city: 'Hatay',
      district: 'İskenderun',
      onMallDraft: (value) => draft = value,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Seç').first);
    await tester.pumpAndSettle();
    expect(draft?.selectedMallId, 'm1');
    expect(draft?.selectedMallName, 'Primall new');

    await tester.tap(find.byKey(const ValueKey('seller-onboard-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Kat').last);
    await tester.pumpAndSettle();
    expect(draft?.floorName, '1. Kat');
    expect(find.textContaining('1. Kat'), findsWidgets);
  });

  testWidgets('TEST H changing mall clears previous floor', (tester) async {
    SellerOnboardingMallDraft? draft;
    await tester.pumpWidget(_locationApp(
      kind: SellerOnboardingLocationKind.mall,
      city: 'Hatay',
      district: 'İskenderun',
      onMallDraft: (value) => draft = value,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Seç').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('seller-onboard-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Kat').last);
    await tester.pumpAndSettle();
    expect(draft?.floorId, 'f1');

    await tester.tap(find.text('AVM değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Seç').at(1));
    await tester.pumpAndSettle();
    expect(draft?.selectedMallId, 'm2');
    expect(draft?.floorId, 'x1');
    expect(draft?.floorName, 'Zemin');
  });

  testWidgets('TEST I standalone still shows map block', (tester) async {
    await tester.pumpWidget(_locationApp(kind: SellerOnboardingLocationKind.standalone));
    await tester.pump();
    expect(find.text('standalone-map'), findsOneWidget);
    expect(find.byKey(const ValueKey('seller-onboard-mall-list')), findsNothing);
  });

  testWidgets('TEST J mall mode does not mount the map widget', (tester) async {
    await tester.pumpWidget(_locationApp(kind: SellerOnboardingLocationKind.mall, city: 'Hatay', district: 'İskenderun'));
    await tester.pumpAndSettle();
    expect(find.text('standalone-map'), findsNothing);
    expect(find.text('Primall new'), findsOneWidget);
  });

  testWidgets('parent summary rows follow partial mall draft', (tester) async {
    tester.view.physicalSize = const Size(1280, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SellerOnboardingMallDraft? draft;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Column(children: [
              SellerOnboardSummary(
                rows: [
                  ('AVM', draft?.selectedMallName ?? '—'),
                  ('Kat', draft?.floorName.isEmpty ?? true ? '—' : draft!.floorName),
                ],
                missing: 0,
                progress: 0.4,
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SellerOnboardingLocationStep(
                    kind: SellerOnboardingLocationKind.mall,
                    onKind: (_) {},
                    standalone: const SizedBox.shrink(),
                    city: 'Hatay',
                    district: 'İskenderun',
                    onPickCityDistrict: () {},
                    onMallDraft: (value) {
                      draft = value;
                      (context as Element).markNeedsBuild();
                    },
                    listMalls: (_, __) async => const [_primall],
                    listFloors: (_, __) async => _floors,
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Seç'));
    await tester.tap(find.widgetWithText(FilledButton, 'Seç'));
    await tester.pumpAndSettle();
    expect(find.text('Primall new'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('seller-onboard-floor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Kat').last);
    await tester.pumpAndSettle();
    expect(find.text('1. Kat'), findsWidgets);
  });
}
