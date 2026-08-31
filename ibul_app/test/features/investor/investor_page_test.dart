import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_state.dart';
import 'package:ibul_app/features/investor/investor_page.dart';
import 'package:ibul_app/features/investor/investor_route_paths.dart';
import 'package:ibul_app/features/investor/sections/investor_hero_section.dart';
import 'package:ibul_app/features/investor/sections/investor_market_sections.dart';
import 'package:ibul_app/features/investor/sections/investor_ops_sections.dart';
import 'package:ibul_app/features/investor/sections/investor_story_sections.dart';
import 'package:ibul_app/widgets/web_footer.dart';
import 'package:ibul_app/widgets/web_header.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const testSupabaseUrl = String.fromEnvironment(
    'IBUL_SUPABASE_URL',
    defaultValue: 'https://example.supabase.co',
  );
  const testSupabaseAnonKey = String.fromEnvironment(
    'IBUL_SUPABASE_ANON_KEY',
    defaultValue: 'test-anon-key',
  );

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: testSupabaseUrl,
      anonKey: testSupabaseAnonKey,
    );
  });

  Widget wrap({required Size viewport, required Widget child}) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewport),
          child: child!,
        );
      },
      home: child,
      routes: {
        InvestorRoutePaths.page: (_) => const InvestorPage(),
        '/home': (_) => const Scaffold(body: Text('IBUL_HOME')),
      },
    );
  }

  testWidgets('hero copy and CTAs are present', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        viewport: const Size(1280, 900),
        child: const Scaffold(
          body: SingleChildScrollView(
            child: InvestorHeroSection(
              onDeck: _noop,
              onContact: _noop,
              onExplore: _noop,
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Yerel ticaretin geleceğini inşa ediyoruz.'),
      findsOneWidget,
    );
    expect(find.text('Yatırımcı Sunumunu İncele'), findsNothing);
    expect(find.text('Sunumu incele'), findsOneWidget);
    expect(find.text('İletişime geç'), findsOneWidget);
    expect(find.text('İBUL’u keşfet'), findsOneWidget);
    expect(find.text('Mağaza'), findsWidgets);
    expect(find.text('Butik'), findsOneWidget);
    expect(find.text('Emlak'), findsOneWidget);
    expect(find.text('Oto kiralama'), findsOneWidget);
    expect(find.text('Customer'), findsNothing);
  });

  testWidgets('live and vision product labels are honest', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        viewport: const Size(1280, 1400),
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                InvestorProductsSection(),
                InvestorDeliveryHourSection(),
                InvestorPackagingSection(),
                InvestorTractionSection(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Canlı'), findsWidgets);
    expect(find.text('Vizyon'), findsWidgets);
    expect(find.text('Emlak'), findsWidgets);
    expect(find.textContaining('Her işletme satabilir'), findsOneWidget);
    expect(
      find.textContaining(
        'Kullanıcı, işletme, sipariş, GMV ve gelir rakamları doğrulanınca bağlanacak',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('valuation'), findsNothing);
    expect(find.text('Product Vision'), findsNothing);
  });

  testWidgets('footer Yatırımcı İlişkileri opens investor page', (
    tester,
  ) async {
    const viewport = Size(1600, 900);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: wrap(
          viewport: viewport,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 80),
                  Text('HOME_PAGE'),
                  WebFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Yatırımcı İlişkileri').last, 240);
    await tester.tap(find.text('Yatırımcı İlişkileri').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(InvestorPage), findsOneWidget);
    expect(find.byType(WebHeader), findsOneWidget);
    expect(
      find.text('Yerel ticaretin geleceğini inşa ediyoruz.'),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('problem, emlak product and map popup are visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(
        viewport: const Size(1280, 1600),
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                InvestorWhySection(),
                InvestorProductsSection(),
                InvestorLocalCommerceSection(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Emlak ilanı başka sitede'), findsOneWidget);
    expect(find.text('Emlak ofisi de satar'), findsOneWidget);
    expect(find.text('Oto kiralama'), findsWidgets);
    expect(find.text('Butik'), findsWidgets);
    expect(find.text('Market'), findsWidgets);
    expect(find.text('Emlak'), findsWidgets);
    expect(find.text('Butik Lila'), findsWidgets);
    expect(find.text('Bluz'), findsOneWidget);
    expect(find.text('890 ₺'), findsOneWidget);
    expect(find.textContaining('Popup’ta ürün'), findsWidgets);
  });

  testWidgets('investor page mobile does not overflow', (tester) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(viewport: viewport, child: const InvestorPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.byType(WebHeader), findsNothing);
    expect(find.text('Yatırımcı İlişkileri'), findsWidgets);
    expect(
      find.text('Yerel ticaretin geleceğini inşa ediyoruz.'),
      findsOneWidget,
    );
  });
}

void _noop() {}
