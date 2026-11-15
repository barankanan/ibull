import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/table_labels.dart';

void main() {
  test('an unsent draft alone blocks close and is not deleted', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: true,
      hasServerBill: false,
      sendResultUncertain: false,
    );
    expect(plan.action, GarsonDraftCloseAction.blocked);
    expect(plan.blocked, isTrue);
    expect(plan.cancelUnsentDraft, isFalse);
    expect(plan.recordsPayment, isFalse);
    expect(plan.writesHistory, isFalse);
    expect(plan.allowsServerCloseRpc, isFalse);
    expect(
      garsonCloseOrdersAreUnsentDraftOnly(<Map<String, dynamic>>[
        <String, dynamic>{'status': 'draft', 'items': <Map<String, dynamic>>[]},
      ]),
      isTrue,
    );
  });

  test('a server bill does not lift an unsent draft block', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: true,
      hasServerBill: true,
      sendResultUncertain: false,
    );
    expect(plan.action, GarsonDraftCloseAction.blocked);
    expect(plan.cancelUnsentDraft, isFalse);
    expect(plan.allowsServerCloseRpc, isFalse);
    expect(
      garsonCloseHasServerBill(<Map<String, dynamic>>[
        <String, dynamic>{'id': 'order-1', 'status': 'sent'},
        <String, dynamic>{'status': 'draft'},
      ]),
      isTrue,
    );
  });

  test('an uncertain send blocks close until the records match', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: false,
      hasServerBill: true,
      sendResultUncertain: true,
    );
    expect(plan.blocked, isTrue);
    expect(plan.allowsServerCloseRpc, isFalse);
    expect(plan.reason, contains('belirsiz'));
  });

  test('explicit draft cancel does not close the table', () {
    final decision = confirmGarsonDraftCancel();
    expect(decision.removedLocalDraft, isTrue);
    expect(decision.closesTable, isFalse);
    final stillBlocked = planGarsonTableClose(
      hasUnsentDraft: true,
      hasServerBill: true,
      sendResultUncertain: false,
    );
    expect(stillBlocked.allowsServerCloseRpc, isFalse);
  });

  test('a failed close RPC keeps the draft and the server orders', () {
    expect(garsonCloseFailurePreservesOrders(rpcSucceeded: false), isTrue);
    expect(garsonCloseFailurePreservesOrders(rpcSucceeded: true), isFalse);
    final plan = planGarsonTableClose(
      hasUnsentDraft: true,
      hasServerBill: true,
      sendResultUncertain: false,
    );
    expect(plan.cancelUnsentDraft, isFalse);
  });

  test('unverified money blocks close', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: false,
      hasServerBill: true,
      sendResultUncertain: false,
      unverifiedMoney: true,
    );
    expect(plan.blocked, isTrue);
    expect(plan.recordsPayment, isFalse);
    expect(plan.allowsServerCloseRpc, isFalse);
  });

  test('a verified server bill may close only through the server RPC', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: false,
      hasServerBill: true,
      sendResultUncertain: false,
    );
    expect(plan.action, GarsonDraftCloseAction.closeVerified);
    expect(plan.allowsServerCloseRpc, isTrue);
    expect(plan.cancelUnsentDraft, isFalse);
    expect(plan.recordsPayment, isFalse);
    expect(plan.writesHistory, isFalse);
  });

  test('an empty table does not invent a payment', () {
    final plan = planGarsonTableClose(
      hasUnsentDraft: false,
      hasServerBill: false,
      sendResultUncertain: false,
    );
    expect(plan.action, GarsonDraftCloseAction.alreadyEmpty);
    expect(plan.recordsPayment, isFalse);
    expect(plan.writesHistory, isFalse);
    expect(plan.cancelUnsentDraft, isFalse);
  });
}
