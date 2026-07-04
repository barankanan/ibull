import 'dart:convert';

import 'package:ibul_app/core/product_rich_description.dart' as rich_desc;

import 'bulk_product_import_models.dart';

/// CSV sayı alanları: 0.35 / 0,35 / 35
num? parseBulkImportFlexibleNumber(String raw) {
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
    normalized = normalized.replaceAll(',', '.');
  }
  return num.tryParse(normalized);
}

double? parseBulkImportFlexibleDouble(String raw) =>
    parseBulkImportFlexibleNumber(raw)?.toDouble();

int? parseBulkImportFlexibleInt(String raw) {
  final num? number = parseBulkImportFlexibleNumber(raw);
  if (number == null) {
    return null;
  }
  if (number is double && number % 1 != 0) {
    return null;
  }
  return number.toInt();
}

bool parseBulkImportBool(String raw) {
  final String normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'evet' ||
      normalized == 'yes';
}

bool parseBulkImportBoolOrNull(String raw) {
  final String normalized = raw.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  if (normalized == 'false' ||
      normalized == '0' ||
      normalized == 'hayır' ||
      normalized == 'hayir' ||
      normalized == 'no') {
    return false;
  }
  return parseBulkImportBool(raw);
}

String readBulkImportField(Map<String, String> values, String key) =>
    values[key]?.trim() ?? '';

double? readBulkImportCargoDouble(
  Map<String, String> values, {
  required String primaryKey,
  required String packageKey,
}) {
  final String primary = readBulkImportField(values, primaryKey);
  if (primary.isNotEmpty) {
    return parseBulkImportFlexibleDouble(primary);
  }
  final String package = readBulkImportField(values, packageKey);
  if (package.isNotEmpty) {
    return parseBulkImportFlexibleDouble(package);
  }
  return null;
}

void validateBulkImportCargoNumericField({
  required String label,
  required String raw,
  required List<String> errors,
}) {
  if (raw.trim().isEmpty) {
    return;
  }
  if (parseBulkImportFlexibleDouble(raw) == null) {
    errors.add('$label sayısal olmalı');
  }
}

String normalizeBulkImportDescription(String? raw) =>
    rich_desc.normalizeProductDescriptionText(raw);

rich_desc.BulkImportDescriptionResolution resolveBulkImportDescriptionFields(
  Map<String, String> values,
) {
  return rich_desc.resolveBulkImportDescriptionFields(
    values,
    normalizeDescription: normalizeBulkImportDescription,
    readField: readBulkImportField,
    parsePipeSeparated: parsePipeSeparated,
  );
}

