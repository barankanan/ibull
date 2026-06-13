import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/models/restaurant_ops_models.dart';
import 'package:ibul_app/services/store/table_order_history_utils.dart';

void main() {
  group('TableOrderHistoryUtils product summary', () {
    test('merges archived order items for display', () {
      final row = <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'archived_orders': <Map<String, dynamic>>[
          {
            'items': <Map<String, dynamic>>[
              {'name': 'Lahmacun', 'quantity': 2, 'price': 120.0},
              {'name': 'Ayran', 'quantity': 1, 'price': 35.0},
            ],
          },
        ],
      };

      expect(TableOrderHistoryUtils.displayItems(row).length, 2);
      expect(TableOrderHistoryUtils.orderItemCount(row), 3);
      expect(
        TableOrderHistoryUtils.productSummary(row),
        '3 ürün · Lahmacun, Ayran',
      );
    });

    test('isWithinRange treats next-day midnight end as inclusive for today', () {
      final today = DateTime(2026, 6, 13);
      final row = <String, dynamic>{
        'closed_at': DateTime(2026, 6, 13, 22, 30).toUtc().toIso8601String(),
      };
      final end = today.add(const Duration(days: 1));
      expect(
        TableOrderHistoryUtils.isWithinRange(row, today, end),
        isTrue,
      );
    });

    test('TableOrderHistoryRecord.fromMap uses archived items when top-level empty',
        () {
      final record = TableOrderHistoryRecord.fromMap(<String, dynamic>{
        'id': 'h1',
        'original_order_id': 'o1',
        'seller_id': 's1',
        'table_number': 4,
        'items': <Map<String, dynamic>>[],
        'archived_orders': <Map<String, dynamic>>[
          {
            'items': <Map<String, dynamic>>[
              {'name': 'Çorba', 'quantity': 1, 'price': 80.0},
            ],
          },
        ],
        'status': 'closed',
        'revision': 1,
        'grand_total': 80.0,
        'closed_at': DateTime.utc(2026, 6, 13, 12).toIso8601String(),
        'created_at': DateTime.utc(2026, 6, 13, 11).toIso8601String(),
        'table_area_name': 'Bahçe',
        'display_table_label': 'Bahçe 4',
        'payment_method': 'cash',
      });

      expect(record.items.length, 1);
      expect(record.tableAreaName, 'Bahçe');
      expect(record.displayTableLabel, 'Bahçe 4');
    });
  });

  group('TableOrderHistoryUtils table identity', () {
    test('tableLabel prefers display_table_label over table_number fallback', () {
      final row = <String, dynamic>{
        'table_number': 11,
        'display_table_label': 'Bahçe 1',
        'table_area_name': 'Bahçe',
      };

      expect(TableOrderHistoryUtils.tableLabel(row), 'Bahçe 1');
    });

    test('tableLabel resolves from archived_orders when top-level label missing', () {
      final row = <String, dynamic>{
        'table_number': 11,
        'archived_orders': <Map<String, dynamic>>[
          <String, dynamic>{
            'display_table_label': 'Bahçe 1',
            'table_area_name': 'Bahçe',
            'area_table_number': 1,
          },
        ],
      };

      expect(TableOrderHistoryUtils.tableLabel(row), 'Bahçe 1');
    });

    test('tableLabel uses area + area_table_number before Masa fallback', () {
      final row = <String, dynamic>{
        'table_number': 11,
        'table_area_name': 'Bahçe',
        'area_table_number': 1,
      };

      expect(TableOrderHistoryUtils.tableLabel(row), 'Bahçe 1');
    });

    test('historyRowMissingIdentity is true when label and area are empty', () {
      expect(
        TableOrderHistoryUtils.historyRowMissingIdentity(<String, dynamic>{
          'table_number': 11,
        }),
        isTrue,
      );
      expect(
        TableOrderHistoryUtils.historyRowMissingIdentity(<String, dynamic>{
          'table_number': 11,
          'display_table_label': 'Bahçe 1',
        }),
        isFalse,
      );
    });

    test('dedupeHistoryRowsLatestPerChain keeps latest row per session_key', () {
      final rows = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'old',
          'session_key': 'sess-1',
          'table_number': 3,
          'display_table_label': 'Salon 3',
          'closed_at': DateTime.utc(2026, 6, 13, 10).toIso8601String(),
        },
        <String, dynamic>{
          'id': 'new',
          'session_key': 'sess-1',
          'table_number': 3,
          'display_table_label': 'Salon 3',
          'closed_at': DateTime.utc(2026, 6, 13, 12).toIso8601String(),
        },
      ];

      final deduped = TableOrderHistoryUtils.dedupeHistoryRowsLatestPerChain(rows);
      expect(deduped.length, 1);
      expect(deduped.first['id'], 'new');
    });
  });
}
