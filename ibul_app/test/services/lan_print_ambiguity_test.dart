import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_lan_host.dart';
import 'package:ibul_app/services/restaurant_offline/restaurant_offline_sync_service.dart';

void main() {
  group('planLanOrderSync never sends an order without evidence', () {
    String? evidenceFor(String status) =>
        planLanOrderSync(listeningHost: true, printStatus: status).evidence;

    test('recorded facts keep their meaning', () {
      expect(evidenceFor('printed'), 'forwarded');
      expect(evidenceFor('forwarded'), 'forwarded');
      expect(evidenceFor('failed'), 'failed');
      expect(evidenceFor('not_sent'), 'failed');
    });

    test('pending, empty, unknown and uncertain may already be on paper', () {
      for (final status in <String>['pending', '', 'uncertain', 'printing', 'weird', 'queued']) {
        expect(evidenceFor(status), 'uncertain', reason: 'status "$status"');
      }
    });

    test('no status ever produces null evidence', () {
      for (final status in <String>['printed', 'forwarded', 'failed', 'not_sent', 'pending', '', 'x']) {
        expect(evidenceFor(status), isNotNull, reason: 'status "$status"');
      }
    });

    test('an unprinted order from an earlier session is held, not printed by the cloud', () {
      String? old(String status) => planLanOrderSync(
        listeningHost: true,
        printStatus: status,
        fromEarlierSession: true,
      ).evidence;
      expect(old('failed'), 'uncertain');
      expect(old('not_sent'), 'uncertain');
      // What was already handed to a printer stays a recorded fact.
      expect(old('forwarded'), 'forwarded');
    });

    test('a stopped center holds everything', () {
      final plan = planLanOrderSync(listeningHost: false, printStatus: 'failed');
      expect(plan.action, 'hold');
    });
  });

  group('combineStationPrintStatuses', () {
    test('one station may have printed while another failed: uncertain, not failed', () {
      expect(combineStationPrintStatuses(<String>['forwarded', 'failed']), 'uncertain');
      expect(combineStationPrintStatuses(<String>['failed', 'uncertain']), 'uncertain');
    });

    test('only all-failed is failed, only all-forwarded is forwarded', () {
      expect(combineStationPrintStatuses(<String>['failed', 'failed']), 'failed');
      expect(combineStationPrintStatuses(<String>['forwarded', 'forwarded']), 'forwarded');
    });

    test('unknown station status is uncertain; no station is not_sent', () {
      expect(combineStationPrintStatuses(<String>['queued']), 'uncertain');
      expect(combineStationPrintStatuses(<String>['forwarded', 'queued']), 'uncertain');
      expect(combineStationPrintStatuses(const <String>[]), 'not_sent');
    });
  });
}
