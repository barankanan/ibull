import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/mall/auth/mall_auth_session.dart';
import 'package:ibul_app/features/mall/management/services/mall_management_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'mall_auth_fakes.dart';

const customerId = '11111111-1111-1111-1111-111111111111';
const mallUserId = '22222222-2222-2222-2222-222222222222';

void main() {
  late FakeSupabaseBackend backend;
  late SupabaseClient customer;
  late MemoryMallSessionStorage storage;
  late MallAuthSession mall;

  setUp(() async {
    backend = FakeSupabaseBackend({
      'baran@gmail.com': customerId,
      'avm@gmail.com': mallUserId,
    });
    customer = backend.client();
    storage = MemoryMallSessionStorage();
    mall = MallAuthSession(clientFactory: backend.client, storage: storage);
    await customer.auth.signInWithPassword(email: 'baran@gmail.com', password: 'secret123');
  });

  tearDown(() async {
    mall.dispose();
    await customer.dispose();
  });

  test('AVM login opens a second session without touching the customer', () async {
    await mall.restore();
    expect(mall.isSignedIn, isFalse);

    await mall.signIn(email: 'avm@gmail.com', password: 'secret123');

    expect(customer.auth.currentUser?.email, 'baran@gmail.com');
    expect(mall.currentUser?.email, 'avm@gmail.com');
    expect(identical(mall.client, customer), isFalse);
    expect(storage.value, contains('avm@gmail.com'));
    expect(storage.value, isNot(contains('baran@gmail.com')));
  });

  test('mall_members is queried with the AVM JWT and AVM user id', () async {
    await mall.signIn(email: 'avm@gmail.com', password: 'secret123');
    backend.requests.clear();

    await MallManagementRepository(session: mall).myMemberships();

    final request = backend.requests.singleWhere((r) => r.path == '/rest/v1/mall_members');
    expect(request.bearerSub, mallUserId);
    expect(request.query, contains('user_id=eq.$mallUserId'));
    expect(request.query, isNot(contains(customerId)));
  });

  test('AVM logout clears only the AVM session', () async {
    await mall.signIn(email: 'avm@gmail.com', password: 'secret123');

    await MallManagementRepository(session: mall).signOut();

    expect(mall.isSignedIn, isFalse);
    expect(storage.value, isNull);
    expect(customer.auth.currentUser?.email, 'baran@gmail.com');
  });

  test('customer logout leaves the AVM session', () async {
    await mall.signIn(email: 'avm@gmail.com', password: 'secret123');

    await customer.auth.signOut();

    expect(customer.auth.currentUser, isNull);
    expect(mall.currentUser?.email, 'avm@gmail.com');
    expect(storage.value, contains('avm@gmail.com'));
  });

  test('a restart restores the AVM session from its own storage key', () async {
    await mall.signIn(email: 'avm@gmail.com', password: 'secret123');
    final restarted = MallAuthSession(clientFactory: backend.client, storage: storage);
    addTearDown(restarted.dispose);

    final user = await restarted.restore();

    expect(user?.id, mallUserId);
    expect(restarted.currentUser?.email, 'avm@gmail.com');
    expect(SecureMallSessionStorage.key, 'ibul_mall_auth_session_v1');
  });

  test('wrong AVM password keeps both sessions as they were', () async {
    await expectLater(
      mall.signIn(email: 'avm@gmail.com', password: 'wrong-pass'),
      throwsA(isA<AuthException>()),
    );
    expect(mall.isSignedIn, isFalse);
    expect(storage.value, isNull);
    expect(customer.auth.currentUser?.email, 'baran@gmail.com');
  });
}
