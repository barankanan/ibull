import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/kitchen_print_dedup.dart';

void main() {
  Future<void> pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('prep overlaps and the second TCP does not wait on status', () async {
    final events = <String>[];
    final started = DateTime.now();
    final report = await runKitchenFastDispatch(
      jobIds: const ['firin', 'ocak'],
      claim: (id) async {
        events.add('claim-start-$id');
        await pause(80);
        events.add('claim-end-$id');
        return true;
      },
      prepare: (id) async {
        events.add('prepare-start-$id');
        await pause(80);
        events.add('prepare-end-$id');
        return true;
      },
      alreadyPrinted: (_) => false,
      markPrinting: (id) async {
        events.add('printing-start-$id');
        await pause(200);
        events.add('printing-end-$id');
      },
      printTcp: (id) async {
        events.add('tcp-start-$id');
        await pause(30);
        events.add('tcp-end-$id');
        return true;
      },
      markCompleted: (id) async {
        events.add('completed-start-$id');
        await pause(200);
        events.add('completed-end-$id');
      },
      markFailed: (id, error) async {
        events.add('failed-$id');
      },
    );
    final elapsed = DateTime.now().difference(started).inMilliseconds;

    expect(
      events.indexOf('claim-start-ocak'),
      lessThan(events.indexOf('claim-end-firin')),
    );
    expect(
      events.indexOf('prepare-start-ocak'),
      lessThan(events.indexOf('prepare-end-firin')),
    );
    expect(
      events.indexOf('tcp-end-firin'),
      lessThan(events.indexOf('tcp-start-ocak')),
    );
    expect(
      events.indexOf('tcp-start-firin'),
      lessThan(events.indexOf('printing-end-firin')),
    );
    expect(
      events.indexOf('tcp-start-ocak'),
      lessThan(events.indexOf('completed-end-firin')),
    );
    expect(report.printedJobIds, ['firin', 'ocak']);
    expect(report.failedJobIds, isEmpty);
    // Serial path would be 2 * (80 + 80 + 200 + 30 + 200) = 1180ms.
    expect(elapsed, lessThan(1000));
  });

  test('a lost claim does not print and a failed ticket prints once', () async {
    final tcp = <String>[];
    final failed = <String>[];
    final report = await runKitchenFastDispatch(
      jobIds: const ['firin', 'ocak', 'lost'],
      claim: (id) async => id != 'lost',
      prepare: (_) async => true,
      alreadyPrinted: (_) => false,
      markPrinting: (_) async {},
      printTcp: (id) async {
        tcp.add(id);
        return id != 'firin';
      },
      markCompleted: (_) async {},
      markFailed: (id, error) async {
        failed.add(id);
      },
    );

    expect(report.unclaimedJobIds, ['lost']);
    expect(tcp, ['firin', 'ocak']);
    expect(failed, ['firin']);
    expect(report.printedJobIds, ['ocak']);
    expect(report.failedJobIds, ['firin']);
  });

  test('an already printed key does not open TCP again', () async {
    final tcp = <String>[];
    final completed = <String>[];
    final report = await runKitchenFastDispatch(
      jobIds: const ['firin'],
      claimedAhead: const {'firin': true},
      claimAheadMs: 0,
      claim: (_) async => throw StateError('claim again'),
      prepare: (_) async => true,
      alreadyPrinted: (_) => true,
      markPrinting: (_) async => throw StateError('printing'),
      printTcp: (id) async {
        tcp.add(id);
        return true;
      },
      markCompleted: (id) async {
        completed.add(id);
      },
      markFailed: (id, error) async {
        throw StateError('failed $id');
      },
    );

    expect(tcp, isEmpty);
    expect(completed, ['firin']);
    expect(report.closedWithoutPrintJobIds, ['firin']);
    expect(report.printedJobIds, isEmpty);
    expect(report.claimWaveMs, 0);
  });

  test('a closed service or an uncertain send does not start physical print', () {
    expect(
      kitchenJobMayStartPhysicalPrint(
        printSystemEnabled: false,
        suppressPhysicalPrint: false,
      ),
      isFalse,
    );
    expect(
      kitchenJobMayStartPhysicalPrint(
        printSystemEnabled: true,
        suppressPhysicalPrint: true,
        localPrintStatus: 'forwarded',
      ),
      isFalse,
    );
    expect(
      kitchenJobMayStartPhysicalPrint(
        printSystemEnabled: true,
        suppressPhysicalPrint: false,
        localPrintStatus: 'uncertain',
      ),
      isFalse,
    );
    expect(
      kitchenJobMayStartPhysicalPrint(
        printSystemEnabled: true,
        suppressPhysicalPrint: false,
        localPrintStatus: 'failed',
      ),
      isTrue,
    );
  });
}
