import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/seller/finance/helpers/today_revenue_breakdown_builder.dart';

void main() {
  final today = DateTime(2026, 6, 13);
  final from = DateTime(today.year, today.month, today.day);
  final to = DateTime(today.year, today.month, today.day, 23, 59, 59);

  group('buildTodayRevenueBreakdown', () {
    test('aggregates table, area and payment slices from closed history', () {
      final breakdown = buildTodayRevenueBreakdown(
        from: from,
        to: to,
        historyRows: [
          {
            'table_number': 3,
            'table_name': 'Salon 3',
            'table_area_name': 'Salon',
            'payment_method': 'cash',
            'grand_total': 120.0,
            'closed_at': today.toIso8601String(),
            'status': 'closed',
            'items': [
              {'quantity': 2, 'price': 60.0},
            ],
          },
          {
            'table_number': 8,
            'display_table_label': 'Teras 1',
            'table_area_name': 'Teras',
            'payment_method': 'card',
            'grand_total': 80.0,
            'closed_at': today.toIso8601String(),
            'status': 'closed',
            'items': [],
          },
        ],
        onlineRows: const [],
        manualIncomeRows: const [],
      );

      expect(breakdown.totalRevenue, closeTo(200.0, 0.01));
      expect(breakdown.tableLines.length, 2);
      expect(breakdown.byArea.map((e) => e.label), containsAll(['Salon', 'Teras']));
      expect(breakdown.byPaymentMethod.map((e) => e.key), containsAll(['cash', 'card']));
      expect(breakdown.topArea?.label, 'Salon');
      expect(breakdown.topPaymentMethod?.key, 'cash');
      expect(breakdown.hasPersistedPaymentMethods, isTrue);
      expect(breakdown.hasPersistedAreaNames, isTrue);
    });

    test('returns honest empty breakdown without fake rows', () {
      final breakdown = buildTodayRevenueBreakdown(
        from: from,
        to: to,
        historyRows: const [],
        onlineRows: const [],
        manualIncomeRows: const [],
      );

      expect(breakdown.totalRevenue, 0);
      expect(breakdown.tableLines, isEmpty);
      expect(breakdown.topArea, isNull);
      expect(breakdown.topPaymentMethod, isNull);
    });

    test('falls back to store_tables area_name when history field is empty', () {
      final breakdown = buildTodayRevenueBreakdown(
        from: from,
        to: to,
        historyRows: [
          {
            'table_number': 5,
            'table_name': 'Bahçe 2',
            'grand_total': 150.0,
            'closed_at': today.toIso8601String(),
            'status': 'closed',
            'items': [],
          },
        ],
        onlineRows: const [],
        manualIncomeRows: const [],
        storeTableRows: [
          {
            'id': 'table-5',
            'table_number': 5,
            'area_name': 'Bahçe',
          },
        ],
      );

      expect(breakdown.tableLines.single.areaName, 'Bahçe');
      expect(breakdown.byArea.map((e) => e.label), contains('Bahçe'));
      expect(breakdown.topArea?.label, 'Bahçe');
      expect(breakdown.hasPersistedAreaNames, isFalse);
    });

    test('shows Belirtilmedi only when area cannot be resolved', () {
      final breakdown = buildTodayRevenueBreakdown(
        from: from,
        to: to,
        historyRows: [
          {
            'table_number': 99,
            'grand_total': 50.0,
            'closed_at': today.toIso8601String(),
            'status': 'closed',
            'items': [],
          },
        ],
        onlineRows: const [],
        manualIncomeRows: const [],
        storeTableRows: const [],
      );

      expect(breakdown.tableLines.single.areaName, 'Belirtilmedi');
      expect(breakdown.byArea.single.label, 'Belirtilmedi');
    });
  });
}
