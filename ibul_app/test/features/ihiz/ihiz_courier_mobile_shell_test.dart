import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/courier/widgets/ihiz_courier_mobile_account.dart';
import 'package:ibul_app/features/ihiz/courier/widgets/ihiz_courier_mobile_home.dart';

void _noop() {}

void main() {
  Widget frame(Size size, Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
          bottomNavigationBar: IhizCourierBottomNav(
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, Size size, Widget child) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(frame(size, child));
    await tester.pump();
  }

  IhizCourierMobileHome home({bool active = false, bool withTask = false}) {
    return IhizCourierMobileHome(
      displayName: active ? 'Ayşe' : null,
      online: active,
      onToggleOnline: () {},
      loading: false,
      onRetry: () {},
      activeTask: active
          ? IhizHomeTask(
              storeName: 'Mağaza',
              destination: 'Müşteri',
              typeLabel: 'İşletme teslimatı',
              status: 'Mağazaya gidiliyor',
              ctaLabel: 'Yola çık',
              onPressed: _noop,
              active: true,
            )
          : null,
      tasks: withTask
          ? [
              IhizHomeTask(
                storeName: 'Kafe',
                destination: 'Adres',
                typeLabel: 'Bağımsız paket',
                distance: '1.2 km',
                eta: '8 dk',
                ctaLabel: 'Paketi teslim al',
                onPressed: _noop,
              ),
            ]
          : const [],
    );
  }

  for (final size in const [Size(360, 780), Size(390, 844), Size(430, 932)]) {
    testWidgets('home empty ${size.width} has no overflow', (tester) async {
      await pump(tester, size, home());
      expect(tester.takeException(), isNull);
      expect(find.text('Uygun teslimatlar'), findsOneWidget);
      expect(find.text('Şu anda uygun teslimat yok.'), findsOneWidget);
      expect(find.text('Sipariş Havuzu'), findsNothing);
      expect(find.text('₺1.250'), findsNothing);
    });

    testWidgets('home active ${size.width} opens map action', (tester) async {
      await pump(tester, size, home(active: true));
      expect(tester.takeException(), isNull);
      expect(find.text('Merhaba, Ayşe'), findsOneWidget);
      expect(find.text('Aktif teslimat'), findsOneWidget);
      expect(find.text('Yola çık'), findsOneWidget);
      expect(find.text('Sipariş Havuzu'), findsNothing);
    });

    testWidgets('account empty ${size.width} has no overflow', (tester) async {
      await pump(
        tester,
        size,
        IhizCourierMobileAccount(
          displayName: null,
          vehicleLabel: null,
          online: false,
          onToggleOnline: () {},
          onEditProfile: () {},
          ratingLabel: '—',
          completedLabel: '—',
          monthEarningsLabel: '—',
          earningsCaption: 'Sunucu kazanç kaydı henüz yok',
          onOpenEarnings: () {},
          documents: const [
            IhizCourierDocStatus(label: 'Ehliyet', status: 'Yüklenmedi'),
          ],
          onSupport: () {},
          onSettings: () {},
          onLogout: () {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Hesabım'), findsWidgets);
      expect(find.text('Çıkış Yap'), findsOneWidget);
      expect(find.text('Aktif'), findsNothing);
      expect(find.text('₺12.480'), findsNothing);
    });
  }

  testWidgets('bottom nav stays at the bottom and does not fill the screen', (
    tester,
  ) async {
    const size = Size(390, 844);
    await pump(tester, size, home());

    final navRect = tester.getRect(find.byType(IhizCourierBottomNav));
    final section = tester.getTopLeft(find.text('Uygun teslimatlar'));
    expect(navRect.height, lessThan(120));
    expect(navRect.bottom, greaterThan(size.height - 40));
    expect(section.dy, lessThan(navRect.top));
    expect(find.text('Uygun teslimatlar'), findsOneWidget);
    expect(find.text('Şu anda uygun teslimat yok.'), findsOneWidget);
  });

  testWidgets('account content sits above the bottom nav at 430', (
    tester,
  ) async {
    const size = Size(430, 932);
    await pump(
      tester,
      size,
      IhizCourierMobileAccount(
        displayName: null,
        vehicleLabel: null,
        online: false,
        onToggleOnline: () {},
        onEditProfile: () {},
        ratingLabel: '—',
        completedLabel: '—',
        monthEarningsLabel: '—',
        earningsCaption: 'Sunucu kazanç kaydı henüz yok',
        onOpenEarnings: () {},
        documents: const [
          IhizCourierDocStatus(label: 'Ehliyet', status: 'Yüklenmedi'),
        ],
        onSupport: () {},
        onSettings: () {},
        onLogout: () {},
      ),
    );
    final navRect = tester.getRect(find.byType(IhizCourierBottomNav));
    final title = tester.getTopLeft(find.text('Hesabım').first);
    expect(navRect.height, lessThan(120));
    expect(title.dy, lessThan(navRect.top));
    expect(find.text('Profilini yönet, performansını takip et ve hesap ayarlarını düzenle.'), findsOneWidget);
    expect(find.text('Çıkış Yap'), findsOneWidget);
  });
}
