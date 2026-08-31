import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/shell/ihiz_footer.dart';
import 'package:ibul_app/features/ihiz/shell/ihiz_header.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:ibul_app/widgets/web_footer.dart';
import 'package:ibul_app/widgets/web_header.dart';
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

  Widget wrapWithViewport({
    required Size viewport,
    required Widget child,
  }) {
    return MaterialApp(
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewport),
          child: child!,
        );
      },
      home: child,
      routes: {
        '/ihiz': (_) => const IhizCourierPage(),
        '/home': (_) => const Scaffold(body: Text('IBUL_HOME')),
      },
    );
  }

  testWidgets('WebFooter Admin Paneli linki gorunur', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      wrapWithViewport(
        viewport: const Size(1600, 900),
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 120),
                Text('HOME_PAGE'),
                SizedBox(height: 24),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('HOME_PAGE'), findsOneWidget);
    expect(find.text('Admin Paneli'), findsOneWidget);
  });

  testWidgets('WebFooter Ihiz linki profesyonel landing acar', (
    WidgetTester tester,
  ) async {
    const viewport = Size(390, 844);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      wrapWithViewport(
        viewport: viewport,
        child: const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 200),
                Text('HOME_PAGE'),
                SizedBox(height: 24),
                WebFooter(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('İhız').last, 300);
    await tester.tap(find.text('İhız').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(IhizCourierPage), findsOneWidget);
    expect(find.byType(IhizHeader), findsOneWidget);
    expect(find.byType(IhizFooter), findsOneWidget);
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.byType(WebHeader), findsNothing);
    expect(
      find.descendant(
        of: find.byType(IhizCourierPage),
        matching: find.byType(WebFooter),
      ),
      findsNothing,
    );
    expect(find.textContaining('Teslimatın yeni hızı'), findsWidgets);
    expect(find.text('Hızlı Teslimat'), findsWidgets);
    expect(find.text('Canlı Takip'), findsWidgets);
    expect(find.text('Güvenli Teslimat'), findsOneWidget);
    expect(find.text('Yerel Kurye Ağı'), findsOneWidget);
    expect(find.text('Sipariş havuzu'), findsNothing);
    expect(find.text('Havuz sistemi aktif'), findsNothing);
  });

  testWidgets('Ihiz landing mobile overflow yok', (WidgetTester tester) async {
    const viewport = Size(360, 800);
    await tester.binding.setSurfaceSize(viewport);
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      wrapWithViewport(
        viewport: viewport,
        child: const IhizCourierPage(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Teslimatın yeni hızı'), findsWidgets);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Kurye Ol'), findsWidgets);
  });
}
