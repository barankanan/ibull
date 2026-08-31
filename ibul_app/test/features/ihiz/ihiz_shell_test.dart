import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/ihiz/shell/ihiz_footer.dart';
import 'package:ibul_app/features/ihiz/shell/ihiz_header.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/widgets/custom_header.dart';
import 'package:ibul_app/widgets/web_footer.dart';
import 'package:ibul_app/widgets/web_header.dart';

void main() {
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
        '/home': (_) => const Scaffold(body: Text('IBUL_HOME')),
        '/ihiz': (_) => const IhizCourierPage(),
      },
    );
  }

  Future<void> pumpIhiz(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(viewport: size, child: const IhizCourierPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets('IHIZ desktop uses IHIZ shell not IBUL chrome', (tester) async {
    await pumpIhiz(tester, const Size(1280, 800));

    expect(tester.takeException(), isNull);
    expect(find.byType(IhizHeader), findsOneWidget);
    expect(find.byType(IhizFooter), findsOneWidget);
    expect(find.byType(WebHeader), findsNothing);
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.byType(WebFooter), findsNothing);
    expect(find.text('Erkek'), findsNothing);
    expect(find.text('Kadın'), findsNothing);
    expect(find.text('Yakın Lokasyon'), findsNothing);
    expect(find.text('Teslimat Takibi'), findsWidgets);
    expect(find.textContaining('Teslimatın yeni hızı'), findsWidgets);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Kurye Ol'), findsWidgets);
  });

  testWidgets('IHIZ mobile uses IHIZ header menu not marketplace header', (
    tester,
  ) async {
    await pumpIhiz(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.byType(IhizHeader), findsOneWidget);
    expect(find.byType(IhizFooter), findsOneWidget);
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.byType(WebHeader), findsNothing);
    expect(find.byType(WebFooter), findsNothing);
    expect(find.text('Erkek'), findsNothing);
    expect(find.byTooltip('Menü'), findsOneWidget);

    await tester.tap(find.byTooltip('Menü'));
    await tester.pump();
    expect(find.text('Ana Sayfa'), findsWidgets);
    expect(find.text('Nasıl Çalışır?'), findsWidgets);
  });

  testWidgets('IHIZ tablet uses IHIZ menu not marketplace header', (
    tester,
  ) async {
    await pumpIhiz(tester, const Size(768, 1024));

    expect(tester.takeException(), isNull);
    expect(find.byType(IhizHeader), findsOneWidget);
    expect(find.byType(IhizFooter), findsOneWidget);
    expect(find.byType(WebHeader), findsNothing);
    expect(find.byType(CustomHeader), findsNothing);
    expect(find.text('Erkek'), findsNothing);
    expect(find.byTooltip('Menü'), findsOneWidget);
  });

  testWidgets('IHIZ footer returns to IBUL home', (tester) async {
    const size = Size(1280, 800);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(size: size),
            child: child!,
          );
        },
        initialRoute: '/ihiz',
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          final page = name == '/ihiz'
              ? const IhizCourierPage()
              : const Scaffold(body: Text('IBUL_HOME'));
          return PageRouteBuilder<void>(
            settings: settings,
            pageBuilder: (_, __, ___) => page,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IhizCourierPage), findsOneWidget);

    tester.widget<InkWell>(find.byKey(IhizFooter.returnToIbulKey)).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('IBUL_HOME'), findsOneWidget);
    expect(find.byType(IhizHeader), findsNothing);
    expect(find.byType(IhizCourierPage), findsNothing);
  });
}
