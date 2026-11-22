// Isolated macOS Keychain probe. No Firebase, no Supabase. It uses the app's
// real SecureLocalStore and OfflinePanelIdentityStore (copied in by
// build_and_run.sh), under a throw-away Keychain account.
// Phases (environment variable IBUL_KC_PHASE): write, read, tamper, nokey, cleanup.
// Each phase runs in its own process so persistence across a full
// quit-and-reopen is what is tested. Prints PROBE <phase> PASS|FAIL lines.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:keychain_probe/core/secure_local_store.dart';
import 'package:keychain_probe/services/restaurant_offline/offline_identity_seal.dart';
import 'package:keychain_probe/services/restaurant_offline/offline_panel_identity.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _phase = Platform.environment['IBUL_KC_PHASE'] ?? 'write';
const _uid = '11111111-1111-4111-8111-111111111111';
const _queueKey = 'ibul.kcprobe.queue';

final _ok = <String>[];
final _bad = <String>[];
void check(String name, bool pass) => (pass ? _ok : _bad).add(name);

OfflinePanelIdentity _identity() => OfflinePanelIdentity(
      authUserId: _uid,
      ownerId: _uid,
      storeName: 'Probe Lokanta',
      storeCategory: 'restaurant',
      isOwner: true,
      savedAt: DateTime.utc(2026, 11, 18, 12),
      permissions: const <String>{'manageOrders'},
    );

Future<void> run() async {
  final store = SecureLocalStore.instance;
  final ident = OfflinePanelIdentityStore();
  final prefs = await SharedPreferences.getInstance();
  final sealKey = OfflineIdentitySeal.keyName;
  final recordKey = OfflinePanelIdentityStore.keyFor(_uid);
  switch (_phase) {
    case 'write':
      await ident.clear(_uid);
      final wrote = await store.writeSecret(sealKey, OfflineIdentitySeal.newKey());
      check('keychain secret write succeeded (no fallback)', wrote);
      await ident.save(_identity());
      await store.writeJson(_queueKey, {'orders': [{'local_order_id': 'L-1', 'sync': 'pendingSync'}]});
      check('identity not copied to SharedPreferences', prefs.getString(recordKey) == null);
      check('queue not copied to SharedPreferences', prefs.getString(_queueKey) == null);
      check('seal key not copied to SharedPreferences', prefs.getString(sealKey) == null);
      check('identity readable in same process',
          (await ident.readChecked(_uid)).integrity == OfflineIdentityIntegrity.ok);
    case 'read':
      final r = await ident.readChecked(_uid);
      check('identity integrity ok after restart', r.integrity == OfflineIdentityIntegrity.ok);
      check('identity fields survive restart',
          r.identity?.ownerId == _uid && r.identity?.isOwner == true && r.identity?.storeName == 'Probe Lokanta');
      final q = await store.readJson(_queueKey);
      check('queue survives restart', q is Map && (q['orders'] as List).length == 1);
      check('nothing in SharedPreferences', prefs.getKeys().where((k) => k.startsWith('ibul.')).isEmpty);
    case 'tamper':
      final record = Map<String, dynamic>.from((await store.readJson(recordKey)) as Map);
      record['is_owner'] = true;
      record['permissions'] = ['manageOrders', 'manageFinance'];
      await store.writeJson(recordKey, record);
      check('edited record is rejected (tampered)',
          (await ident.readChecked(_uid)).integrity == OfflineIdentityIntegrity.tampered);
      check('edited record gives no identity', (await ident.readChecked(_uid)).identity == null);
    case 'nokey':
      await ident.save(_identity());
      check('re-sealed record verifies', (await ident.readChecked(_uid)).integrity == OfflineIdentityIntegrity.ok);
      await store.delete(sealKey);
      final r = await ident.readChecked(_uid);
      check('record without device key is refused',
          r.integrity == OfflineIdentityIntegrity.noDeviceKey && r.identity == null);
    case 'cleanup':
      await store.delete(sealKey);
      await store.delete(recordKey);
      await store.delete(_queueKey);
      check('cleaned', await store.readJson(_queueKey) == null);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await run();
  } catch (e) {
    check('no exception: $e', false);
  }
  for (final n in _ok) {
    stdout.writeln('PROBE $_phase PASS $n');
  }
  for (final n in _bad) {
    stdout.writeln('PROBE $_phase FAIL $n');
  }
  stdout.writeln('PROBE $_phase ${_bad.isEmpty ? 'RESULT_PASS' : 'RESULT_FAIL'} account=${SecureLocalStore.macOsAccountName}');
  await stdout.flush();
  exit(_bad.isEmpty ? 0 : 1);
}
