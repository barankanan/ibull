import 'package:flutter_test/flutter_test.dart';
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
}
