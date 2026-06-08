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
}
