import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_desktop_app_banner.dart';
import 'package:ibul_app/features/seller/panel/widgets/seller_download_app_content.dart';

void main() {
  group('Seller desktop download config', () {
    test('download URLs are non-empty absolute https URLs', () {
      final windows = AppRuntimeConfig.sellerDesktopWindowsDownloadUrl;
      final macos = AppRuntimeConfig.sellerDesktopMacosDownloadUrl;

      for (final url in [windows, macos]) {
        expect(url.trim(), isNotEmpty);
        final uri = Uri.parse(url);
        expect(uri.scheme, 'https');
        expect(uri.host, isNotEmpty);
      }
    });

    test('default URLs use the ibul-public-downloads GitHub release tag', () {
      expect(
        AppRuntimeConfig.sellerDesktopWindowsDownloadUrl,
        'https://github.com/barankanan/ibull/releases/download/ibul-public-downloads/IbulSellerSetup.exe',
      );
      expect(
        AppRuntimeConfig.sellerDesktopMacosDownloadUrl,
        'https://github.com/barankanan/ibull/releases/download/ibul-public-downloads/IbulSellerDesktop.dmg',
      );
    });

    test('legacy alias still resolves to the unified Windows installer', () {
      expect(
        AppRuntimeConfig.windowsInstallerDownloadUrl,
        AppRuntimeConfig.sellerDesktopWindowsDownloadUrl,
      );
    });
  });

  group('SellerDesktopAppBanner', () {
    testWidgets('renders download buttons and dismisses via X', (tester) async {
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
      expect(find.text('Windows için İndir'), findsOneWidget);
      expect(find.text('MacBook için İndir'), findsOneWidget);

      await tester.tap(find.byTooltip('Kapat'));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('SellerDownloadAppContent', () {
    testWidgets('renders Windows and macOS download cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SellerDownloadAppContent()),
        ),
      );
      await tester.pump();

      expect(find.text('Satıcı Uygulamasını İndir'), findsOneWidget);
      expect(find.text('Windows'), findsOneWidget);
      expect(find.text('macOS'), findsOneWidget);
      expect(find.text('Windows için İndir'), findsOneWidget);
      expect(find.text('MacBook için İndir'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
