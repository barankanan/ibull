import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/panel/helpers/seller_panel_lifecycle_guards.dart';

void main() {
  group('canApplySellerPanelAsyncUpdate', () {
    test('returns false when unmounted', () {
      expect(
        canApplySellerPanelAsyncUpdate(
          mounted: false,
          requestId: 1,
          activeRequestId: 1,
        ),
        isFalse,
      );
    });

    test('returns false when request id is stale', () {
      expect(
        canApplySellerPanelAsyncUpdate(
          mounted: true,
          requestId: 1,
          activeRequestId: 2,
        ),
        isFalse,
      );
    });

    test('returns true when mounted and request id matches', () {
      expect(
        canApplySellerPanelAsyncUpdate(
          mounted: true,
          requestId: 3,
          activeRequestId: 3,
        ),
        isTrue,
      );
    });
  });

  group('sellerOrderIdsToHighlight', () {
    test('returns empty on first snapshot', () {
      expect(
        sellerOrderIdsToHighlight(
          hadPriorSnapshot: false,
          previousIds: <String>{},
          incomingIds: List<String>.generate(1000, (i) => 'order-$i'),
        ),
        isEmpty,
      );
    });

    test('returns only ids not in previous snapshot', () {
      expect(
        sellerOrderIdsToHighlight(
          hadPriorSnapshot: true,
          previousIds: <String>{'a', 'b'},
          incomingIds: <String>['a', 'b', 'c'],
        ),
        <String>['c'],
      );
    });
  });

  group('SellerOrderHighlightExpiryScheduler', () {
    test('schedules 1000 orders with a single active timer', () {
      final expired = <List<String>>[];
      final scheduler = SellerOrderHighlightExpiryScheduler(
        highlightDuration: const Duration(seconds: 30),
        onExpired: expired.add,
      );
      addTearDown(scheduler.dispose);

      for (var i = 0; i < 1000; i++) {
        scheduler.schedule('order-$i');
      }

      expect(scheduler.scheduledExpiryCount, 1000);
      expect(scheduler.activeTimerCount, 1);
    });

    test('fires onExpired and clears expired ids', () async {
      final expiredBatches = <List<String>>[];
      final scheduler = SellerOrderHighlightExpiryScheduler(
        highlightDuration: const Duration(milliseconds: 20),
        onExpired: expiredBatches.add,
      );
      addTearDown(scheduler.dispose);

      scheduler.schedule('order-1');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(expiredBatches, isNotEmpty);
      expect(expiredBatches.first, contains('order-1'));
      expect(scheduler.scheduledExpiryCount, 0);
      expect(scheduler.activeTimerCount, 0);
    });
  });
}
