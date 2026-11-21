import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ibul_app/services/restaurant_offline/lan_advertiser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';
import 'package:ibul_app/services/restaurant_offline/lan_staff_probe.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/seller_lan_center.dart';
import 'package:ibul_app/services/staff_login_policy.dart';

class _FakeAdvertiser implements LanAdvertiser {
  final List<Map<String, Object>> started = <Map<String, Object>>[];
  int stops = 0;

  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {
    started.add(<String, Object>{
      'name': instanceName,
      'port': port,
      'rid': restaurantId,
      'mid': machineId,
      'fp': fingerprint,
    });
  }

  @override
  Future<void> stop() async => stops++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));
  group('lanStaffDecision: nobody is accepted by default', () {
    test('no membership is rejected', () {
      expect(lanStaffDecision(null).kind, StaffProbeKind.rejected);
    });

    test('an inactive membership is rejected', () {
      expect(
        lanStaffDecision(<String, dynamic>{
          'status': 'inactive',
          'staff_role': 'waiter',
        }).kind,
        StaffProbeKind.rejected,
      );
    });

    test('the waiter role alone grants nothing', () {
      expect(
        lanStaffDecision(<String, dynamic>{
          'status': 'active',
          'staff_role': 'waiter',
          'permissions': <String>[],
        }).kind,
        StaffProbeKind.rejected,
      );
    });

    test('a sub-admin needs manageOrders', () {
      expect(
        lanStaffDecision(<String, dynamic>{
          'status': 'active',
          'staff_role': 'sub_admin',
          'permissions': <String>['viewFinance'],
        }).kind,
        StaffProbeKind.rejected,
      );
      expect(
        lanStaffDecision(<String, dynamic>{
          'status': 'active',
          'staff_role': 'sub_admin',
          'permissions': <String>['manageOrders'],
          'must_change_password': false,
          'credential_epoch': 3,
        }).kind,
        StaffProbeKind.active,
      );
    });

    test('a temporary password, or no password answer, is refused', () {
      Map<String, dynamic> row(Object? flag, {bool include = true}) =>
          <String, dynamic>{
            'status': 'active',
            'staff_role': 'sub_admin',
            'permissions': <String>['manageOrders'],
            if (include) 'must_change_password': flag,
            'credential_epoch': 1,
          };
      expect(lanStaffDecision(row(true)).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row(null, include: false)).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row('false')).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row(0)).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row(false)).kind, StaffProbeKind.active);
    });

    test('the credential epoch is passed on and must be an int', () {
      Map<String, dynamic> row(Object? epoch, {bool include = true}) =>
          <String, dynamic>{
            'status': 'active',
            'staff_role': 'sub_admin',
            'permissions': <String>['manageOrders'],
            'must_change_password': false,
            if (include) 'credential_epoch': epoch,
          };
      expect(lanStaffDecision(row(4)).credentialEpoch, 4);
      expect(lanStaffDecision(row(4)).kind, StaffProbeKind.active);
      expect(lanStaffDecision(row(null, include: false)).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row('4')).kind, StaffProbeKind.rejected);
      expect(lanStaffDecision(row(4.5)).kind, StaffProbeKind.rejected);
    });

    test('the authority reader asks the owner-only RPC and fails closed', () async {
      final calls = <String>[];
      final reader = lanStaffAuthorityReader((fn, params) async {
        calls.add('$fn:${params['p_staff_id']}');
        return <String, dynamic>{'found': false};
      }, 'r1');
      expect(await reader('s1'), isNull);
      expect(calls, <String>['lan_staff_authority:s1']);
      final missingRpc = lanStaffAuthorityReader(
        (fn, params) async => throw StateError('PGRST202 function not found'),
        'r1',
      );
      final probe = lanStaffProbe(missingRpc, restaurantId: 'r1');
      expect((await probe('s1')).kind, StaffProbeKind.rejected);
      final odd = lanStaffAuthorityReader((fn, params) async => 'x', 'r1');
      expect((await lanStaffProbe(odd)('s1')).kind, StaffProbeKind.rejected);
    });
  });

  group('lanStaffProbe', () {
    test('a dropped connection is unreachable, not a revocation', () async {
      final probe = lanStaffProbe((_) async => throw const SocketException('down'));
      expect((await probe('s1')).kind, StaffProbeKind.unreachable);
    });

    test('an unexpected failure rejects instead of accepting', () async {
      final probe = lanStaffProbe((_) async => throw StateError('rls denied'));
      expect((await probe('s1')).kind, StaffProbeKind.rejected);
    });

    test('an empty staff id is rejected without asking the server', () async {
      var asked = 0;
      final probe = lanStaffProbe((_) async {
        asked++;
        return <String, dynamic>{'status': 'active', 'staff_role': 'waiter'};
      });
      expect((await probe('  ')).kind, StaffProbeKind.rejected);
      expect(asked, 0);
    });
  });

  test('Bonjour record carries only the browser keys and a safe name', () {
    final args = dnsSdRegisterArguments(
      instanceName: 'IBUL; rm -rf /',
      port: 18772,
      restaurantId: 'rid-1',
      machineId: 'mid-1',
      fingerprint: 'abcd',
    );
    expect(args.sublist(0, 5), <String>['-R', 'IBUL rm -rf', '_ibul-lan._tcp', 'local.', '18772']);
    expect(args.sublist(5), <String>[
      'svc=ibul-lan',
      'rid=rid-1',
      'mid=mid-1',
      'fp=abcd',
    ]);
  });

  group('SellerLanCenter.start', () {
    late Directory temp;
    late _FakeAdvertiser advertiser;
    late LanAdvertiser original;
    const loopback = <LanInterfaceChoice>[
      LanInterfaceChoice(name: 'lo0', address: '127.0.0.1'),
    ];

    Future<Map<String, dynamic>?> allowAll(String _) async =>
        <String, dynamic>{'status': 'active', 'staff_role': 'waiter'};

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('ibul-seller-lan');
      advertiser = _FakeAdvertiser();
      original = SellerLanCenter.advertiser;
      SellerLanCenter.advertiser = advertiser;
      RestaurantLanHostRegistry.current = null;
      SellerLanCenter.accessReader = null;
    });

    tearDown(() async {
      await SellerLanCenter.stop();
      SellerLanCenter.advertiser = original;
      RestaurantLanHostRegistry.current = null;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('an evidence key that could not be registered at start is registered on reconnect', () async {
      final original = SellerLanCenter.evidenceKeyRegistrar;
      addTearDown(() => SellerLanCenter.evidenceKeyRegistrar = original);
      var cloudUp = false;
      final registered = <String>[];
      SellerLanCenter.evidenceKeyRegistrar = ({
        required String restaurantId,
        required String keyId,
        required String modulusHex,
        required String serverFingerprint,
        String? branchId,
      }) async {
        if (!cloudUp) throw const SocketException('Connection refused');
        registered.add(keyId);
        return 'branch-9';
      };
      final started = await SellerLanCenter.start(
        restaurantId: 'rid-ev',
        readMembership: allowAll,
        operatorConfirmed: true,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: loopback,
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(started.state, SellerLanCenterState.running);
      final host = RestaurantLanHostRegistry.current!;
      expect(registered, isEmpty, reason: 'cloud was away at start');
      expect(host.branchId ?? '', isEmpty);
      expect(await SellerLanCenter.ensureEvidenceKeyRegistered(restaurantId: 'rid-ev'), isFalse);
      cloudUp = true;
      expect(await SellerLanCenter.ensureEvidenceKeyRegistered(restaurantId: 'rid-ev'), isTrue);
      expect(registered, hasLength(1));
      expect(host.branchId, 'branch-9');
      // Another restaurant's id, or no running center, registers nothing.
      expect(await SellerLanCenter.ensureEvidenceKeyRegistered(restaurantId: 'other'), isFalse);
      expect(registered, hasLength(1));
    });

    test('without the owner\'s confirmation nothing opens', () async {
      final result = await SellerLanCenter.start(
        restaurantId: 'rid-1',
        readMembership: allowAll,
        operatorConfirmed: false,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: loopback,
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(result.state, SellerLanCenterState.needsConfirmation);
      expect(RestaurantLanHostRegistry.current?.listening ?? false, isFalse);
      expect(advertiser.started, isEmpty);
    });

    test('no trusted network interface means no listener', () async {
      final result = await SellerLanCenter.start(
        restaurantId: 'rid-1',
        readMembership: allowAll,
        operatorConfirmed: true,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: const <LanInterfaceChoice>[],
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(result.state, SellerLanCenterState.noNetwork);
      expect(RestaurantLanHostRegistry.current?.listening ?? false, isFalse);
    });

    test('a missing restaurant id fails without starting', () async {
      final result = await SellerLanCenter.start(
        restaurantId: ' ',
        readMembership: allowAll,
        operatorConfirmed: true,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: loopback,
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(result.state, SellerLanCenterState.failed);
    });

    test('a confirmed start opens one host, announces it and issues a code', () async {
      final result = await SellerLanCenter.start(
        restaurantId: 'rid-1',
        readMembership: allowAll,
        operatorConfirmed: true,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: loopback,
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(result.state, SellerLanCenterState.running, reason: result.message);
      final host = RestaurantLanHostRegistry.current!;
      expect(host.listening, isTrue);
      expect(host.boundAddress, '127.0.0.1');
      expect(advertiser.started, hasLength(1));
      expect(advertiser.started.single['rid'], 'rid-1');
      expect((advertiser.started.single['fp'] as String).isNotEmpty, isTrue);

      final first = host.issuePairingCode();
      final second = host.issuePairingCode();
      expect(first.code, isNot(second.code));
      expect(second.expiresAt.isAfter(DateTime.now()), isTrue);

      final again = await SellerLanCenter.start(
        restaurantId: 'rid-1',
        readMembership: allowAll,
        operatorConfirmed: true,
        materialDirectory: Directory('${temp.path}/lan'),
        interfaces: loopback,
        deviceStore: MemoryLanEnrollmentStore(),
        port: 0,
      );
      expect(again.state, SellerLanCenterState.alreadyRunning);
      expect(advertiser.started, hasLength(1));
    });
  });
}
