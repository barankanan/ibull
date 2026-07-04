import 'package:flutter_test/flutter_test.dart';

/// Models the close-table critical vs background phase split used by
/// [_closeGarsonTable] in seller_panel_page.dart.
class GarsonClosePhasePlan {
  const GarsonClosePhasePlan({
    required this.criticalSteps,
    required this.backgroundSteps,
  });

  final List<String> criticalSteps;
  final List<String> backgroundSteps;

  bool get canOptimisticUpdateAfterCritical => criticalSteps.isNotEmpty;

  bool blocksUiOnBackground(String step) => criticalSteps.contains(step);
}

GarsonClosePhasePlan defaultClosePhasePlan() {
  return const GarsonClosePhasePlan(
    criticalSteps: <String>[
      'closeTableWithHistory',
      'closeRestaurantOrdersForTable',
      'verifyById',
      'ensureTableHistoryRecorded',
      'verifyMergedSnapshot',
      'optimisticBoardUpdate',
    ],
    backgroundSteps: <String>[
      'cacheGarsonLastGoodSections',
      'reloadRestaurantDashboardMetrics',
      'consolidateDuplicateHistoryChain',
      'fullBoardProductsFetch',
    ],
  );
}

void main() {
  group('garson table close performance plan', () {
    test('critical DB steps bittikten sonra optimistic update yapılabilir', () {
      final plan = defaultClosePhasePlan();
      expect(plan.canOptimisticUpdateAfterCritical, isTrue);
      expect(
        plan.criticalSteps,
        contains('optimisticBoardUpdate'),
      );
    });

    test('products fetch close flow critical pathte değil', () {
      final plan = defaultClosePhasePlan();
      expect(plan.blocksUiOnBackground('fullBoardProductsFetch'), isFalse);
      expect(
        plan.backgroundSteps,
        contains('fullBoardProductsFetch'),
      );
    });

    test('board section cache arka planda çalışabilir', () {
      final plan = defaultClosePhasePlan();
      expect(
        plan.backgroundSteps,
        contains('cacheGarsonLastGoodSections'),
      );
      expect(
        plan.criticalSteps,
        isNot(contains('cacheGarsonLastGoodSections')),
      );
    });

    test('non-critical refresh background listesinde', () {
      final plan = defaultClosePhasePlan();
      expect(
        plan.backgroundSteps,
        containsAll(<String>[
          'reloadRestaurantDashboardMetrics',
          'consolidateDuplicateHistoryChain',
        ]),
      );
    });
  });

  group('debounced board refresh model', () {
    test('ardışık refresh istekleri debounce edilir', () {
      var refreshCount = 0;
      DateTime? lastScheduled;
      const debounceMs = 300;

      void scheduleRefresh(DateTime now) {
        if (lastScheduled != null &&
            now.difference(lastScheduled!).inMilliseconds < debounceMs) {
          return;
        }
        lastScheduled = now;
        refreshCount++;
      }

      final t0 = DateTime(2026, 6, 30, 12, 0, 0);
      scheduleRefresh(t0);
      scheduleRefresh(t0.add(const Duration(milliseconds: 50)));
      scheduleRefresh(t0.add(const Duration(milliseconds: 400)));

      expect(refreshCount, 2);
    });
  });
}
