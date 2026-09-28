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
    expect(html, contains('href="/"'));
    expect(html, contains('href="/map"'));
    expect(html, contains('href="/login"'));
    expect(html, contains('href="/hesabim"'));
    expect(html, contains('name="q"'));
    expect(html, contains("performance.mark('ibul_html_shell_visible')"));
    expect(html, isNot(contains("setLoaderMessage('Yükleniyor")));
    expect(html, contains('min-width: 1100px'));
    expect(html, contains('ihmixxzqnpamcwmrfibx.supabase.co'));
  });

  test('web runner keeps Firebase off the web compile graph', () {
    final runner = File('lib/app/ibul_main_runner.dart').readAsStringSync();
    expect(runner, contains('firebase_native_boot_stub.dart'));
    expect(runner, isNot(contains('package:firebase_core')));
    expect(runner, isNot(contains('push_notification_service.dart')));
    final appState = File('lib/core/app_state.dart').readAsStringSync();
    final follow = File('lib/services/store_follow_service.dart').readAsStringSync();
    expect(appState, contains('push_notification_binding.dart'));
    expect(appState, isNot(contains("import '../services/push_notification_service.dart'")));
    expect(follow, contains('push_notification_binding.dart'));
    final footer = File('lib/widgets/web_footer.dart').readAsStringSync();
    expect(footer, isNot(contains("import '../screens/become_seller_page.dart'")));
    expect(footer, isNot(contains("import '../screens/seller_login_page.dart'")));
    final routes = File('lib/app/app_route_table.dart').readAsStringSync();
    expect(routes, contains('deferred as marketplace_pages'));
    expect(routes, contains('deferred as vehicle_hub'));
  });

  test('home core keeps shell dismiss and does not prefetch below-fold as its own library', () {
    final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
    expect(core, contains('dismissWebBootLoader()'));
    expect(core, contains('initialSearchQuery'));
    expect(core, isNot(contains('home_below_fold_entry.dart')));
    expect(core, isNot(contains('_BelowFoldTrigger')));
  });

  test('web hosting fingerprints deferred part.js with the app hash', () {
    final hosting = File('../scripts/build_web_hosting.sh').readAsStringSync();
    final ci = File('../scripts/build_web_ci.sh').readAsStringSync();
    final py = File('../scripts/fingerprint_web_js.py').readAsStringSync();
    expect(hosting, contains('fingerprint_web_js.py'));
    expect(ci, contains('fingerprint_web_js.py'));
    expect(py, contains('main.dart.js_\\1.part.{digest}.js'));
    expect(py, contains('copied deferred parts but entry JS has no'));
  });
}
