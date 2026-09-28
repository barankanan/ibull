import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/map_page.dart';

void main() {
  test('live home bottom nav Harita tab uses deferred map loader', () {
    final core = File('lib/screens/home_screen_core.dart').readAsStringSync();
    expect(core, contains('HomeLazyRoutes.mapTab'));
    expect(core, contains('HomeDeferredTab'));
    expect(core, contains('AppAnimatedIndexedStack'));
    expect(const MapPage(), isA<MapPage>());
    final map = File('lib/screens/map_page.dart').readAsStringSync();
    expect(map, contains('Navigator.canPop(context)'));
    expect(map, isNot(contains('_openedFromProductDetail')));
  });
}
