import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/ibul_chrome.dart';
import 'package:ibul_app/features/coupon/widgets/reward_wheel_floating_button.dart';

void main() {
  group('RewardWheelFabMetrics', () {
    test('visibility follows server canSpin, not width', () {
      const widths = [375.0, 390.0, 430.0, 768.0, 1024.0, 1440.0];
      for (final width in widths) {
        expect(
          RewardWheelFabMetrics.shouldShow(canSpin: true),
          isTrue,
          reason: 'eligible wheel must show at $width',
        );
        expect(
          RewardWheelFabMetrics.shouldShow(canSpin: false),
          isFalse,
          reason: 'used-up wheel must hide at $width',
        );
      }
    });

    test('compact widths use mobile size, desktop uses 56', () {
      expect(RewardWheelFabMetrics.sizeFor(375), 52);
      expect(RewardWheelFabMetrics.sizeFor(390), 52);
      expect(RewardWheelFabMetrics.sizeFor(430), 52);
      expect(RewardWheelFabMetrics.sizeFor(768), 52);
      expect(RewardWheelFabMetrics.sizeFor(1024), 52);
      expect(RewardWheelFabMetrics.sizeFor(1099), 52);
      expect(RewardWheelFabMetrics.sizeFor(IbulChrome.web), 56);
      expect(RewardWheelFabMetrics.sizeFor(1440), 56);
    });

    test('body overlay sits above nav without double-counting nav height', () {
      expect(
        RewardWheelFabMetrics.bottomOffset(
          overlayInScaffoldBody: true,
          hasBottomNav: true,
          safeAreaBottom: 34,
        ),
        RewardWheelFabMetrics.mobileGap,
      );
      expect(
        RewardWheelFabMetrics.bottomOffset(
          overlayInScaffoldBody: true,
          hasBottomNav: false,
          safeAreaBottom: 34,
        ),
        RewardWheelFabMetrics.desktopGap + 34,
      );
      expect(
        RewardWheelFabMetrics.bottomOffset(
          overlayInScaffoldBody: false,
          hasBottomNav: true,
          safeAreaBottom: 34,
        ),
        kBottomNavigationBarHeight + 34 + RewardWheelFabMetrics.mobileGap,
      );
    });
  });

  group('RewardWheelHomeOverlay', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required double width,
      required bool hasBottomNav,
      bool wheelActive = true,
      double safeBottom = 0,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              padding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: Scaffold(
              body: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  const ColoredBox(color: Colors.white),
                  RewardWheelHomeOverlay(
                    hasBottomNav: hasBottomNav,
                    wheelActive: wheelActive,
                  ),
                ],
              ),
              bottomNavigationBar: hasBottomNav
                  ? BottomNavigationBar(
                      currentIndex: 0,
                      onTap: (_) {},
                      items: const [
                        BottomNavigationBarItem(
                          icon: Icon(Icons.home),
                          label: 'Ana Sayfa',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.shopping_cart),
                          label: 'Sepet',
                        ),
                        BottomNavigationBarItem(
                          icon: Icon(Icons.person),
                          label: 'Hesap',
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders at mobile and desktop breakpoints', (tester) async {
      const cases = [
        (375.0, true),
        (390.0, true),
        (430.0, true),
        (768.0, true),
        (1024.0, true),
        (1440.0, false),
      ];
      for (final entry in cases) {
        await pumpAt(
          tester,
          width: entry.$1,
          hasBottomNav: entry.$2,
        );
        expect(
          find.byTooltip('Hediye Çarkı'),
          findsOneWidget,
          reason: 'wheel must be visible at ${entry.$1}',
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('hides when wheel is inactive on both compact and desktop',
        (tester) async {
      await pumpAt(
        tester,
        width: 375,
        hasBottomNav: true,
        wheelActive: false,
      );
      expect(find.byTooltip('Hediye Çarkı'), findsNothing);

      await pumpAt(
        tester,
        width: 1440,
        hasBottomNav: false,
        wheelActive: false,
      );
      expect(find.byTooltip('Hediye Çarkı'), findsNothing);
    });

    testWidgets('stays above bottom nav and inside the screen', (tester) async {
      await pumpAt(
        tester,
        width: 390,
        hasBottomNav: true,
        safeBottom: 34,
      );

      final button = tester.getRect(find.byType(RewardWheelFloatingButton));
      final nav = tester.getRect(find.byType(BottomNavigationBar));
      expect(button.bottom, lessThanOrEqualTo(nav.top + 0.5));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(390));
      expect(button.width, RewardWheelFabMetrics.mobileSize);
      expect(button.height, RewardWheelFabMetrics.mobileSize);
    });
  });
}
