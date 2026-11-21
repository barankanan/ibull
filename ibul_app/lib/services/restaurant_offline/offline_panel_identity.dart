import 'package:flutter/foundation.dart';

import '../../core/secure_local_store.dart';
import 'offline_identity_seal.dart';

/// What this device last verified online about the signed-in account: which
/// restaurant it belongs to and what it may do there. It is written only after
/// a successful online load and is the single source for an offline start.
class OfflinePanelIdentity {
  const OfflinePanelIdentity({
    required this.authUserId,
    required this.ownerId,
    required this.storeName,
    required this.storeCategory,
    required this.isOwner,
    required this.savedAt,
    this.lastSeenAt,
    this.staffRole,
    this.permissions = const <String>{},
    this.visibleModules,
    this.jobTitle,
  });

  final String authUserId;
  final String ownerId;
  final String storeName;
  final String storeCategory;
  final bool isOwner;
  final DateTime savedAt;

  /// The latest time this device saw the record in use. It only moves
  /// forward; a wall clock behind it means the clock was set back.
  final DateTime? lastSeenAt;
  final String? staffRole;
  final Set<String> permissions;
  final Set<String>? visibleModules;
  final String? jobTitle;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'auth_user_id': authUserId,
    'owner_id': ownerId,
    'store_name': storeName,
    'store_category': storeCategory,
    'is_owner': isOwner,
    'saved_at': savedAt.toUtc().toIso8601String(),
    if (lastSeenAt != null)
      'last_seen_at': lastSeenAt!.toUtc().toIso8601String(),
    'staff_role': staffRole,
    'permissions': permissions.toList(growable: false),
    'visible_modules': visibleModules?.toList(growable: false),
    'job_title': jobTitle,
  };

  static OfflinePanelIdentity? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final authUserId = map['auth_user_id']?.toString().trim() ?? '';
    final ownerId = map['owner_id']?.toString().trim() ?? '';
    final savedAt = DateTime.tryParse(map['saved_at']?.toString() ?? '');
    if (authUserId.isEmpty || ownerId.isEmpty || savedAt == null) return null;
    Set<String>? readSet(Object? value) => value is List
        ? value.map((item) => item.toString()).toSet()
        : null;
    return OfflinePanelIdentity(
      authUserId: authUserId,
      ownerId: ownerId,
      storeName: map['store_name']?.toString() ?? '',
      storeCategory: map['store_category']?.toString() ?? '',
      isOwner: map['is_owner'] == true,
      savedAt: savedAt,
      lastSeenAt: DateTime.tryParse(map['last_seen_at']?.toString() ?? ''),
      staffRole: map['staff_role']?.toString(),
      permissions: readSet(map['permissions']) ?? const <String>{},
      visibleModules: readSet(map['visible_modules']),
      jobTitle: map['job_title']?.toString(),
    );
  }

  OfflinePanelIdentity copyWith({DateTime? lastSeenAt}) => OfflinePanelIdentity(
    authUserId: authUserId,
    ownerId: ownerId,
    storeName: storeName,
    storeCategory: storeCategory,
    isOwner: isOwner,
    savedAt: savedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    staffRole: staffRole,
    permissions: permissions,
    visibleModules: visibleModules,
    jobTitle: jobTitle,
  );
}

/// Whether the saved record can be believed.
enum OfflineIdentityIntegrity {
  /// Sealed on this device and unchanged since.
  ok,

  /// Nothing saved for this account.
  missing,

  /// Edited, unsealed, or sealed on another device.
  tampered,

  /// This device has no keystore secret, so no record can be checked.
  noDeviceKey,
}

class OfflineIdentityRead {
  const OfflineIdentityRead(this.integrity, [this.identity]);

  final OfflineIdentityIntegrity integrity;
  final OfflinePanelIdentity? identity;
}

enum OfflineStartVerdict {
  /// Open Garson and Sistem from local data with the saved permissions.
  allow,

  /// No signed-in session on this device.
  noSession,

  /// This account was never verified online on this device.
  neverVerified,

  /// The saved record belongs to another account.
  otherAccount,

  /// The last online verification is older than [offlineIdentityMaxAge].
  expired,

