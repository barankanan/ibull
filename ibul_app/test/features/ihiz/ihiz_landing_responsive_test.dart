import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/ihiz_landing_body.dart';
import 'package:ibul_app/features/ihiz/theme/ihiz_brand.dart';

void main() {
  Widget harness({required Size size, required Widget child}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: IhizBrand.contentMaxWidth,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IhizLandingBody landing() => IhizLandingBody(
        onLogin: () {},
        onCourierApply: () {},
        onBusinessJoin: () {},
        onBindBusiness: (_) {},
        onPackageSend: () {},
        onSubmitTracking: (_) {},
        howItWorksKey: GlobalKey(),
      );

  Future<void> pumpLanding(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(harness(size: size, child: landing()));
    // Landing tracking is a real input, not a looping mock animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('landing mobile 390x844 no overflow + CTAs present',
      (tester) async {
    await pumpLanding(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Kurye Ol'), findsWidgets);
    expect(find.text('Nasıl Çalışır?'), findsWidgets);
    expect(find.text('Mağaza'), findsWidgets);
    expect(find.text('İhız'), findsWidgets);
  });

  testWidgets('landing tablet 768x1024 no overflow', (tester) async {
    await pumpLanding(tester, const Size(768, 1024));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('hızlı teslimat altyapısı'), findsOneWidget);
    expect(find.text('İşletmeyi Bul'), findsOneWidget);
  });

  testWidgets('landing desktop 1280x800 feature cards present', (tester) async {
    await pumpLanding(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Daha hızlı teslimat'), findsOneWidget);
    expect(find.text('Daha az operasyon'), findsOneWidget);
    expect(find.text('Daha iyi müşteri deneyimi'), findsOneWidget);
    expect(IhizBrand.useWideGrid(1220 - 64), isTrue);
  });
}
