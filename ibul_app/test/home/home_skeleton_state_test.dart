import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/lazy_section_loader.dart';
import 'package:ibul_app/core/section_load_state.dart';
import 'package:ibul_app/widgets/home_category_card_section.dart';
import 'package:ibul_app/widgets/skeleton_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Home skeleton state', () {
    test('SectionLoadState loading sırasında error göstermez', () {
      final loading = SectionLoadState.beginLoading();
      expect(loading.isLoading, isTrue);
      expect(loading.shouldShowError, isFalse);
      expect(loading.logStateLabel, 'loading');
    });

    testWidgets('LazySectionLoader load tamamlanınca skeleton kalkar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazySectionLoader(
              sectionName: 'testSection',
              loader: () async {},
              skeleton: const SkeletonLoading(
                width: 200,
                height: 100,
                borderRadius: 8,
              ),
              builder: (_) => const Text('loaded-content'),
              fallbackDelay: Duration.zero,
              maxSkeletonDuration: const Duration(seconds: 1),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsOneWidget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('loaded-content'), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsNothing);
    });

    testWidgets('LazySectionLoader timeout olursa skeleton sonsuz kalmaz', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazySectionLoader(
              sectionName: 'timeoutSection',
              loader: () => completer.future,
              skeleton: const SkeletonLoading(
                width: 200,
                height: 100,
                borderRadius: 8,
              ),
              builder: (_) => const Text('timeout-content'),
              fallbackDelay: Duration.zero,
              loadTimeout: const Duration(milliseconds: 100),
              maxSkeletonDuration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('timeout-content'), findsOneWidget);
      expect(find.byType(SkeletonLoading), findsNothing);
    });

    testWidgets('HomeCategoryCardSection empty data dönerse skeleton kalkar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryCardSections(
              groups: const [],
              isLoading: false,
              convertToProduct: (_) => throw UnimplementedError(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsNothing);
      expect(find.byType(HomeCategoryCardSection), findsNothing);
    });

    testWidgets('HomeCategoryCardSection loading bitince skeleton kalkar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryCardSections(
              groups: const [],
              isLoading: true,
              convertToProduct: (_) => throw UnimplementedError(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeCategoryCardSections(
              groups: const [],
              isLoading: false,
              convertToProduct: (_) => throw UnimplementedError(),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonLoading), findsNothing);
    });

    test('Sponsored empty state loading dışına çıkar', () {
      const empty = SectionLoadState(phase: SectionLoadPhase.empty);
      expect(empty.isLoading, isFalse);
      expect(empty.logStateLabel, 'empty');
      expect(empty.shouldShowError, isFalse);
    });
  });
}
