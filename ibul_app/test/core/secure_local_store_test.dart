import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/secure_local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const existingKey = 'ibul_phase3_existing_key';
  const freshKey = 'ibul_phase3_fresh_key';
  const sessionKey = 'ibul_phase3_session_token';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      existingKey: 'legacy-token',
    });
  });

  test('reads an existing key and writes a new fixture key', () async {
    final store = SecureLocalStore.instance;

    expect(await store.readString(existingKey), 'legacy-token');

    await store.writeString(freshKey, 'fresh-token');
    expect(await store.readString(freshKey), 'fresh-token');
  });

  test('delete removes the fixture key', () async {
    final store = SecureLocalStore.instance;
    await store.writeString(freshKey, 'to-delete');
    await store.delete(freshKey);
    expect(await store.readString(freshKey), isNull);
  });

  test('session token survives a second read in the same process', () async {
    final store = SecureLocalStore.instance;
    await store.delete(sessionKey);
    await store.writeString(sessionKey, 'session-abc');
    expect(await store.readString(sessionKey), 'session-abc');
    await store.delete(sessionKey);
    expect(await store.readString(sessionKey), isNull);
  });
}
