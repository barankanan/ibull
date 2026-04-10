import 'dart:convert';
import 'dart:typed_data';

import 'bulk_product_price_stock_update_models.dart';

class BulkProductPriceStockCsvParser {
  const BulkProductPriceStockCsvParser();

  BulkProductPriceStockCsvDocument parseBytes(Uint8List bytes) {
    final String rawText = utf8.decode(bytes, allowMalformed: true);
    return parseString(rawText);
  }

  BulkProductPriceStockCsvDocument parseString(String input) {
    final String sanitized = input.replaceFirst('\uFEFF', '');
    final List<List<String>> matrix = _parseMatrix(sanitized);
    if (matrix.isEmpty) {
      return const BulkProductPriceStockCsvDocument(
        headers: <String>[],
        rows: <Map<String, String>>[],
      );
    }

    final List<String> headers = matrix.first
        .map(normalizeBulkProductPriceStockHeader)
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

    return BulkProductPriceStockCsvDocument(headers: headers, rows: rows);
  }

  List<List<String>> _parseMatrix(String input) {
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

      if (!inQuotes && char == ',') {
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
