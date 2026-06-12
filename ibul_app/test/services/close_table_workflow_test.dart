// ignore_for_file: prefer_const_constructors

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/store/close_table_workflow.dart';
import 'package:ibul_app/utils/order_status_constants.dart';

// ─── In-memory fake for DB operations ──────────────────────────────────────
//
// Instead of mocking SupabaseClient (which requires complex method-chain
// stubs), we model each DB operation as a simple function that tests can
// override with closures. This keeps the tests pure Dart with zero external
// mock libraries.

typedef _BulkDeleteFn = Future<void> Function();
typedef _DeleteByIdFn = Future<void> Function(String id);
typedef _MarkClosedFn = Future<void> Function(String id);
typedef _VerifyFn = Future<List<Map<String, dynamic>>> Function(List<String>);

// ─── Helper to build a fake DB row with a given status ─────────────────────
Map<String, dynamic> _row(String id, {required String status}) =>
    {'id': id, 'status': status};

// ─── Test harness ────────────────────────────────────────────────────────────

Future<void> _run({
  required List<String> orderIds,
  required _BulkDeleteFn bulkDelete,
  required _DeleteByIdFn deleteById,
  required _MarkClosedFn markClosed,
  required _VerifyFn verifyByIds,
  List<CloseTableWorkflowEvent>? capturedEvents,
}) {
  return runCloseTableFallbackWorkflow(
    orderIds: orderIds,
    bulkDelete: bulkDelete,
    deleteById: deleteById,
    markClosed: markClosed,
    verifyByIds: verifyByIds,
    onEvent: capturedEvents?.add,
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  // ── isTerminalCloseStatus ─────────────────────────────────────────────────

  group('isTerminalCloseStatus', () {
    test('marks known terminal statuses as terminal', () {
      for (final s in [
        'closed',
        'paid',
        'cancelled',
        'canceled',
        'completed',
        'complete',
        'archived',
        'payment_completed',
        'completed_payment',
        'CLOSED', // case-insensitive
        '  paid  ', // whitespace-tolerant
      ]) {
        expect(
          OrderStatusConstants.isTerminalStatus(s),
          isTrue,
          reason: '"$s" should be terminal',
        );
      }
    });

    test('marks active statuses as non-terminal', () {
      for (final s in ['open', 'pending', 'sent', 'new', '', null]) {
        expect(
          OrderStatusConstants.isTerminalStatus(s),
          isFalse,
          reason: '"$s" must NOT be treated as terminal',
        );
      }
    });
  });

  // ── Scenario A: Bulk DELETE succeeds ──────────────────────────────────────

  group('Scenario A — bulk DELETE succeeds', () {
    test('calls bulkDelete once and skips per-order loop', () async {
      var bulkDeleteCalls = 0;
      var deleteByIdCalls = 0;
      var markClosedCalls = 0;

      await _run(
        orderIds: ['id-1', 'id-2'],
        bulkDelete: () async => bulkDeleteCalls++,
        deleteById: (id) async => deleteByIdCalls++,
        markClosed: (id) async => markClosedCalls++,
        // After bulk delete, rows are gone — verify returns empty list.
        verifyByIds: (ids) async => const [],
      );

      expect(bulkDeleteCalls, 1, reason: 'bulkDelete must be called exactly once');
      expect(deleteByIdCalls, 0, reason: 'per-order DELETE must NOT run on bulk success');
      expect(markClosedCalls, 0, reason: 'markClosed must NOT run on bulk success');
    });

    test('emits bulkDelete=success event then verify=success', () async {
      final events = <CloseTableWorkflowEvent>[];

      await _run(
        orderIds: ['id-1'],
        bulkDelete: () async {},
        deleteById: (_) async {},
        markClosed: (_) async {},
        verifyByIds: (_) async => const [],
        capturedEvents: events,
      );

      expect(
        events.any(
          (e) =>
              e.phase == CloseTablePhase.bulkDelete &&
              e.result == CloseTablePhaseResult.success,
        ),
        isTrue,
        reason: 'bulkDelete success event must be emitted',
      );
      expect(
        events.any(
          (e) =>
              e.phase == CloseTablePhase.verify &&
              e.result == CloseTablePhaseResult.success,
        ),
        isTrue,
        reason: 'verify success event must be emitted after bulk delete',
      );
    });

    test('does not throw when verifyByIds returns empty (all rows deleted)', () async {
      await expectLater(
        _run(
          orderIds: ['id-1', 'id-2', 'id-3'],
          bulkDelete: () async {},
          deleteById: (_) async {},
          markClosed: (_) async {},
          verifyByIds: (_) async => const [],
        ),
        completes,
      );
    });

    test('throws CloseTableVerificationException if verify still finds active rows', () async {
      await expectLater(
        _run(
          orderIds: ['id-1'],
          bulkDelete: () async {}, // "succeeds" but rows remain (DB bug)
          deleteById: (_) async {},
          markClosed: (_) async {},
          verifyByIds: (_) async => [_row('id-1', status: 'open')],
        ),
        throwsA(isA<CloseTableVerificationException>()),
      );
    });
  });

  // ── Scenario B: Bulk DELETE fails → per-order fallback ───────────────────

  group('Scenario B — bulk DELETE fails (P0001 trigger), per-order fallback', () {
    test('when bulk DELETE throws, per-order DELETE is called for each order', () async {
      final deletedIds = <String>[];

      await _run(
        orderIds: ['id-1', 'id-2'],
        bulkDelete: () async => throw Exception('P0001 trigger error'),
        deleteById: (id) async => deletedIds.add(id),
        markClosed: (_) async {},
        verifyByIds: (_) async => const [], // verify: all gone after individual deletes
      );

      expect(deletedIds, containsAll(['id-1', 'id-2']));
      expect(deletedIds.length, 2);
    });

    test('when per-order DELETE also fails, markClosed is called instead', () async {
      final markedIds = <String>[];

      await _run(
        orderIds: ['id-1', 'id-2'],
        bulkDelete: () async => throw Exception('P0001'),
        deleteById: (_) async => throw Exception('P0001 per-order'),
        markClosed: (id) async => markedIds.add(id),
        // verify: rows now have status='closed' (terminal)
        verifyByIds: (ids) async =>
            ids.map((id) => _row(id, status: 'closed')).toList(),
      );

      expect(markedIds, containsAll(['id-1', 'id-2']));
      expect(markedIds.length, 2);
    });

    test('emits correct event sequence for full fallback path', () async {
      final events = <CloseTableWorkflowEvent>[];

      await _run(
        orderIds: ['id-x'],
        bulkDelete: () async => throw Exception('P0001'),
        deleteById: (_) async => throw Exception('per-order failed'),
        markClosed: (_) async {},
        verifyByIds: (ids) async =>
            ids.map((id) => _row(id, status: 'closed')).toList(),
        capturedEvents: events,
      );

      final phases = events.map((e) => e.phase).toList();
      expect(
        phases.contains(CloseTablePhase.bulkDelete),
        isTrue,
        reason: 'bulkDelete phase must be emitted',
      );
      expect(
        phases.contains(CloseTablePhase.perOrderDelete),
        isTrue,
        reason: 'perOrderDelete phase must be emitted when bulk fails',
      );
      expect(
        phases.contains(CloseTablePhase.perOrderMarkClosed),
        isTrue,
        reason: 'perOrderMarkClosed phase must be emitted when per-order DELETE also fails',
      );
      expect(
        phases.contains(CloseTablePhase.verify),
        isTrue,
        reason: 'verify phase must always be emitted',
      );
    });

    test('bulk fails + per-order DELETE succeeds → markClosed is NOT called', () async {
      var markClosedCalls = 0;

      await _run(
        orderIds: ['id-1'],
        bulkDelete: () async => throw Exception('P0001'),
        deleteById: (_) async {}, // per-order delete works
        markClosed: (_) async => markClosedCalls++,
        verifyByIds: (_) async => const [],
      );

      expect(
        markClosedCalls,
        0,
        reason: 'markClosed must NOT be called when per-order DELETE succeeds',
      );
    });

    test('throws when even markClosed fails for some orders and verify finds active', () async {
      await expectLater(
        _run(
          orderIds: ['id-1'],
          bulkDelete: () async => throw Exception('P0001'),
          deleteById: (_) async => throw Exception('cannot delete'),
          markClosed: (_) async => throw Exception('cannot update either'),
          // verify: order still active because nothing worked
          verifyByIds: (_) async => [_row('id-1', status: 'pending')],
        ),
        throwsA(
          isA<CloseTableVerificationException>().having(
            (e) => e.activeCount,
            'activeCount',
            1,
          ),
        ),
      );
    });
  });

  // ── Scenario C: Edge cases ────────────────────────────────────────────────

  group('Edge cases', () {
    test('empty orderIds list → returns immediately without any DB call', () async {
      var anyCalled = false;

      await _run(
        orderIds: const [],
        bulkDelete: () async => anyCalled = true,
        deleteById: (_) async => anyCalled = true,
        markClosed: (_) async => anyCalled = true,
        verifyByIds: (_) async {
          anyCalled = true;
          return const [];
        },
      );

      expect(anyCalled, isFalse, reason: 'No DB calls for empty order list');
    });

    test('verify accepts rows with terminal status as successfully closed', () async {
      // Mixed: some rows deleted (absent from verify), some marked 'closed'.
      await expectLater(
        _run(
          orderIds: ['id-1', 'id-2', 'id-3'],
          bulkDelete: () async => throw Exception('P0001'),
          deleteById: (id) async {
            if (id == 'id-1') return; // id-1 deleted OK
            throw Exception('blocked');
          },
          markClosed: (id) async {}, // id-2 and id-3 marked
          verifyByIds: (ids) async => [
            // id-1 deleted → absent
            _row('id-2', status: 'closed'), // terminal
            _row('id-3', status: 'paid'), // also terminal
          ],
        ),
        completes,
      );
    });

    test('CloseTableVerificationException contains failing IDs', () async {
      late CloseTableVerificationException caught;
      try {
        await _run(
          orderIds: ['id-A', 'id-B'],
          bulkDelete: () async => throw Exception('P0001'),
          deleteById: (_) async => throw Exception('blocked'),
          markClosed: (_) async => throw Exception('blocked'),
          verifyByIds: (ids) async =>
              ids.map((id) => _row(id, status: 'pending')).toList(),
        );
        fail('Expected CloseTableVerificationException');
      } on CloseTableVerificationException catch (e) {
        caught = e;
      }

      expect(caught.activeCount, 2);
      expect(caught.activeIds, containsAll(['id-A', 'id-B']));
    });
  });
}
