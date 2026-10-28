import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'bulk_product_price_stock_update_models.dart';

class BulkProductPriceStockCsvParser {
  const BulkProductPriceStockCsvParser();

  BulkProductPriceStockCsvDocument parseBytes(Uint8List bytes) {
    final String rawText = utf8.decode(bytes, allowMalformed: true);
    return parseString(rawText);
  }

  BulkProductPriceStockCsvDocument parseString(String input) {
    final String sanitized = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final int commas = ','.allMatches(sanitized.split('\n').first).length;
    final int semicolons = ';'.allMatches(sanitized.split('\n').first).length;
    final delimiter = semicolons > commas ? ';' : ',';

    final List<List<dynamic>> matrix = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(sanitized);

    if (matrix.isEmpty) {
      return const BulkProductPriceStockCsvDocument(
        headers: <String>[],
        rows: <Map<String, String>>[],
      );
    }

    final List<String> headers = matrix.first
        .map((dynamic cell) => normalizeBulkProductPriceStockHeader(cell?.toString() ?? ''))
        .toList(growable: false);

    final List<Map<String, String>> rows = <Map<String, String>>[];
    for (final List<dynamic> rawRow in matrix.skip(1)) {
      if (rawRow.every((dynamic cell) => (cell?.toString() ?? '').trim().isEmpty)) {
        continue;
      }
      final Map<String, String> row = <String, String>{};
      for (int index = 0; index < headers.length; index++) {
        final String header = headers[index];
        if (header.isEmpty) {
          continue;
        }
        row[header] = index < rawRow.length ? (rawRow[index]?.toString() ?? '').trim() : '';
      }
      rows.add(row);
    }

    return BulkProductPriceStockCsvDocument(headers: headers, rows: rows);
  }
}
