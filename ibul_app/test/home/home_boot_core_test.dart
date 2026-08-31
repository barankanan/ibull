import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/app_providers.dart';
import 'package:ibul_app/core/app_motion.dart';
import 'package:ibul_app/core/home_boot_diagnostics.dart';
import 'package:ibul_app/core/ibul_app_mode.dart';
import 'package:ibul_app/core/single_flight_guard.dart';
import 'package:ibul_app/widgets/home_boot_timeout_banner.dart';

void main() {
  group('Home boot core guards', () {
    setUp(() {
      HomeBootDiagnostics.resetForTests();
      IbulAppModeRegistry.resetForTests();
    });

    test('home_screen_core.dart does not call network in build()', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      final buildStart = source.indexOf('Widget build(BuildContext context)');
      expect(buildStart, greaterThan(0));
      final buildBody = source.substring(buildStart, buildStart + 1200);
      expect(buildBody.contains('HomePreviewFetch.fetch'), isFalse);
      expect(buildBody.contains('_fetchPreviewProducts()'), isFalse);
    });

    test('staged reveal paints immediately without timer failsafe', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(source, contains('_sectionsRevealed = true'));
      expect(source, contains('_ensureSectionsVisible'));
      expect(source, contains('kProductsRevealDelay = Duration.zero'));
      expect(source, contains('kCategoryRevealDelay = Duration.zero'));
      expect(source, isNot(contains('failsafe_2s')));
    });

    test('product fetch uses SingleFlightGuard', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(source, contains('SingleFlightGuard'));
      expect(source, contains('_productFetchGuard.tryBegin()'));
    });

    test('SingleFlightGuard blocks overlapping runs', () {
      final guard = SingleFlightGuard(debounce: Duration.zero);
      expect(guard.tryBegin(), isTrue);
      expect(guard.tryBegin(), isFalse);
      guard.finish();
      expect(guard.tryBegin(), isTrue);
    });

    test('AppAnimatedIndexedStack lazyMount skips unvisited tabs', () {
      final stack = AppAnimatedIndexedStack(
        index: 0,
        lazyMount: true,
        children: const [
          Text('home'),
          Text('map'),
        ],
      );
      expect(stack.lazyMount, isTrue);
    });

    test('customer app does not mount seller/admin/print providers', () {
      IbulAppModeRegistry.current = IbulAppMode.customer;
      final providers = buildCustomerProviders();
      expect(providers.length, 5);
      expect(countMountedProviders(IbulAppMode.customer), 5);
    });

    test('home deferred entry uses HomeScreenCore on all viewports', () {
      final entry =
          File('lib/screens/home_screen_deferred_entry.dart').readAsStringSync();
      expect(entry, contains('HomeScreenCore('));
      expect(entry, isNot(contains('legacy_home.HomeScreen')));
      expect(entry, isNot(contains('home_screen.dart')));
      expect(entry, isNot(contains('home_screen_legacy_full.dart')));
    });

    test('home uses real product card rail not preview DTO', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('DeferredHomeFullRailSection'));
      expect(core, isNot(contains('HomeProductPreviewSectionDto')));
    });

    test('initial product render limit is 8', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(source, contains('kPreviewBatchSize = 8'));
    });

    test('web home does not stall hero or sponsored behind artificial delays', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(source, contains('kHeroDelay = Duration.zero'));
      expect(source, contains('kSideDelay = Duration.zero'));
      expect(source, contains('kSponsoredDelay = Duration.zero'));
      expect(source, contains('kProductsRevealDelay = Duration.zero'));
      expect(source, isNot(contains('milliseconds: 800')));
      expect(source, isNot(contains('milliseconds: 1000')));
      expect(source, isNot(contains('milliseconds: 500')));
      expect(source, isNot(contains('milliseconds: 300')));
    });

    testWidgets('HomeBootTimeoutBanner renders non-blocking message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HomeBootTimeoutBanner(
              message: 'Ürünler yükleniyor, bağlantı yavaş olabilir.',
            ),
          ),
        ),
      );
      expect(
        find.text('Ürünler yükleniyor, bağlantı yavaş olabilir.'),
        findsOneWidget,
      );
    });

    test('web home uses Column inside WebStickyFooterScrollView', () {
      final source =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(source, contains('_buildWebHomeScrollBody'));
      expect(source, contains('WebStickyFooterScrollView'));
      expect(source, contains('Column('));
    });

    test('home_screen_gate does not setState on watchdog tick', () {
      final gate =
          File('lib/screens/home_screen_gate.dart').readAsStringSync();
      expect(gate, contains('ListenableBuilder'));
      expect(gate, contains('Positioned.fill'));
      expect(gate, isNot(contains('setState(() {});')));
    });

    test('deferred module mounts with SizedBox.expand', () {
      final deferred =
          File('lib/widgets/deferred_module_screen.dart').readAsStringSync();
      expect(deferred, contains('SizedBox.expand'));
      expect(deferred, isNot(contains('_readyToMount')));
    });

    test('map tab loader only referenced from deferred tab slot', () {
      final core =
          File('lib/screens/home_screen_core.dart').readAsStringSync();
      expect(core, contains('HomeLazyRoutes.mapTab'));
      expect(core, isNot(contains('MapPage(')));
    });
  });
}
