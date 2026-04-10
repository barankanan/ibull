import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture products tab with draft', (tester) async {
    await _captureScenario(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.productsWithDraft,
      fileName: '01_urunler_sekmesi_draft_var.png',
    );
  });

  testWidgets('capture orders tab with draft', (tester) async {
    await _captureScenario(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersWithDraft,
      fileName: '02_siparis_sekmesi_draft_var.png',
    );
  });

  testWidgets('capture orders tab with empty draft', (tester) async {
    await _captureScenario(
      tester,
      scenario: SellerPanelGarsonPreviewScenario.ordersEmptyDraft,
      fileName: '03_siparis_sekmesi_draft_bos.png',
    );
  });

  testWidgets('capture post-submit active order state', (tester) async {
    final boundaryKey = GlobalKey();
    _prepareViewport(tester);
    _ensureOutputDir();

    await tester.pumpWidget(
      Material(
        child: RepaintBoundary(
          key: boundaryKey,
          child: const SellerPanelGarsonPreview(
            scenario: SellerPanelGarsonPreviewScenario.ordersWithDraftOnly,
            enableLocalSubmit: true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    _assertNoRenderException(tester);

    await tester.tap(find.text('Siparişi Gönder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    _assertNoRenderException(tester);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile(
        '../goldens/garson_flow/04_submit_sonrasi_aktif_siparis.png',
      ),
    );
    _maybeExitAfterCapture();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _captureScenario(
  WidgetTester tester, {
  required SellerPanelGarsonPreviewScenario scenario,
  required String fileName,
}) async {
  final boundaryKey = GlobalKey();
  _prepareViewport(tester);
  _ensureOutputDir();

  await tester.pumpWidget(
    Material(
      child: RepaintBoundary(
        key: boundaryKey,
        child: SellerPanelGarsonPreview(scenario: scenario),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  _assertNoRenderException(tester);

  await expectLater(
    find.byKey(boundaryKey),
    matchesGoldenFile('../goldens/garson_flow/$fileName'),
  );
  _maybeExitAfterCapture();

  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void _prepareViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
}

void _ensureOutputDir() {
  Directory('test/goldens/garson_flow').createSync(recursive: true);
}

void _maybeExitAfterCapture() {
  if (Platform.environment['GARSON_SCREENSHOT_EXIT'] == '1') {
    exit(0);
  }
}

void _assertNoRenderException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception != null) {
    fail('Preview render exception: $exception');
  }
}
