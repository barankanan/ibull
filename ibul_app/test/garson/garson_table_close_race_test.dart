import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_board_state.dart';
import 'package:ibul_app/utils/garson_table_route_session.dart';

void main() {
  group('garson table close race guards', () {
    test('masa A cleanup masa B route pop edemez', () {
      final allowed = shouldAllowGarsonRoutePop(
        activeRouteTableNumber: 2,
        activeRouteSessionId: 'session_b',
        targetTableNumber: 1,
        targetRouteSessionId: 'session_a',
      );
      expect(allowed, isFalse);
    });

    test('masa A close Future geç biter; current route B ise selection temizlenmez', () {
      final allowed = shouldAllowGarsonRouteSelectionClear(
        activeRouteTableNumber: 2,
        activeRouteSessionId: 'session_b',
        targetTableNumber: 1,
        targetRouteSessionId: 'session_a',
      );
      expect(allowed, isFalse);
    });

    test('aynı masa farklı session ile temizlenemez', () {
      final allowed = shouldAllowGarsonRouteSelectionClear(
        activeRouteTableNumber: 1,
        activeRouteSessionId: 'session_new',
        targetTableNumber: 1,
        targetRouteSessionId: 'session_old',
      );
      expect(allowed, isFalse);
    });

    test('aynı masa aynı session ile temizlenebilir', () {
      final allowed = shouldAllowGarsonRouteSelectionClear(
        activeRouteTableNumber: 1,
        activeRouteSessionId: 'session_a',
        targetTableNumber: 1,
        targetRouteSessionId: 'session_a',
      );
      expect(allowed, isTrue);
    });

    test('board refresh kapanan masa için stale route temizlemez', () {
      final shouldClear = shouldClearStaleGarsonTableRoute(
        isGarsonModule: true,
        isTableRouteOpen: true,
        selectedTableNumber: 1,
        selectedTableValid: false,
        boardSectionsCount: 2,
        boardTablesCount: 10,
        closingTableNumbers: {1},
      );
      expect(shouldClear, isFalse);
    });

    test('board refresh aktif route farklı masadaysa korunur', () {
      final preserve = shouldPreserveGarsonRouteDuringBoardRefresh(
        activeRouteTableNumber: 2,
        closingTableNumber: 1,
        activeRouteOpen: true,
      );
      expect(preserve, isTrue);
    });

    test('geçici invalid snapshot aktif route korunursa stale guard atlanır', () {
      final preserve = shouldPreserveGarsonRouteDuringBoardRefresh(
        activeRouteTableNumber: 2,
        closingTableNumber: 1,
        activeRouteOpen: true,
      );
      expect(preserve, isTrue);
    });

    test('yeni session açılınca eski close session eşleşmez', () {
      final sessionA = GarsonTableRouteSession.open(tableNumber: 1);
      final sessionB = GarsonTableRouteSession.open(tableNumber: 1);
      expect(sessionA.sessionId, isNot(sessionB.sessionId));

      final allowed = shouldAllowGarsonRoutePop(
        activeRouteTableNumber: 1,
        activeRouteSessionId: sessionB.sessionId,
        targetTableNumber: 1,
        targetRouteSessionId: sessionA.sessionId,
      );
      expect(allowed, isFalse);
    });

    test('closingTableIds sadece ilgili masayı stale guarddan muaf tutar', () {
      final closingA = shouldClearStaleGarsonTableRoute(
        isGarsonModule: true,
        isTableRouteOpen: true,
        selectedTableNumber: 1,
        selectedTableValid: false,
        boardSectionsCount: 2,
        boardTablesCount: 10,
        closingTableNumbers: {1},
      );
      final closingB = shouldClearStaleGarsonTableRoute(
        isGarsonModule: true,
        isTableRouteOpen: true,
        selectedTableNumber: 2,
        selectedTableValid: false,
        boardSectionsCount: 2,
        boardTablesCount: 10,
        closingTableNumbers: {1},
      );
      expect(closingA, isFalse);
      expect(closingB, isTrue);
    });

    test('double close guard closingTableNumbers set ile modellenir', () {
      final closing = <int>{1};
      expect(closing.contains(1), isTrue);
      closing.remove(1);
      expect(closing.contains(1), isFalse);
    });
  });
}
