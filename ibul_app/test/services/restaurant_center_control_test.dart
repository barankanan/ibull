import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/domain/store_vertical.dart';
import 'package:ibul_app/services/bridge_lifecycle_service.dart';
import 'package:ibul_app/services/bridge_manager.dart';
import 'package:ibul_app/services/print_service_start_gate.dart';
import 'package:ibul_app/services/restaurant_offline/lan_advertiser.dart';
import 'package:ibul_app/services/restaurant_offline/lan_interface.dart';
import 'package:ibul_app/services/restaurant_offline/offline_identity_seal.dart';
import 'package:ibul_app/services/restaurant_offline/offline_panel_identity.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_access.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_control.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_cache_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_local_print_queue_service.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_models.dart';
import 'package:ibul_app/services/restaurant_offline/seller_lan_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentAdvertiser implements LanAdvertiser {
  @override
  Future<void> start({
    required String instanceName,
    required int port,
    required String restaurantId,
    required String machineId,
    required String fingerprint,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _Records implements OfflineIdentityRecordStore {
  final Map<String, Map<String, dynamic>> rows = <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => rows[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async =>
      rows[key] = Map<String, dynamic>.from(value);

  @override
  Future<void> delete(String key) async => rows.remove(key);
}

class _Vault implements OfflineSealKeyVault {
  @override
  Future<String?> read() async => 'a2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2s=';

  @override
  Future<String?> readOrCreate() async => 'a2tra2tra2tra2tra2tra2tra2tra2tra2tra2tra2s=';
}

RestaurantCenterAccess _decide({
  bool desktop = true,
  bool verified = true,
  String? category = 'Yemek / Restoran',
  bool record = true,
  bool owner = true,
  Set<String> permissions = const <String>{},
}) => decideRestaurantCenterAccess(
  desktopHost: desktop,
  accountVerified: verified,
  vertical: resolveStoreVertical(category),
  hasRestaurantRecord: record,
  isOwner: owner,
  permissions: permissions,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('who may run the printer center', () {
    test('an owner of a restaurant with saved restaurant records may', () {
      expect(_decide().allowed, isTrue);
    });

    test('wrong business type is refused', () {
      expect(_decide(category: 'Elektronik').denial, RestaurantCenterDenial.notRestaurant);
      expect(_decide(category: 'Emlak').denial, RestaurantCenterDenial.notRestaurant);
      expect(_decide(category: '').denial, RestaurantCenterDenial.unknownBusiness);
      expect(_decide(category: null).denial, RestaurantCenterDenial.unknownBusiness);
    });

    test('a food label without any restaurant record is not enough', () {
      expect(_decide(record: false).denial, RestaurantCenterDenial.noRestaurantRecord);
    });

    test('staff need the print settings permission', () {
      expect(
        _decide(owner: false, permissions: <String>{'manageOrders'}).denial,
        RestaurantCenterDenial.notAuthorised,
      );
      expect(
        _decide(owner: false, permissions: <String>{'managePrintSettings'}).allowed,
        isTrue,
      );
    });

    test('an unverified account and a phone or tablet are refused', () {
      expect(_decide(verified: false).denial, RestaurantCenterDenial.noVerifiedAccount);
      expect(_decide(desktop: false).denial, RestaurantCenterDenial.notDesktop);
      expect(restaurantCenterDesktopHost(platform: TargetPlatform.macOS, isWeb: false), isTrue);
      expect(restaurantCenterDesktopHost(platform: TargetPlatform.windows, isWeb: false), isTrue);
      expect(restaurantCenterDesktopHost(platform: TargetPlatform.iOS, isWeb: false), isFalse);
      expect(restaurantCenterDesktopHost(platform: TargetPlatform.android, isWeb: false), isFalse);
      expect(restaurantCenterDesktopHost(platform: TargetPlatform.macOS, isWeb: true), isFalse);
    });

    test('a restaurant never starts its bridge by opening the seller screen', () {
      expect(bridgeStartsWithSellerScreen(StoreVertical.restaurant), isFalse);
      expect(bridgeStartsWithSellerScreen(StoreVertical.unknown), isFalse);
      expect(bridgeStartsWithSellerScreen(StoreVertical.ecommerce), isTrue);
      expect(bridgeStartsWithSellerScreen(StoreVertical.gallery), isTrue);
      expect(bridgeStartsWithSellerScreen(StoreVertical.realEstate), isTrue);
    });
  });

  group('reading the facts saved on this device', () {
    late _Records records;
    late OfflinePanelIdentityStore identities;

    Future<void> save({
      String category = 'Restoran',
      bool owner = true,
      Set<String> permissions = const <String>{},
    }) => identities.save(
      OfflinePanelIdentity(
        authUserId: 'user-1',
        ownerId: 'rest-1',
        storeName: 'Lokanta',
        storeCategory: category,
        isOwner: owner,
        savedAt: DateTime.now(),
        staffRole: owner ? null : 'sub_admin',
        permissions: permissions,
      ),
    );

    Future<void> saveRecord(String restaurantId, String category) =>
        RestaurantLocalCacheService().upsertFromOnlineSnapshot(
          restaurantId: restaurantId,
          restaurantName: 'Lokanta',
          sellerId: restaurantId,
          storeCategory: category,
          tables: <Map<String, dynamic>>[
            <String, dynamic>{'id': 't1', 'table_number': 1},
          ],
        );

    Future<RestaurantCenterAccess> read(
      String restaurantId, {
      String? user = 'user-1',
      TargetPlatform platform = TargetPlatform.windows,
    }) => readRestaurantCenterAccess(
      restaurantId,
      currentUserId: () => user,
      identityStore: identities,
      platform: platform,
      isWeb: false,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      records = _Records();
      identities = OfflinePanelIdentityStore(records: records, vault: _Vault());
    });

    test('verified restaurant owner with tables is allowed on macOS and Windows', () async {
      await save();
      await saveRecord('rest-1', 'Restoran');
      expect((await read('rest-1')).allowed, isTrue);
      expect((await read('rest-1', platform: TargetPlatform.macOS)).allowed, isTrue);
      expect(
        (await read('rest-1', platform: TargetPlatform.android)).denial,
        RestaurantCenterDenial.notDesktop,
      );
    });

    test('an e-commerce store is refused even with saved rows', () async {
      await save(category: 'Elektronik');
      await saveRecord('rest-1', 'Elektronik');
      expect((await read('rest-1')).denial, RestaurantCenterDenial.notRestaurant);
    });

    test('nobody signed in, another account, or another restaurant is refused', () async {
      await save();
      await saveRecord('rest-1', 'Restoran');
      expect((await read('rest-1', user: null)).denial, RestaurantCenterDenial.noVerifiedAccount);
      expect((await read('rest-1', user: 'user-2')).denial, RestaurantCenterDenial.noVerifiedAccount);
      expect((await read('rest-9')).denial, RestaurantCenterDenial.noVerifiedAccount);
    });

    test('an edited saved identity is refused', () async {
      await save(category: 'Elektronik');
      await saveRecord('rest-1', 'Restoran');
      final key = OfflinePanelIdentityStore.keyFor('user-1');
      records.rows[key] = <String, dynamic>{
        ...records.rows[key]!,
        'store_category': 'Restoran',
        'storeCategory': 'Restoran',
      };
      expect((await read('rest-1')).allowed, isFalse);
    });

    test('the verified business type is readable without the cloud', () async {
      Future<String?> category(String id, {String? user = 'user-1'}) =>
          readVerifiedStoreCategory(
            id,
            currentUserId: () => user,
            identityStore: identities,
          );
      expect(await category('rest-1'), isNull);
      await save();
      expect(await category('rest-1'), 'Restoran');
      expect(await category('rest-9'), isNull);
      expect(await category('rest-1', user: 'user-2'), isNull);
      expect(await category('rest-1', user: null), isNull);
      final key = OfflinePanelIdentityStore.keyFor('user-1');
      records.rows[key] = <String, dynamic>{
        ...records.rows[key]!,
        'store_name': 'Edited',
        'storeName': 'Edited',
      };
      expect(await category('rest-1'), isNull);
    });

    test('staff without the permission is refused, with it allowed', () async {
      await saveRecord('rest-1', 'Restoran');
      await save(owner: false, permissions: <String>{'manageOrders'});
      expect((await read('rest-1')).denial, RestaurantCenterDenial.notAuthorised);
      await save(owner: false, permissions: <String>{'managePrintSettings'});
      expect((await read('rest-1')).allowed, isTrue);
    });
  });

  group('Başlat / Durdur', () {
    late Directory temp;
    late int bridgeStarts;
    late int serviceCloses;
    late List<DateTime> holds;
    late List<DateTime> prepared;
    late RestaurantCenterAccess access;
    const loopback = <LanInterfaceChoice>[
      LanInterfaceChoice(name: 'lo0', address: '127.0.0.1'),
    ];

    Future<Map<String, dynamic>?> membership(String _) async => null;

    Future<RestaurantCenterStart> start() => RestaurantCenterControl.start(
      restaurantId: 'rest-1',
      readMembership: membership,
      materialDirectory: Directory('${temp.path}/lan'),
      interfaces: loopback,
      deviceStore: MemoryLanEnrollmentStore(),
      port: 0,
    );

    bool listening() => RestaurantLanHostRegistry.current?.listening ?? false;

    /// What a new launch of the seller app does before anything else.
    void relaunch() {
      RestaurantLanHostRegistry.current = null;
      PrintServiceStartGate.enforce();
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      RestaurantLocalPrintQueueService.clearAllMemoryForTests();
      temp = await Directory.systemTemp.createTemp('ibul-center-control');
      bridgeStarts = 0;
      serviceCloses = 0;
      holds = <DateTime>[];
      access = RestaurantCenterAccess.granted;
      SellerLanCenter.advertiser = _SilentAdvertiser();
      SellerLanCenter.evidenceKeyRegistrar = null;
      SellerLanCenter.accessReader = (_) async => access;
      RestaurantCenterControl.startBridge = () async {
        bridgeStarts++;
        return PrintServiceStartGate.open;
      };
      RestaurantCenterControl.closePrintService = () async => serviceCloses++;
      RestaurantCenterControl.holdJobsWaitingSince = (_, before) async {
        holds.add(before);
        return 3;
      };
      prepared = <DateTime>[];
      RestaurantCenterControl.prepareBridge = (since) async => prepared.add(since);
      RestaurantLanHostRegistry.current = null;
      PrintServiceStartGate.enforce();
    });

    tearDown(() async {
      await SellerLanCenter.stop();
      RestaurantLanHostRegistry.current = null;
      RestaurantCenterControl.resetForTests();
      PrintServiceStartGate.resetForTests();
      BridgeManager.debugPrintStartDisabled = null;
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('a launch starts with everything closed', () async {
      expect(RestaurantCenterControl.startedThisSession, isFalse);
      expect(PrintServiceStartGate.refusal(), isNotNull);
      expect(listening(), isFalse);
      expect(bridgeStarts, 0);
    });

    test('every other start path is refused while the center is closed', () async {
      final wizard = await BridgeManager.ensureReady();
      expect(wizard.ok, isFalse);
      expect(wizard.message, PrintServiceStartGate.closedMessage);
      expect(await BridgeManager.ensureRunning(), isFalse);
      final agent = await BridgeManager.installLaunchAgent();
      if (Platform.isMacOS) {
        expect(agent.success, isFalse);
        expect(agent.error, contains('otomatik başlatılmaz'));
      }
      final statuses = await BridgeLifecycleService(
        bridgeUri: Uri.parse('http://127.0.0.1:9'),
        isolatedDesktop: false,
        startAgent: () async => fail('a closed center must not start an agent'),
      ).ensureRunning().toList();
      expect(statuses.last, BridgeStatus.unavailable);
    });

    test('a business that is not a restaurant is not held back', () async {
      PrintServiceStartGate.noteBusiness(restaurantRules: false);
      expect(PrintServiceStartGate.refusal(), isNull);
      BridgeManager.debugPrintStartDisabled = true;
      final result = await BridgeManager.ensureReady();
      expect(result.details['startGateClosed'], isNull);
    });

    test('a business that may not run a center gets a refusal and no service', () async {
      access = const RestaurantCenterAccess(RestaurantCenterDenial.notRestaurant);
      final result = await start();
      expect(result.access.allowed, isFalse);
      expect(result.message, contains('restoran'));
      expect(listening(), isFalse);
      expect(bridgeStarts, 0);
      expect(holds, isEmpty);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('an unauthorised user cannot start it either', () async {
      access = const RestaurantCenterAccess(RestaurantCenterDenial.notAuthorised);
      final result = await start();
      expect(result.center, isNull);
      expect(listening(), isFalse);
      expect(bridgeStarts, 0);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('Başlat brings up the order center and the print service', () async {
      final result = await start();
      expect(result.centerRunning, isTrue, reason: result.message);
      expect(result.bridgeOk, isTrue);
      expect(listening(), isTrue);
      expect(bridgeStarts, 1);
      expect(RestaurantCenterControl.startedThisSession, isTrue);
    });

    test('receipts that waited while it was closed are held, not printed', () async {
      final before = DateTime.now();
      final result = await start();
      expect(result.heldOldJobs, 3);
      expect(holds, hasLength(1));
      expect(holds.single.isBefore(before), isFalse);
      // A second Başlat in the same session holds nothing new.
      await start();
      expect(holds, hasLength(1));
    });

    test('the bridge is told the limit and warmed before the first order', () async {
      await start();
      expect(prepared, hasLength(1));
      expect(prepared.single, PrintServiceStartGate.startedAt);
    });

    test('old jobs cannot print even when the cloud was away at Başlat', () async {
      RestaurantCenterControl.holdJobsWaitingSince = (_, _) async {
        throw const SocketException('offline');
      };
      final old = DateTime.now().toUtc().subtract(const Duration(minutes: 5));
      // Closed: nothing may print.
      expect(PrintServiceStartGate.jobIsFromBefore(old.toIso8601String()), isTrue);
      final result = await start();
      expect(result.centerRunning, isTrue);
      // Started offline: the old job is still refused by the hub, a new one is not.
      expect(PrintServiceStartGate.jobIsFromBefore(old.toIso8601String()), isTrue);
      expect(PrintServiceStartGate.jobIsFromBefore(''), isTrue);
      final fresh = DateTime.now().toUtc().add(const Duration(seconds: 1));
      expect(PrintServiceStartGate.jobIsFromBefore(fresh.toIso8601String()), isFalse);
      // Stop and start again: what waited in between is old again.
      await RestaurantCenterControl.stop();
      final between = DateTime.now().toUtc();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await start();
      expect(PrintServiceStartGate.jobIsFromBefore(between.toIso8601String()), isTrue);
    });

    test('a business without restaurant rules prints its jobs as before', () {
      PrintServiceStartGate.noteBusiness(restaurantRules: false);
      expect(PrintServiceStartGate.jobIsFromBefore('2020-01-01T00:00:00Z'), isFalse);
    });

    test('a hold that failed offline is done when the internet returns', () async {
      var cloudUp = false;
      RestaurantCenterControl.holdJobsWaitingSince = (_, before) async {
        if (!cloudUp) throw const SocketException('offline');
        holds.add(before);
        return 1;
      };
      final result = await start();
      expect(result.centerRunning, isTrue);
      expect(holds, isEmpty);
      cloudUp = true;
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      expect(holds, hasLength(1));
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      expect(holds, hasLength(1));
    });

    test('pressing Başlat twice keeps one order center', () async {
      final results = await Future.wait(<Future<RestaurantCenterStart>>[start(), start()]);
      expect(results.every((result) => result.centerRunning), isTrue);
      final host = RestaurantLanHostRegistry.current;
      final again = await start();
      expect(again.center!.state, SellerLanCenterState.alreadyRunning);
      expect(identical(RestaurantLanHostRegistry.current, host), isTrue);
    });

    test('closing and reopening the app leaves it closed even after Başlat', () async {
      await start();
      await RestaurantCenterControl.stop(); // app exit
      relaunch();
      expect(listening(), isFalse);
      expect(RestaurantCenterControl.startedThisSession, isFalse);
      expect((await BridgeManager.ensureReady()).ok, isFalse);
      // The old "owned" mark no longer reopens anything.
      await SellerLanCenter.markOwned('rest-1', true);
      relaunch();
      expect(listening(), isFalse);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('Durdur closes the center and shuts every start path again', () async {
      await start();
      await RestaurantCenterControl.stop();
      await RestaurantCenterControl.closePrintServiceSafely();
      expect(listening(), isFalse);
      expect(serviceCloses, 1);
      expect(PrintServiceStartGate.open, isFalse);
      expect((await BridgeManager.ensureReady()).ok, isFalse);
    });

    test('Durdur keeps the waiting print jobs', () async {
      await start();
      final queue = RestaurantLocalPrintQueueService();
      await queue.enqueue(
        job: RestaurantLocalPrintJobRecord(
          localJobId: 'job-1',
          restaurantId: 'rest-1',
          localOrderId: 'order-1',
          tableId: '1',
          tableName: 'Masa 1',
          documentType: 'kitchen',
          role: 'mutfak',
          station: 'Genel',
          printerSnapshot: const <String, dynamic>{'id': 'p1', 'backend': 'tcp'},
          payloadSnapshot: const <String, dynamic>{'table_number': 1},
          status: RestaurantLocalPrintJobStatus.created,
          attempts: 0,
          createdAt: DateTime.now(),
        ),
      );
      await RestaurantCenterControl.stop();
      await RestaurantCenterControl.closePrintServiceSafely();
      final jobs = await RestaurantLocalPrintQueueService().list('rest-1');
      expect(jobs.map((job) => job.localJobId), <String>['job-1']);
      expect(jobs.single.status, RestaurantLocalPrintJobStatus.queued);
    });

    test('a choice made during an internet cut reaches the cloud on return', () async {
      var writes = 0;
      var cloudUp = false;
      RestaurantCenterControl.oweCloudSetting('rest-1', () async {
        if (!cloudUp) throw Exception('no cloud');
        writes++;
      });
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      expect(writes, 0);
      expect(RestaurantCenterControl.owesCloudSetting('rest-1'), isTrue);
      cloudUp = true;
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      expect(writes, 1);
      expect(RestaurantCenterControl.owesCloudSetting('rest-1'), isFalse);
    });

    test('only the latest choice made offline is written', () async {
      final written = <bool>[];
      RestaurantCenterControl.oweCloudSetting('rest-1', () async => written.add(true));
      RestaurantCenterControl.oweCloudSetting('rest-1', () async => written.add(false));
      await RestaurantCenterControl.holdOwedOldJobs('rest-1');
      expect(written, <bool>[false]);
    });

    test('a print service that died is brought back with the same old-job '
        'limit, never after Durdur', () async {
      var starts = 0;
      final prepared = <DateTime>[];
      RestaurantCenterControl.startBridge = () async {
        starts += 1;
        return true;
      };
      RestaurantCenterControl.prepareBridge = (since) async =>
          prepared.add(since);

      // Never started: nothing to revive.
      expect(await RestaurantCenterControl.reviveBridge(), isFalse);
      expect(starts, 0);

      final startedAt = DateTime.utc(2026, 11, 25, 9);
      PrintServiceStartGate.grant(startedAt);
      expect(await RestaurantCenterControl.reviveBridge(), isTrue);
      expect(starts, 1);
      // Jobs from before this session's Başlat stay held after the revive.
      expect(prepared, <DateTime>[startedAt]);
      expect(PrintServiceStartGate.startedAt, startedAt);

      PrintServiceStartGate.revoke(); // Durdur
      expect(await RestaurantCenterControl.reviveBridge(), isFalse);
      expect(starts, 1);
    });

    test('closing the app is not Durdur: this computer stays the center',
        () async {
      await start();
      expect(listening(), isTrue);
      expect(await SellerLanCenter.isOwned('rest-1'), isTrue);

      await RestaurantCenterControl.stop(byOperator: false); // app exit
      expect(listening(), isFalse);
      expect(PrintServiceStartGate.open, isFalse);
      expect(await SellerLanCenter.isOwned('rest-1'), isTrue);

      await start();
      await RestaurantCenterControl.stop(); // the operator's Durdur
      expect(await SellerLanCenter.isOwned('rest-1'), isFalse);
    });
  });
}
