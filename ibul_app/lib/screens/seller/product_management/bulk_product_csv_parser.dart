import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'bulk_product_import_models.dart';

class BulkProductCsvParser {
  const BulkProductCsvParser();

  BulkProductCsvDocument parseBytes(Uint8List bytes) {
    final String rawText = utf8.decode(bytes, allowMalformed: true);
    return parseString(rawText);
  }

  BulkProductCsvDocument parseString(String input) {
    final String sanitized = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final String delimiter = _detectDelimiter(sanitized);

    // CsvToListConverter parses standard CSV preserving commas in quotes and JSON fields
    final List<List<dynamic>> matrix = CsvToListConverter(
      fieldDelimiter: delimiter,
      eol: '\n',
      shouldParseNumbers: false,
      allowInvalid: true,
    ).convert(sanitized);

    if (matrix.isEmpty) {
      return const BulkProductCsvDocument(
        headers: <String>[],
        rows: <Map<String, String>>[],
      );
    }

    final List<String> headers = matrix.first
        .map((dynamic cell) => _normalizeHeader(cell?.toString() ?? ''))
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

    return BulkProductCsvDocument(headers: headers, rows: rows);
  }

  String _normalizeHeader(String rawHeader) {
    final String trimmed = rawHeader.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final String normalizedKey = trimmed.toLowerCase();
    return bulkProductImportHeaderAliases[normalizedKey] ?? trimmed;
  }

  String _detectDelimiter(String input) {
    final int newline = input.indexOf('\n');
    final String headerLine =
        newline >= 0 ? input.substring(0, newline) : input;
    final int commas = ','.allMatches(headerLine).length;
    final int semicolons = ';'.allMatches(headerLine).length;
    return semicolons > commas ? ';' : ',';
  }
}
