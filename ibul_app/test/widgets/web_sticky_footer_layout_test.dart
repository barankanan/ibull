import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/ibul_chrome.dart';
import 'package:ibul_app/widgets/web_footer.dart';
import 'package:ibul_app/widgets/web_sticky_footer_scroll_view.dart';

void main() {
  for (final size in const [
    Size(1440, 900),
    Size(1366, 768),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'short page keeps footer clearance at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pumpShell(
          tester,
          size: size,
          child: const SizedBox(height: 160, child: Text('SHORT')),
        );
        final footer = tester.getRect(find.byType(WebFooter));
        final content = tester.getRect(find.text('SHORT'));
        final clearance = footer.top - content.bottom;
        expect(
          clearance,
          greaterThanOrEqualTo(IbulChrome.footerShortClearanceDesktop - 1),
        );
        expect(footer.bottom, greaterThan(size.height));
        expect(footer.width, lessThanOrEqualTo(size.width + 1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('second short page uses the same clearance', (tester) async {
    const size = Size(1440, 900);
    await _pumpShell(
      tester,
      size: size,
      child: const SizedBox(height: 80, child: Text('OTHER')),
    );
    final footer = tester.getRect(find.byType(WebFooter));
    final content = tester.getRect(find.text('OTHER'));
    expect(
      footer.top - content.bottom,
      greaterThanOrEqualTo(IbulChrome.footerShortClearanceDesktop - 1),
    );
    expect(footer.bottom, greaterThan(size.height));
  });

  testWidgets('long page uses the smaller footer spacing', (tester) async {
    const size = Size(1440, 900);
    await _pumpShell(
      tester,
      size: size,
      child: const SizedBox(height: 2000, child: Text('LONG')),
    );
    final footer = tester.getRect(find.byType(WebFooter));
    final content = tester.getRect(find.text('LONG'));
    expect(
      footer.top - content.bottom,
      closeTo(IbulChrome.footerLongSpacingDesktop, 2),
    );
    expect(footer.top, greaterThan(size.height));
    expect(tester.takeException(), isNull);
  });

  testWidgets('short sliver page uses the same clearance', (tester) async {
    const size = Size(1440, 900);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(height: 72, child: Text('HEADER')),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(height: 120, child: Text('RESULTS')),
                    ),
                    WebStickyFooterEndSliver(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final footer = tester.getRect(find.byType(WebFooter));
    final content = tester.getRect(find.text('RESULTS'));
    expect(
      footer.top - content.bottom,
      greaterThanOrEqualTo(IbulChrome.footerShortClearanceDesktop - 1),
    );
    expect(footer.bottom, greaterThan(size.height));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(1440, 900), Size(1920, 1080)]) {
    testWidgets(
      'avm-sized short page keeps clearance at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await _pumpShell(
          tester,
          size: size,
          child: const SizedBox(height: 420, child: Text('AVM')),
        );
        final footer = tester.getRect(find.byType(WebFooter));
        final content = tester.getRect(find.text('AVM'));
        expect(
          footer.top - content.bottom,
          greaterThanOrEqualTo(IbulChrome.footerShortClearanceDesktop - 1),
        );
        expect(footer.bottom, greaterThan(size.height));
      },
    );
  }

  testWidgets('tablet short page uses tablet clearance', (tester) async {
    const size = Size(800, 900);
    await _pumpShell(
      tester,
      size: size,
      child: const SizedBox(height: 120, child: Text('TABLET')),
    );
    final footer = tester.getRect(find.byType(WebFooter));
    final content = tester.getRect(find.text('TABLET'));
    expect(
      footer.top - content.bottom,
      greaterThanOrEqualTo(IbulChrome.footerShortClearanceTablet - 1),
    );
    expect(footer.bottom, greaterThan(size.height));
  });

  test('pages do not construct WebFooter outside the shell', () {
    const allowed = {
      'lib/widgets/web_footer.dart',
      'lib/widgets/web_sticky_footer_scroll_view.dart',
    };
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final relative = path.contains('/lib/')
          ? 'lib/${path.split('/lib/').last}'
          : path;
      if (allowed.contains(relative)) continue;
      final source = entity.readAsStringSync();
      if (source.contains('WebFooter(')) offenders.add(relative);
    }
    expect(offenders, isEmpty);
  });

  testWidgets('mobile short page uses the smaller clearance', (tester) async {
    const size = Size(390, 844);
    await _pumpShell(
      tester,
      size: size,
      child: const SizedBox(height: 80, child: Text('MOBILE')),
    );
    final footer = tester.getRect(find.byType(WebFooter));
    final content = tester.getRect(find.text('MOBILE'));
    expect(
      footer.top - content.bottom,
      greaterThanOrEqualTo(IbulChrome.footerShortClearanceMobile - 1),
    );
    expect(
      footer.top - content.bottom,
      lessThan(IbulChrome.footerShortClearanceDesktop),
    );
    expect(footer.left, greaterThanOrEqualTo(-1));
    expect(footer.right, lessThanOrEqualTo(size.width + 1));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MarketplaceWebPageShell(
        header: const SizedBox(height: 72, child: Text('HEADER')),
        child: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
