import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('index.html preloads the matching CanvasKit variant, not both', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('preloadCanvasKitVariant'));
    expect(html, contains('canvaskit/chromium/'));
    expect(html, contains("base + 'canvaskit.wasm'"));
    expect(html, contains("base + 'canvaskit.js'"));
    expect(html, isNot(contains('href="canvaskit/canvaskit.wasm"')));
    expect(html, contains('v8BreakIterator'));
    expect(html, contains('ImageDecoder'));
  });

  test('home gate prefetches only the core home chunk', () {
    final gate = File('lib/screens/home_screen_gate.dart').readAsStringSync();
    expect(gate, contains('unawaited(loadModule())'));
    expect(gate, isNot(contains("deferred as legacy_home")));
    expect(gate, isNot(contains('legacy_home.loadLibrary()')));
    expect(gate, isNot(contains('_isMobileWebViewport')));
  });

  test('deferred home mounts as soon as the library is ready', () {
    final source =
        File('lib/widgets/deferred_module_screen.dart').readAsStringSync();
    expect(source, isNot(contains('Future<void>.delayed(Duration.zero)')));
    expect(source, contains('setState(() => _libraryLoaded = true)'));
  });

  test('web boot shell matches desktop header, not a blank white page', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, contains('id="ibul-web-chrome"'));
    expect(html, contains('iBul'));
    expect(html, contains('Yakın Lokasyon'));
    expect(html, contains('min-width: 1100px'));
    expect(html, contains('ihmixxzqnpamcwmrfibx.supabase.co'));
  });

  test('web runner keeps Firebase off the web compile graph', () {
    final runner = File('lib/app/ibul_main_runner.dart').readAsStringSync();
    expect(runner, contains('firebase_native_boot_stub.dart'));
    expect(runner, isNot(contains('package:firebase_core')));
    expect(runner, isNot(contains('push_notification_service.dart')));
  });
}
