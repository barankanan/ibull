import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/finance/helpers/today_income_builder.dart';

void main() {
  group('buildTodayIncomeLines', () {
    test(
      'groups same table session and exposes payment method plus reference',
      () {
        final localNow = DateTime.now();
        final from = DateTime(localNow.year, localNow.month, localNow.day);
        final to = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
          23,
          59,
          59,
        );
        final sessionTime = from.add(const Duration(hours: 14));

        final lines = buildTodayIncomeLines(
          from: from,
          to: to,
          historyRows: [
            {
              'id': 'h1',
              'original_order_id': 'o1',
              'session_key': 'session-55',
              'table_number': 5,
              'display_table_label': 'Bahce 5',
              'grand_total': 200,
              'status': 'closed',
              'closed_at': sessionTime.toUtc().toIso8601String(),
              'payment_method': 'card',
            },
            {
              'id': 'h2',
              'original_order_id': 'o2',
              'session_key': 'session-55',
              'table_number': 5,
              'display_table_label': 'Bahce 5',
              'grand_total': 300,
              'status': 'closed',
              'closed_at': sessionTime
                  .add(const Duration(minutes: 5))
                  .toUtc()
                  .toIso8601String(),
              'payment_method': 'card',
            },
          ],
        );

        expect(lines.length, 1);
        expect(lines.single.label, 'Bahce 5');
        expect(lines.single.amount, closeTo(500, 0.01));
        expect(lines.single.paymentMethod, 'card');
        expect(lines.single.reference, 'session-55');
      },
    );

    test('duplicate original order id does not double count today income', () {
      final localNow = DateTime.now();
      final from = DateTime(localNow.year, localNow.month, localNow.day);
      final to = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        23,
        59,
        59,
      );
      final closedAt = from.add(const Duration(hours: 12));

      final lines = buildTodayIncomeLines(
        from: from,
        to: to,
        historyRows: [
          {
            'id': 'dup-a',
            'original_order_id': 'same-order',
            'session_key': 'session-dup',
            'table_number': 7,
            'grand_total': 250,
            'status': 'closed',
            'closed_at': closedAt.toUtc().toIso8601String(),
          },
          {
            'id': 'dup-b',
            'original_order_id': 'same-order',
            'session_key': 'session-dup',
            'table_number': 7,
            'grand_total': 250,
            'status': 'closed',
            'closed_at': closedAt.toUtc().toIso8601String(),
          },
        ],
      );

      expect(lines.length, 1);
      expect(lines.single.amount, closeTo(250, 0.01));
    });

    test('cancelled and refunded rows are excluded from totals', () {
      final localNow = DateTime.now();
      final from = DateTime(localNow.year, localNow.month, localNow.day);
      final to = DateTime(
        localNow.year,
        localNow.month,
        localNow.day,
        23,
        59,
        59,
      );
      final closedAt = from.add(const Duration(hours: 11));

      final lines = buildTodayIncomeLines(
        from: from,
        to: to,
        historyRows: [
          {
            'id': 'ok-1',
            'session_key': 'session-ok',
            'table_number': 3,
            'grand_total': 180,
            'status': 'closed',
            'closed_at': closedAt.toUtc().toIso8601String(),
          },
          {
            'id': 'bad-1',
            'session_key': 'session-bad',
            'table_number': 4,
            'grand_total': 500,
            'status': 'refunded',
            'closed_at': closedAt.toUtc().toIso8601String(),
          },
        ],
        onlineRows: [
          {
            'order_id': 'online-ok',
            'total_price': 50,
            'status': 'delivered',
            'created_at': closedAt.toUtc().toIso8601String(),
          },
          {
            'order_id': 'online-bad',
            'total_price': 90,
            'status': 'cancelled',
            'created_at': closedAt.toUtc().toIso8601String(),
          },
        ],
      );

      final total = lines.fold<double>(0, (sum, line) => sum + line.amount);
      expect(total, closeTo(230, 0.01));
    });

    test('today filter follows local day boundaries after UTC conversion', () {
      final includedLocal = DateTime.parse('2026-06-08T21:30:00Z').toLocal();
      final excludedLocal = includedLocal.add(const Duration(days: 1));
      final from = DateTime(
        includedLocal.year,
        includedLocal.month,
        includedLocal.day,
      );
      final to = DateTime(
        includedLocal.year,
        includedLocal.month,
        includedLocal.day,
        23,
        59,
        59,
      );

      final lines = buildTodayIncomeLines(
        from: from,
        to: to,
        historyRows: [
          {
            'id': 'included',
            'session_key': 'today-local',
            'table_number': 9,
            'grand_total': 90,
            'status': 'closed',
            'closed_at': includedLocal.toUtc().toIso8601String(),
          },
          {
            'id': 'excluded',
            'session_key': 'tomorrow-local',
            'table_number': 10,
            'grand_total': 120,
            'status': 'closed',
            'closed_at': excludedLocal.toUtc().toIso8601String(),
          },
        ],
      );

      expect(lines.length, 1);
      expect(lines.single.reference, 'today-local');
      expect(lines.single.amount, closeTo(90, 0.01));
    });

    test(
      'derives garson income from archived orders when optimistic row has no grand total',
      () {
        final localNow = DateTime.now();
        final from = DateTime(localNow.year, localNow.month, localNow.day);
        final to = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
          23,
          59,
          59,
        );
        final closedAt = from.add(const Duration(hours: 16));

        final lines = buildTodayIncomeLines(
          from: from,
          to: to,
          historyRows: [
            {
              'id': 'optimistic-close-1',
              'table_number': 12,
              'status': 'closed',
              'closed_at': closedAt.toUtc().toIso8601String(),
              'payment_method': 'cash',
              'archived_orders': [
                {
                  'id': 'customer-order-1',
                  'display_table_label': 'Salon 12',
                  'total': 120,
                  'status': 'closed',
                },
                {
                  'id': 'customer-order-2',
                  'display_table_label': 'Salon 12',
                  'total_amount': 80,
                  'status': 'closed',
                },
              ],
            },
          ],
        );

        expect(lines.length, 1);
        expect(lines.single.label, 'Salon 12');
        expect(lines.single.amount, closeTo(200, 0.01));
        expect(lines.single.paymentMethod, 'cash');
        expect(lines.single.reference, 'optimistic-close-1');
      },
    );
  });
}
