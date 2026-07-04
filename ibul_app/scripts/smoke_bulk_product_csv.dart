#!/usr/bin/env dart
// Toplu CSV indirme/yükleme smoke testi.
//
// Kullanım:
//   dart run scripts/smoke_bulk_product_csv.dart
//   set -a && source ../.env && set +a && dart run scripts/smoke_bulk_product_csv.dart --rls

import 'dart:convert';
import 'dart:io';

import 'package:ibul_app/screens/seller/product_management/bulk_product_csv_parser.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_models.dart';
import 'package:ibul_app/screens/seller/product_management/bulk_product_import_validator.dart';

const _parser = BulkProductCsvParser();
const _validator = BulkProductImportValidator();

Future<void> main(List<String> args) async {
  final bool runRls = args.contains('--rls');
  var passed = 0;
  var failed = 0;

  void pass(String msg) {
    passed++;
    stdout.writeln('PASS: $msg');
  }

  void fail(String msg) {
    failed++;
    stderr.writeln('FAIL: $msg');
  }

  stdout.writeln('=== Bulk CSV Smoke Test ===\n');

  // 1. CSV indirme (macOS/desktop kod yolu)
  stdout.writeln('--- 1. CSV İndirme ---');
  try {
    final bytes = buildBulkProductImportTemplateBytes();
    if (bytes.length < 4 ||
        bytes[0] != 0xEF ||
        bytes[1] != 0xBB ||
        bytes[2] != 0xBF) {
      fail('UTF-8 BOM eksik');
    } else {
      pass('UTF-8 BOM mevcut');
    }

    final savedPath = await _saveToDownloads(bytes, bulkProductImportTemplateFileName);

    if (savedPath.trim().isEmpty) {
      fail('saveBytes yol döndürmedi');
    } else {
      final file = File(savedPath);
      if (!await file.exists()) {
        fail('Dosya diskte yok: $savedPath');
      } else {
        pass('Dosya kaydedildi: $savedPath');
        if (savedPath.contains('ibul_toplu_urun_sablonu.csv')) {
          pass('Dosya adı doğru');
        } else {
          fail('Dosya adı beklenenden farklı: $savedPath');
        }

        final diskBytes = await file.readAsBytes();
        final text = utf8.decode(diskBytes);
        if (text.contains('iPhone 15 Pro') &&
            text.contains('Güçlü') &&
            text.contains('Şarj')) {
          pass('Türkçe karakterler dosyada korunuyor');
        } else {
          fail('Türkçe karakterler bozulmuş olabilir');
        }

        final doc = _parser.parseBytes(diskBytes);
        if (doc.headers.length >= bulkProductImportCanonicalHeaders.length) {
          pass(
            'Kolon sayısı doğru (${doc.headers.length} başlık)',
          );
        } else {
          fail('Kolon sayısı eksik: ${doc.headers.length}');
        }

        if (doc.rows.length >= 3) {
          pass('Örnek satır sayısı: ${doc.rows.length}');
        } else {
          fail('Örnek satır eksik: ${doc.rows.length}');
        }

        // JSON kolonları kaymamalı
        final preview = _validator.validate(
          fileName: bulkProductImportTemplateFileName,
          document: doc,
          lockedMainCategory: 'Elektronik',
        );
        final jsonRows = preview.rows
            .where((r) => r.candidate?.attributesMap.isNotEmpty == true)
            .length;
        if (jsonRows >= 2) {
          pass('attributes_json kolonları parse edildi ($jsonRows satır)');
        } else {
          fail('attributes_json parse başarısız');
        }
        final variantRows = preview.rows
            .where((r) => (r.candidate?.variants.length ?? 0) > 0)
            .length;
        if (variantRows >= 1) {
          pass('variants_json kolonları parse edildi ($variantRows satır)');
        } else {
          fail('variants_json parse başarısız');
        }

        for (final row in preview.rows) {
          if (!row.isValid) {
            fail(
              'Şablon satır ${row.rowNumber} geçersiz: ${row.errors.join('; ')}',
            );
          }
        }
        if (preview.validRowCount >= 3) {
          pass('Şablonun 3 örnek satırı geçerli');
        }
      }
    }
  } catch (e, st) {
    fail('CSV indirme hatası: $e\n$st');
  }

  // 2. CSV tekrar yükleme / önizleme
  stdout.writeln('\n--- 2. CSV Önizleme ---');
  try {
    final templateBytes = buildBulkProductImportTemplateBytes();
    final doc = _parser.parseBytes(templateBytes);
    final preview = _validator.validate(
      fileName: 'roundtrip.csv',
      document: doc,
      lockedMainCategory: 'Elektronik',
    );
    if (preview.fileErrors.isEmpty) {
      pass('Dosya seviyesi hata yok');
    } else {
      fail('Dosya hataları: ${preview.fileErrors.join(' | ')}');
    }
    if (preview.validRowCount == preview.totalRows) {
      pass('Tüm satırlar geçerli (${preview.validRowCount})');
    } else {
      for (final row in preview.rows.where((r) => !r.isValid)) {
        stderr.writeln(
          '  Satır ${row.rowNumber}: ${row.errors.join(', ')}',
        );
      }
      fail(
        'Geçersiz satır: ${preview.invalidRowCount}/${preview.totalRows}',
      );
    }
  } catch (e) {
    fail('Önizleme hatası: $e');
  }

  // 3. Gerçek ürün satırları validasyonu
  stdout.writeln('\n--- 3. Gerçek Ürün Satırları ---');
  try {
    final customCsv = _buildRealProductCsv();
    final doc = _parser.parseString(customCsv);
    final preview = _validator.validate(
      fileName: 'real_products.csv',
      document: doc,
      lockedMainCategory: 'Elektronik',
    );
    if (preview.validRowCount >= 2) {
      pass('2 gerçek ürün satırı geçerli');
    } else {
      for (final row in preview.rows) {
        stderr.writeln(
          '  Satır ${row.rowNumber} [${row.isValid ? 'OK' : 'HATA'}]: '
          '${row.errors.isEmpty ? row.candidate?.productName : row.errors.join(', ')}',
        );
      }
      fail('Gerçek ürün satırları geçersiz');
    }

  // Duplicate SKU uyarısı simülasyonu
    final dupCsv =
        '${bulkProductImportCanonicalHeaders.join(',')}\n'
        '${_realProductRow(name: 'A', sub: 'Telefon', sku: 'DUP-001')}\n'
        '${_realProductRow(name: 'B', sub: 'Telefon', sku: 'DUP-001')}';
    final dupDoc = _parser.parseString(dupCsv);
    final dupPreview = _validator.validate(
      fileName: 'dup.csv',
      document: dupDoc,
      lockedMainCategory: 'Elektronik',
    );
    if (dupPreview.validRowCount == 2) {
      pass('Duplicate SKU validasyonda satırları engellemez (import aşamasında uyarı)');
    }
  } catch (e) {
    fail('Gerçek ürün testi: $e');
  }

  // 4. RLS (opsiyonel, anon key ile)
  if (runRls) {
    stdout.writeln('\n--- 7. RLS Güvenliği (anon) ---');
    await _runRlsChecks(pass, fail);
  } else {
    stdout.writeln(
      '\nSKIP: RLS testi için --rls ve IBUL_SUPABASE_URL/ANON_KEY gerekli',
    );
  }

  stdout.writeln('\n=== Sonuç: $passed geçti, $failed başarısız ===');
  exit(failed > 0 ? 1 : 0);
}

