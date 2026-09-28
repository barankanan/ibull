import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web header logo opens marketplace home, not a same-route no-op', () {
    final header = File('lib/widgets/web_header.dart').readAsStringSync();
    expect(header, contains('_openMarketplaceHome'));
    expect(header, contains('HomeNavigation.openHome(context)'));
    expect(header, contains('Ana sayfaya git'));
    expect(header, contains('HitTestBehavior.opaque'));
    expect(header, isNot(contains("IbulRouter.go(context, '/')")));

    final homeNav = File('lib/core/home_navigation.dart').readAsStringSync();
    expect(homeNav, contains('IbulRouter.goMarketplaceHome'));

    final router = File('lib/app/ibul_router.dart').readAsStringSync();
    expect(router, contains('goMarketplaceHome'));
    expect(router, contains('path == marketplaceHome'));
    expect(router, contains('marketplaceRoot'));
    expect(router, contains('router.state.uri.path'));
    expect(router, isNot(contains('GoRouterState.of(context)')));
  });
}
