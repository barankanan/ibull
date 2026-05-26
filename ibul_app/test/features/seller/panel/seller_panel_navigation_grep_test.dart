import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sellerPanelFile = File('lib/screens/seller_panel_page.dart');
  final mainFile = File('lib/main.dart');

  String readSellerPanel() => sellerPanelFile.readAsStringSync();
  String readMainFile() => mainFile.readAsStringSync();

  String sectionBetween(String source, String start, String end) {
    final startIndex = source.indexOf(start);
    final endIndex = source.indexOf(end, startIndex);
    expect(
      startIndex,
      greaterThanOrEqualTo(0),
      reason: 'missing section start: $start',
    );
    expect(
      endIndex,
      greaterThan(startIndex),
      reason: 'missing section end: $end',
    );
    return source.substring(startIndex, endIndex);
  }

  group('seller_panel_page navigation grep guard', () {
    test('all _selectedModule writes are centralized', () {
      final lines = sellerPanelFile.readAsLinesSync();
      final rawWrites = <String>[];
      final rawWritePattern = RegExp(r'(^|[^=])_selectedModule\s*=\s*[^=]');

      for (final line in lines) {
        if (!rawWritePattern.hasMatch(line)) continue;
        final normalized = line.trim();
        final isAllowedFieldSeed =
            normalized ==
            'SellerModule _selectedModule = SellerModule.dashboard;';
        final isAllowedInternalSetter = normalized == '_selectedModule = next;';
        if (!isAllowedFieldSeed && !isAllowedInternalSetter) {
          rawWrites.add(normalized);
        }
      }

      expect(
        rawWrites,
        isEmpty,
        reason: 'unexpected direct _selectedModule writes: $rawWrites',
      );
      expect(readSellerPanel(), contains('bool _setActiveSellerModule('));
    });

    test('no direct setState block mutates _selectedModule', () {
      final source = readSellerPanel();
      final directSetStateWrite = RegExp(
        r'setState\s*\(\s*\(\)\s*\{[\s\S]{0,220}?_selectedModule\s*=',
      );
      expect(
        directSetStateWrite.hasMatch(source),
        isFalse,
        reason: 'navigation ownership must stay inside _setActiveSellerModule',
      );
    });

    test('async/background code cannot explicitly write dashboard', () {
      final source = readSellerPanel();
      final nonUserDashboardWrite = RegExp(
        r'_setActiveSellerModule\s*\(\s*SellerModule\.dashboard\s*,[\s\S]{0,160}?userInitiated:\s*false',
      );
      expect(nonUserDashboardWrite.hasMatch(source), isFalse);
      expect(source, contains('reason=user_selected_lock'));
      expect(source, contains('reason=garson_active'));
      expect(source, contains('reason=garson_table_route_open'));
    });

    test(
      '_buildContent never renders dashboard for garson/system/products',
      () {
        final source = readSellerPanel();
        final buildContent = sectionBetween(
          source,
          'Widget _buildContent() {',
          'bool _isFoodStoreCategory',
        );
        final garsonBranch = sectionBetween(
          buildContent,
          'case SellerModule.garson:',
          'case SellerModule.system:',
        );
        final systemBranch = sectionBetween(
          buildContent,
          'case SellerModule.system:',
          'case SellerModule.store:',
        );
        final productsBranch = sectionBetween(
          buildContent,
          'case SellerModule.products:',
          'case SellerModule.collections:',
        );

        expect(productsBranch, contains('return _buildProductsModule();'));
        expect(productsBranch, isNot(contains('_buildDashboard(')));
        expect(garsonBranch, contains('return _buildGarsonModule();'));
        expect(garsonBranch, isNot(contains('_buildDashboard(')));
        expect(systemBranch, contains('return _buildSystemModule();'));
        expect(systemBranch, isNot(contains('_buildDashboard(')));
        expect(buildContent, isNot(contains('default:')));
      },
    );

    test('dashboard refresh guards exist in both refresh entrypoints', () {
      final source = readSellerPanel();
      const guard =
          'if (!shouldRunDashboardRefresh(selectedModule: _selectedModule)) {';
      expect(guard.allMatches(source).length, 2);
      expect(source, contains('reason=dashboard_not_visible'));
    });

    test('garson build consumes frozen visible-orders stream', () {
      final source = readSellerPanel();
      expect(
        RegExp(
          r'stream:\s*_garsonVisibleOrdersController\.stream',
        ).allMatches(source).length,
        2,
      );
      expect(
        source,
        isNot(contains('stream: _getSellerTableOrdersStream(sellerId)')),
      );
      expect(source, contains('[GarsonBuild][render]'));
      expect(source, contains('[GarsonManualRefresh][start]'));
      expect(source, contains('[GarsonManualRefresh][done]'));
      expect(source, contains('[GarsonAutoRefresh][blocked]'));
    });

    test('local print polling no longer uses page setState in status apply', () {
      final source = readSellerPanel();
      final applyStatus = sectionBetween(
        source,
        'void _applyLocalPrintStatus(',
        'String _localPrintHealthMessage(',
      );
      expect(applyStatus, isNot(contains('setState(')));
      expect(source, contains('_localPrintUiRevision'));
    });

    test('sidebar user-tap sources stay explicit', () {
      final source = readSellerPanel();
      expect(source, contains("return 'sidebar_dashboard_tap';"));
      expect(source, contains("return 'sidebar_garson_tap';"));
      expect(source, contains("return 'sidebar_system_tap';"));
    });

    test(
      'SellerPanelPage is not created with UniqueKey or dashboard default',
      () {
        final source = readMainFile();
        expect(
          RegExp(
            r'SellerPanelPage\([\s\S]{0,200}?key:\s*UniqueKey\(',
          ).hasMatch(source),
          isFalse,
        );
        expect(
          RegExp(
            r'SellerPanelPage\([\s\S]{0,200}?initialModule:\s*SellerModule\.dashboard',
          ).hasMatch(source),
          isFalse,
        );
        expect(source, contains("ValueKey<String>('seller_panel_"));
      },
    );

    test('didUpdateWidget does not reset to dashboard', () {
      final source = readSellerPanel();
      final didUpdateWidget = sectionBetween(
        source,
        'void didUpdateWidget(SellerPanelPage oldWidget) {',
        'List<SellerProduct> _productsMatchingSearch',
      );
      expect(didUpdateWidget, isNot(contains('SellerModule.dashboard')));
    });

    test('async functions do not tryAsyncSet dashboard directly', () {
      final source = readSellerPanel();
      const forbiddenSources = <String>[
        '_refreshDashboardData',
        '_loadDashboardTableOrdersGuarded',
        '_loadStoreProfile',
        '_applyStoreProfileStateFieldsFromData',
        '_ensureModuleDataLoaded',
      ];
      for (final fn in forbiddenSources) {
        final idx = source.indexOf(fn);
        expect(idx, greaterThanOrEqualTo(0), reason: 'missing function $fn');
      }
      expect(
        RegExp(r'tryAsyncSet\s*\(\s*SellerModule\.dashboard').hasMatch(source),
        isFalse,
      );
    });

    test(
      'lifecycle logging does not read ModalRoute in init/dispose/helper',
      () {
        final source = readSellerPanel();
        final initState = sectionBetween(
          source,
          'void initState() {',
          'Future<void> _restoreLastSelectedModule() async {',
        );
        final dispose = sectionBetween(
          source,
          'void dispose() {',
          'void didChangeAppLifecycleState(AppLifecycleState state) {',
        );
        final lifecycleHelper = sectionBetween(
          source,
          'String _sellerPanelLifecycleRouteName() =>',
          'SellerPanelNavigationSource _navigationSourceCategory',
        );

        expect(initState, isNot(contains('ModalRoute.of(context)')));
        expect(dispose, isNot(contains('ModalRoute.of(context)')));
        expect(lifecycleHelper, isNot(contains('ModalRoute.of(context)')));
        expect(
          source,
          contains("_debugRouteName = ModalRoute.of(context)?.settings.name;"),
        );
      },
    );
  });
}
