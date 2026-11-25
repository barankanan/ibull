import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/print_service_start_gate.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_access.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_auto_start.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_center_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _allowed = RestaurantCenterAccess.granted;
const _refused = RestaurantCenterAccess(RestaurantCenterDenial.notAuthorised);

void main() {
  late List<String> calls;
  late RestaurantCenterStart startAnswer;
  late bool cloudUp;
  late bool cloudSaveWorks;
  late bool oldServiceExits;

  /// What a real launch does before anyone is signed in.
  void launchApp() {
    PrintServiceStartGate.resetForTests();
    PrintServiceStartGate.enforce();
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    RestaurantCenterAutoStart.resetForTests();
    RestaurantCenterControl.resetForTests();
    launchApp();
    calls = <String>[];
    startAnswer = const RestaurantCenterStart(access: _allowed, bridgeOk: true);
    cloudUp = true;
    cloudSaveWorks = true;
    oldServiceExits = true;
    RestaurantCenterAutoStart.hostsCenter = () => true;
    RestaurantCenterAutoStart.startCenter = (id) async {
      calls.add('start:$id');
      if (startAnswer.access.allowed) PrintServiceStartGate.grant();
      return startAnswer;
    };
    RestaurantCenterAutoStart.savePrintSystemOn = (id, previous, service) async {
      calls.add('save');
      if (!cloudSaveWorks) throw Exception('Bulut ayarı güncellenemedi.');
      return true;
    };
    RestaurantCenterAutoStart.switchOnThisComputer = () async {
      calls.add('local-on');
    };
    RestaurantCenterAutoStart.cloudAnswers = () async => cloudUp;
    RestaurantCenterAutoStart.oweCloudOn = (id) => calls.add('owe:$id');
    RestaurantCenterAutoStart.stopCenter = () async {
      calls.add('stop');
      PrintServiceStartGate.revoke();
    };
    RestaurantCenterAutoStart.closePrintService = () async {
      calls.add('close');
    };
    RestaurantCenterAutoStart.printServiceGone = () async => oldServiceExits;
  });

  tearDown(() {
    RestaurantCenterAutoStart.resetForTests();
    PrintServiceStartGate.resetForTests();
  });

  group('preference', () {
    test('is off until someone switches it on', () async {
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isFalse);
    });

    test('is remembered per restaurant on this computer', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isTrue);
      expect(await RestaurantCenterAutoStart.isEnabled('rest-2'), isFalse);
      await RestaurantCenterAutoStart.setEnabled('rest-1', false);
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isFalse);
    });

    test('survives the app being closed and opened again', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      RestaurantCenterAutoStart.resetForTests();
      launchApp();
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isTrue);
    });
  });

  group('the operator choice is kept across launches', () {
    /// The app is closed and opened again: memory is gone, the disk is not.
    void relaunch() {
      RestaurantCenterAutoStart.resetForTests();
      launchApp();
      RestaurantCenterAutoStart.hostsCenter = () => true;
      RestaurantCenterAutoStart.startCenter = (id) async {
        calls.add('start:$id');
        PrintServiceStartGate.grant();
        return startAnswer;
      };
      RestaurantCenterAutoStart.savePrintSystemOn = (id, p, s) async => true;
      RestaurantCenterAutoStart.closePrintService = () async {};
      RestaurantCenterAutoStart.printServiceGone = () async => true;
      RestaurantCenterAutoStart.stopCenter = () async {
        PrintServiceStartGate.revoke();
      };
    }

    test('Başlat once: the next launch starts by itself', () async {
      final opened = await RestaurantCenterAutoStart.open(restaurantId: 'rest-1');
      expect(opened.ok, isTrue);
      await RestaurantCenterAutoStart.rememberOperatorChoice(
        'rest-1',
        started: true,
      );
      relaunch();
      calls.clear();
      final launch = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(launch!.ok, isTrue);
      expect(calls, <String>['start:rest-1']);
    });

    test('Durdur: the next launch stays closed', () async {
      await RestaurantCenterAutoStart.rememberOperatorChoice(
        'rest-1',
        started: true,
      );
      await RestaurantCenterAutoStart.rememberOperatorChoice(
        'rest-1',
        started: false,
      );
      relaunch();
      calls.clear();
      expect(await RestaurantCenterAutoStart.openAtLaunch('rest-1'), isNull);
      expect(calls, isEmpty);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('closing the app is not Durdur: the choice is still there', () async {
      await RestaurantCenterAutoStart.rememberOperatorChoice(
        'rest-1',
        started: true,
      );
      // App exit revokes the in-memory gate only.
      PrintServiceStartGate.revoke();
      relaunch();
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isTrue);
    });

    test('a caller that does not know the restaurant yet does not use up the '
        'launch start', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      expect(await RestaurantCenterAutoStart.openAtLaunch(''), isNull);
      expect(await RestaurantCenterAutoStart.openAtLaunch('other'), isNull);
      final launch = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(launch!.ok, isTrue);
      expect(calls.where((c) => c.startsWith('start')), hasLength(1));
    });

    test('a launch start that failed is not repeated by the second caller',
        () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      startAnswer = const RestaurantCenterStart(
        access: _allowed,
        bridgeOk: false,
        bridgeMessage: 'port busy',
      );
      final first = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      final second = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(first!.ok, isFalse);
      expect(identical(first, second), isTrue);
      expect(calls.where((c) => c.startsWith('start')), hasLength(1));
      // A failed start is not the operator's Durdur.
      expect(await RestaurantCenterAutoStart.isEnabled('rest-1'), isTrue);
    });
  });

  group('a print service that stopped unexpectedly', () {
    late int revives;
    late DateTime now;

    setUp(() {
      revives = 0;
      now = DateTime.utc(2026, 11, 25, 12);
      RestaurantCenterAutoStart.clock = () => now;
      RestaurantCenterAutoStart.reviveBridge = () async {
        revives += 1;
        return false;
      };
    });

    test('is not started when the operator never pressed Başlat', () async {
      expect(
        await RestaurantCenterAutoStart.printServiceStoppedAnswering(),
        isFalse,
      );
      expect(revives, 0);
    });

    test('is not started after Durdur', () async {
      PrintServiceStartGate.grant();
      PrintServiceStartGate.revoke();
      await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      expect(revives, 0);
    });

    test('is started again between Başlat and Durdur', () async {
      PrintServiceStartGate.grant();
      RestaurantCenterAutoStart.reviveBridge = () async {
        revives += 1;
        return true;
      };
      expect(
        await RestaurantCenterAutoStart.printServiceStoppedAnswering(),
        isTrue,
      );
      expect(revives, 1);
    });

    test('is never started on a device that is not the center', () async {
      PrintServiceStartGate.grant();
      RestaurantCenterAutoStart.hostsCenter = () => false;
      await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      expect(revives, 0);
    });

    test('waits longer after each failure and gives up after five', () async {
      PrintServiceStartGate.grant();
      await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      expect(revives, 1);
      // The next health check, 10 seconds later, does not hammer it.
      now = now.add(const Duration(seconds: 10));
      await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      expect(revives, 1);
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(minutes: 10));
        await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      }
      expect(revives, RestaurantCenterAutoStart.maxReviveAttempts);
    });

    test('a service that answered again gets a fresh set of attempts', () async {
      PrintServiceStartGate.grant();
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(minutes: 10));
        await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      }
      expect(revives, RestaurantCenterAutoStart.maxReviveAttempts);
      RestaurantCenterAutoStart.notePrintServiceAnswers();
      await RestaurantCenterAutoStart.printServiceStoppedAnswering();
      expect(revives, RestaurantCenterAutoStart.maxReviveAttempts + 1);
    });

    test('two health checks at once start one service, not two', () async {
      PrintServiceStartGate.grant();
      await Future.wait(<Future<bool>>[
        RestaurantCenterAutoStart.printServiceStoppedAnswering(),
        RestaurantCenterAutoStart.printServiceStoppedAnswering(),
      ]);
      expect(revives, 1);
    });
  });

  group('launch', () {
    test('with the preference off nothing is started or closed', () async {
      expect(await RestaurantCenterAutoStart.openAtLaunch('rest-1'), isNull);
      expect(calls, isEmpty);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('with the preference on the left-over service is closed, then one '
        'complete Başlat runs', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      final result = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(result!.ok, isTrue);
      expect(calls, <String>['close', 'start:rest-1', 'save']);
      expect(PrintServiceStartGate.open, isTrue);
      expect(RestaurantCenterAutoStart.lastLaunch.value, same(result));
    });

    test('two callers at launch start one center, not two', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      final results = await Future.wait(<Future<RestaurantCenterOpen?>>[
        RestaurantCenterAutoStart.openAtLaunch('rest-1'),
        RestaurantCenterAutoStart.openAtLaunch('rest-1'),
      ]);
      expect(identical(results[0], results[1]), isTrue);
      expect(calls.where((c) => c.startsWith('start')), hasLength(1));
    });

    test('Durdur stays in force: the launch start does not run again in the '
        'same session', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      PrintServiceStartGate.revoke(); // operator pressed Durdur
      calls.clear();
      await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(calls, isEmpty);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('an account that may not manage printers gets nothing started', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      startAnswer = const RestaurantCenterStart(access: _refused);
      final result = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(result!.ok, isFalse);
      expect(calls, isNot(contains('save')));
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('a handheld or a non-restaurant business never auto-starts', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      RestaurantCenterAutoStart.hostsCenter = () => false;
      expect(await RestaurantCenterAutoStart.openAtLaunch('rest-1'), isNull);
      RestaurantCenterAutoStart.resetForTests();
      RestaurantCenterAutoStart.hostsCenter = () => true;
      PrintServiceStartGate.noteBusiness(restaurantRules: false);
      expect(await RestaurantCenterAutoStart.openAtLaunch('rest-1'), isNull);
    });

    test('an old service that will not exit is not doubled by a second one', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      oldServiceExits = false;
      final result = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(result!.ok, isFalse);
      expect(calls, <String>['close']);
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('without internet the center still opens on this computer and the '
        'cloud record is owed', () async {
      await RestaurantCenterAutoStart.setEnabled('rest-1', true);
      cloudUp = false;
      cloudSaveWorks = false;
      final result = await RestaurantCenterAutoStart.openAtLaunch('rest-1');
      expect(result!.ok, isTrue);
      expect(result.savedOnThisComputerOnly, isTrue);
      expect(calls, containsAllInOrder(<String>['local-on', 'owe:rest-1']));
      expect(PrintServiceStartGate.open, isTrue);
    });
  });

  group('open (the shared Başlat)', () {
    test('a print service that does not come up leaves nothing half open', () async {
      startAnswer = const RestaurantCenterStart(
        access: _allowed,
        bridgeOk: false,
        bridgeMessage: 'Yazıcı servisi başlatılamadı.',
      );
      final result = await RestaurantCenterAutoStart.open(restaurantId: 'rest-1');
      expect(result.ok, isFalse);
      expect(result.message, 'Yazıcı servisi başlatılamadı.');
      expect(calls, containsAllInOrder(<String>['stop', 'close']));
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('a cloud that answers with a refusal is not treated as an outage', () async {
      cloudSaveWorks = false;
      cloudUp = true;
      final result = await RestaurantCenterAutoStart.open(restaurantId: 'rest-1');
      expect(result.ok, isFalse);
      expect(calls, isNot(contains('local-on')));
      expect(PrintServiceStartGate.open, isFalse);
    });

    test('jobs that waited from before the start are reported, never printed '
        'by the start itself', () async {
      startAnswer = const RestaurantCenterStart(
        access: _allowed,
        bridgeOk: true,
        heldOldJobs: 3,
      );
      final result = await RestaurantCenterAutoStart.open(restaurantId: 'rest-1');
      expect(result.heldOldJobs, 3);
      final before = DateTime.now().toUtc().subtract(const Duration(hours: 1));
      expect(PrintServiceStartGate.jobIsFromBefore(before.toIso8601String()), isTrue);
    });

    test('pressing Başlat while the launch start runs shares its run', () async {
      final both = await Future.wait(<Future<RestaurantCenterOpen>>[
        RestaurantCenterAutoStart.open(restaurantId: 'rest-1'),
        RestaurantCenterAutoStart.open(restaurantId: 'rest-1'),
      ]);
      expect(identical(both[0], both[1]), isTrue);
      expect(calls.where((c) => c.startsWith('start')), hasLength(1));
    });
  });
}
