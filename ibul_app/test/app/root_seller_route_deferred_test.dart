import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('root /seller route loads seller panel as a deferred chunk', () {
    final source = File('../lib/main.dart').readAsStringSync();
    expect(source, contains('IbulMaterialApp'));
    expect(source, isNot(contains('mode=eager')));
    expect(
      source.contains("import 'package:ibul_app/screens/seller_panel_page.dart';"),
      isFalse,
    );
    final routes = File('lib/app/seller_routes.dart').readAsStringSync();
    expect(routes, contains("deferred as seller_panel"));
    final table = File('lib/app/app_route_table.dart').readAsStringSync();
    expect(table, contains('mode=deferred'));
  });

  test('shared route table registers deferred ihiz and site info routes', () {
    final table = File('lib/app/app_route_table.dart').readAsStringSync();
    expect(table, contains("case '/ihiz':"));
    expect(table, contains('SellerRoutes.buildIhizCourier'));
    expect(table, contains('SiteInfoRoutes.pageForPath'));
    expect(table, contains('IhizRoutePaths.isTrackPath'));
    final customer = File('lib/app/customer_app.dart').readAsStringSync();
    expect(customer, contains('IbulMaterialApp'));
    expect(customer, contains('includeAuthRoutes: true'));
  });

  test('root MyApp uses the shared route table', () {
    final source = File('../lib/main.dart').readAsStringSync();
    expect(source, contains('IbulMaterialApp'));
    expect(source, contains('includeAuthRoutes: false'));
    final shell = File('lib/app/ibul_material_app.dart').readAsStringSync();
    expect(shell, contains('MaterialApp.router'));
    expect(shell, contains('createIbulGoRouter'));
  });

  test('print station configure payload omits refresh_token', () {
    final source =
        File('lib/services/print_station_service.dart').readAsStringSync();
    expect(source, contains("'access_token': session.accessToken"));
    expect(source, isNot(contains("'refresh_token'")));
    expect(source, isNot(contains('session.refreshToken')));
  });

  test('visual search results use paged catalog search', () {
    final source = File('lib/screens/search_results_page.dart').readAsStringSync();
    expect(source, contains('searchProductsPaged'));
    expect(source, isNot(contains('getAllProducts()')));
  });
}
