import 'dart:convert';

import 'package:ibul_app/core/category_pricing_helper.dart';

import 'bulk_product_import_mapping.dart';
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

    final bool hasLegacyHeaders =
        !normalizedHeaderSet.contains('sub_category') &&
        !normalizedHeaderSet.contains('alt kategori');

    final List<String> missingHeaders = hasLegacyHeaders
        ? <String>[
            if (!normalizedHeaderSet.contains('Ürün Adı') &&
                !normalizedHeaderSet.contains('product_name'))
              'product_name',
            if (!normalizedHeaderSet.contains('Fiyat') &&
                !normalizedHeaderSet.contains('price'))
              'price',
            if (!normalizedHeaderSet.contains('Stok') &&
                !normalizedHeaderSet.contains('stock_quantity'))
              'stock_quantity',
          ]
        : bulkProductImportRequiredHeaders
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

    final List<BulkProductImportPreviewRow> rows = <BulkProductImportPreviewRow>[];
    for (int index = 0; index < document.rows.length; index++) {
      rows.add(
        _validateRow(
          rowNumber: index + 2,
          rawValues: document.rows[index],
          lockedMainCategory: lockedMainCategory,
          hasLegacyHeaders: hasLegacyHeaders,
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
    required bool hasLegacyHeaders,
  }) {
    final Map<String, String> values = _normalizeRowKeys(rawValues);
    final List<String> errors = <String>[];

    final String productName = readBulkImportField(values, 'product_name');
    final String brand = readBulkImportField(values, 'brand');
    final String mainCategory = readBulkImportField(values, 'main_category').isNotEmpty
        ? readBulkImportField(values, 'main_category')
        : (lockedMainCategory ?? '');
    final String subCategory = readBulkImportField(values, 'sub_category');
    final String priceText = readBulkImportField(values, 'price');
    final String stockText = readBulkImportField(values, 'stock_quantity');
    final String statusRaw = readBulkImportField(values, 'status');
    final String status = normalizeBulkProductImportStatus(statusRaw);
    final String vatRateText = readBulkImportField(values, 'tax_rate');
    final String attributesJson = readBulkImportField(values, 'attributes_json');
    final String variantsJson = readBulkImportField(values, 'variants_json');
    final String imageUrlsRaw = readBulkImportField(values, 'image_urls');
    final String mainImageUrl = readBulkImportField(values, 'main_image_url');
    final String cargoWeightRaw = readBulkImportField(values, 'cargo_weight_kg');
    final String cargoWidthRaw = readBulkImportField(values, 'cargo_width_cm');
    final String cargoLengthRaw = readBulkImportField(values, 'cargo_length_cm');
    final String cargoHeightRaw = readBulkImportField(values, 'cargo_height_cm');

    if (productName.isEmpty) errors.add('product_name boş');
    if (brand.isEmpty && !hasLegacyHeaders) errors.add('brand boş');
    if (mainCategory.isEmpty) errors.add('main_category boş');
    if (subCategory.isEmpty && !hasLegacyHeaders) {
      errors.add('sub_category boş');
    }
    if (!_isKnownMainCategory(mainCategory) && mainCategory.isNotEmpty) {
      errors.add('main_category sistemde tanımlı değil: $mainCategory');
    }

    final double? price = parseBulkImportFlexibleDouble(priceText);
    if (priceText.isEmpty) {
      errors.add('price boş');
    } else if (price == null || price <= 0) {
      errors.add('price sayı olmalı ve 0\'dan büyük olmalı');
    }

    final int? stock = parseBulkImportFlexibleInt(stockText);
    if (stockText.isEmpty) {
      errors.add('stock_quantity boş');
    } else if (stock == null || stock < 0) {
      errors.add('stock_quantity geçerli bir sayı olmalı');
    }

    if (status.isNotEmpty &&
        !bulkProductImportAllowedStatuses.contains(status)) {
      errors.add(
        'status pending_approval, draft veya passive olmalı (active otomatik onaya gider)',
      );
    }

    if (vatRateText.isNotEmpty && parseBulkImportFlexibleNumber(vatRateText) == null) {
      errors.add('tax_rate sayı olmalı');
    }

    validateBulkImportCargoNumericField(
      label: 'cargo_weight_kg',
      raw: cargoWeightRaw,
      errors: errors,
    );
    validateBulkImportCargoNumericField(
      label: 'cargo_width_cm',
      raw: cargoWidthRaw,
      errors: errors,
    );
    validateBulkImportCargoNumericField(
      label: 'cargo_length_cm',
      raw: cargoLengthRaw,
      errors: errors,
    );
    validateBulkImportCargoNumericField(
      label: 'cargo_height_cm',
      raw: cargoHeightRaw,
      errors: errors,
    );

    if (attributesJson.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(attributesJson);
        if (parsed is! Map) {
          errors.add('attributes_json geçerli JSON nesnesi olmalı');
        }
      } catch (_) {
        errors.add('attributes_json geçerli JSON olmalı');
      }
    }

    final String highlightsJson = readBulkImportField(values, 'highlights_json');
    if (highlightsJson.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(highlightsJson);
        if (parsed is! List) {
          errors.add('highlights_json geçerli JSON dizisi olmalı');
        }
      } catch (_) {
        errors.add('highlights_json geçerli JSON olmalı');
      }
    }

    final String richDescriptionJson =
        readBulkImportField(values, 'rich_description_json');
    if (richDescriptionJson.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(richDescriptionJson);
        if (parsed is! List) {
          errors.add('rich_description_json geçerli JSON dizisi olmalı');
        }
      } catch (_) {
        errors.add('rich_description_json geçerli JSON olmalı');
      }
    }

    if (variantsJson.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(variantsJson);
        if (parsed is! List) {
          errors.add('variants_json geçerli JSON dizisi olmalı');
        }
      } catch (_) {
        errors.add('variants_json geçerli JSON olmalı');
      }
    }

    for (final String url in <String>[
      if (mainImageUrl.isNotEmpty) mainImageUrl,
      ...parsePipeSeparated(imageUrlsRaw),
    ]) {
      if (!_isValidUrl(url)) {
        errors.add('Görsel URL geçersiz: $url');
        break;
      }
    }

    if (errors.isNotEmpty) {
      return BulkProductImportPreviewRow(
        rowNumber: rowNumber,
        rawValues: values,
        errors: errors,
      );
    }

    final Map<String, String> attributesMap = parseBulkImportAttributesMap(values);
    final List<Map<String, dynamic>> variants = _parseVariants(variantsJson);
    final String salePriceText = readBulkImportField(values, 'sale_price');
    final double? salePrice = salePriceText.isEmpty
        ? null
        : parseBulkImportFlexibleDouble(salePriceText);
    final List<String> highlightInfos = parseBulkImportHighlights(values);
    final descriptionResolution = resolveBulkImportDescriptionFields(values);
    final String deliveryTime = readBulkImportField(values, 'delivery_time');
    final String estimatedDeliveryDaysRaw =
        readBulkImportField(values, 'estimated_delivery_days');
    final String shippingProfileRaw =
        readBulkImportField(values, 'cargo_shipping_profile');
    final bool freeShipping = parseBulkImportBoolOrNull(
      readBulkImportField(values, 'free_shipping'),
    );

    return BulkProductImportPreviewRow(
      rowNumber: rowNumber,
      rawValues: values,
      errors: const <String>[],
      candidate: BulkProductImportCandidate(
        productName: productName,
        brand: brand,
        modelCode: _optional(values, 'model_code'),
        mainCategory: mainCategory,
        subCategory: subCategory.isNotEmpty
            ? subCategory
            : _defaultSubCategory(mainCategory),
        description: descriptionResolution.description,
        price: price,
        stock: stock,
        status: status,
        color: _optional(values, 'color'),
        sku: _optional(values, 'sku'),
        barcode: _optional(values, 'barcode'),
        salePrice: salePrice,
        vatRate: vatRateText.isEmpty
            ? null
            : parseBulkImportFlexibleNumber(vatRateText),
        currency: _optional(values, 'currency').isEmpty
            ? 'TRY'
            : _optional(values, 'currency'),
        warrantyMonths:
            parseBulkImportFlexibleInt(readBulkImportField(values, 'warranty_months')),
        originCountry: _optional(values, 'origin_country'),
        condition: _optional(values, 'condition'),
        isFeatured: parseBulkImportBool(readBulkImportField(values, 'is_featured')),
        mainImageUrl: mainImageUrl.isEmpty ? null : mainImageUrl,
        imageUrls: _resolveImageUrls(mainImageUrl, imageUrlsRaw),
        videoUrl: _optional(values, 'video_url'),
        attributesMap: attributesMap,
        variants: variants,
        cargoWeightKg: readBulkImportCargoDouble(
          values,
          primaryKey: 'cargo_weight_kg',
          packageKey: 'package_weight_kg',
        ),
        cargoWidthCm: readBulkImportCargoDouble(
          values,
          primaryKey: 'cargo_width_cm',
          packageKey: 'package_width_cm',
        ),
        cargoLengthCm: readBulkImportCargoDouble(
          values,
          primaryKey: 'cargo_length_cm',
          packageKey: 'package_length_cm',
        ),
        cargoHeightCm: readBulkImportCargoDouble(
          values,
          primaryKey: 'cargo_height_cm',
          packageKey: 'package_height_cm',
        ),
        cargoShippingProfile: normalizeBulkImportShippingProfile(
          shippingProfileRaw,
        ),
        freeShipping: freeShipping,
        portionPrice: parseBulkImportFlexibleDouble(
          readBulkImportField(values, 'portion_price'),
        ),
        kiloPrice: parseBulkImportFlexibleDouble(
          readBulkImportField(values, 'kilo_price'),
        ),
        minGram: parseBulkImportFlexibleInt(readBulkImportField(values, 'min_gram')),
        defaultGram:
            parseBulkImportFlexibleInt(readBulkImportField(values, 'default_gram')),
        gramStep: parseBulkImportFlexibleInt(readBulkImportField(values, 'gram_step')),
        maxGram: parseBulkImportFlexibleInt(readBulkImportField(values, 'max_gram')),
        priceType: _normalizePriceType(readBulkImportField(values, 'price_type')),
        preparationTimeMinutes: parseBulkImportFlexibleInt(
          readBulkImportField(values, 'preparation_time_minutes'),
        ),
        highlightInfos: highlightInfos,
        deliveryTime: deliveryTime.isEmpty ? null : deliveryTime,
        estimatedDeliveryDays: estimatedDeliveryDaysRaw.isEmpty
            ? null
            : parseBulkImportFlexibleInt(estimatedDeliveryDaysRaw),
        richDescriptionBlocks: descriptionResolution.richBlocks,
      ),
    );
  }

  Map<String, String> _normalizeRowKeys(Map<String, String> rawValues) {
    final Map<String, String> values = <String, String>{};
    for (final MapEntry<String, String> entry in rawValues.entries) {
      final String key = entry.key.trim();
      if (key.isEmpty) continue;
      final String canonical =
          bulkProductImportHeaderAliases[key.toLowerCase()] ?? key;
      values[canonical] = entry.value.trim();
    }
    if (values.containsKey('Ürün Adı')) {
      values['product_name'] = values['Ürün Adı']!;
    }
    if (values.containsKey('Fiyat')) {
      values['price'] = values['Fiyat']!;
    }
    if (values.containsKey('Stok')) {
      values['stock_quantity'] = values['Stok']!;
    }
    if (values.containsKey('Marka')) {
      values['brand'] = values['Marka']!;
    }
    if (values.containsKey('Açıklama')) {
      values['description'] = values['Açıklama']!;
    }
    if (values.containsKey('Model Kodu')) {
      values['model_code'] = values['Model Kodu']!;
    }
    if (values.containsKey('Ürün Özellikleri') &&
        !values.containsKey('attributes_json')) {
      values['attributes_json'] = '';
      values['_legacy_attributes'] = values['Ürün Özellikleri']!;
    }
    return values;
  }

  List<Map<String, dynamic>> _parseVariants(String variantsJson) {
    if (variantsJson.isEmpty) return const <Map<String, dynamic>>[];
    try {
      final dynamic parsed = jsonDecode(variantsJson);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((Map item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      }
    } catch (_) {}
    return const <Map<String, dynamic>>[];
  }

  List<String> _resolveImageUrls(String mainImageUrl, String imageUrlsRaw) {
    final List<String> urls = <String>[];
    if (mainImageUrl.isNotEmpty) urls.add(mainImageUrl);
    for (final String url in parsePipeSeparated(imageUrlsRaw)) {
      if (!urls.contains(url)) urls.add(url);
    }
    return urls;
  }

  String _optional(Map<String, String> values, String key) =>
      readBulkImportField(values, key);

  bool _isValidUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  String _normalizePriceType(String rawPriceType) {
    final String normalized = rawPriceType.trim().toLowerCase();
    if (normalized.isEmpty) return 'portion';
    if (normalized == 'porsiyon' || normalized == 'portion') return 'portion';
    if (normalized == 'kg' || normalized == 'kilogram') return 'kg';
    return '';
  }

  bool _isKnownMainCategory(String value) {
    final String lookup = normalizeCategoryKey(value);
    return bulkProductImportCategoryCatalog.keys.any(
      (String category) => normalizeCategoryKey(category) == lookup,
    );
  }

  String _defaultSubCategory(String mainCategory) {
    final List<String> subCategories =
        bulkProductImportCategoryCatalog[mainCategory] ?? const <String>[];
    if (subCategories.contains('Diğer')) return 'Diğer';
    if (subCategories.contains('Ana Yemek')) return 'Ana Yemek';
    if (subCategories.isNotEmpty) return subCategories.first;
    return 'Diğer';
  }
}
