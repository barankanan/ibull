import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_board_state.dart';

void main() {
  group('shouldWarnGarsonOrdersUntouched', () {
    test('owner closing a garson-only table (orders=0) does NOT warn', () {
      // The exact false-alarm the user kept hitting: table_orders existed,
      // no customer `orders` rows, identity matches → normal close, no scary
      // "kapatılamadı" message.
      expect(
        shouldWarnGarsonOrdersUntouched(
          ordersClosed: 0,
          hadTableOrders: true,
          identityMatches: true,
        ),
        isFalse,
      );
    });

    test('identity mismatch with untouched orders DOES warn (real risk)', () {
      expect(
        shouldWarnGarsonOrdersUntouched(
          ordersClosed: 0,
          hadTableOrders: true,
          identityMatches: false,
        ),
        isTrue,
      );
    });

    test('never warns when customer orders were actually closed', () {
      expect(
        shouldWarnGarsonOrdersUntouched(
          ordersClosed: 2,
          hadTableOrders: true,
          identityMatches: false,
        ),
        isFalse,
      );
    });

    test('never warns when the table had no orders at all', () {
      expect(
        shouldWarnGarsonOrdersUntouched(
          ordersClosed: 0,
          hadTableOrders: false,
          identityMatches: false,
        ),
        isFalse,
      );
    });
  });

  group('decideGarsonEmptyStateSelfHeal', () {
    final now = DateTime(2026, 6, 7, 15, 0, 0);

    test('not on garson → show empty (no background work elsewhere)', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: false,
          isTableRouteOpen: false,
          isLoading: false,
          attempts: 0,
          maxAttempts: 4,
          lastHealAt: null,
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.showEmpty,
      );
    });

    test('first collapse on garson board → schedules a reload', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: true,
          isTableRouteOpen: false,
          isLoading: false,
          attempts: 0,
          maxAttempts: 4,
          lastHealAt: null,
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.scheduleReload,
      );
    });

    test('while loading → shows loading without scheduling again', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: true,
          isTableRouteOpen: false,
          isLoading: true,
          attempts: 1,
          maxAttempts: 4,
          lastHealAt: now.subtract(const Duration(milliseconds: 200)),
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.showLoading,
      );
    });

    test('within throttle window → waits (loading), does not re-schedule', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: true,
          isTableRouteOpen: false,
          isLoading: false,
          attempts: 1,
          maxAttempts: 4,
          lastHealAt: now.subtract(const Duration(seconds: 1)),
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.showLoading,
      );
    });

    test('after throttle elapses → schedules the next attempt', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: true,
          isTableRouteOpen: false,
          isLoading: false,
          attempts: 1,
          maxAttempts: 4,
          lastHealAt: now.subtract(const Duration(seconds: 5)),
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.scheduleReload,
      );
    });

    test('budget exhausted → falls through to the real empty state', () {
      // Genuinely empty store: after maxAttempts the placeholder becomes the
      // final state and we stop re-fetching (no infinite loop).
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: true,
          isTableRouteOpen: false,
          isLoading: false,
          attempts: 4,
          maxAttempts: 4,
          lastHealAt: now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.showEmpty,
      );
    });

    test('table route open (no module) still self-heals', () {
      expect(
        decideGarsonEmptyStateSelfHeal(
          isGarsonVisible: false,
          isTableRouteOpen: true,
          isLoading: false,
          attempts: 0,
          maxAttempts: 4,
          lastHealAt: null,
          now: now,
        ),
        GarsonEmptyStateSelfHealAction.scheduleReload,
      );
    });
  });
}
