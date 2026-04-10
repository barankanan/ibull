import 'package:ibul_app/models/seller_product.dart';

import 'bulk_product_price_stock_update_models.dart';

class BulkProductPriceStockUpdateValidator {
  const BulkProductPriceStockUpdateValidator();

  BulkProductPriceStockUpdatePreview validate({
    required String fileName,
    required BulkProductPriceStockCsvDocument document,
    required List<SellerProduct> existingProducts,
  }) {
    final List<String> normalizedHeaders = document.headers
        .map((String header) => header.trim())
        .where((String header) => header.isNotEmpty)
        .toList(growable: false);
    final Set<String> headerSet = normalizedHeaders.toSet();
    final List<String> fileErrors = <String>[];

    final List<String> missingHeaders =
        bulkProductPriceStockUpdateRequiredHeaders
            .where((String header) => !headerSet.contains(header))
            .toList(growable: false);

    if (normalizedHeaders.isEmpty) {
      fileErrors.add('CSV dosyası boş veya başlık satırı okunamadı.');
    }
    if (missingHeaders.isNotEmpty) {
      fileErrors.add('Eksik zorunlu kolonlar: ${missingHeaders.join(', ')}');
    }
    if (document.rows.isEmpty) {
      fileErrors.add('Önizleme için en az 1 veri satırı gerekli.');
    }

    final Map<String, SellerProduct> productsBySku = <String, SellerProduct>{};
    for (final SellerProduct product in existingProducts) {
      final String normalizedSku = normalizeBulkProductSku(product.sku);
      if (normalizedSku.isEmpty || productsBySku.containsKey(normalizedSku)) {
        continue;
      }
      productsBySku[normalizedSku] = product;
    }

    final Map<String, int> duplicateCounts = <String, int>{};
    for (final Map<String, String> rawRow in document.rows) {
      final String sku = normalizeBulkProductSku(rawRow['sku']);
      if (sku.isEmpty) {
        continue;
      }
      duplicateCounts[sku] = (duplicateCounts[sku] ?? 0) + 1;
    }

    final List<BulkProductPriceStockPreviewRow> rows =
        <BulkProductPriceStockPreviewRow>[];
    for (int index = 0; index < document.rows.length; index++) {
      rows.add(
        _validateRow(
          rowNumber: index + 2,
          rawValues: document.rows[index],
          productsBySku: productsBySku,
          duplicateCounts: duplicateCounts,
        ),
      );
    }

    return BulkProductPriceStockUpdatePreview(
      fileName: fileName,
      headers: normalizedHeaders,
      rows: rows,
      fileErrors: fileErrors,
    );
  }

