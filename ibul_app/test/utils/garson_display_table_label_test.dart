import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/utils/table_labels.dart';

void main() {
  group('resolveGarsonDisplayTableLabel', () {
    test('Bahçe 3 display_label ile modal title üretir', () {
      final result = resolveGarsonDisplayTableLabel(
        table: <String, dynamic>{
          'id': 'table-bahce-3',
          'table_number': 12,
          'area_name': 'Bahçe',
          'area_table_number': 3,
          'display_label': 'Bahçe 3',
        },
        fallbackTableNumber: 12,
      );

      expect(result.label, 'Bahçe 3');
      expect(result.source, GarsonTableLabelSource.tableDisplayLabel);
      expect(result.usedFallback, isFalse);
      expect(garsonCloseTableDialogTitle(result.label), 'Bahçe 3 kapatılsın mı?');
      expect(
        garsonCloseTableDialogTitle(result.label),
        isNot('Masa 12 kapatılsın mı?'),
      );
    });

    test('Salon 4 display_label ile doğru label üretir', () {
      final result = resolveGarsonDisplayTableLabel(
        table: <String, dynamic>{
          'id': 'table-salon-4',
          'table_number': 4,
          'area_name': 'Salon',
          'area_table_number': 4,
          'display_label': 'Salon 4',
        },
        fallbackTableNumber: 4,
      );

      expect(result.label, 'Salon 4');
      expect(garsonCloseTableDialogTitle(result.label), 'Salon 4 kapatılsın mı?');
    });

    test('snackbar Bahçe 3 kapatıldı üretir Masa 12 değil', () {
      const label = 'Bahçe 3';
      expect(garsonCloseTableSnackbarText(label), 'Bahçe 3 kapatıldı.');
      expect(garsonCloseTableSnackbarText(label), isNot('Masa 12 kapatıldı.'));
    });

    test('display_label yoksa area_name + area_table_number kullanılır', () {
      final result = resolveGarsonDisplayTableLabel(
        table: <String, dynamic>{
          'id': 'table-bahce-3',
          'table_number': 12,
          'area_name': 'Bahçe',
          'area_table_number': 3,
        },
        fallbackTableNumber: 12,
      );

      expect(result.label, 'Bahçe 3');
      expect(result.source, GarsonTableLabelSource.areaNumber);
      expect(result.usedFallback, isFalse);
    });

    test('sectionItem displayLabel öncelikli', () {
      final result = resolveGarsonDisplayTableLabel(
        table: <String, dynamic>{
          'table_number': 12,
          'display_label': 'Bahçe 3',
        },
        sectionDisplayLabel: 'Bahçe 3',
        fallbackTableNumber: 12,
      );

      expect(result.label, 'Bahçe 3');
      expect(result.source, GarsonTableLabelSource.sectionItem);
    });

    test('activeOrder display_table_label table eksikken kullanılır', () {
      final result = resolveGarsonDisplayTableLabel(
        activeOrder: <String, dynamic>{
          'display_table_label': 'Teras 2',
          'table_number': 31,
        },
        fallbackTableNumber: 31,
      );

      expect(result.label, 'Teras 2');
      expect(result.source, GarsonTableLabelSource.orderDisplayLabel);
    });

    test('her şey eksikse fallback Masa N ve usedFallback true', () {
      final result = resolveGarsonDisplayTableLabel(
        fallbackTableNumber: 12,
      );

      expect(result.label, 'Masa 12');
      expect(result.source, GarsonTableLabelSource.fallback);
      expect(result.usedFallback, isTrue);
    });
  });
}