  /// The menu and tables were never saved on this device.
  noLocalData,

  /// The saved record was edited, copied from another device, or cannot be
  /// checked because this device has no keystore secret.
  integrityFailed,

  /// The device clock is behind the last time the record was used.
  clockRolledBack,
}

/// How long the owner's device may keep opening offline without seeing the
/// server. Nobody else can revoke the owner, so this window only limits a
/// lost or copied device; three days covers a long outage.
const Duration offlineIdentityMaxAge = Duration(hours: 72);

/// Staff permissions can be withdrawn by the owner at any time, and a device
/// that is offline cannot hear about it. A staff record is therefore good
/// for one shift only: a revoked account loses offline access after 12 hours
/// at the latest, and loses online access at once. While the cloud is
/// reachable the record is renewed in the background, so a working shift
/// does not run into this limit.
const Duration offlineStaffIdentityMaxAge = Duration(hours: 12);

/// Tolerated backwards clock drift before the clock counts as set back.
const Duration offlineClockRollbackTolerance = Duration(minutes: 10);

Duration offlineIdentityMaxAgeFor({required bool isOwner}) =>
    isOwner ? offlineIdentityMaxAge : offlineStaffIdentityMaxAge;

class OfflineStartDecision {
  const OfflineStartDecision(this.verdict, {this.identity});

  final OfflineStartVerdict verdict;
  final OfflinePanelIdentity? identity;

  bool get allowed => verdict == OfflineStartVerdict.allow;

  String get message {
    switch (verdict) {
      case OfflineStartVerdict.allow:
        return 'İnternet yok. Yerel verilerle Garson ve Sistem açıldı.';
      case OfflineStartVerdict.noSession:
        return 'İnternet yok ve bu cihazda açık oturum yok. Giriş için internet gerekir.';
      case OfflineStartVerdict.neverVerified:
        return 'İnternet yok. Bu hesap bu cihazda daha önce doğrulanmadığı için çevrimdışı açılamaz.';
      case OfflineStartVerdict.otherAccount:
        return 'İnternet yok. Bu cihazdaki kayıt başka bir hesaba ait; çevrimdışı açılamaz.';
      case OfflineStartVerdict.expired:
        return 'İnternet yok ve son doğrulama çok eski. Çevrimdışı açılış için önce internetle giriş yapın.';
      case OfflineStartVerdict.noLocalData:
        return 'İnternet yok ve bu cihazda kayıtlı menü ile masa verisi yok.';
      case OfflineStartVerdict.integrityFailed:
        return 'İnternet yok. Bu cihazdaki çevrimdışı yetki kaydı doğrulanamadı; çevrimdışı açılamaz. İnternetle giriş yapın.';
      case OfflineStartVerdict.clockRolledBack:
        return 'İnternet yok ve cihaz saati geri alınmış görünüyor. Çevrimdışı açılış için saati düzeltin veya internetle giriş yapın.';
    }
  }
}

/// Whether the panel may open without the server. Nothing here widens what
/// the account could do online: the saved permissions are used as they are,
/// and a managed staff account is never treated as the owner.
OfflineStartDecision decideOfflineStart({
  required String? currentAuthUserId,
  required OfflinePanelIdentity? saved,
  required bool hasLocalSnapshot,
  required bool managedStaff,
  required DateTime now,
  OfflineIdentityIntegrity savedIntegrity = OfflineIdentityIntegrity.ok,
  Duration? maxAge,
}) {
  final userId = currentAuthUserId?.trim() ?? '';
  if (userId.isEmpty) {
    return const OfflineStartDecision(OfflineStartVerdict.noSession);
  }
  if (savedIntegrity == OfflineIdentityIntegrity.tampered ||
      savedIntegrity == OfflineIdentityIntegrity.noDeviceKey) {
    return const OfflineStartDecision(OfflineStartVerdict.integrityFailed);
  }
  if (saved == null) {
    return const OfflineStartDecision(OfflineStartVerdict.neverVerified);
  }
  if (saved.authUserId != userId) {
    return const OfflineStartDecision(OfflineStartVerdict.otherAccount);
  }
  // A staff account whose saved record says "owner" is not believed.
  if (managedStaff && saved.isOwner) {
    return const OfflineStartDecision(OfflineStartVerdict.neverVerified);
  }
  final nowUtc = now.toUtc();
  final seen = saved.lastSeenAt?.toUtc();
  if (seen != null &&
      nowUtc.isBefore(seen.subtract(offlineClockRollbackTolerance))) {
    return const OfflineStartDecision(OfflineStartVerdict.clockRolledBack);
  }
  // Time already observed on this device counts even if the clock was
  // moved back to just after the save.
  final reference = seen != null && seen.isAfter(nowUtc) ? seen : nowUtc;
  final age = reference.difference(saved.savedAt.toUtc());
  final limit = maxAge ?? offlineIdentityMaxAgeFor(isOwner: saved.isOwner);
  if (age.isNegative || age > limit) {
    return const OfflineStartDecision(OfflineStartVerdict.expired);
  }
  if (!hasLocalSnapshot) {
    return const OfflineStartDecision(OfflineStartVerdict.noLocalData);
  }
  return OfflineStartDecision(OfflineStartVerdict.allow, identity: saved);
}