  BulkProductPriceStockPreviewRow _validateRow({
    required int rowNumber,
    required Map<String, String> rawValues,
    required Map<String, SellerProduct> productsBySku,
    required Map<String, int> duplicateCounts,
  }) {
    final Map<String, String> values = <String, String>{};
    for (final MapEntry<String, String> entry in rawValues.entries) {
      values[entry.key.trim()] = entry.value.trim();
    }

    final List<String> errors = <String>[];
    final String rawSku = _cleanText(values['sku']);
    final String normalizedSku = normalizeBulkProductSku(rawSku);
    final SellerProduct? currentProduct = normalizedSku.isEmpty
        ? null
        : productsBySku[normalizedSku];

    if (rawSku.isEmpty) {
      errors.add('SKU boş olamaz');
    }
    if (normalizedSku.isNotEmpty && (duplicateCounts[normalizedSku] ?? 0) > 1) {
      errors.add('Aynı SKU CSV içinde birden fazla kez yer alıyor');
    }
    if (currentProduct == null && rawSku.isNotEmpty) {
      errors.add('Ürün bulunamadı');
    }

    final String priceText = _cleanText(values['price']);
    final double? parsedPrice = _parseFlexibleDouble(priceText);
    if (priceText.isEmpty) {
      errors.add('Fiyat boş olamaz');
    } else if (parsedPrice == null || parsedPrice <= 0) {
      errors.add('Fiyat 0’dan büyük sayısal bir değer olmalı');
    }

    final String stockText = _cleanText(values['stock']);
    final int? parsedStock = _parseFlexibleInt(stockText);
    if (stockText.isEmpty) {
      errors.add('Stok boş olamaz');
    } else if (parsedStock == null || parsedStock < 0) {
      errors.add('Stok 0 veya daha büyük tam sayı olmalı');
    }

    final String rawStatus = _cleanText(values['status']);
    final String? normalizedRequestedStatus = normalizeBulkProductCsvStatus(
      rawStatus,
    );
    if (rawStatus.isNotEmpty && normalizedRequestedStatus == null) {
      errors.add(
        'Durum geçersiz. Desteklenen değerler: Aktif, Pasif, Beklemede',
      );
    }

    if (errors.isNotEmpty || currentProduct == null) {
      return BulkProductPriceStockPreviewRow(
        rowNumber: rowNumber,
        sku: rawSku,
        rawValues: values,
        currentProduct: currentProduct,
        errors: errors,
        rowState: BulkProductPriceStockUpdateRowState.invalid,
      );
    }

    final double newPrice = parsedPrice!;
    final int newStock = parsedStock!;
    final String currentStatus = normalizeBulkProductStoredStatus(
      currentProduct.status,
    );
    final String effectiveStatus = resolveBulkProductExpectedStatus(
      currentStatus: currentProduct.status,
      requestedStatus: normalizedRequestedStatus,
    );
    final bool priceChanged = !_samePrice(currentProduct.price, newPrice);
    final bool stockChanged = currentProduct.stock != newStock;
    final bool statusChanged =
        normalizedRequestedStatus != null &&
        currentStatus != normalizedRequestedStatus;

    if (!priceChanged && !stockChanged && !statusChanged) {
      return BulkProductPriceStockPreviewRow(
        rowNumber: rowNumber,
        sku: currentProduct.sku,
        rawValues: values,
        currentProduct: currentProduct,
        errors: const <String>[],
        rowState: BulkProductPriceStockUpdateRowState.unchanged,
      );
    }

    return BulkProductPriceStockPreviewRow(
      rowNumber: rowNumber,
      sku: currentProduct.sku,
      rawValues: values,
      currentProduct: currentProduct,
      errors: const <String>[],
      rowState: BulkProductPriceStockUpdateRowState.updatable,
      updatePlan: BulkProductPriceStockUpdatePlan(
        currentProduct: currentProduct,
        newPrice: newPrice,
        newStock: newStock,
        effectiveStatus: effectiveStatus,
        statusToPersist: statusChanged ? normalizedRequestedStatus : null,
        priceChanged: priceChanged,
        stockChanged: stockChanged,
        statusChanged: statusChanged,
      ),
    );
  }

  String _cleanText(String? value) {
    return value?.trim() ?? '';
  }

  bool _samePrice(double left, double right) {
    return (left - right).abs() < 0.0001;
  }

  num? _parseFlexibleNumber(String raw) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return null;
    }

    String normalized = input.replaceAll(' ', '');
    final int lastComma = normalized.lastIndexOf(',');
    final int lastDot = normalized.lastIndexOf('.');

    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      final int commaCount = ','.allMatches(normalized).length;
      normalized = commaCount == 1
          ? normalized.replaceAll(',', '.')
          : normalized.replaceAll(',', '');
    } else if (lastDot >= 0) {
      final int dotCount = '.'.allMatches(normalized).length;
      normalized = dotCount > 1 ? normalized.replaceAll('.', '') : normalized;
    }

    return num.tryParse(normalized);
  }

  double? _parseFlexibleDouble(String raw) {
    final num? number = _parseFlexibleNumber(raw);
    return number?.toDouble();
  }

  int? _parseFlexibleInt(String raw) {
    final num? number = _parseFlexibleNumber(raw);
    if (number == null) {
      return null;
    }
    if (number is double && number % 1 != 0) {
      return null;
    }
    return number.toInt();
  }
}
