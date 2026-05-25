import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/garson_table_area_groups.dart';

void main() {
  group('groupGarsonTablesByArea', () {
    test('groups Salon and Bahçe separately with natural table order', () {
      final groups = groupGarsonTablesByArea(
        tableNumbers: const <int>[10, 11, 12, 20, 21],
        storeTables: <Map<String, dynamic>>[
          <String, dynamic>{
            'table_number': 10,
            'area_name': 'Salon',
            'area_table_number': 4,
          },
          <String, dynamic>{
            'table_number': 11,
            'area_name': 'Salon',
            'area_table_number': 1,
          },
          <String, dynamic>{
            'table_number': 12,
            'area_name': 'Salon',
            'area_table_number': 2,
          },
          <String, dynamic>{
            'table_number': 20,
            'area_name': 'Bahçe',
            'area_table_number': 2,
          },
          <String, dynamic>{
            'table_number': 21,
            'area_name': 'Bahçe',
            'area_table_number': 1,
          },
        ],
        storeTableAreas: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'salon-id',
            'name': 'Salon',
            'sort_order': 1,
          },
          <String, dynamic>{
            'id': 'bahce-id',
            'name': 'Bahçe',
            'sort_order': 2,
          },
        ],
      );

      expect(groups, hasLength(2));
      expect(groups[0].areaName, 'Salon');
      expect(groups[0].tableNumbers, <int>[11, 12, 10]);
      expect(groups[1].areaName, 'Bahçe');
      expect(groups[1].tableNumbers, <int>[21, 20]);
    });

    test('tables without area go under Diğer last', () {
      final groups = groupGarsonTablesByArea(
        tableNumbers: const <int>[1, 2, 3],
        storeTables: <Map<String, dynamic>>[
          <String, dynamic>{'table_number': 1, 'area_name': 'Salon'},
          <String, dynamic>{'table_number': 2},
          <String, dynamic>{'table_number': 3, 'area_name': 'Teras'},
        ],
        storeTableAreas: <Map<String, dynamic>>[
          <String, dynamic>{'id': 's', 'name': 'Salon', 'sort_order': 1},
          <String, dynamic>{'id': 't', 'name': 'Teras', 'sort_order': 2},
        ],
      );

      expect(groups.last.areaName, kGarsonOtherAreaLabel);
      expect(groups.last.tableNumbers, <int>[2]);
    });

    test('area sort_order controls group order', () {
      final groups = groupGarsonTablesByArea(
        tableNumbers: const <int>[1, 2],
        storeTables: <Map<String, dynamic>>[
          <String, dynamic>{
            'table_number': 1,
            'area_id': 'teras',
            'area_table_number': 1,
          },
          <String, dynamic>{
            'table_number': 2,
            'area_id': 'salon',
            'area_table_number': 1,
          },
        ],
        storeTableAreas: <Map<String, dynamic>>[
          <String, dynamic>{'id': 'salon', 'name': 'Salon', 'sort_order': 5},
          <String, dynamic>{'id': 'teras', 'name': 'Teras', 'sort_order': 1},
        ],
      );

      expect(groups.first.areaName, 'Teras');
      expect(groups.last.areaName, 'Salon');
    });
  });
}
