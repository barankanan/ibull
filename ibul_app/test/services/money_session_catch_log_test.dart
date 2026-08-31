import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('order and auth no longer swallow with catch (_)', () {
    final order = File('lib/services/order_service.dart').readAsStringSync();
    expect(order, isNot(contains('catch (_)')));
    expect(order, contains("context: 'walletReserveStatusUpdate'"));
    expect(order, contains("context: 'orderRollbackDelete'"));
    expect(order, contains("context: 'walletReserveRpcDecode'"));

    final auth = File('lib/services/auth_service.dart').readAsStringSync();
    expect(auth, isNot(contains('catch (_)')));
    expect(auth, contains("context: 'recordAuthLoginAttempt'"));
    expect(auth, contains("context: 'googleSignOut'"));
  });

  test('session and store identity lookups log swallowed failures', () {
    final appState = File('lib/core/app_state.dart').readAsStringSync();
    expect(appState, contains("context: 'applyCustomerSessionProfile'"));

    final appStateAuth = File('lib/core/app_state_auth.dart').readAsStringSync();
    expect(appStateAuth, isNot(contains('catch (_)')));
    expect(appStateAuth, contains("context: 'loadOwnedProductLists'"));

    final store = File('lib/services/store_service.dart').readAsStringSync();
    expect(store, contains("context: 'resolveStoreOwnerDirect'"));
    expect(store, contains("context: 'resolveStoreOwnerSubAdmin'"));
    expect(store, contains("context: 'getSellerIdByBusinessName'"));
  });
}
