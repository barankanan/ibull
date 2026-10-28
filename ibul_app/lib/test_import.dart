import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_csv_parser.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_mapping.dart';
import 'dart:convert';

void main() {
  final String csvText = buildBulkProductImportTemplateCsv(false);
  print('--- Generated CSV ---');
  print(csvText);
  
  final parser = const BulkProductCsvParser();
  final document = parser.parseString(csvText);
  
  print('\n--- Parsed Document ---');
  print('Headers: \${document.headers}');
  print('Row count: \${document.rows.length}');
  
  final validator = const BulkProductImportValidator();
  final preview = validator.validate(
    fileName: 'test.csv',
    document: document,
  );
  
  print('\n--- Validation Result ---');
  print('Valid rows: \${preview.validRowCount}');
  print('Invalid rows: \${preview.invalidRowCount}');
  print('File errors: \${preview.fileErrors}');
  
  for (var row in preview.rows) {
    print('Row \${row.rowNumber} errors: \${row.errors}');
    if (row.candidate != null) {
      final specs = buildBulkImportSpecificationsJson(row.candidate!, food: false);
      print('Candidate specifications: \$specs');
      print('Candidate variants: \${jsonEncode(row.candidate!.variants)}');
      print('Candidate isFeatured: \${row.candidate!.isFeatured}');
      print('Candidate mainImageUrl: \${row.candidate!.mainImageUrl}');
    }
  }
}
