import 'package:shared_preferences/shared_preferences.dart';

/// The waiter send key and the exact payload it belongs to.
class WaiterSubmitIdentity {
  const WaiterSubmitIdentity({required this.key, required this.payload});

  final String key;
  final String payload;
}

/// Keeps one in-flight table send across an app restart.
/// A new key is created only after the previous send is confirmed.
class WaiterSubmitIdentityStore {
  WaiterSubmitIdentityStore({Map<String, String>? memory}) : _memory = memory;

  final Map<String, String>? _memory;

  String _keyName(String scope) => 'waiter_submit_key:$scope';
  String _payloadName(String scope) => 'waiter_submit_payload:$scope';

  Future<WaiterSubmitIdentity?> read(String scope) async {
    final memory = _memory;
    if (memory != null) {
      final key = memory[_keyName(scope)];
      final payload = memory[_payloadName(scope)];
      if (key == null || key.isEmpty || payload == null) return null;
      return WaiterSubmitIdentity(key: key, payload: payload);
    }
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyName(scope));
    final payload = prefs.getString(_payloadName(scope));
    if (key == null || key.isEmpty || payload == null) return null;
    return WaiterSubmitIdentity(key: key, payload: payload);
  }

  Future<void> save(String scope, WaiterSubmitIdentity identity) async {
    final memory = _memory;
    if (memory != null) {
      memory[_keyName(scope)] = identity.key;
      memory[_payloadName(scope)] = identity.payload;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName(scope), identity.key);
    await prefs.setString(_payloadName(scope), identity.payload);
  }

  Future<void> clear(String scope) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(_keyName(scope));
      memory.remove(_payloadName(scope));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName(scope));
    await prefs.remove(_payloadName(scope));
  }
}
