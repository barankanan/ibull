import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/mobile_app_download_prompt_controller.dart';
import 'package:ibul_app/widgets/customer_mobile_app_download_prompt.dart';

Future<List<String>> _pumpPrompt(
  WidgetTester tester, {
  required MobileAppDownloadLinks links,
  VoidCallback? onDismiss,
}) async {
  final openedUrls = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: CustomerMobileAppDownloadPrompt(
            links: links,
            openUrl: openedUrls.add,
            onDismiss: onDismiss ?? () {},
          ),
        ),
      ),
    ),
  );
  return openedUrls;
}

void main() {
  const apkUrl =
      'https://github.com/barankanan/ibull/releases/download/ibul-public-downloads/IbulCustomer.apk';
  const playUrl = 'https://play.google.com/store/apps/details?id=com.ibul';
  const testFlightUrl = 'https://testflight.apple.com/join/abc123';
  const appStoreUrl = 'https://apps.apple.com/app/id123456789';

  group('CustomerMobileAppDownloadPrompt cards', () {
    testWidgets('renders title, subtitle and both platform cards', (
      tester,
    ) async {
      await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(androidApkUrl: apkUrl),
      );

      expect(find.text('İBUL’u telefonuna indir'), findsOneWidget);
      expect(
        find.text(
          'Daha hızlı alışveriş, yakın fırsatlar ve favori mağazaların cebinde.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(CustomerMobileAppDownloadPrompt.androidCardKey),
        findsOneWidget,
      );
      expect(
        find.byKey(CustomerMobileAppDownloadPrompt.iosCardKey),
        findsOneWidget,
      );
      expect(find.text('Daha sonra'), findsOneWidget);
    });

    testWidgets('Android APK link makes Android card active with APK label', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(androidApkUrl: apkUrl),
      );

      expect(find.text('Android APK indir'), findsOneWidget);

      await tester.tap(
        find.byKey(CustomerMobileAppDownloadPrompt.androidCardKey),
      );
      await tester.pump();
      expect(opened, [apkUrl]);
    });

    testWidgets('Play Store link shows "Google Play’de aç" and opens it', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(
          androidApkUrl: apkUrl,
          androidPlayStoreUrl: playUrl,
        ),
      );

      expect(find.text('Google Play’de aç'), findsOneWidget);

      await tester.tap(
        find.byKey(CustomerMobileAppDownloadPrompt.androidCardKey),
      );
      await tester.pump();
      expect(opened, [playUrl]);
    });

    testWidgets('missing iOS link shows disabled "Yakında" iPhone card', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(androidApkUrl: apkUrl),
      );

      expect(find.text('iPhone'), findsOneWidget);
      expect(find.text('Yakında'), findsOneWidget);

      await tester.tap(find.byKey(CustomerMobileAppDownloadPrompt.iosCardKey));
      await tester.pump();
      expect(opened, isEmpty); // disabled kart hiçbir URL açmaz
    });

    testWidgets('TestFlight link makes iPhone card active', (tester) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(iosTestFlightUrl: testFlightUrl),
      );

      expect(find.text('TestFlight’tan yükle'), findsOneWidget);

      await tester.tap(find.byKey(CustomerMobileAppDownloadPrompt.iosCardKey));
      await tester.pump();
      expect(opened, [testFlightUrl]);
    });

    testWidgets('App Store link takes priority over TestFlight', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(
          iosAppStoreUrl: appStoreUrl,
          iosTestFlightUrl: testFlightUrl,
        ),
      );

      expect(find.text('App Store’da aç'), findsOneWidget);

      await tester.tap(find.byKey(CustomerMobileAppDownloadPrompt.iosCardKey));
      await tester.pump();
      expect(opened, [appStoreUrl]);
    });

    testWidgets('missing Android link shows disabled Android card', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(iosTestFlightUrl: testFlightUrl),
      );

      expect(find.text('Android'), findsOneWidget);
      expect(find.text('Yakında'), findsOneWidget);

      await tester.tap(
        find.byKey(CustomerMobileAppDownloadPrompt.androidCardKey),
      );
      await tester.pump();
      expect(opened, isEmpty);
    });

    testWidgets('empty/whitespace URLs are treated as missing (no broken open)', (
      tester,
    ) async {
      final opened = await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(
          androidApkUrl: '   ',
          androidPlayStoreUrl: '',
          iosAppStoreUrl: '',
          iosTestFlightUrl: ' ',
        ),
      );

      expect(find.text('Yakında'), findsNWidgets(2));

      await tester.tap(
        find.byKey(CustomerMobileAppDownloadPrompt.androidCardKey),
      );
      await tester.tap(find.byKey(CustomerMobileAppDownloadPrompt.iosCardKey));
      await tester.pump();
      expect(opened, isEmpty);
    });

    testWidgets('dismiss button triggers onDismiss', (tester) async {
      bool dismissed = false;
      await _pumpPrompt(
        tester,
        links: const MobileAppDownloadLinks(androidApkUrl: apkUrl),
        onDismiss: () => dismissed = true,
      );

      await tester.tap(find.text('Daha sonra'));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('MobileAppDownloadLinks.iosSource', () {
    test('app_store when App Store link exists (TestFlight varken bile)', () {
      expect(
        const MobileAppDownloadLinks(
          iosAppStoreUrl: appStoreUrl,
          iosTestFlightUrl: testFlightUrl,
        ).iosSource,
        'app_store',
      );
    });

    test('testflight when only TestFlight link exists', () {
      expect(
        const MobileAppDownloadLinks(iosTestFlightUrl: testFlightUrl).iosSource,
        'testflight',
      );
    });

    test('null when no iOS link (disabled reason=no_ios_link)', () {
      expect(const MobileAppDownloadLinks(androidApkUrl: apkUrl).iosSource, isNull);
    });
  });

  group('MobileAppDownloadPromptController.evaluate', () {
    const withLinks = MobileAppDownloadLinks(androidApkUrl: apkUrl);
    const noLinks = MobileAppDownloadLinks();

    test('1024px mobile web width shows prompt', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 1024,
          platform: TargetPlatform.windows,
          links: withLinks,
        ),
        MobileAppPromptVisibility.show,
      );
    });

    test('1440px desktop width hides prompt', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 1440,
          platform: TargetPlatform.windows,
          links: withLinks,
        ),
        MobileAppPromptVisibility.hiddenDesktop,
      );
    });

    test('all links empty hides prompt with no_links', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 390,
          platform: TargetPlatform.android,
          links: noLinks,
        ),
        MobileAppPromptVisibility.hiddenNoLinks,
      );
    });

    test('empty-string links count as no_links', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 390,
          platform: TargetPlatform.iOS,
          links: const MobileAppDownloadLinks(
            androidApkUrl: '',
            androidPlayStoreUrl: ' ',
            iosAppStoreUrl: '',
            iosTestFlightUrl: '',
          ),
        ),
        MobileAppPromptVisibility.hiddenNoLinks,
      );
    });

    test('dismissed hides prompt', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 390,
          platform: TargetPlatform.android,
          links: withLinks,
          dismissed: true,
        ),
        MobileAppPromptVisibility.hiddenDismissed,
      );
    });

    test('native mobile platform shows even at wide width', () {
      expect(
        MobileAppDownloadPromptController.evaluate(
          width: 1440,
          platform: TargetPlatform.android,
          links: withLinks,
        ),
        MobileAppPromptVisibility.show,
      );
    });
  });
}
