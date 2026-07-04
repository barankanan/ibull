import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/ibul_safe_boot_app.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/core/web_boot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppRuntimeConfig.setSafeBootOverrideForTest(null);
  });

  group('Safe boot app', () {
    test('parseSafeBootFlag parses true variants', () {
      expect(AppRuntimeConfig.parseSafeBootFlag('true'), isTrue);
      expect(AppRuntimeConfig.parseSafeBootFlag('TRUE'), isTrue);
      expect(AppRuntimeConfig.parseSafeBootFlag('1'), isTrue);
      expect(AppRuntimeConfig.parseSafeBootFlag('false'), isFalse);
      expect(AppRuntimeConfig.parseSafeBootFlag(null), isFalse);
    });

    test('safe boot override controls safeBootMode in tests', () {
      AppRuntimeConfig.setSafeBootOverrideForTest(true);
      expect(AppRuntimeConfig.safeBootMode, isTrue);
      AppRuntimeConfig.setSafeBootOverrideForTest(false);
      expect(AppRuntimeConfig.safeBootMode, isFalse);
    });

    test('shouldRunFullAppBootstrap returns false in safe boot mode', () {
      expect(shouldRunFullAppBootstrap(safeBootMode: true), isFalse);
      expect(shouldRunFullAppBootstrap(safeBootMode: false), isTrue);
    });

    testWidgets('IbulSafeBootApp renders safe boot screen', (tester) async {
      await tester.pumpWidget(const IbulSafeBootApp());

      expect(find.text('İBUL Safe Boot'), findsOneWidget);
      expect(find.text('Uygulama güvenli modda açıldı.'), findsOneWidget);
      expect(
        find.text('Bu ekran görünüyorsa Flutter web mount başarılı.'),
        findsOneWidget,
      );
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('WebBootFatalScreen renders without providers', (tester) async {
      await tester.pumpWidget(
        const WebBootFatalScreen(
          message: 'Test fatal message',
          technicalDetail: 'detail',
        ),
      );

      expect(find.text('Uygulama başlatılamadı'), findsOneWidget);
      expect(find.text('Test fatal message'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
      expect(find.text('Sayfayı Yenile'), findsOneWidget);
    });

    test('safe boot branch skips full bootstrap helper', () {
      expect(shouldRunFullAppBootstrap(safeBootMode: true), isFalse);
      expect(shouldRunFullAppBootstrap(safeBootMode: false), isTrue);
    });
  });
}
