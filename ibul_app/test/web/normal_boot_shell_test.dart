import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/ibul_boot_controller.dart';
import 'package:ibul_app/app/ibul_boot_shell_app.dart';
import 'package:ibul_app/app/ibul_safe_boot_app.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/core/ibul_boot_stage.dart';
import 'package:ibul_app/core/web_boot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppRuntimeConfig.setBootStageOverrideForTest(null);
    AppRuntimeConfig.setSafeBootOverrideForTest(null);
  });

  group('Normal boot shell', () {
    test('shouldRunFullAppBootstrap is true when safe boot is false', () {
      expect(shouldRunFullAppBootstrap(safeBootMode: false), isTrue);
    });

    testWidgets('IbulBootShellScreen renders loading UI without providers', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: IbulBootShellScreen(currentStep: 'supabase_init')),
      );

      expect(find.text('İBUL yükleniyor'), findsOneWidget);
      expect(find.text('Başlatılıyor…'), findsOneWidget);
      expect(find.text('supabase_init'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('IbulProgressiveBootApp shows shell while loading', (
      tester,
    ) async {
      final controller = IbulBootController();
      await tester.pumpWidget(
        IbulProgressiveBootApp(
          controller: controller,
          bootStage: IbulBootStage.normal,
          readyBuilder: (_) => const MaterialApp(home: Text('Real App')),
        ),
      );

      expect(find.text('İBUL yükleniyor'), findsOneWidget);
      expect(find.text('Real App'), findsNothing);
    });

    testWidgets('IbulProgressiveBootApp shows ready app when bootstrap done', (
      tester,
    ) async {
      final controller = IbulBootController()..status = IbulBootStatus.ready;
      await tester.pumpWidget(
        IbulProgressiveBootApp(
          controller: controller,
          bootStage: IbulBootStage.normal,
          readyBuilder: (_) => const MaterialApp(home: Text('Real App')),
        ),
      );

      expect(find.text('Real App'), findsOneWidget);
    });

    testWidgets('IbulProgressiveBootApp shows fatal screen on error', (
      tester,
    ) async {
      final controller = IbulBootController()
        ..status = IbulBootStatus.error
        ..errorMessage = 'Supabase failed';
      await tester.pumpWidget(
        IbulProgressiveBootApp(
          controller: controller,
          bootStage: IbulBootStage.normal,
          readyBuilder: (_) => const MaterialApp(home: Text('Real App')),
        ),
      );

      expect(find.text('Uygulama başlatılamadı'), findsOneWidget);
      expect(find.text('Supabase failed'), findsOneWidget);
    });

    testWidgets('boot stage shell renders diagnostic shell page', (
      tester,
    ) async {
      final controller = IbulBootController()..status = IbulBootStatus.ready;
      await tester.pumpWidget(
        IbulProgressiveBootApp(
          controller: controller,
          bootStage: IbulBootStage.shell,
          readyBuilder: (_) => const MaterialApp(home: Text('Real App')),
        ),
      );

      expect(find.textContaining('Boot stage: shell'), findsOneWidget);
    });

    testWidgets('boot stage providers renders diagnostic providers page', (
      tester,
    ) async {
      AppRuntimeConfig.setBootStageOverrideForTest(IbulBootStage.providers);
      await tester.pumpWidget(
        const MaterialApp(home: IbulBootDiagnosticProvidersPage()),
      );

      expect(find.textContaining('Boot stage: providers'), findsOneWidget);
    });

    testWidgets('WebBootFatalScreen renders without providers', (tester) async {
      await tester.pumpWidget(
        const WebBootFatalScreen(
          message: 'Boot failed',
          technicalDetail: 'timeout',
        ),
      );

      expect(find.text('Uygulama başlatılamadı'), findsOneWidget);
      expect(find.text('Boot failed'), findsOneWidget);
      expect(find.text('timeout'), findsOneWidget);
    });

    test('parseIbulBootStage maps diagnostic stages', () {
      expect(parseIbulBootStage('shell'), IbulBootStage.shell);
      expect(parseIbulBootStage('providers'), IbulBootStage.providers);
      expect(parseIbulBootStage('home_no_cache'), IbulBootStage.homeNoCache);
      expect(parseIbulBootStage('normal'), IbulBootStage.normal);
    });
  });
}