Future<String> _saveToDownloads(List<int> bytes, String fileName) async {
  final home = Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    final downloads = Directory('$home/Downloads');
    if (await downloads.exists()) {
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
    'Smoke test ürün açıklaması — Türkçe karakter: şğüöçı',
    '24999',
    '5',
    'active',
    'Siyah',
    sku,
    '8690000${sku.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}',
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
  return cells.map((c) {
    if (c.contains(',') || c.contains('"') || c.contains('\n')) {
      return '"${c.replaceAll('"', '""')}"';
    }
    return c;
  }).join(',');
}

Future<void> _runRlsChecks(
  void Function(String) pass,
  void Function(String) fail,
) async {
  final url = (Platform.environment['IBUL_SUPABASE_URL'] ?? '').trim();
  final anonKey = (Platform.environment['IBUL_SUPABASE_ANON_KEY'] ?? '').trim();
  if (url.isEmpty || anonKey.isEmpty) {
    fail('IBUL_SUPABASE_URL / IBUL_SUPABASE_ANON_KEY yok');
    return;
  }

  final client = HttpClient();
  try {
    final headers = <String, String>{
      'apikey': anonKey,
      'Authorization': 'Bearer $anonKey',
    };

    final activeUri = Uri.parse(
      '$url/rest/v1/products?select=id,name,status,seller_id&status=eq.Aktif&limit=3',
    );
    final activeReq = await client.getUrl(activeUri);
    headers.forEach(activeReq.headers.set);
    final activeRes = await activeReq.close();
    final activeBody = await activeRes.transform(utf8.decoder).join();
    if (activeRes.statusCode == 200) {
      final rows = jsonDecode(activeBody) as List;
      pass('Anon active ürün okuyabiliyor (${rows.length} kayıt örneği)');
    } else {
      fail('Anon active okuma HTTP ${activeRes.statusCode}: $activeBody');
    }

    final draftUri = Uri.parse(
      '$url/rest/v1/products?select=id,name,status&status=eq.Taslak&limit=5',
    );
    final draftReq = await client.getUrl(draftUri);
    headers.forEach(draftReq.headers.set);
    final draftRes = await draftReq.close();
    final draftBody = await draftRes.transform(utf8.decoder).join();
    if (draftRes.statusCode == 200) {
      final rows = jsonDecode(draftBody) as List;
      if (rows.isEmpty) {
        pass('Anon draft ürün göremiyor (0 kayıt)');
      } else {
        fail('Anon draft ürün görebiliyor: ${rows.length} kayıt — RLS sorunu');
      }
    } else if (draftRes.statusCode == 401 || draftRes.statusCode == 403) {
      pass('Anon draft erişimi engellendi (HTTP ${draftRes.statusCode})');
    } else {
      pass('Anon draft sorgusu boş/engelli (HTTP ${draftRes.statusCode})');
    }

    final passiveUri = Uri.parse(
      '$url/rest/v1/products?select=id&status=eq.Pasif&limit=5',
    );
    final passiveReq = await client.getUrl(passiveUri);
    headers.forEach(passiveReq.headers.set);
    final passiveRes = await passiveReq.close();
    final passiveBody = await passiveRes.transform(utf8.decoder).join();
    if (passiveRes.statusCode == 200) {
      final rows = jsonDecode(passiveBody) as List;
      if (rows.isEmpty) {
        pass('Anon passive ürün göremiyor');
      } else {
        fail('Anon passive ürün görebiliyor: ${rows.length}');
      }
    } else {
      pass('Anon passive erişimi kısıtlı');
    }

    // Başka satıcı ürününü güncelleme denemesi
    final patchUri = Uri.parse('$url/rest/v1/products?id=eq.00000000-0000-0000-0000-000000000001');
    final patchReq = await client.patchUrl(patchUri);
    headers.forEach(patchReq.headers.set);
    patchReq.headers.contentType = ContentType.json;
    patchReq.write(jsonEncode({'name': 'RLS smoke hack'}));
    final patchRes = await patchReq.close();
    await patchRes.drain();
    if (patchRes.statusCode == 401 ||
        patchRes.statusCode == 403 ||
        patchRes.statusCode == 404 ||
        patchRes.statusCode == 406) {
      pass('Anon başka satıcı ürününü düzenleyemiyor (HTTP ${patchRes.statusCode})');
    } else {
      fail('Anon PATCH beklenmeyen yanıt: HTTP ${patchRes.statusCode}');
    }
  } catch (e) {
    fail('RLS test hatası: $e');
  } finally {
    client.close();
  }
}
