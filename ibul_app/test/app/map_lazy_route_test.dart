import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/app_motion.dart';
import 'package:ibul_app/screens/home_deferred_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Map lazy route', () {
    testWidgets('HomeDeferredTab loads after first frame callback', (
      tester,
    ) async {
      var loaded = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeDeferredTab(
              load: () async {
                loaded = true;
                return const Text('map-loaded');
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(loaded, isTrue);
      expect(find.text('map-loaded'), findsOneWidget);
    });

    testWidgets('AppAnimatedIndexedStack lazyMount skips unvisited tabs', (
      tester,
    ) async {
      var mapBuilt = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAnimatedIndexedStack(
              index: 0,
              lazyMount: true,
              children: [
                const Text('home-tab'),
                Builder(
                  builder: (_) {
                    mapBuilt = true;
                    return const Text('map-tab');
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('home-tab'), findsOneWidget);
      expect(mapBuilt, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAnimatedIndexedStack(
              index: 1,
              lazyMount: true,
              children: [
                const Text('home-tab'),
                Builder(
                  builder: (_) {
                    mapBuilt = true;
                    return const Text('map-tab');
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(mapBuilt, isTrue);
      expect(find.text('map-tab'), findsOneWidget);
    });
  });
}
