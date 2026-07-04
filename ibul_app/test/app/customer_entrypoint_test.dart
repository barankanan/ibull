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

    test('customer_app.dart has no seller/admin routes', () {
      final content = readLib('lib/app/customer_app.dart');
      expect(content.contains('/seller'), isFalse);
      expect(content.contains('/admin'), isFalse);
      expect(content.contains('seller_panel_page'), isFalse);
    });

    test('app_providers customer mode excludes restaurant/print providers', () {
      IbulAppModeRegistry.resetForTests();
      IbulAppModeRegistry.current = IbulAppMode.customer;
      final providers = buildCustomerProviders();
      expect(providers.length, 6);
      expect(countMountedProviders(IbulAppMode.customer), 6);
    });

    test('full mode may include extra IO providers', () {
      IbulAppModeRegistry.resetForTests();
      IbulAppModeRegistry.current = IbulAppMode.full;
      final fullCount = countMountedProviders(IbulAppMode.full);
      final customerCount = countMountedProviders(IbulAppMode.customer);
      expect(fullCount, greaterThanOrEqualTo(customerCount));
      expect(customerCount, 6);
    });
  });
}
