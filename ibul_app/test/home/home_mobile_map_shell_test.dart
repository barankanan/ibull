import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_mobile_shortcut.dart';
import 'package:ibul_app/features/products/helpers/category_filter_config.dart';

void main() {
  group('Harita tab shell routing', () {
    test('map tab index shell içinde 2', () {
      expect(CategoryFilterConfig.mapTabIndex, 2);
    });

    test('Yakın Lokasyon nearbyLocation tipindedir', () {
      final action = HomeMobileShortcutRegistry.fromKey('yakin_lokasyon');
      expect(action, isNotNull);
      expect(action!.type, HomeMobileShortcutType.nearbyLocation);
    });

    testWidgets(
      'Yakın Lokasyon switchToMapTab callback çağırır, push yapmaz',
      (tester) async {
        var mapTabCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      HomeMobileShortcutNavigator.open(
                        context,
                        HomeMobileShortcutRegistry.fromKey('yakin_lokasyon')!,
                        callbacks: HomeMobileShortcutCallbacks(
                          switchToMapTab: () => mapTabCalled = true,
                        ),
                      );
                    },
                    child: const Text('openMap'),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('openMap'));
        await tester.pump();

        expect(mapTabCalled, isTrue);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );
  });
}
