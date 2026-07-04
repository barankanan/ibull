import 'dart:convert';
import 'dart:typed_data';

import 'bulk_product_import_models.dart';

class BulkProductCsvParser {
  const BulkProductCsvParser();

  BulkProductCsvDocument parseBytes(Uint8List bytes) {
    final String rawText = utf8.decode(bytes, allowMalformed: true);
    return parseString(rawText);
  }

  BulkProductCsvDocument parseString(String input) {
    final String sanitized = input.replaceFirst('\uFEFF', '');
    final String delimiter = _detectDelimiter(sanitized);
    final List<List<String>> matrix = _parseMatrix(sanitized, delimiter);
    if (matrix.isEmpty) {
      return const BulkProductCsvDocument(
        headers: <String>[],
        rows: <Map<String, String>>[],
      );
    }

    final List<String> headers = matrix.first
        .map(_normalizeHeader)
        .toList(growable: false);

    final List<Map<String, String>> rows = <Map<String, String>>[];
    for (final List<String> rawRow in matrix.skip(1)) {
      if (rawRow.every((String cell) => cell.trim().isEmpty)) {
        continue;
      }
      final Map<String, String> row = <String, String>{};
      for (int index = 0; index < headers.length; index++) {
        final String header = headers[index];
        if (header.isEmpty) {
          continue;
        }
        row[header] = index < rawRow.length ? rawRow[index].trim() : '';
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

  List<List<String>> _parseMatrix(String input, String delimiter) {
    final List<List<String>> rows = <List<String>>[];
    final StringBuffer cell = StringBuffer();
    final List<String> currentRow = <String>[];
    bool inQuotes = false;

    void flushCell() {
      currentRow.add(cell.toString());
      cell.clear();
    }

    void flushRow() {
      flushCell();
      rows.add(List<String>.from(currentRow));
      currentRow.clear();
    }

    for (int index = 0; index < input.length; index++) {
      final String char = input[index];
      if (char == '"') {
        final bool hasEscapedQuote =
            inQuotes && index + 1 < input.length && input[index + 1] == '"';
        if (hasEscapedQuote) {
          cell.write('"');
          index++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (!inQuotes && char == delimiter) {
        flushCell();
        continue;
      }

      if (!inQuotes && char == '\n') {
        flushRow();
        continue;
      }

      if (!inQuotes && char == '\r') {
        continue;
      }

      cell.write(char);
    }

    final bool hasPendingData =
        cell.isNotEmpty || currentRow.isNotEmpty || rows.isEmpty;
    if (hasPendingData) {
      flushRow();
    }

    return rows;
  }
}
