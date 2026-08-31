import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/app_providers.dart';
import 'package:ibul_app/core/ibul_app_mode.dart';

void main() {
  group('Customer entrypoint import guard', () {
    final libRoot = Directory.current.path.endsWith('ibul_app')
        ? Directory.current
        : Directory('ibul_app');

    String readLib(String relativePath) {
      return File('${libRoot.path}/$relativePath').readAsStringSync();
    }

    test('main_customer.dart does not import seller panel', () {
      final content = readLib('lib/main_customer.dart');
      expect(content.contains('seller_panel_page'), isFalse);
      expect(content.contains('SellerPanelPage'), isFalse);
      expect(content, contains('IbulAppMode.customer'));
    });

    test('main_customer.dart does not import admin modules', () {
      final content = readLib('lib/main_customer.dart');
      expect(content.contains('admin_panel_page'), isFalse);
      expect(content.contains('AdminPanelPage'), isFalse);
    });

    test('main_customer.dart does not import local print services', () {
      final content = readLib('lib/main_customer.dart');
      expect(content.contains('local_print_service'), isFalse);
      expect(content.contains('desktop_print_orchestrator'), isFalse);
      expect(content.contains('restaurant_connectivity_service'), isFalse);
    });

    test('customer_app.dart lazy-loads seller/admin without eager panel import', () {
      final content = readLib('lib/app/customer_app.dart');
      expect(content.contains('IbulMaterialApp'), isTrue);
      expect(content.contains('includeAuthRoutes: true'), isTrue);
      expect(content.contains('seller_panel_page'), isFalse);
      final table = readLib('lib/app/app_route_table.dart');
      expect(table.contains('/seller'), isTrue);
      expect(table.contains('/admin'), isTrue);
      expect(table.contains('SellerRoutes.buildSellerPanel'), isTrue);
    });

    test('app_providers customer mode excludes restaurant/print providers', () {
      IbulAppModeRegistry.resetForTests();
      IbulAppModeRegistry.current = IbulAppMode.customer;
      final providers = buildCustomerProviders();
      expect(providers.length, 5);
      expect(countMountedProviders(IbulAppMode.customer), 5);
    });

    test('full mode may include extra IO providers', () {
      IbulAppModeRegistry.resetForTests();
      IbulAppModeRegistry.current = IbulAppMode.full;
      final fullCount = countMountedProviders(IbulAppMode.full);
      final customerCount = countMountedProviders(IbulAppMode.customer);
      expect(fullCount, greaterThanOrEqualTo(customerCount));
      expect(customerCount, 5);
    });
  });
}