/// The two sections that work without the cloud.
const Set<String> offlineOperationModuleNames = <String>{
  'dashboard',
  'garson',
  'system',
};

/// Where the sealed record itself is kept. It needs no secrecy: the seal
/// makes an edited copy worthless.
abstract class OfflineIdentityRecordStore {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> value);
  Future<void> delete(String key);
}

class _SecureStoreRecords implements OfflineIdentityRecordStore {
  _SecureStoreRecords(this._store);

  final SecureLocalStore _store;

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final raw = await _store.readJson(key);
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) =>
      _store.writeJson(key, value);

  @override
  Future<void> delete(String key) => _store.delete(key);
}

/// The device secret in the platform keystore. A keystore that refuses the
/// read or the write yields null; nothing falls back to a settings file.
class KeystoreSealKeyVault implements OfflineSealKeyVault {
  KeystoreSealKeyVault({SecureLocalStore? store})
    : _store = store ?? SecureLocalStore.instance;

  final SecureLocalStore _store;

  @override
  Future<String?> read() => _store.readSecret(OfflineIdentitySeal.keyName);

  @override
  Future<String?> readOrCreate() async {
    final existing = await read();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = OfflineIdentitySeal.newKey();
    final stored = await _store.writeSecret(
      OfflineIdentitySeal.keyName,
      created,
    );
    return stored ? created : null;
  }
}

/// Debug builds without keystore access (ad-hoc signed test builds) may keep
/// the secret in the settings file when the build says so explicitly. This
/// keeps the sealing code path under test; it gives no protection and is
/// compiled out of release builds.
class _DebugSettingsSealKeyVault implements OfflineSealKeyVault {
  final SecureLocalStore _store = SecureLocalStore.instance;

  @override
  Future<String?> read() => _store.readString(OfflineIdentitySeal.keyName);

  @override
  Future<String?> readOrCreate() async {
    final existing = await read();
    if (existing != null && existing.isNotEmpty) return existing;
    final created = OfflineIdentitySeal.newKey();
    await _store.writeString(OfflineIdentitySeal.keyName, created);
    return created;
  }
}

const bool _kDebugUnprotectedSealKey = bool.fromEnvironment(
  'IBUL_DEBUG_UNPROTECTED_OFFLINE_SEAL',
);

/// True only for a debug build that asked for the unprotected seal key.
bool get offlineSealKeyUnprotected => kDebugMode && _kDebugUnprotectedSealKey;

OfflineSealKeyVault defaultOfflineSealKeyVault() => offlineSealKeyUnprotected
    ? _DebugSettingsSealKeyVault()
    : KeystoreSealKeyVault();

/// Local persistence of the last verified identity, one sealed record per
/// account. See [OfflineIdentitySeal].
class OfflinePanelIdentityStore {
  OfflinePanelIdentityStore({
    SecureLocalStore? store,
    OfflineIdentityRecordStore? records,
    OfflineSealKeyVault? vault,
  }) : _records =
           records ?? _SecureStoreRecords(store ?? SecureLocalStore.instance),
       _vault = vault ?? defaultOfflineSealKeyVault();

