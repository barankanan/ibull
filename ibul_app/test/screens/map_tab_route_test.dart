import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/map_page.dart';

void main() {
  test('legacy home bottom nav Harita tab uses deferred map loader', () {
    final legacy =
        File('lib/screens/home_screen_legacy_full.dart').readAsStringSync();
    expect(legacy, contains('HomeLazyRoutes.mapTab'));
    expect(legacy, contains('HomeDeferredTab'));
    expect(legacy, contains('AppAnimatedIndexedStack'));
    expect(const MapPage(), isA<MapPage>());
  });
}
