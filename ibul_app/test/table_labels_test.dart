import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/table_labels.dart';

void main() {
  group('table label resolution', () {
    test('display_label wins', () {
      final row = <String, dynamic>{
        'display_label': 'Bahçe 3',
        'table_name': 'Salon 9',
        'area_name': 'Bahçe',
        'table_number': 3,
      };
      expect(
        resolveTableCardTitle(tableRow: row, tableNumber: 3),
        'Bahçe 3',
      );
    });

    test('falls back to table_name', () {
      final row = <String, dynamic>{
        'display_label': '',
        'table_name': 'Bahçe 2',
      };
      expect(
        resolveTableCardTitle(tableRow: row, tableNumber: 99),
        'Bahçe 2',
      );
    });

    test('falls back to area_name + table_number', () {
      final row = <String, dynamic>{
        'display_label': '',
        'table_name': '',
        'area_name': 'Salon',
        'table_number': 7,
      };
      expect(
        resolveTableCardTitle(tableRow: row, tableNumber: 7),
        'Salon 7',
      );
    });

    test('final fallback is Masa N', () {
      expect(
        resolveTableCardTitle(tableRow: null, tableNumber: 5),
        'Masa 5',
      );
    });

    test('print payload fields are consistent', () {
      final row = <String, dynamic>{
        'display_label': 'Bahçe 3',
        'area_name': 'Bahçe',
        'area_table_number': 3,
      };
      final fields = resolvePrintableTablePayloadFields(
        tableRow: row,
        tableNumber: 3,
      );
      expect(fields['display_table_label'], 'Bahçe 3');
      expect(fields['table_display_name'], 'Bahçe 3');
      expect(fields['table_name'], 'Bahçe 3');
      expect(fields['table_area_name'], 'Bahçe');
      expect(fields['area_name'], 'Bahçe');
      expect(fields['table_number'], 3);
      expect(fields['area_table_number'], 3);
    });
  });

  group('area filter matching', () {
    test('all shows everything', () {
      expect(
        matchesAreaFilter(filterKey: 'all', tableRow: null),
        true,
      );
    });

    test('id-based filter matches', () {
      final row = <String, dynamic>{'area_id': 'a1', 'area_name': 'Bahçe'};
      expect(matchesAreaFilter(filterKey: 'id:a1', tableRow: row), true);
      expect(matchesAreaFilter(filterKey: 'id:a2', tableRow: row), false);
    });

    test('name-based filter matches (case-insensitive)', () {
      final row = <String, dynamic>{'area_name': 'Bahçe'};
      expect(matchesAreaFilter(filterKey: 'name:bahçe', tableRow: row), true);
      expect(matchesAreaFilter(filterKey: 'name:Salon', tableRow: row), false);
    });
  });

  group('area table number suggestion', () {
    test('suggests first missing positive number', () {
      final tables = <Map<String, dynamic>>[
        {'area_id': 'a', 'area_table_number': 1},
        {'area_id': 'a', 'area_table_number': 3},
        {'area_id': 'b', 'area_table_number': 1},
      ];
      expect(nextAreaTableNumberSuggestion(tables, 'a'), 2);
      expect(nextAreaTableNumberSuggestion(tables, 'b'), 2);
    });
  });

  group('SQL migration contract (syntax/keys)', () {
    test('print job payload migration contains required keys', () {
      final file = File(
        'supabase/migrations/20260606_print_jobs_table_labels.sql',
      );
      expect(file.existsSync(), true);
      final sql = file.readAsStringSync();
      for (final requiredKey in <String>[
        'display_table_label',
        'table_display_name',
        'table_area_name',
        'area_table_number',
      ]) {
        expect(sql.contains(requiredKey), true, reason: requiredKey);
      }
      // Backwards-compat guard: keep using table_number lookup.
      expect(sql.contains('table_number = p_table_number'), true);
    });
  });
}

