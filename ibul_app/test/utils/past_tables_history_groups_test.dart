import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ibul_app/models/restaurant_ops_models.dart';
import 'package:ibul_app/utils/past_tables_history_groups.dart';

TableOrderHistoryRecord _record({
  required String id,
  required DateTime closedAt,
}) {
  return TableOrderHistoryRecord(
    id: id,
    originalOrderId: 'order-$id',
    sellerId: 'seller-1',
    tableNumber: 1,
    items: const <Map<String, dynamic>>[],
    status: 'closed',
    revision: 1,
    grandTotal: 100,
    closedAt: closedAt,
    createdAt: closedAt.subtract(const Duration(hours: 1)),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
  });

  group('groupPastTableHistoryRecords', () {
    test('groups by local closedAt day newest first', () {
      final groups = groupPastTableHistoryRecords(<TableOrderHistoryRecord>[
        _record(
          id: 'a',
          closedAt: DateTime(2026, 6, 28, 18, 30),
        ),
        _record(
          id: 'b',
          closedAt: DateTime(2026, 6, 30, 12, 0),
        ),
        _record(
          id: 'c',
          closedAt: DateTime(2026, 6, 30, 20, 15),
        ),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.items.map((r) => r.id).toList(), ['c', 'b']);
      expect(groups.last.items.single.id, 'a');
      expect(groups.first.label, contains('2026'));
      expect(groups.first.label, contains('•'));
    });

    test('empty input returns empty list', () {
      expect(groupPastTableHistoryRecords(const []), isEmpty);
    });
  });
}
