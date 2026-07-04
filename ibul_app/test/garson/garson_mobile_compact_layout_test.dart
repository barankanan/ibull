import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/garson/garson_compact_layout.dart';

void main() {
  group('garson compact layout helpers', () {
    test('isGarsonCompactLayout uses 900px breakpoint', () {
      expect(isGarsonCompactLayout(899), isTrue);
      expect(isGarsonCompactLayout(900), isFalse);
      expect(isGarsonCompactLayout(1200), isFalse);
    });
  });

  group('GarsonAreaFilterCompact', () {
    testWidgets('renders compact area dropdown', (tester) async {
      var selected = 'all';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: GarsonAreaFilterCompact(
                selectedKey: selected,
                options: const [
                  (key: 'all', label: 'Tüm Alanlar'),
                  (key: 'bahce', label: 'Bahçe'),
                ],
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Alan:'), findsOneWidget);
      expect(find.text('Tüm Alanlar'), findsOneWidget);
      expect(find.text('Alan Seç'), findsNothing);
    });
  });

  group('GarsonCompactStatsRow', () {
    testWidgets('renders single-line summary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GarsonCompactStatsRow(
              totalTables: 14,
              occupiedTables: 1,
              newCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('14 masa · 1 dolu · 0 yeni'), findsOneWidget);
      expect(find.text('Toplam Masa'), findsNothing);
      expect(find.text('Mutfakta'), findsNothing);
    });
  });

  group('GarsonAreaSectionHeaderCompact', () {
    testWidgets('renders compact section header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GarsonAreaSectionHeaderCompact(
              areaName: 'Bahçe',
              totalCount: 3,
              occupiedCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('BAHÇE'), findsOneWidget);
      expect(find.text('3 masa · 0 dolu · 3 boş'), findsOneWidget);
    });
  });

  group('compact layout visibility contract', () {
    testWidgets('compact width hides hero banner text', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LayoutBuilder(
            builder: (context, constraints) {
              final compact = isGarsonCompactLayout(constraints.maxWidth);
              return Column(
                children: [
                  if (!compact)
                    const Text('Garson • Masa Siparişleri'),
                  const GarsonCompactStatsRow(
                    totalTables: 2,
                    occupiedTables: 0,
                    newCount: 0,
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Garson • Masa Siparişleri'), findsNothing);
      expect(find.text('2 masa · 0 dolu · 0 yeni'), findsOneWidget);
    });

    testWidgets('desktop width keeps hero banner text', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LayoutBuilder(
            builder: (context, constraints) {
              final compact = isGarsonCompactLayout(constraints.maxWidth);
              return Column(
                children: [
                  if (!compact)
                    const Text('Garson • Masa Siparişleri'),
                  if (compact)
                    const GarsonCompactStatsRow(
                      totalTables: 2,
                      occupiedTables: 0,
                      newCount: 0,
                    ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('Garson • Masa Siparişleri'), findsOneWidget);
      expect(find.text('2 masa · 0 dolu · 0 yeni'), findsNothing);
    });
  });
}
