import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/order_send_access.dart';
import 'package:ibul_app/services/store/table_operation_access.dart';

void main() {
  test('final staff denial does not fall back to a direct write', () {
    expect(
      shouldFallbackToDirectTableWrite(
        code: '42501',
        message: 'Bu restoran için masa işlemi yetkiniz yok.',
      ),
      isFalse,
    );
    expect(
      isFinalTableOperationDenialError(
        Exception(
          'Masa aktarımı yapılamadı. Bu restoran için masa işlemi yetkiniz yok.',
        ),
      ),
      isTrue,
    );
  });

  test('older owner-only rejection still uses the compatibility fallback', () {
    expect(
      shouldFallbackToDirectTableWrite(
        code: '42501',
        message: 'Yetki hatası: bu masayı kapatma yetkiniz yok.',
      ),
      isTrue,
    );
    expect(
      shouldFallbackToDirectTableWrite(
        code: '42883',
        message: 'function public.close_table_orders does not exist',
      ),
      isTrue,
    );
    expect(
      shouldFallbackToDirectTableWrite(
        code: 'PGRST202',
        message: 'Could not find the function public.transfer_table_orders',
      ),
      isTrue,
    );
  });

  test('permission wording stays recognizable for the existing RLS path', () {
    expect(
      isTableOperationPermissionDenied(
        code: '42501',
        message: 'permission denied for table table_orders',
      ),
      isTrue,
    );
    expect(
      isTableOperationPermissionDenied(
        message: 'new row violates row-level security policy',
      ),
      isTrue,
    );
    expect(
      isFinalTableOperationDenial(
        message: 'new row violates row-level security policy',
      ),
      isFalse,
    );
  });

  test('missing close RPC is blocked and an unclear payload is read-only', () {
    expect(
      decideCloseTableRpc(
        functionMissing: true,
        timedOut: false,
        ordersUpdated: 2,
      ),
      CloseTableRpcDecision.blocked,
    );
    expect(
      decideCloseTableRpc(
        functionMissing: false,
        timedOut: true,
        ordersUpdated: 2,
      ),
      CloseTableRpcDecision.readOnly,
    );
    expect(
      decideCloseTableRpc(
        functionMissing: false,
        timedOut: false,
        ordersUpdated: null,
      ),
      CloseTableRpcDecision.readOnly,
    );
    expect(
      decideCloseTableRpc(
        functionMissing: false,
        timedOut: false,
        ordersUpdated: 0,
      ),
      CloseTableRpcDecision.accept,
    );
    expect(
      isCloseTableRpcMissing(
        code: 'PGRST202',
        message: 'Could not find the function public.close_table_with_history',
      ),
      isTrue,
    );
  });

  test('target close is confirmed only for this table and this session', () {
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: 0,
        historyMatchesSession: true,
      ),
      TargetTableCloseVerdict.confirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: 0,
        historyMatchesSession: false,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 1,
        openCustomerOrders: 0,
        historyMatchesSession: true,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: 1,
        historyMatchesSession: true,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: null,
        openCustomerOrders: 0,
        historyMatchesSession: true,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: null,
        historyMatchesSession: true,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: 0,
        historyMatchesSession: null,
      ),
      TargetTableCloseVerdict.notConfirmed,
    );
  });

  test('open orders on another table or visit do not count as this close', () {
    const seller = '7264153b-f493-4508-8402-5fa8cfaabed8';
    const otherSeller = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
    final rows = [
      {'table': 1, 'seller': seller, 'session': 'salon'},
      {'table': 11, 'seller': otherSeller, 'session': 'bahce-visit'},
      {'table': 11, 'seller': seller, 'session': 'old-visit'},
      {'table': 11, 'seller': seller, 'session': 'bahce-visit'},
    ];
    final matching = rows.where(
      (row) => rowIsTargetCloseSession(
        targetTableNumber: 11,
        targetSellerId: seller,
        rowTableNumber: row['table'] as int,
        rowSellerId: row['seller'] as String,
        targetSessionKey: 'bahce-visit',
        rowSessionKey: row['session'] as String,
        sessionScoped: true,
      ),
    );
    expect(matching, hasLength(1));
    expect(
      judgeTargetTableCloseRead(
        openTableOrders: 0,
        openCustomerOrders: 0,
        historyMatchesSession: matching.length == 1,
      ),
      TargetTableCloseVerdict.confirmed,
    );
  });

  test('rpc timeout forbids every later close write', () {
    expect(
      furtherCloseWritesAllowed(rpcTimedOut: true, writesForbidden: false),
      isFalse,
    );
    expect(
      furtherCloseWritesAllowed(rpcTimedOut: true, writesForbidden: true),
      isFalse,
    );
    expect(
      furtherCloseWritesAllowed(rpcTimedOut: false, writesForbidden: true),
      isFalse,
    );
    expect(
      furtherCloseWritesAllowed(rpcTimedOut: false, writesForbidden: false),
      isTrue,
    );
    expect(
      isCloseWriteForbiddenError(StateError(closeTableRpcUnverifiedMessage)),
      isTrue,
    );
    expect(
      isCloseWriteForbiddenError(StateError(closeTableRpcBlockedMessage)),
      isTrue,
    );
    expect(
      isCloseWriteForbiddenError(StateError(diagnosticWriteRefusedMessage)),
      isTrue,
    );
    expect(isCloseWriteForbiddenError(Exception('network reset')), isFalse);
  });

  test('timeout verification source only reads the target table', () {
    final source = File(
      'lib/services/store/store_table_service.dart',
    ).readAsStringSync();
    final verifyAt = source.indexOf(
      'Future<Map<String, dynamic>> _readOnlyCloseVerification',
    );
    final timeoutAt = source.lastIndexOf('} on TimeoutException', verifyAt);
    final historyAt = source.indexOf('Future<bool> ensureTableHistoryRecorded');
    expect(timeoutAt, greaterThan(0));
    expect(verifyAt, greaterThan(timeoutAt));
    expect(historyAt, greaterThan(verifyAt));
    final timeoutBody = source.substring(timeoutAt, verifyAt);
    final verifyBody = source.substring(verifyAt, historyAt);
    for (final body in [timeoutBody, verifyBody]) {
      expect(body.contains('.insert('), isFalse);
      expect(body.contains('.update('), isFalse);
      expect(body.contains('.delete('), isFalse);
      expect(body.contains('closeRestaurantOrdersForTable'), isFalse);
      expect(body.contains('ensureTableHistoryRecorded'), isFalse);
      expect(body.contains('_closeTableClientSide'), isFalse);
    }
    expect(timeoutBody.contains('_readOnlyCloseVerification'), isTrue);
    expect(verifyBody.contains(".from('table_orders')"), isTrue);
    expect(verifyBody.contains(".from('orders')"), isTrue);
    expect(verifyBody.contains(".from('table_order_history')"), isTrue);
    expect(verifyBody.contains(".eq('table_number', tableNumber)"), isTrue);
    expect(verifyBody.contains(".eq('session_key', session)"), isTrue);
    expect(verifyBody.contains('writes_forbidden'), isTrue);
  });

  test('panel skips database writes after an unverified close', () {
    final panel = File('lib/screens/seller_panel_page.dart').readAsStringSync();
    expect(panel.contains('isCloseWriteForbiddenError(bulkErr)'), isTrue);
    expect(panel.contains("closeResult['writes_forbidden'] == true"), isTrue);
    expect(
      panel.contains('if (!writesForbidden && targetOrderIds.isNotEmpty)'),
      isTrue,
    );
    expect(panel.contains('if (!writesForbidden)'), isTrue);
  });
}
