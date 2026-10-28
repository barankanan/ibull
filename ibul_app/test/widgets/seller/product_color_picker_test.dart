import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/widgets/seller/product_color_picker.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_mapping.dart';

void main() {
  group('ProductColorPicker.isValidHex regex validation', () {
    test('accepts valid 6-character #RRGGBB hex codes', () {
      expect(ProductColorPicker.isValidHex('#000000'), isTrue);
      expect(ProductColorPicker.isValidHex('#FFFFFF'), isTrue);
      expect(ProductColorPicker.isValidHex('#ffffff'), isTrue);
      expect(ProductColorPicker.isValidHex('#1a2B3c'), isTrue);
      expect(ProductColorPicker.isValidHex('#FF00AA'), isTrue);
      expect(ProductColorPicker.isValidHex('#004488'), isTrue);
    });

    test('accepts valid 8-character #RRGGBBAA hex codes', () {
      expect(ProductColorPicker.isValidHex('#00000000'), isTrue);
      expect(ProductColorPicker.isValidHex('#FFFFFFFF'), isTrue);
      expect(ProductColorPicker.isValidHex('#11223344'), isTrue);
      expect(ProductColorPicker.isValidHex('#aabbccdd'), isTrue);
      expect(ProductColorPicker.isValidHex('#AABBCCDD'), isTrue);
    });

    test('rejects invalid hex characters such as #GGGGGG', () {
      expect(ProductColorPicker.isValidHex('#GGGGGG'), isFalse);
      expect(ProductColorPicker.isValidHex('#gggggg'), isFalse);
      expect(ProductColorPicker.isValidHex('#ZZZZZZ'), isFalse);
      expect(ProductColorPicker.isValidHex('#12345G'), isFalse);
      expect(ProductColorPicker.isValidHex('#XYZ12345'), isFalse);
    });

    test('rejects invalid lengths and missing # prefix', () {
      expect(ProductColorPicker.isValidHex('FFFFFF'), isFalse);
      expect(ProductColorPicker.isValidHex('#FFF'), isFalse);
      expect(ProductColorPicker.isValidHex('#12345'), isFalse);
      expect(ProductColorPicker.isValidHex('#1234567'), isFalse);
      expect(ProductColorPicker.isValidHex('#123456789'), isFalse);
      expect(ProductColorPicker.isValidHex('#'), isFalse);
      expect(ProductColorPicker.isValidHex('   '), isTrue); // default allowEmpty = true
      expect(ProductColorPicker.isValidHex('   ', allowEmpty: false), isFalse);
      expect(ProductColorPicker.isValidHex(null), isTrue); // default allowEmpty = true
      expect(ProductColorPicker.isValidHex(null, allowEmpty: false), isFalse);
    });
  });

  group('ProductColorPicker Widget Tests', () {
    testWidgets('renders initial color name and hex', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductColorPicker(
              initialColorName: 'Gece Mavisi',
              initialColorHex: '#001133',
              onChanged: (name, hex) {},
            ),
          ),
        ),
      );

      expect(find.text('Gece Mavisi'), findsOneWidget);
      expect(find.text('#001133'), findsOneWidget);
    });

    testWidgets('tapping predefined color updates name, hex, and notifies callback', (tester) async {
      String? changedName;
      String? changedHex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductColorPicker(
              onChanged: (name, hex) {
                changedName = name;
                changedHex = hex;
              },
            ),
          ),
        ),
      );

      // Tap on 'Kırmızı' circle swatch
      await tester.tap(find.byKey(const ValueKey('color_Kırmızı')));
      await tester.pumpAndSettle();

      expect(changedName, equals('Kırmızı'));
      expect(changedHex, equals('#FF0000'));
      expect(find.text('Kırmızı'), findsWidgets);
      expect(find.text('#FF0000'), findsOneWidget);
    });

    testWidgets('empty hex field allows color name without validation error', (tester) async {
      String? changedHex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductColorPicker(
              initialColorName: 'Klasik Siyah',
              onChanged: (_, hex) {
                changedHex = hex;
              },
            ),
          ),
        ),
      );

      expect(find.text('Klasik Siyah'), findsOneWidget);
      expect(ProductColorPicker.isValidHex(changedHex, allowEmpty: true), isTrue);
    });
  });

  group('CSV color_hex Validation Tests', () {
    final validator = BulkProductImportValidator();

    Map<String, String> createBaseRowValues({String color = 'Siyah', String colorHex = ''}) {
      return <String, String>{
        'product_name': 'Test Ürün',
        'brand': 'Test Marka',
        'main_category': 'Elektronik',
        'sub_category': 'Kulaklık',
        'description': 'Test açıklama',
        'price': '100',
        'stock_quantity': '10',
        'status': 'draft',
        'color': color,
        'color_hex': colorHex,
      };
    }

    test('valid color_hex (#004488) passes CSV validation', () {
      final values = createBaseRowValues(colorHex: '#004488');
      final row = validator.validateRow(
        rowNumber: 2,
        rawValues: values,
        hasLegacyHeaders: false,
      );

      expect(row.errors, isEmpty);
      expect(row.candidate?.colorHex, equals('#004488'));
    });

    test('valid 8-char color_hex (#AABBCCDD) passes CSV validation', () {
      final values = createBaseRowValues(colorHex: '#AABBCCDD');
      final row = validator.validateRow(
        rowNumber: 2,
        rawValues: values,
        hasLegacyHeaders: false,
      );

      expect(row.errors, isEmpty);
      expect(row.candidate?.colorHex, equals('#AABBCCDD'));
    });

    test('invalid color_hex (#GGGGGG) fails CSV validation with error', () {
      final values = createBaseRowValues(colorHex: '#GGGGGG');
      final row = validator.validateRow(
        rowNumber: 2,
        rawValues: values,
        hasLegacyHeaders: false,
      );

      expect(row.errors, isNotEmpty);
      expect(
        row.errors.any((e) => e.contains('Geçersiz color_hex kodu')),
        isTrue,
      );
    });

    test('empty color_hex with color name passes validation (legacy product support)', () {
      final values = createBaseRowValues(color: 'Kırmızı', colorHex: '');
      final row = validator.validateRow(
        rowNumber: 2,
        rawValues: values,
        hasLegacyHeaders: false,
      );

      expect(row.errors, isEmpty);
      expect(row.candidate?.color, equals('Kırmızı'));
      expect(row.candidate?.colorHex, isEmpty);
    });

    test('invalid color_hex in variants_json triggers validation error', () {
      final values = createBaseRowValues();
      values['variants_json'] = r'[{"color":"Mavi","color_hex":"#GGGGGG","stock":5,"price":50}]';

      final row = validator.validateRow(
        rowNumber: 2,
        rawValues: values,
        hasLegacyHeaders: false,
      );

      expect(row.errors, isNotEmpty);
      expect(
        row.errors.any((e) => e.contains('Varyant için geçersiz color_hex kodu')),
        isTrue,
      );
    });

    test('mapping candidate with color and color_hex produces valid specs JSON', () {
      final candidate = BulkProductImportCandidate(
        productName: 'Telefon',
        brand: 'Marka',
        mainCategory: 'Elektronik',
        subCategory: 'Telefon',
        description: 'Açıklama',
        price: 1000,
        stock: 5,
        status: 'draft',
        color: 'Gece Mavisi',
        colorHex: '#002244',
      );

      final specsJson = buildBulkImportSpecificationsJson(candidate, food: false);
      expect(specsJson, contains('"color_hex":"#002244"'));
      expect(specsJson, contains('"color":"Gece Mavisi"'));

      final attrLines = buildBulkImportAttributeLines(candidate);
      expect(attrLines, contains('Renk: Gece Mavisi'));
    });
  });
}
