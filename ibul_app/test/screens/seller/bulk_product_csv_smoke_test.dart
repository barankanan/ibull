import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_csv_parser.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';

/// macOS/desktop CSV indirme ve round-trip smoke testi.
void main() {
  const parser = BulkProductCsvParser();
  const validator = BulkProductImportValidator();

  group('CSV smoke (dosya sistemi)', () {
    test('Downloads\'a yazılır, BOM ve Türkçe karakterler korunur', () async {
      final bytes = buildBulkProductImportTemplateBytes();
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      final path = await _saveToDownloads(bytes, bulkProductImportTemplateFileName);
      final file = File(path);
      expect(await file.exists(), isTrue);
      expect(path, contains('ibul_toplu_urun_sablonu.csv'));

      final diskBytes = await file.readAsBytes();
      final text = utf8.decode(diskBytes);
      expect(text, contains('Güçlü'));
      expect(text, contains('inç'));

      final doc = parser.parseBytes(diskBytes);
      expect(doc.headers.length, bulkProductImportCanonicalHeaders.length);
      expect(doc.rows.length, greaterThanOrEqualTo(3));

      final preview = validator.validate(
        fileName: bulkProductImportTemplateFileName,
        document: doc,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.fileErrors, isEmpty);
      expect(preview.validRowCount, preview.totalRows);

      final withAttrs = preview.rows
          .where((r) => r.candidate?.attributesMap.isNotEmpty == true)
          .length;
      expect(withAttrs, greaterThanOrEqualTo(2));

      final withVariants = preview.rows
          .where((r) => (r.candidate?.variants.length ?? 0) > 0)
          .length;
      expect(withVariants, greaterThanOrEqualTo(1));
    });

    test('2 gerçek elektronik ürün satırı geçerli parse edilir', () {
      final csv = _buildRealProductCsv();
      final doc = parser.parseString(csv);
      final preview = validator.validate(
        fileName: 'real.csv',
        document: doc,
        lockedMainCategory: 'Elektronik',
      );
      expect(preview.validRowCount, 2);
      final phone = preview.rows.first.candidate!;
      expect(phone.mainCategory, 'Elektronik');
      expect(phone.subCategory, 'Telefon');
      expect(phone.attributesMap['RAM'], '12 GB');
      expect(phone.variants.length, 1);
    });
  });
}

Future<String> _saveToDownloads(List<int> bytes, String fileName) async {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    final downloads = Directory('$home/Downloads');
    if (downloads.existsSync()) {
      final file = File('${downloads.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }
  final temp = await Directory.systemTemp.createTemp('ibul_csv_smoke_');
  final file = File('${temp.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

String _buildRealProductCsv() {
  return '${bulkProductImportCanonicalHeaders.join(',')}\n'
      '${_realProductRow(name: 'Samsung Galaxy S24 Ultra', sub: 'Telefon', sku: 'SM-S928-TEST')}\n'
      '${_realProductRow(name: 'Arçelik Fırın A', sub: 'Ev Aletleri', sku: 'ARC-FRN-TEST')}';
}

String _realProductRow({
  required String name,
  required String sub,
  required String sku,
}) {
  return _csvRow(<String>[
    name,
    'TestMarka',
    'MODEL-$sku',
    'Elektronik',
    sub,
    'Smoke test — Türkçe: şğüöçı',
    '24999',
    '5',
    'active',
    'Siyah',
    sku,
    '8690000123456',
    '22999',
    '20',
    'TRY',
    '24',
    'Türkiye',
    'new',
    'false',
    'https://example.com/$sku.jpg',
    '',
    '',
    r'{"RAM":"12 GB","Garanti Süresi":"24 Ay"}',
    r'[{"Renk":"Siyah","Stok":3,"Fiyat":24999}]',
    '2.1',
    '40',
    '50',
    '35',
    'standart',
    'false',
    '',
    '',
    '',
    '',
    '',
    '',
  ]);
}

String _csvRow(List<String> cells) {
  return cells
      .map((String c) {
        if (c.contains(',') || c.contains('"') || c.contains('\n')) {
          return '"${c.replaceAll('"', '""')}"';
        }
        return c;
      })
      .join(',');
}
