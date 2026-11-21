import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/offline_panel_identity.dart';

final _now = DateTime.utc(2026, 11, 18, 12);

OfflinePanelIdentity _identity({
  String user = 'user-1',
  bool isOwner = true,
  DateTime? savedAt,
  Set<String> permissions = const <String>{},
  Set<String>? visibleModules,
}) => OfflinePanelIdentity(
  authUserId: user,
  ownerId: 'rest-1',
  storeName: 'Lokanta',
  storeCategory: 'restoran',
  isOwner: isOwner,
  savedAt: savedAt ?? _now.subtract(const Duration(hours: 2)),
  staffRole: isOwner ? null : 'sub_admin',
  permissions: permissions,
  visibleModules: visibleModules,
);

OfflineStartDecision _decide({
  String? user = 'user-1',
  OfflinePanelIdentity? saved,
  bool snapshot = true,
  bool managed = false,
}) => decideOfflineStart(
  currentAuthUserId: user,
  saved: saved,
  hasLocalSnapshot: snapshot,
  managedStaff: managed,
  now: _now,
);

void main() {
  test('a device that verified this owner recently may open offline', () {
    final decision = _decide(saved: _identity());
    expect(decision.verdict, OfflineStartVerdict.allow);
    expect(decision.identity!.ownerId, 'rest-1');
  });

  test('no session, never verified, or another account stays closed', () {
    expect(_decide(user: null, saved: _identity()).verdict, OfflineStartVerdict.noSession);
    expect(_decide(saved: null).verdict, OfflineStartVerdict.neverVerified);
    expect(
      _decide(user: 'user-2', saved: _identity()).verdict,
      OfflineStartVerdict.otherAccount,
    );
  });

  test('an old verification stays closed; a staff record opens with no password gate', () {
    expect(
      _decide(saved: _identity(isOwner: false), managed: true).verdict,
      OfflineStartVerdict.allow,
    );
    expect(
      _decide(
        saved: _identity(savedAt: _now.subtract(const Duration(days: 8))),
      ).verdict,
      OfflineStartVerdict.expired,
    );
    // A record dated in the future is not trusted either.
    expect(
      _decide(saved: _identity(savedAt: _now.add(const Duration(days: 1)))).verdict,
      OfflineStartVerdict.expired,
    );
  });

  test('without the saved menu and tables there is nothing to open', () {
    expect(
      _decide(saved: _identity(), snapshot: false).verdict,
      OfflineStartVerdict.noLocalData,
    );
  });

  test('a staff account is never opened as the owner', () {
    expect(
      _decide(saved: _identity(isOwner: true), managed: true).verdict,
      OfflineStartVerdict.neverVerified,
    );
  });

  test('staff open with exactly the saved permissions', () {
    final decision = _decide(
      saved: _identity(
        isOwner: false,
        permissions: {'viewOrders', 'manageOrders'},
        visibleModules: {'garson'},
      ),
      managed: true,
    );
    expect(decision.allowed, isTrue);
    expect(decision.identity!.isOwner, isFalse);
    expect(decision.identity!.permissions, {'viewOrders', 'manageOrders'});
    expect(decision.identity!.visibleModules, {'garson'});
  });

  test('the record survives a save and read; a broken one is ignored', () {
    final original = _identity(
      isOwner: false,
      permissions: {'manageOrders'},
      visibleModules: {'garson', 'system'},
    );
    final restored = OfflinePanelIdentity.fromJson(original.toJson())!;
    expect(restored.authUserId, original.authUserId);
    expect(restored.ownerId, original.ownerId);
    expect(restored.isOwner, isFalse);
    expect(restored.permissions, original.permissions);
    expect(restored.visibleModules, original.visibleModules);
    expect(restored.savedAt.toUtc(), original.savedAt.toUtc());
    expect(OfflinePanelIdentity.fromJson({'owner_id': 'x'}), isNull);
    expect(OfflinePanelIdentity.fromJson('text'), isNull);
  });

  test('every refusal has its own message and none claims success', () {
    final messages = <String>{};
    for (final verdict in OfflineStartVerdict.values) {
      messages.add(OfflineStartDecision(verdict).message);
    }
    expect(messages, hasLength(OfflineStartVerdict.values.length));
    expect(offlineOperationModuleNames, {'garson', 'system'});
  });

  test('staff lose offline access after 12 hours, the owner after 72', () {
    final oneDay = _now.subtract(const Duration(hours: 24));
    expect(
      _decide(saved: _identity(isOwner: false, savedAt: oneDay), managed: true).verdict,
      OfflineStartVerdict.expired,
    );
    expect(
      _decide(saved: _identity(savedAt: oneDay)).verdict,
      OfflineStartVerdict.allow,
    );
    expect(
      _decide(saved: _identity(savedAt: _now.subtract(const Duration(hours: 73)))).verdict,
      OfflineStartVerdict.expired,
    );
    expect(
      _decide(
        saved: _identity(
          isOwner: false,
          savedAt: _now.subtract(const Duration(hours: 11)),
        ),
        managed: true,
      ).verdict,
      OfflineStartVerdict.allow,
    );
  });

  test('money operations are refused without the cloud, with their own text', () {
    expect(
      offlineMoneyOperationBlock(cloudReachable: true, operation: 'closeTable'),
      isNull,
    );
    final pay = offlineMoneyOperationBlock(
      cloudReachable: false,
      operation: 'partialPayment',
    )!;
    final close = offlineMoneyOperationBlock(
      cloudReachable: false,
      operation: 'closeTable',
    )!;
    expect(pay, contains('kaydedilmedi'));
    expect(close, contains('Masa açık kaldı'));
    expect(pay, isNot(close));
    for (final text in [pay, close]) {
      expect(text.toLowerCase(), isNot(contains('başarı')));
    }
  });
}
