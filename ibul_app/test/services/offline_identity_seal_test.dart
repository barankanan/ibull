import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/offline_identity_seal.dart';
import 'package:ibul_app/services/restaurant_offline/offline_panel_identity.dart';

class _MemoryVault implements OfflineSealKeyVault {
  _MemoryVault({this.key, this.writable = true});

  String? key;
  final bool writable;

  @override
  Future<String?> read() async => key;

  @override
  Future<String?> readOrCreate() async {
    if (key != null) return key;
    if (!writable) return null;
    return key = OfflineIdentitySeal.newKey();
  }
}

class _MemoryRecords implements OfflineIdentityRecordStore {
  final Map<String, Map<String, dynamic>> rows = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final row = rows[key];
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    rows[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> delete(String key) async {
    rows.remove(key);
  }
}

final _savedAt = DateTime.utc(2026, 11, 18, 10);

OfflinePanelIdentity _staff({Set<String> permissions = const <String>{'take_orders'}}) =>
    OfflinePanelIdentity(
      authUserId: 'staff-1',
      ownerId: 'rest-1',
      storeName: 'Lokanta',
      storeCategory: 'restoran',
      isOwner: false,
      savedAt: _savedAt,
      staffRole: 'sub_admin',
      permissions: permissions,
      visibleModules: const <String>{'garson'},
      jobTitle: 'Garson',
    );

void main() {
  late _MemoryRecords records;
  late _MemoryVault vault;
  late OfflinePanelIdentityStore store;
  final key = OfflinePanelIdentityStore.keyFor('staff-1');

  setUp(() {
    records = _MemoryRecords();
    vault = _MemoryVault();
    store = OfflinePanelIdentityStore(records: records, vault: vault);
  });

  test('a record sealed on this device reads back unchanged', () async {
    await store.save(_staff());
    final read = await store.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.ok);
    expect(read.identity!.permissions, <String>{'take_orders'});
    expect(read.identity!.isOwner, isFalse);
    expect(records.rows[key]!['seal'], isNotEmpty);
  });

  test('an edited permission list does not verify', () async {
    await store.save(_staff());
    records.rows[key]!['permissions'] = <String>['take_orders', 'close_table', 'finance'];
    final read = await store.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.tampered);
    expect(read.identity, isNull);
  });

  test('staff rewritten as owner, other restaurant or later date does not verify', () async {
    for (final edit in <void Function(Map<String, dynamic>)>[
      (row) => row['is_owner'] = true,
      (row) => row['owner_id'] = 'rest-2',
      (row) => row['saved_at'] = DateTime.utc(2027).toIso8601String(),
      (row) => row['visible_modules'] = <String>['garson', 'finance'],
      (row) => row['staff_role'] = 'owner',
      (row) => row['auth_user_id'] = 'staff-2',
    ]) {
      await store.save(_staff());
      edit(records.rows[key]!);
      final read = await store.readChecked('staff-1');
      expect(read.integrity, OfflineIdentityIntegrity.tampered);
      expect(read.identity, isNull);
    }
  });

  test('a record without a seal is not believed', () async {
    await vault.readOrCreate();
    records.rows[key] = _staff().toJson();
    final read = await store.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.tampered);
    expect(read.identity, isNull);
  });

  test('a record copied from another device does not verify here', () async {
    await store.save(_staff());
    final copied = Map<String, dynamic>.from(records.rows[key]!);
    final otherRecords = _MemoryRecords()..rows[key] = copied;
    final otherDevice = OfflinePanelIdentityStore(
      records: otherRecords,
      vault: _MemoryVault(key: OfflineIdentitySeal.newKey()),
    );
    final read = await otherDevice.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.tampered);
    expect(read.identity, isNull);
  });

  test('without a keystore nothing is saved and nothing is believed', () async {
    final noVault = OfflinePanelIdentityStore(
      records: records,
      vault: _MemoryVault(writable: false),
    );
    await noVault.save(_staff());
    expect(records.rows, isEmpty);

    await store.save(_staff());
    final read = await noVault.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.noDeviceKey);
    expect(read.identity, isNull);
  });

  test('the seal ignores the order permissions were saved in', () async {
    await store.save(_staff(permissions: const <String>{'b', 'a'}));
    records.rows[key]!['permissions'] = <String>['a', 'b'];
    expect(
      (await store.readChecked('staff-1')).integrity,
      OfflineIdentityIntegrity.ok,
    );
  });

  test('touch keeps the seal valid and records the last seen time', () async {
    await store.save(_staff());
    final later = _savedAt.add(const Duration(hours: 3));
    await store.touch('staff-1', later);
    final read = await store.readChecked('staff-1');
    expect(read.integrity, OfflineIdentityIntegrity.ok);
    expect(read.identity!.lastSeenAt, later);
    expect(read.identity!.savedAt, _savedAt);
  });

  test('a tampered record cannot be re-sealed through touch', () async {
    await store.save(_staff());
    records.rows[key]!['is_owner'] = true;
    await store.touch('staff-1', _savedAt.add(const Duration(hours: 1)));
    expect(
      (await store.readChecked('staff-1')).integrity,
      OfflineIdentityIntegrity.tampered,
    );
  });

  group('decision', () {
    OfflineStartDecision decide({
      required OfflinePanelIdentity? saved,
      OfflineIdentityIntegrity integrity = OfflineIdentityIntegrity.ok,
      DateTime? now,
      bool managed = true,
    }) => decideOfflineStart(
      currentAuthUserId: 'staff-1',
      saved: saved,
      savedIntegrity: integrity,
      hasLocalSnapshot: true,
      managedStaff: managed,
      now: now ?? _savedAt.add(const Duration(hours: 1)),
    );

    test('a tampered or unsealed record refuses the offline start', () {
      expect(
        decide(saved: null, integrity: OfflineIdentityIntegrity.tampered).verdict,
        OfflineStartVerdict.integrityFailed,
      );
      expect(
        decide(saved: null, integrity: OfflineIdentityIntegrity.noDeviceKey).verdict,
        OfflineStartVerdict.integrityFailed,
      );
    });

    test('staff are refused after 12 hours, owners after 72', () {
      expect(offlineStaffIdentityMaxAge, const Duration(hours: 12));
      expect(offlineIdentityMaxAge, const Duration(hours: 72));
      expect(
        decide(saved: _staff(), now: _savedAt.add(const Duration(hours: 11))).verdict,
        OfflineStartVerdict.allow,
      );
      expect(
        decide(saved: _staff(), now: _savedAt.add(const Duration(hours: 13))).verdict,
        OfflineStartVerdict.expired,
      );
    });

    test('a clock set back behind the last seen time is refused', () {
      final seen = _staff().copyWith(
        lastSeenAt: _savedAt.add(const Duration(hours: 20)),
      );
      expect(
        decide(saved: seen, now: _savedAt.add(const Duration(hours: 2))).verdict,
        OfflineStartVerdict.clockRolledBack,
      );
    });

    test('time already spent offline counts against the window', () {
      // Saved at 10:00, last seen 23:00 the same day: 13 hours have passed
      // whatever the wall clock says now.
      final seen = _staff().copyWith(
        lastSeenAt: _savedAt.add(const Duration(hours: 13)),
      );
      expect(
        decide(saved: seen, now: _savedAt.add(const Duration(hours: 13, minutes: 1))).verdict,
        OfflineStartVerdict.expired,
      );
    });
  });
}
