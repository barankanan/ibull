import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three MaterialApps share generateAppRoute', () {
    final table = File('lib/app/app_route_table.dart').readAsStringSync();
    final customer = File('lib/app/customer_app.dart').readAsStringSync();
    final full = File('lib/app/full_app.dart').readAsStringSync();
    final root = File('../lib/main.dart').readAsStringSync();

    expect(table, contains('generateAppRoute'));
    expect(table, contains('includeAuthRoutes'));
    expect(table, contains("case '/login':"));
    expect(table, contains("case '/seller':"));
    expect(table, contains("case '/ihiz':"));
    expect(table, contains('SiteInfoRoutes.pageForPath'));
    expect(table, contains('IhizRoutePaths.isTrackPath'));
    expect(table, contains('mode=deferred'));

    expect(customer, contains('IbulMaterialApp'));
    expect(customer, contains('includeAuthRoutes: true'));
    expect(customer, isNot(contains('seller_panel_page')));
    expect(full, contains('IbulMaterialApp'));
    expect(full, contains('includeAuthRoutes: false'));
    expect(root, contains('IbulMaterialApp'));
    expect(root, contains('includeAuthRoutes: false'));
    final shell = File('lib/app/ibul_material_app.dart').readAsStringSync();
    expect(shell, contains('MaterialApp.router'));
    expect(shell, contains('createIbulGoRouter'));
    expect(
      root.contains("import 'package:ibul_app/screens/seller_panel_page.dart';"),
      isFalse,
    );
  });

  test('seller panel stays a deferred chunk', () {
    final routes = File('lib/app/seller_routes.dart').readAsStringSync();
    expect(routes, contains("deferred as seller_panel"));
    expect(routes, contains("ValueKey<String>('seller_panel_"));
  });
}
