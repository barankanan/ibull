import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/ibul_chrome.dart';
import 'package:ibul_app/features/ihiz/theme/ihiz_brand.dart';
import 'package:ibul_app/responsive/breakpoints.dart';
import 'package:ibul_app/widgets/home_header_shell.dart';
import 'package:ibul_app/widgets/web_footer.dart';

void main() {
  test('marketplace chrome web is 1100 and shared with ScreenBreakpoints', () {
    expect(IbulChrome.web, 1100);
    expect(IbulChrome.web, ScreenBreakpoints.marketplaceWeb);
    expect(IbulChrome.maxContentWidth, ScreenBreakpoints.maxContentWidth);
    expect(IbulChrome.isWeb(1099), isFalse);
    expect(IbulChrome.isWeb(1100), isTrue);
    expect(IbulChrome.isFooterCompact(919), isTrue);
    expect(IbulChrome.isFooterCompact(920), isFalse);
  });

  test('İHIZ desktop stays 1024 and does not inherit marketplace 1100', () {
    expect(IhizBrand.desktopMin, 1024);
    expect(IhizBrand.isDesktop(1023), isFalse);
    expect(IhizBrand.isDesktop(1024), isTrue);
    expect(IhizBrand.isDesktop(1099), isTrue);
    expect(IbulChrome.isWeb(1024), isFalse);
  });

  test('chrome widgets share IbulChrome; İHIZ shell does not import it', () {
    const chromeFiles = [
      'lib/widgets/web_header.dart',
      'lib/widgets/home_header_shell.dart',
      'lib/widgets/web_footer.dart',
      'lib/screens/home_screen_core.dart',
      'lib/screens/home_screen_deferred_entry.dart',
      'lib/screens/product_detail_page.dart',
    ];
    for (final path in chromeFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('ibul_chrome.dart'), reason: path);
      expect(source, contains('IbulChrome.'), reason: path);
    }

    const ihizFiles = [
      'lib/features/ihiz/shell/ihiz_header.dart',
      'lib/features/ihiz/shell/ihiz_footer.dart',
      'lib/features/ihiz/theme/ihiz_brand.dart',
    ];
    for (final path in ihizFiles) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('ibul_chrome.dart')), reason: path);
      expect(source, isNot(contains('web_header.dart')), reason: path);
      expect(source, isNot(contains('custom_header.dart')), reason: path);
    }
  });

  test('web product chrome uses IBUL logo and optional back button', () {
    final header = File('lib/widgets/web_header.dart').readAsStringSync();
    expect(header, contains('showBackButton'));
    expect(header, contains('AppAssets.ibulLogo'));
    expect(header, contains("message: 'Geri'"));
    expect(header, isNot(contains('shopping_bag')));
    expect(header, contains('FontWeight.w500'));

    final shell = File('lib/widgets/home_header_shell.dart').readAsStringSync();
    expect(shell, contains('AppAssets.ibulLogo'));
    expect(shell, isNot(contains('shopping_bag')));

    final pdp = File('lib/screens/product_detail_page.dart').readAsStringSync();
    expect(pdp, contains('_webProductBackButton'));
    expect(pdp, contains('topLeftOverlay: _webProductBackButton(context)'));
    expect(pdp, isNot(contains('showBackButton: true')));
    expect(pdp, contains('color: AppColors.primary'));
    expect(pdp, contains('color: Colors.white'));
    expect(pdp, contains('SizedBox(width: 32)'));
    expect(pdp, contains('IbulChrome.contentConstraints'));

    final slider =
        File('lib/widgets/product_detail/product_image_slider.dart')
            .readAsStringSync();
    expect(slider, contains('topLeftOverlay'));
    expect(slider, contains('left: 10'));
    expect(slider, contains('top: 10'));
    expect(slider, contains('_buildVideoPill(context, viewModel)'));

    final cartBar =
        File('lib/widgets/product_detail/product_bottom_bar.dart').readAsStringSync();
    expect(cartBar, contains('SEPETE EKLE'));
    expect(cartBar, contains('maxLines: 1'));
    expect(cartBar, contains('MainAxisSize.min'));
    expect(cartBar, isNot(contains('width: 120')));
  });

  testWidgets('HomeHeaderShell is mobile chrome below 1100 without overflow',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1099, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHeaderShell(onSearch: (_) {}),
        ),
      ),
    );

    expect(find.text('Erkek'), findsNothing);
    expect(find.text('iBul'), findsOneWidget);
    expect(find.byTooltip('Harita'), findsOneWidget);
    expect(find.byTooltip('Favorilerim'), findsOneWidget);
    expect(find.bySemanticsLabel('Ana sayfaya git'), findsOneWidget);
    expect(find.bySemanticsLabel('Kamera'), findsOneWidget);
    expect(find.bySemanticsLabel('Ara'), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('WebFooter compact layout uses footerCompact threshold',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WebFooter()),
        ),
      ),
    );

    expect(find.text('Kurumsal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