String? normalizeBulkImportShippingProfile(String? raw) {
  final String normalized = (raw ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  switch (normalized) {
    case 'standart':
    case 'standard':
    case 'normal':
      return 'standart';
    case 'ucretsiz':
    case 'ücretsiz':
    case 'free':
    case 'free_shipping':
      return 'ucretsiz';
    case 'hassas':
    case 'fragile':
      return 'hassas';
    case 'agir':
    case 'ağır':
    case 'heavy':
      return 'agir';
    case 'hacimli':
    case 'bulky':
    case 'volume':
      return 'hacimli';
    default:
      return normalized;
  }
}

/// Satıcı panelindeki kargo seçeneği dropdown değerleri.
String mapBulkImportShippingProfileToUiOption({
  required String? profile,
  required bool freeShipping,
}) {
  if (freeShipping ||
      normalizeBulkImportShippingProfile(profile) == 'ucretsiz') {
    return 'Ücretsiz Kargo';
  }
  switch (normalizeBulkImportShippingProfile(profile)) {
    case 'hassas':
    case 'agir':
    case 'hacimli':
      return 'Sabit Ücret';
    case 'standart':
    default:
      return 'Alıcı Öder';
  }
}

Map<String, String> parseBulkImportAttributesMap(Map<String, String> values) {
  final String attributesJson = readBulkImportField(values, 'attributes_json');
  if (attributesJson.isNotEmpty) {
    try {
      final dynamic parsed = jsonDecode(attributesJson);
      if (parsed is Map) {
        return parsed.map(
          (dynamic key, dynamic value) =>
              MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {}
  }

  final String legacyAttributes = readBulkImportField(values, '_legacy_attributes');
  if (legacyAttributes.isNotEmpty) {
    return <String, String>{
      for (final String item in parseCommaSeparated(legacyAttributes)) item: item,
    };
  }

  return const <String, String>{};
}

List<String> parseBulkImportHighlights(Map<String, String> values) {
  final String highlightsJson = readBulkImportField(values, 'highlights_json');
  if (highlightsJson.isNotEmpty) {
    try {
      final dynamic parsed = jsonDecode(highlightsJson);
      if (parsed is List) {
        return parsed
            .map((dynamic item) => item?.toString().trim() ?? '')
            .where((String item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {}
  }

  final String keyFeatures = readBulkImportField(values, 'key_features');
  if (keyFeatures.isNotEmpty) {
    return parsePipeSeparated(keyFeatures);
  }

  return parseCommaSeparated(readBulkImportField(values, 'highlight_infos'));
}

List<String> buildBulkImportAttributeLines(BulkProductImportCandidate candidate) {
  final List<String> lines = candidate.attributesMap.entries
      .where(
        (MapEntry<String, String> entry) =>
            entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty,
      )
      .map(
        (MapEntry<String, String> entry) =>
            '${entry.key.trim()}: ${entry.value.trim()}',
      )
      .toList(growable: true);

  final String? color = candidate.color?.trim();
  if (color != null && color.isNotEmpty) {
    final int colorIndex = lines.indexWhere(
      (String line) => line.toLowerCase().startsWith('renk:'),
    );
    if (colorIndex >= 0) {
      lines[colorIndex] = 'Renk: $color';
    } else {
      lines.add('Renk: $color');
    }
  }

  return lines;
}

String buildBulkImportSpecificationsJson(
  BulkProductImportCandidate candidate, {
  required bool food,
}) {
  final Map<String, dynamic> specifications = <String, dynamic>{
    'vatRate': candidate.vatRate ?? 0,
    'currency': candidate.currency,
    'barcode': candidate.barcode,
    'warrantyMonths': candidate.warrantyMonths,
    'originCountry': candidate.originCountry,
    'condition': candidate.condition,
    'isFeatured': candidate.isFeatured,
    'color': candidate.color,
    'freeShipping': candidate.freeShipping,
  };

  if (candidate.attributesMap.isNotEmpty) {
    specifications['attributes'] = candidate.attributesMap;
  }

  if (candidate.cargoWeightKg != null) {
    specifications['weightKg'] = candidate.cargoWeightKg;
  }
  if (candidate.cargoWidthCm != null) {
    specifications['widthCm'] = candidate.cargoWidthCm;
  }
  if (candidate.cargoLengthCm != null) {
    specifications['lengthCm'] = candidate.cargoLengthCm;
  }
  if (candidate.cargoHeightCm != null) {
    specifications['heightCm'] = candidate.cargoHeightCm;
  }

  final String? shippingProfile = normalizeBulkImportShippingProfile(
    candidate.cargoShippingProfile,
  );
  if (shippingProfile != null) {
    specifications['shippingProfile'] = shippingProfile;
  }

  specifications['cargo'] = <String, dynamic>{
    'weightKg': candidate.cargoWeightKg,
    'widthCm': candidate.cargoWidthCm,
    'lengthCm': candidate.cargoLengthCm,
    'heightCm': candidate.cargoHeightCm,
    'shippingProfile': shippingProfile,
    'freeShipping': candidate.freeShipping,
  };

  final String? deliveryTime = candidate.deliveryTime?.trim();
  if (deliveryTime != null && deliveryTime.isNotEmpty) {
    specifications['deliveryTime'] = deliveryTime;
  }
  if (candidate.estimatedDeliveryDays != null) {
    specifications['estimatedDeliveryDays'] = candidate.estimatedDeliveryDays;
  }

  if (candidate.highlightInfos.isNotEmpty) {
    specifications['highlights'] = candidate.highlightInfos;
    specifications['key_features'] = candidate.highlightInfos;
  }

  if (candidate.richDescriptionBlocks.isNotEmpty) {
    final List<rich_desc.ProductRichDescriptionBlock> normalized =
        rich_desc.normalizeStoryBlocks(candidate.richDescriptionBlocks);
    specifications['description_story_json'] =
        rich_desc.encodeDescriptionStoryJson(normalized);
    specifications['rich_description_json'] =
        rich_desc.encodeLegacyRichDescriptionJson(normalized);
  }

  if (food) {
    specifications['features'] = List<String>.from(candidate.highlightInfos);
    specifications['additional_info'] = List<String>.from(
      candidate.highlightInfos,
    );
  }

  specifications.removeWhere(
    (String key, dynamic value) =>
        value == null ||
        (value is String && value.trim().isEmpty) ||
        (value is Map && value.isEmpty),
  );

  return jsonEncode(specifications);
}

Map<String, dynamic> decodeBulkImportSpecificationsMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return <String, dynamic>{};
  }
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return <String, dynamic>{};
}

double? readSpecificationCargoDouble(
  Map<String, dynamic> specs,
  String flatKey, {
  String nestedKey = '',
}) {
  final dynamic flat = specs[flatKey];
  if (flat != null) {
    if (flat is num) {
      return flat.toDouble();
    }
    return parseBulkImportFlexibleDouble(flat.toString());
  }

  final dynamic cargo = specs['cargo'];
  if (cargo is Map) {
    final String key = nestedKey.isEmpty ? flatKey : nestedKey;
    final dynamic nested = cargo[key];
    if (nested is num) {
      return nested.toDouble();
    }
    if (nested != null) {
      return parseBulkImportFlexibleDouble(nested.toString());
    }
  }
  return null;
}
