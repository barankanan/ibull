import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/presentation/pages/admin_ads_manager_content.dart';

void main() {
  late List<String> logs;

  setUp(() {
    logs = <String>[];
  });

  Future<void> pumpStage(
    WidgetTester tester,
    AdminAdsDebugIsolationStage stage,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1600, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminAdsManagerContent(
          debugIsolationStage: stage,
          debugTapLogSink: logs.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndExpectLog(
    WidgetTester tester, {
    required String buttonLabel,
    required String expectedLog,
  }) async {
    await tester.tap(find.widgetWithText(ElevatedButton, buttonLabel));
    await tester.pump();
    expect(logs, contains(expectedLog));
  }

  testWidgets('pure isolation stage accepts taps', (WidgetTester tester) async {
    await pumpStage(tester, AdminAdsDebugIsolationStage.pure);

    await tapAndExpectLog(
      tester,
      buttonLabel: 'PURE ADS TEST',
      expectedLog: 'PURE ADS BUTTON CLICKED',
    );
  });

  testWidgets('hero isolation stage accepts taps', (WidgetTester tester) async {
    await pumpStage(tester, AdminAdsDebugIsolationStage.heroOnly);

    await tapAndExpectLog(
      tester,
      buttonLabel: 'PURE ADS TEST',
      expectedLog: 'PURE ADS BUTTON CLICKED',
    );
    await tapAndExpectLog(
      tester,
      buttonLabel: 'HERO TEST',
      expectedLog: 'HERO TEST CLICKED',
    );
  });

  testWidgets('hero and stats isolation stage accepts taps', (
    WidgetTester tester,
  ) async {
    await pumpStage(tester, AdminAdsDebugIsolationStage.heroAndStats);

    await tapAndExpectLog(
      tester,
      buttonLabel: 'PURE ADS TEST',
      expectedLog: 'PURE ADS BUTTON CLICKED',
    );
    await tapAndExpectLog(
      tester,
      buttonLabel: 'HERO TEST',
      expectedLog: 'HERO TEST CLICKED',
    );
    await tapAndExpectLog(
      tester,
      buttonLabel: 'STATS TEST',
      expectedLog: 'STATS TEST CLICKED',
    );
  });

  testWidgets('hero stats and filters isolation stage accepts taps', (
    WidgetTester tester,
  ) async {
    await pumpStage(tester, AdminAdsDebugIsolationStage.heroStatsAndFilters);

    await tapAndExpectLog(
      tester,
      buttonLabel: 'PURE ADS TEST',
      expectedLog: 'PURE ADS BUTTON CLICKED',
    );
    await tapAndExpectLog(
      tester,
      buttonLabel: 'FILTER TEST',
      expectedLog: 'FILTER TEST CLICKED',
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);
  });

  testWidgets('hero stats filters and table isolation stage accepts taps', (
    WidgetTester tester,
  ) async {
    await pumpStage(
      tester,
      AdminAdsDebugIsolationStage.heroStatsFiltersAndTable,
    );

    await tapAndExpectLog(
      tester,
      buttonLabel: 'PURE ADS TEST',
      expectedLog: 'PURE ADS BUTTON CLICKED',
    );
    await tapAndExpectLog(
      tester,
      buttonLabel: 'TABLE TEST',
      expectedLog: 'TABLE TEST CLICKED',
    );
    expect(find.text('Kampanya tablosu'), findsOneWidget);
  });
}
