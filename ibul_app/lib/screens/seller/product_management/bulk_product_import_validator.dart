import 'bulk_product_import_models.dart';

class BulkProductImportValidator {
  const BulkProductImportValidator();

  BulkProductImportPreview validate({
    required String fileName,
    required BulkProductCsvDocument document,
    String? lockedMainCategory,
  }) {
    final List<String> normalizedHeaders = document.headers
        .map((String header) => header.trim())
        .where((String header) => header.isNotEmpty)
        .toList(growable: false);

    final Set<String> normalizedHeaderSet = normalizedHeaders.toSet();
    final List<String> fileErrors = <String>[];

    final List<String> missingHeaders = bulkProductImportRequiredHeaders
        .where((String header) => !normalizedHeaderSet.contains(header))
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

    final List<BulkProductImportPreviewRow> rows =
        <BulkProductImportPreviewRow>[];
    for (int index = 0; index < document.rows.length; index++) {
      rows.add(
        _validateRow(
          rowNumber: index + 2,
          rawValues: document.rows[index],
          lockedMainCategory: lockedMainCategory,
        ),
      );
    }

    return BulkProductImportPreview(
      fileName: fileName,
      headers: normalizedHeaders,
      rows: rows,
      fileErrors: fileErrors,
    );
  }

  BulkProductImportPreviewRow _validateRow({
    required int rowNumber,
    required Map<String, String> rawValues,
    required String? lockedMainCategory,
  }) {
    final Map<String, String> values = <String, String>{};
    for (final MapEntry<String, String> entry in rawValues.entries) {
      values[entry.key.trim()] = entry.value.trim();
    }

    final List<String> errors = <String>[];
    final String productName = _cleanText(values['Ürün Adı']);
    final String priceText = _cleanText(values['Fiyat']);
    final String stockText = _cleanText(values['Stok']);
    final String vatRateText = _cleanText(values['KDV Oranı']);
    final String preparationTimeText = _cleanText(values['Hazırlama Süresi']);
    final String rawPriceType = _cleanText(values['Fiyat Tipi']);

    if (productName.isEmpty) {
      errors.add('Ürün adı boş');
    }

    final double price = _parseOptionalDoubleWithDefault(priceText);
    if (priceText.isNotEmpty && !_isParsableNumber(priceText)) {
      errors.add('Fiyat geçersiz');
    }

    final int stock = _parseOptionalIntWithDefault(stockText);
    if (stockText.isNotEmpty && !_isParsableInteger(stockText)) {
      errors.add('Stok geçersiz');
    } else if (stock < 0) {
      errors.add('Stok geçersiz');
    }

    final num vatRate = _parseOptionalNumberWithDefault(vatRateText);
    if (vatRateText.isNotEmpty && !_isParsableNumber(vatRateText)) {
      errors.add('KDV oranı geçersiz');
    }

    final int preparationTimeMinutes = _parseOptionalIntWithDefault(
      preparationTimeText,
    );
    if (preparationTimeText.isNotEmpty &&
        !_isParsableInteger(preparationTimeText)) {
      errors.add('Hazırlama süresi geçersiz');
    }

    final String normalizedPriceType = _normalizePriceType(rawPriceType);
    if (rawPriceType.isNotEmpty && normalizedPriceType.isEmpty) {
      errors.add('Fiyat tipi geçersiz');
    }

    if (lockedMainCategory != null &&
        lockedMainCategory.trim().isNotEmpty &&
        !_isKnownMainCategory(lockedMainCategory)) {
      errors.add('Mağaza kategorisi sistemde bulunamadı');
    }

    if (errors.isNotEmpty) {
      return BulkProductImportPreviewRow(
        rowNumber: rowNumber,
        rawValues: values,
        errors: errors,
      );
    }

    return BulkProductImportPreviewRow(
      rowNumber: rowNumber,
      rawValues: values,
      errors: const <String>[],
      candidate: BulkProductImportCandidate(
        productName: productName,
        price: price,
        stock: stock,
        vatRate: vatRate,
        preparationTimeMinutes: preparationTimeMinutes,
        description: _optionalTextOrEmpty(values['Açıklama']),
        brand: _optionalTextOrEmpty(values['Marka']),
        modelCode: _optionalTextOrEmpty(values['Model Kodu']),
        priceType: normalizedPriceType.isEmpty
            ? 'portion'
            : normalizedPriceType,
        productAttributes: parseCommaSeparated(values['Ürün Özellikleri']),
        highlightInfos: parseCommaSeparated(values['Öne Çıkan Bilgiler']),
      ),
    );
  }

  String _optionalTextOrEmpty(String? value) {
    return _cleanText(value);
  }

  String _cleanText(String? value) {
    return value?.trim() ?? '';
  }

  bool _isParsableNumber(String raw) => _parseFlexibleNumber(raw) != null;

  bool _isParsableInteger(String raw) => _parseFlexibleInt(raw) != null;

  num _parseOptionalNumberWithDefault(String raw, {num defaultValue = 0}) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return defaultValue;
    }
    return _parseFlexibleNumber(input) ?? defaultValue;
  }

  double _parseOptionalDoubleWithDefault(
    String raw, {
    double defaultValue = 0,
  }) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return defaultValue;
    }
    return _parseFlexibleDouble(input) ?? defaultValue;
  }

  int _parseOptionalIntWithDefault(String raw, {int defaultValue = 0}) {
    final String input = raw.trim();
    if (input.isEmpty) {
      return defaultValue;
    }
    return _parseFlexibleInt(input) ?? defaultValue;
  }

  String _normalizePriceType(String rawPriceType) {
    final String normalized = rawPriceType.trim().toLowerCase();
    if (normalized.isEmpty) return 'portion';
    if (normalized == 'porsiyon' || normalized == 'portion') {
      return 'portion';
    }
    if (normalized == 'kg' || normalized == 'kilogram') {
      return 'kg';
    }
    return '';
  }

  bool _isKnownMainCategory(String value) {
    final String lookup = value.trim().toLowerCase();
    return bulkProductImportCategoryCatalog.keys.any(
      (String category) => category.trim().toLowerCase() == lookup,
    );
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