  final OfflineIdentityRecordStore _records;
  final OfflineSealKeyVault _vault;

  static String keyFor(String authUserId) =>
      'ibul.offline_panel_identity.${authUserId.trim()}';

  /// Seals and stores the identity. Without a device secret nothing is
  /// stored, and an older record is removed so it cannot be used.
  Future<void> save(OfflinePanelIdentity identity) async {
    final key = keyFor(identity.authUserId);
    final secret = await _vault.readOrCreate();
    if (secret == null || secret.isEmpty) {
      await _records.delete(key);
      return;
    }
    final record = identity
        .copyWith(lastSeenAt: identity.lastSeenAt ?? identity.savedAt)
        .toJson();
    record['seal_v'] = OfflineIdentitySeal.version;
    record['seal'] = OfflineIdentitySeal.sign(secret, record);
    await _records.write(key, record);
  }

  /// The saved identity together with whether it can be believed. The
  /// identity is returned only when its seal verifies on this device.
  Future<OfflineIdentityRead> readChecked(String authUserId) async {
    final id = authUserId.trim();
    if (id.isEmpty) {
      return const OfflineIdentityRead(OfflineIdentityIntegrity.missing);
    }
    try {
      final record = await _records.read(keyFor(id));
      if (record == null) {
        return const OfflineIdentityRead(OfflineIdentityIntegrity.missing);
      }
      final secret = await _vault.read();
      if (secret == null || secret.isEmpty) {
        return const OfflineIdentityRead(OfflineIdentityIntegrity.noDeviceKey);
      }
      final identity = OfflinePanelIdentity.fromJson(record);
      if (identity == null ||
          identity.authUserId != id ||
          !OfflineIdentitySeal.verify(secret, record)) {
        return const OfflineIdentityRead(OfflineIdentityIntegrity.tampered);
      }
      return OfflineIdentityRead(OfflineIdentityIntegrity.ok, identity);
    } catch (_) {
      return const OfflineIdentityRead(OfflineIdentityIntegrity.tampered);
    }
  }

  /// The identity when it verifies, otherwise null.
  Future<OfflinePanelIdentity?> read(String authUserId) async =>
      (await readChecked(authUserId)).identity;

  /// Moves the last-seen time forward. A record that does not verify is
  /// left alone, so this cannot be used to re-seal an edited record.
  Future<void> touch(String authUserId, DateTime now) async {
    final current = await readChecked(authUserId);
    final identity = current.identity;
    if (current.integrity != OfflineIdentityIntegrity.ok || identity == null) {
      return;
    }
    final seen = identity.lastSeenAt;
    if (seen != null && !now.toUtc().isAfter(seen.toUtc())) return;
    await save(identity.copyWith(lastSeenAt: now.toUtc()));
  }

  Future<void> clear(String authUserId) async {
    final id = authUserId.trim();
    if (id.isEmpty) return;
    await _records.delete(keyFor(id));
  }
}

/// Money operations are decided by the server (totals, remaining balance,
/// history). Without the cloud they are refused up front instead of being
/// attempted and left in an unknown state. Null means the operation may run.
String? offlineMoneyOperationBlock({
  required bool cloudReachable,
  required String operation,
}) {
  if (cloudReachable) return null;
  switch (operation) {
    case 'partialPayment':
      return 'İnternet yokken ara ödeme alınamaz. Ödeme kaydedilmedi. '
          'Bağlantı gelince yeniden deneyin.';
    case 'closeTable':
      return 'İnternet yokken hesap kesilemez. Masa açık kaldı, hiçbir '
          'ödeme kaydedilmedi. Bağlantı gelince yeniden deneyin.';
    case 'splitBill':
      return 'İnternet yokken kişi başı tutar hesaplanamaz: ödenen tutarlar '
          'sunucudan okunur. Hiçbir ödeme kaydedilmedi.';
    case 'transferTable':
      return 'İnternet yokken masa aktarılamaz. Siparişler yerinde kaldı, '
          'hiçbir kayıt değişmedi. Bağlantı gelince yeniden deneyin.';
    default:
      return 'İnternet yokken bu işlem yapılamaz. Hiçbir kayıt değişmedi.';
  }
}
