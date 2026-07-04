import 'package:flutter/foundation.dart';

/// Identifies a single Garson table detail route instance.
class GarsonTableRouteSession {
  GarsonTableRouteSession({
    required this.tableNumber,
    required this.sessionId,
    required this.openedAt,
    this.tableId,
  });

  final int tableNumber;
  final String? tableId;
  final String sessionId;
  final DateTime openedAt;

  factory GarsonTableRouteSession.open({
    required int tableNumber,
    String? tableId,
  }) {
    return GarsonTableRouteSession(
      tableNumber: tableNumber,
      tableId: tableId,
      sessionId:
          'garson_${tableNumber}_${DateTime.now().microsecondsSinceEpoch}',
      openedAt: DateTime.now(),
    );
  }
}

bool shouldAllowGarsonRouteSelectionClear({
  required int? activeRouteTableNumber,
  required String? activeRouteSessionId,
  required int? targetTableNumber,
  String? targetRouteSessionId,
}) {
  if (targetTableNumber == null || targetTableNumber <= 0) return true;
  if (activeRouteTableNumber == null) return true;
  if (activeRouteTableNumber != targetTableNumber) return false;
  if (targetRouteSessionId == null ||
      targetRouteSessionId.trim().isEmpty ||
      activeRouteSessionId == null) {
    return true;
  }
  return activeRouteSessionId == targetRouteSessionId;
}

bool shouldAllowGarsonRoutePop({
  required int? activeRouteTableNumber,
  required String? activeRouteSessionId,
  required int targetTableNumber,
  String? targetRouteSessionId,
}) {
  return shouldAllowGarsonRouteSelectionClear(
    activeRouteTableNumber: activeRouteTableNumber,
    activeRouteSessionId: activeRouteSessionId,
    targetTableNumber: targetTableNumber,
    targetRouteSessionId: targetRouteSessionId,
  );
}

bool shouldPreserveGarsonRouteDuringBoardRefresh({
  required int? activeRouteTableNumber,
  required int? closingTableNumber,
  required bool activeRouteOpen,
}) {
  if (!activeRouteOpen || activeRouteTableNumber == null) return false;
  if (closingTableNumber == null) return true;
  return activeRouteTableNumber != closingTableNumber;
}

void logGarsonCloseStart({
  required int tableNumber,
  String? tableId,
  String? tableName,
  String? activeOrderId,
  String? routeSessionId,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonClose][start] '
    'tableId=${tableId ?? '-'} '
    'tableName=${tableName ?? '-'} '
    'tableNumber=$tableNumber '
    'activeOrderId=${activeOrderId ?? '-'} '
    'routeSessionId=${routeSessionId ?? '-'} '
    'startedAt=${DateTime.now().toIso8601String()}',
  );
}

void logGarsonCloseStep({
  required int tableNumber,
  required String step,
  required int ms,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonClose][step] '
    'tableNumber=$tableNumber '
    'step=$step '
    'ms=$ms',
  );
}

void logGarsonCloseFinish({
  required int tableNumber,
  required String status,
  required int totalMs,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonClose][finish] '
    'tableNumber=$tableNumber '
    'status=$status '
    'totalMs=$totalMs',
  );
}

void logGarsonRouteOpen({
  required int tableNumber,
  required String routeSessionId,
  String? tableId,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonRoute][open] '
    'tableId=${tableId ?? '-'} '
    'tableNumber=$tableNumber '
    'routeSessionId=$routeSessionId '
    'openedAt=${DateTime.now().toIso8601String()}',
  );
}

void logGarsonRoutePopRequest({
  required String reason,
  required int targetTableNumber,
  int? currentRouteTableNumber,
  String? routeSessionId,
  required bool allowed,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonRoute][pop_request] '
    'reason=$reason '
    'targetTableId=$targetTableNumber '
    'currentRouteTableId=${currentRouteTableNumber ?? '-'} '
    'routeSessionId=${routeSessionId ?? '-'} '
    'allowed=$allowed',
  );
}

void logGarsonBoardRefresh({
  required String reason,
  int? closingTableId,
  int? activeRouteTableId,
  required bool shouldPreserveActiveRoute,
}) {
  if (!kDebugMode) return;
  debugPrint(
    '[GarsonBoard][refresh] '
    'reason=$reason '
    'closingTableId=${closingTableId ?? '-'} '
    'activeRouteTableId=${activeRouteTableId ?? '-'} '
    'shouldPreserveActiveRoute=$shouldPreserveActiveRoute',
  );
}
