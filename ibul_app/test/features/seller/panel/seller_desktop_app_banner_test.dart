import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_desktop_app_banner_prefs.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_module_helpers.dart';
import 'package:ibul_app/features/seller/panel/models/seller_panel_types.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_desktop_app_banner.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_download_app_content.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SellerDesktopAppBannerPrefs', () {
    test('dismiss state persists', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SellerDesktopAppBannerPrefs.isBannerHidden(), isFalse);
      await SellerDesktopAppBannerPrefs.setBannerHidden(true);
      expect(await SellerDesktopAppBannerPrefs.isBannerHidden(), isTrue);
      expect(
        SellerDesktopAppBannerPrefs.hideBannerKey,
        'hide_seller_desktop_app_banner_v1',
      );
    });
  });

  group('SellerDesktopAppBanner', () {
    testWidgets('desktop app banner can be dismissed', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerDesktopAppBanner(
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(
        find.text('Satıcı uygulamasını indirin, işlemlerinizi hızlandırın.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('Seller sidebar download module', () {
    test('sidebar shows İndir under Destek', () {
      final modules = visibleSellerModules('Yemek');
      final supportIndex = modules.indexOf(SellerModule.support);
      final downloadIndex = modules.indexOf(SellerModule.downloadApp);
      expect(supportIndex, greaterThanOrEqualTo(0));
      expect(downloadIndex, supportIndex + 1);
      expect(sellerModuleLabel(SellerModule.downloadApp), 'İndir');
    });

    testWidgets('app module/page renders Windows and macOS cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SellerDownloadAppContent()),
        ),
      );

      expect(find.text('Satıcı Uygulamasını İndir'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Neden masaüstü uygulama kurmalısınız?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Windows için İndir'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'MacBook için İndir'), findsOneWidget);
    });
  });
}
