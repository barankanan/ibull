import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/home_mobile_shortcut.dart';
import 'package:ibul_app/widgets/feature_menu.dart';

void main() {
  group('HomeMobileShortcutRegistry', () {
    test('tüm mobil kısayollar eşlenir', () {
      const keys = [
        'yakin_lokasyon',
        'urun_listele',
        'gorsel_zeka',
        'urun_parcala',
        'yakinda',
        'ibul_premium',
        'bana_ozel',
        'hizli_yemek',
        'yapay_zeka',
      ];

      for (final key in keys) {
        expect(HomeMobileShortcutRegistry.fromKey(key), isNotNull, reason: key);
      }
    });

    test('Yakın Lokasyon nearbyLocation tipindedir', () {
      final action = HomeMobileShortcutRegistry.fromKey('yakin_lokasyon');
      expect(action!.type, HomeMobileShortcutType.nearbyLocation);
    });

    test('Bana Özel personalized tipindedir', () {
      final action = HomeMobileShortcutRegistry.fromKey('bana_ozel');
      expect(action!.type, HomeMobileShortcutType.personalized);
    });

    test('Hızlı Yemek Yemek kategorisine map edilir', () {
      final action = HomeMobileShortcutRegistry.fromKey('hizli_yemek');
      expect(action!.categorySlug, 'Yemek');
    });

    test('Premium ve Yakında kısayolları rafa gider', () {
      expect(
        HomeMobileShortcutRegistry.fromKey('yakinda')!.type,
        HomeMobileShortcutType.comingSoonShelf,
      );
      expect(
        HomeMobileShortcutRegistry.fromKey('ibul_premium')!.type,
        HomeMobileShortcutType.comingSoonShelf,
      );
    });
  });

  group('FeatureMenu', () {
    testWidgets('kartlar render edilir ve onTap çalışır', (tester) async {
      String? tappedKey;
      String? tappedLabel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureMenu(
              onShortcutTap: (key, label) {
                tappedKey = key;
                tappedLabel = label;
              },
            ),
          ),
        ),
      );

      expect(find.text('Yakın Lokasyon'), findsOneWidget);
      await tester.tap(find.text('Yakın Lokasyon'));
      await tester.pump();

      expect(tappedKey, 'yakin_lokasyon');
      expect(tappedLabel, 'Yakın Lokasyon');
    });

    testWidgets('onTap null değildir', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureMenu(
              onShortcutTap: (key, label) => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Yapay Zeka'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('web pointer click cursor içerir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureMenu(onShortcutTap: (key, label) {}),
          ),
        ),
      );

      final mouseRegions = tester.widgetList<MouseRegion>(
        find.byType(MouseRegion),
      );
      expect(
        mouseRegions.any((region) => region.cursor == SystemMouseCursors.click),
        isTrue,
      );
    });

    test('FeatureMenu.featureConfigs 8 kart içerir', () {
      expect(FeatureMenu.featureConfigs.length, 8);
      expect(
        FeatureMenu.featureConfigs.every((config) => config.key.isNotEmpty),
        isTrue,
      );
      final yakinda = FeatureMenu.featureConfigs.firstWhere(
        (config) => config.key == 'yakinda',
      );
      expect(yakinda.comingSoon, isTrue);
      expect(
        FeatureMenu.featureConfigs.any((c) => c.key == 'ibul_premium'),
        isFalse,
      );
    });

    testWidgets('Yakında kartı rozet gösterir, Premium ayrı kart değildir',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FeatureMenu()),
        ),
      );

      expect(find.text('Yakında'), findsWidgets);
      expect(find.text('İBUL Premium'), findsNothing);
    });
  });
}
