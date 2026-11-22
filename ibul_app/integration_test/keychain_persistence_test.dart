// Real-device Keychain check. Run twice with the same IBUL_KEYCHAIN_ACCOUNT:
//   --dart-define=IBUL_KC_PHASE=write   then   --dart-define=IBUL_KC_PHASE=read
// A pass needs the secret to be in the Keychain (no SharedPreferences copy)
// and to survive a full process restart. Uses a throw-away account name.
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/secure_local_store.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phase = String.fromEnvironment('IBUL_KC_PHASE', defaultValue: 'write');
const _key = 'ibul.kctest.secret';
const _jsonKey = 'ibul.kctest.queue';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('keychain persistence ($_phase)', (tester) async {
    final store = SecureLocalStore.instance;
    final prefs = await SharedPreferences.getInstance();
    if (_phase == 'write') {
      final ok = await store.writeSecret(_key, 'seal-secret-v1');
      expect(ok, isTrue, reason: 'Keychain write failed (no fallback allowed)');
      await store.writeString(_jsonKey, '{"orders":[{"id":"L1"}]}');
      expect(prefs.getString(_key), isNull);
      expect(prefs.getString(_jsonKey), isNull,
          reason: 'value fell back to SharedPreferences, not the Keychain');
    } else {
      expect(await store.readString(_key), 'seal-secret-v1');
      expect(await store.readString(_jsonKey), '{"orders":[{"id":"L1"}]}');
      expect(prefs.getString(_key), isNull);
      expect(prefs.getString(_jsonKey), isNull);
      await store.delete(_key);
      await store.delete(_jsonKey);
      expect(await store.readString(_key), isNull);
    }
  });
}
