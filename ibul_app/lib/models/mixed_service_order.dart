import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import '../utils/garson_product_selection.dart';
import 'product_pricing.dart';
import 'seller_product.dart';

class MixedServiceDisplayEntry {
  const MixedServiceDisplayEntry._({
    required this.label,
    required this.isGroupHeader,
    this.detail,
  });

  const MixedServiceDisplayEntry.groupHeader(String label)
    : this._(label: label, isGroupHeader: true);

  const MixedServiceDisplayEntry.item(String label, {String? detail})
    : this._(label: label, isGroupHeader: false, detail: detail);

  final String label;
  final bool isGroupHeader;

  /// Secondary text shown below the item label (e.g. gramaj, note). Null for headers.
  final String? detail;
}

class MixedServiceTemplateResolution {
  const MixedServiceTemplateResolution({
    required this.serviceProductId,
    required this.serviceProductName,
    required this.templateItems,
    required this.linkedIds,
    required this.matchedProducts,
    required this.activeMatchedProducts,
    required this.selectableProducts,
  });

  final String serviceProductId;
  final String serviceProductName;
  final List<Map<String, dynamic>> templateItems;
  final List<String> linkedIds;
  final List<SellerProduct> matchedProducts;
  final List<SellerProduct> activeMatchedProducts;
  final List<SellerProduct> selectableProducts;

  int get templateItemsCount => templateItems.length;
  int get matchedSelectableProductsCount => matchedProducts.length;
  int get activeMatchedProductsCount => activeMatchedProducts.length;
  int get filteredOutProductsCount =>
      matchedProducts.length - selectableProducts.length;
}

class _ResolvedTemplateItemMatch {
  const _ResolvedTemplateItemMatch({
    required this.item,
    required this.product,
    required this.matchSource,
    required this.missReason,
  });

  final Map<String, dynamic> item;
  final SellerProduct? product;
  final String? matchSource;
  final String? missReason;
}

class MixedServiceOrder {
  const MixedServiceOrder._();

  static const String itemType = 'mixed_service';
  static const String legacyTemplateProductType = 'mixed_service_template';
  static const String menuTemplateProductType = 'menu_template';
  static const String serviceTemplateProductType = 'service_template';
  static const String templateProductType = legacyTemplateProductType;
  static const String defaultItemName = 'Karışık Servis';
  static const String manualPriceMode = 'manual_price';
  static const String autoSumPriceMode = 'auto_sum';
  static const String fixedPriceMode = 'fixed_price';
  static const String manualAllowedPriceMode = 'manual_price_allowed';

  static const String _metadataProductTypeKey = '_ibul_product_type';
  static const String _metadataTemplateConfigKey =
      '_ibul_mixed_service_template';
  static const String childLocalRowIdKey = 'local_row_id';

  static const String standardGroupingMode = 'standard';
  static const String plateGroupingMode = 'plate';
  static const List<int> supportedServiceRounds = <int>[1, 2, 3, 4, 5];

  static bool isMixedService(Map<String, dynamic> item) {
    final normalizedType = item['item_type']?.toString().trim().toLowerCase();
    return normalizedType == itemType;
  }

  static bool isTemplateProduct(SellerProduct product) {
    return isTemplateProductType(productTypeFromProduct(product));
  }

  static bool isMenuTemplateProduct(SellerProduct product) {
    return productTypeFromProduct(product) == menuTemplateProductType;
  }

  static bool isServiceTemplateProduct(SellerProduct product) {
    return productTypeFromProduct(product) == serviceTemplateProductType;
  }

  static bool isTemplateProductType(String? raw) {
    final normalized = normalizeTemplateProductType(raw, fallback: '');
    return normalized == menuTemplateProductType ||
        normalized == serviceTemplateProductType;
  }

  static bool isTemplateProductRow(Map<String, dynamic> row) {
    final explicitType = row['product_type']?.toString().trim().toLowerCase();
    if (isTemplateProductType(explicitType)) {
      return true;
    }
    final metadata = _metadataEnvelope(row['specifications']);
    return isTemplateProductType(metadata[_metadataProductTypeKey]?.toString());
  }

  static String productTypeFromProduct(SellerProduct product) {
    return resolveProductKind(
      specifications: product.specifications,
      category: product.mainCategory,
      subCategory: product.subCategory,
    );
  }

  static String normalizeTemplateProductType(
    String? raw, {
    String fallback = serviceTemplateProductType,
  }) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case menuTemplateProductType:
        return menuTemplateProductType;
      case serviceTemplateProductType:
      case legacyTemplateProductType:
        return serviceTemplateProductType;
      default:
        return fallback;
    }
  }

  /// Resolves the product kind using explicit metadata only.
  ///
  /// Priority:
  ///   1. `specifications._ibul_product_type` (JSON field in specs column)
  ///   2. `productType` field (DB `product_type` column)
  ///
  /// Category/subcategory names (e.g. Yemek > Servis) and product titles do
  /// not affect the resolved kind. Template rows must set type explicitly.
  ///
  /// Returns one of: [menuTemplateProductType], [serviceTemplateProductType],
  /// or `'standard'`.
  static String resolveProductKind({
    String? specifications,
    String? productType,
    String? category,
    String? subCategory,
  }) {
    // 1. specifications._ibul_product_type
    final metadata = _metadataEnvelope(specifications);
    if (metadata.isNotEmpty) {
      final fromSpecs = normalizeTemplateProductType(
        metadata[_metadataProductTypeKey]?.toString(),
        fallback: '',
      );
      if (fromSpecs.isNotEmpty) return fromSpecs;
    }
    // 2. product_type field
    final fromType = normalizeTemplateProductType(productType, fallback: '');
    if (fromType.isNotEmpty) return fromType;
    return 'standard';
  }

  static String templateTypeLabelFromProduct(SellerProduct product) {
    switch (productTypeFromProduct(product)) {
      case menuTemplateProductType:
        return 'Menü';
      case serviceTemplateProductType:
        return 'Servis';
      default:
        return 'Şablon';
    }
  }

  static Map<String, dynamic>? templateConfigFromProduct(
    SellerProduct product,
  ) {
    final metadata = _templateMetadataFromSpecifications(
      product.specifications,
    );
    final config = metadata?[_metadataTemplateConfigKey];
    if (config is! Map) return null;
    return normalizeTemplateConfig(Map<String, dynamic>.from(config));
  }

  static String encodeTemplateSpecifications({
    String productType = serviceTemplateProductType,
    required String pricingMode,
    required double fixedPrice,
    required bool manualPriceAllowed,
    required List<Map<String, dynamic>> templateItems,
  }) {
    final normalizedItems = normalizeTemplateItems(templateItems);
    return jsonEncode(<String, dynamic>{
      _metadataProductTypeKey: normalizeTemplateProductType(productType),
      _metadataTemplateConfigKey: <String, dynamic>{
        'pricing_mode': pricingMode,
        'fixed_price': fixedPrice,
        'manual_price_allowed': manualPriceAllowed,
        'template_items': normalizedItems,
      },
    });
  }

  static Map<String, dynamic> normalizeTemplateConfig(
    Map<String, dynamic> raw,
  ) {
    final manualPriceAllowed =
        raw['manual_price_allowed'] == true ||
        raw['pricing_mode']?.toString().trim() == manualAllowedPriceMode;
    final pricingMode = manualPriceAllowed
        ? manualAllowedPriceMode
        : normalizeTemplatePricingMode(raw['pricing_mode']?.toString());
    final normalized = <String, dynamic>{
      'pricing_mode': pricingMode,
      'fixed_price': parsePrice(raw['fixed_price']),
      'manual_price_allowed': manualPriceAllowed,
      'template_items': normalizeTemplateItems(raw['template_items']),
    };
    return normalized;
  }

  static List<Map<String, dynamic>> normalizeTemplateItems(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final item = entry.value;
          final index = entry.key;
          final map = Map<String, dynamic>.from(item);
          final productId =
              map['product_id']?.toString() ??
              map['productId']?.toString() ??
              '';
          final sellerProductId =
              map['seller_product_id']?.toString() ??
              map['sellerProductId']?.toString() ??
              productId;
          final linkedProductId =
              map['linked_product_id']?.toString() ??
              map['linkedProductId']?.toString() ??
              sellerProductId;
          final linkedProductIds = _linkedIdsForTemplateItem(map);
          final localRowId = normalizeChildLocalRowId(
            map,
            fallbackProductId: productId,
            fallbackIndex: index,
          );
          final quantity = _safeQuantity((map['quantity'] as num?)?.toInt());
          final explicitLineTotal = parsePrice(map['line_total']);
          final unitPriceSnapshot = parsePrice(
            map['unit_price_snapshot'] ?? map['unit_price'],
          );
          final selectedServiceAmount =
              (map['selected_portion_value'] as num?)?.toDouble() ??
              (map['selected_service_amount'] as num?)?.toDouble() ??
              (map['selectedServiceAmount'] as num?)?.toDouble();
          final selectedWeightGrams =
              (map['selected_weight_grams'] as num?)?.toInt() ??
              (map['selectedWeightGrams'] as num?)?.toInt();
          final selectedPricingType =
              map['selected_pricing_type']?.toString() ??
              map['selectedPricingType']?.toString() ??
              ((selectedWeightGrams ?? 0) > 0 ? 'kg' : 'portion');
          final selectedOptionLabel = _storedChildOptionLabel(
            map,
            selectedServiceAmount: selectedServiceAmount,
            selectedWeightGrams: selectedWeightGrams,
          );
          final resolvedUnitPrice = unitPriceSnapshot > 0
              ? unitPriceSnapshot
              : explicitLineTotal > 0
              ? (explicitLineTotal / quantity).toDouble()
              : 0.0;
          return <String, dynamic>{
            childLocalRowIdKey: localRowId,
            'product_id': productId,
            'seller_product_id': sellerProductId,
            'linked_product_id': linkedProductId,
            'product_name':
                map['product_name']?.toString() ??
                map['name']?.toString() ??
                '-',
            'quantity': quantity,
            'unit_price_snapshot': resolvedUnitPrice,
            'line_total': explicitLineTotal > 0
                ? explicitLineTotal
                : childItemLineTotal(
                    unitPrice: resolvedUnitPrice,
                    quantity: quantity,
                  ),
            'selected_pricing_type': selectedPricingType,
            'selected_portion_value': selectedServiceAmount,
            'service_control_type':
                map['service_control_type']?.toString() ??
                map['serviceControlType']?.toString(),
            'selected_service_amount': selectedServiceAmount,
            'selected_weight_grams': selectedWeightGrams,
            'selected_option_label': selectedOptionLabel,
            'amount_label': selectedOptionLabel,
            'service_round': normalizeServiceRound(map['service_round']),
            'note': map['note']?.toString() ?? map['notes']?.toString() ?? '',
            'station_id':
                map['station_id']?.toString() ?? map['stationId']?.toString(),
            'printer_routing_enabled': map['printer_routing_enabled'] != false,
            if (linkedProductIds.isNotEmpty)
              'linked_product_ids': linkedProductIds,
          };
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> normalizeOrderItem(Map<String, dynamic> item) {
    final childItems = normalizeChildItems(item['child_items']);
    final quantity = _safeQuantity((item['quantity'] as num?)?.toInt());
    final serviceRoundCount = normalizeServiceRoundCount(
      item['service_round_count'] ?? item['plate_count'] ?? item['table_count'],
      childItems: childItems,
    );
    final resolvedName = item['item_name']?.toString().trim().isNotEmpty == true
        ? item['item_name'].toString().trim()
        : item['name']?.toString().trim().isNotEmpty == true
        ? item['name'].toString().trim()
        : defaultItemName;
    // Keep a stable unit-price snapshot so draft diffs (add/remove/update)
    // don't mis-classify pure quantity changes as "cancel + re-add total".
    final explicitUnitPriceSnapshot = parsePrice(
      item['unitPriceSnapshot'] ??
          item['unit_price_snapshot'] ??
          item['unit_price'] ??
          item['unitPrice'],
    );
    final explicitTotalPrice = parsePrice(item['total_price'] ?? item['price']);
    final fallbackUnitPrice = explicitTotalPrice > 0
        ? (explicitTotalPrice / quantity).toDouble()
        : 0.0;
    final unitPriceSnapshot =
        explicitUnitPriceSnapshot > 0 ? explicitUnitPriceSnapshot : fallbackUnitPrice;

    final normalized = <String, dynamic>{
      'product_id':
          item['product_id']?.toString() ??
          item['productId']?.toString() ??
          item['source_template_id']?.toString(),
      'source_product_type':
          item['source_product_type']?.toString() ??
          item['product_type']?.toString(),
      'source_template_id':
          item['source_template_id']?.toString() ??
          item['product_id']?.toString() ??
          item['productId']?.toString(),
      'name': resolvedName,
      'item_name': resolvedName,
      // In the app layer, `price` is treated as UNIT price (see receipt renderers).
      // Persist total separately so callers can display or recompute line totals.
      'unit_price_snapshot': unitPriceSnapshot,
      'unitPriceSnapshot': unitPriceSnapshot,
      'price': unitPriceSnapshot > 0 ? unitPriceSnapshot : (item['price'] ?? 0),
      'total_price': item['total_price'] ?? item['totalPrice'] ?? item['price'],
      'fixed_price': item['fixed_price'],
      'quantity': quantity,
      'gramaj': item['gramaj']?.toString() ?? '',
      'amount_label':
          item['amount_label']?.toString() ?? item['gramaj']?.toString() ?? '',
      'service_control_type':
          item['service_control_type']?.toString() ??
          item['serviceControlType']?.toString(),
      'selected_service_amount':
          (item['selected_service_amount'] as num?)?.toDouble() ??
          (item['selectedServiceAmount'] as num?)?.toDouble(),
      'selected_weight_grams':
          _coalescedGramsFromItem(item) ??
          (item['selected_weight_grams'] as num?)?.toInt() ??
          (item['selectedWeightGrams'] as num?)?.toInt(),
      'selected_grams':
          _coalescedGramsFromItem(item) ??
          (item['selected_grams'] as num?)?.toInt() ??
          (item['selectedGrams'] as num?)?.toInt(),
      'selected_size_name':
          item['selected_size_name']?.toString() ??
          item['selectedSizeName']?.toString(),
      'selectedSizeName':
          item['selectedSizeName']?.toString() ??
          item['selected_size_name']?.toString(),
      'notes': item['notes']?.toString() ?? item['note']?.toString() ?? '',
      'note': item['note']?.toString() ?? item['notes']?.toString() ?? '',
      'general_note':
          item['general_note']?.toString() ??
          item['note']?.toString() ??
          item['notes']?.toString() ??
          '',
      'station_id':
          item['station_id']?.toString() ?? item['stationId']?.toString(),
      'station_name':
          item['station_name']?.toString() ??
          item['kitchen_station_name']?.toString(),
      'kitchen_station_name':
          item['kitchen_station_name']?.toString() ??
          item['station_name']?.toString(),
      'printer_routing_enabled': item['printer_routing_enabled'] != false,
      'attributes':
          (item['attributes'] as List?)?.whereType<String>().toList() ??
          <String>[],
      'item_type': item['item_type']?.toString() ?? 'product',
      'product_type':
          item['product_type']?.toString() ?? item['source_product_type'],
      'pricing_mode': _normalizePricingMode(
        item['pricing_mode']?.toString(),
        fallback: isMixedService(item) ? autoSumPriceMode : '',
      ),
      'manual_price': item['manual_price'],
      'manual_price_allowed': item['manual_price_allowed'] == true,
      'line_total': item['line_total'] ?? item['total_price'],
      'child_items': childItems,
      'service_round_count': serviceRoundCount,
      'plate_count': serviceRoundCount,
      'grouping_mode': serviceRoundCount > 0
          ? plateGroupingMode
          : standardGroupingMode,
    };
    if (isMixedService(normalized)) {
      final unitTotal = resolveMainItemTotal(normalized);
      final lineTotal = unitTotal * quantity;
      normalized['price'] = unitTotal;
      normalized['unit_price_snapshot'] = unitTotal;
      normalized['unitPriceSnapshot'] = unitTotal;
      normalized['total_price'] = lineTotal;
      normalized['line_total'] = lineTotal;
    } else {
      // Ensure `price` stays UNIT price and totals are derived from it.
      final unit = parsePrice(
        normalized['unitPriceSnapshot'] ??
            normalized['unit_price_snapshot'] ??
            normalized['price'],
      );
      final lineTotal = (unit * quantity).toDouble();
      normalized['price'] = unit;
      normalized['unit_price_snapshot'] = unit;
      normalized['unitPriceSnapshot'] = unit;
      normalized['total_price'] = lineTotal;
      normalized['line_total'] = lineTotal;
    }
    return GarsonProductSelection.enrichOrderItem(normalized);
  }

  static List<Map<String, dynamic>> normalizeChildItems(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .toList(growable: false)
        .asMap()
        .entries
        .map((entry) {
          final item = entry.value;
          final index = entry.key;
          final map = Map<String, dynamic>.from(item);
          final productId =
              map['product_id']?.toString() ??
              map['productId']?.toString() ??
              '';
          final sellerProductId =
              map['seller_product_id']?.toString() ??
              map['sellerProductId']?.toString() ??
              productId;
          final linkedProductId =
              map['linked_product_id']?.toString() ??
              map['linkedProductId']?.toString() ??
              sellerProductId;
          final linkedProductIds = _linkedIdsForTemplateItem(map);
          final localRowId = normalizeChildLocalRowId(
            map,
            fallbackProductId: productId,
            fallbackIndex: index,
          );
          final quantity = _safeQuantity((map['quantity'] as num?)?.toInt());
          final explicitLineTotal = parsePrice(map['line_total']);
          final explicitUnitPrice = parsePrice(
            map['unit_price'] ?? map['unit_price_snapshot'],
          );
          final selectedServiceAmount =
              (map['selected_portion_value'] as num?)?.toDouble() ??
              (map['selected_service_amount'] as num?)?.toDouble() ??
              (map['selectedServiceAmount'] as num?)?.toDouble();
          final selectedWeightGrams =
              (map['selected_weight_grams'] as num?)?.toInt() ??
              (map['selectedWeightGrams'] as num?)?.toInt();
          final selectedPricingType =
              map['selected_pricing_type']?.toString() ??
              map['selectedPricingType']?.toString() ??
              ((selectedWeightGrams ?? 0) > 0 ? 'kg' : 'portion');
          final selectedOptionLabel = _storedChildOptionLabel(
            map,
            selectedServiceAmount: selectedServiceAmount,
            selectedWeightGrams: selectedWeightGrams,
          );
          final unitPrice = explicitUnitPrice > 0
              ? explicitUnitPrice
              : explicitLineTotal > 0
              ? (explicitLineTotal / quantity).toDouble()
              : 0.0;
          final lineTotal = explicitLineTotal > 0
              ? explicitLineTotal
              : childItemLineTotal(unitPrice: unitPrice, quantity: quantity);
          return <String, dynamic>{
            childLocalRowIdKey: localRowId,
            'product_id': productId,
            'seller_product_id': sellerProductId,
            'linked_product_id': linkedProductId,
            'product_name':
                map['product_name']?.toString() ??
                map['name']?.toString() ??
                '-',
            'quantity': quantity,
            'attributes':
                (map['attributes'] as List?)?.whereType<String>().toList() ??
                    const <String>[],
            'selected_pricing_type': selectedPricingType,
            'selected_portion_value': selectedServiceAmount,
            'unit_price': unitPrice,
            'line_total': lineTotal,
            'service_control_type':
                map['service_control_type']?.toString() ??
                map['serviceControlType']?.toString(),
            'selected_service_amount': selectedServiceAmount,
            'selected_weight_grams': selectedWeightGrams,
            'selected_option_label': selectedOptionLabel,
            'amount_label': selectedOptionLabel,
            'service_round': normalizeServiceRound(map['service_round']),
            'note': map['note']?.toString() ?? map['notes']?.toString() ?? '',
            'station_id':
                map['station_id']?.toString() ?? map['stationId']?.toString(),
            if (linkedProductIds.isNotEmpty)
              'linked_product_ids': linkedProductIds,
          };
        })
        .toList(growable: false);
  }

  static int normalizeServiceRound(dynamic raw) {
    final parsed = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (parsed == null || !supportedServiceRounds.contains(parsed)) {
      return 1;
    }
    return parsed;
  }

  static int normalizeServiceRoundCount(dynamic raw, {dynamic childItems}) {
    final parsed = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (parsed != null) {
      if (parsed <= 0) return 0;
      if (parsed > supportedServiceRounds.length) {
        return supportedServiceRounds.length;
      }
      return parsed;
    }
    var inferredMax = 0;
    for (final child in normalizeChildItems(childItems)) {
      final round = normalizeServiceRound(child['service_round']);
      if (round > inferredMax) {
        inferredMax = round;
      }
    }
    return inferredMax > 1 ? inferredMax : 0;
  }

  static int serviceRoundCountForItem(Map<String, dynamic> item) {
    return normalizeServiceRoundCount(
      item['service_round_count'] ?? item['plate_count'] ?? item['table_count'],
      childItems: item['child_items'],
    );
  }

  static bool usesPlateGrouping(Map<String, dynamic> item) {
    return serviceRoundCountForItem(item) > 0;
  }

  static double parsePrice(dynamic raw) {
    if (raw is num) return raw.toDouble();
    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) return 0;

    var normalized = text.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (normalized.isEmpty) return 0;
    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');

    if (hasComma && hasDot) {
      if (normalized.lastIndexOf(',') > normalized.lastIndexOf('.')) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (hasComma) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalized) ?? 0;
  }

  static double itemLineTotal(Map<String, dynamic> item) {
    if (isMixedService(item)) {
      final quantity = _safeQuantity((item['quantity'] as num?)?.toInt());
      return resolveMainItemTotal(item) * quantity;
    }

    final explicitLineTotal = parsePrice(item['line_total']);
    if (explicitLineTotal > 0) {
      return explicitLineTotal;
    }
    final qty = (item['quantity'] as num?)?.toInt() ?? 1;
    return qty * parsePrice(item['price']);
  }

  static double resolveMainItemTotal(Map<String, dynamic> item) {
    final pricingMode = _normalizePricingMode(
      item['pricing_mode']?.toString(),
      fallback: autoSumPriceMode,
    );
    final autoTotal = childItemsAutoTotal(item['child_items']);
    final fixedPrice = parsePrice(item['fixed_price']);
    final manualPrice = parsePrice(item['manual_price']);
    final explicitTotal = parsePrice(
      item['total_price'] ?? item['line_total'] ?? item['price'],
    );

    switch (pricingMode) {
      case fixedPriceMode:
        if (fixedPrice > 0) return fixedPrice;
        if (explicitTotal > 0) return explicitTotal;
        return autoTotal;
      case manualAllowedPriceMode:
        if (manualPrice > 0) return manualPrice;
        if (autoTotal > 0) return autoTotal;
        if (fixedPrice > 0) return fixedPrice;
        return explicitTotal;
      case manualPriceMode:
        if (manualPrice > 0) return manualPrice;
        if (fixedPrice > 0) return fixedPrice;
        if (explicitTotal > 0) return explicitTotal;
        return autoTotal;
      case autoSumPriceMode:
      default:
        if (autoTotal > 0) return autoTotal;
        if (fixedPrice > 0) return fixedPrice;
        return explicitTotal;
    }
  }

  static double childItemsAutoTotal(dynamic raw) {
    return normalizeChildItems(
      raw,
    ).fold<double>(0, (sum, item) => sum + parsePrice(item['line_total']));
  }

  static double childItemLineTotal({
    required double unitPrice,
    int quantity = 1,
  }) {
    return unitPrice * _safeQuantity(quantity);
  }

  static String? resolveStationIdForProducts(Iterable<SellerProduct> products) {
    final stationIds = products
        .map((product) => product.stationId?.trim() ?? '')
        .where((stationId) => stationId.isNotEmpty)
        .toSet();
    if (stationIds.length == 1) {
      return stationIds.first;
    }
    return null;
  }

  static bool resolvePrinterRoutingEnabled(Iterable<SellerProduct> products) {
    if (products.isEmpty) return true;
    return products.any((product) => product.printerRoutingEnabled);
  }

  static Map<int, List<Map<String, dynamic>>> groupChildItemsByRound(
    Map<String, dynamic> item,
  ) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final child in normalizeChildItems(item['child_items'])) {
      final round = normalizeServiceRound(child['service_round']);
      grouped.putIfAbsent(round, () => <Map<String, dynamic>>[]).add(child);
    }
    return grouped;
  }

  /// Returns the plain text note for a kitchen print item.
  ///
  /// Only the user-entered note and product attributes are included.
  /// Plate/child structure is NO longer encoded in this string — it is stored
  /// as structured [buildKitchenPlates] / [buildKitchenServiceChildren] data.
  static String buildKitchenNote(Map<String, dynamic> item) {
    final note =
        (item['notes'] ?? item['note'] ?? item['general_note'])
            ?.toString()
            .trim() ??
        '';
    final attrs =
        (item['attributes'] as List?)
            ?.whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];
    final noteParts = <String>[if (note.isNotEmpty) note, ...attrs];
    return noteParts.join(', ');
  }

  static Map<String, dynamic> _buildKitchenChildMap(
    Map<String, dynamic> child,
  ) {
    return <String, dynamic>{
      'id': (child['order_item_id'] ??
              child['product_id'] ??
              child['linked_product_id'] ??
              '')
          .toString(),
      'name': (child['product_name'] ??
              child['item_name'] ??
              child['name'] ??
              'Ürün')
          .toString(),
      'quantity': (child['quantity'] as num?)?.toInt() ?? 1,
      'amount_label': _storedChildOptionLabel(
        child,
        selectedServiceAmount:
            (child['selected_portion_value'] as num?)?.toDouble() ??
            (child['selected_service_amount'] as num?)?.toDouble() ??
            (child['selectedServiceAmount'] as num?)?.toDouble(),
        selectedWeightGrams:
            (child['selected_weight_grams'] as num?)?.toInt() ??
            (child['selectedWeightGrams'] as num?)?.toInt(),
      ),
      'note': (child['note'] ?? child['notes'] ?? '').toString().trim(),
      'station_id': (child['station_id'] ?? '').toString(),
    };
  }

  /// Returns structured plate data for kitchen print payloads.
  ///
  /// Each plate map has `{'label': 'Tabak N', 'items': [...]}`.
  /// Returns an empty list when the item has no plate-grouped children.
  static List<Map<String, dynamic>> buildKitchenPlates(
    Map<String, dynamic> item,
  ) {
    if (!usesPlateGrouping(item)) return const <Map<String, dynamic>>[];
    final grouped = groupChildItemsByRound(item);
    if (grouped.isEmpty) return const <Map<String, dynamic>>[];
    final rounds = grouped.keys.toList()..sort();
    return rounds
        .map(
          (round) => <String, dynamic>{
            'label': 'Tabak $round',
            'items': grouped[round]!
                .map(_buildKitchenChildMap)
                .toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  /// Returns a flat service-children list for non-plate-grouped items.
  ///
  /// Returns an empty list when the item uses plate grouping.
  static List<Map<String, dynamic>> buildKitchenServiceChildren(
    Map<String, dynamic> item,
  ) {
    if (usesPlateGrouping(item)) return const <Map<String, dynamic>>[];
    return normalizeChildItems(item['child_items'])
        .map(_buildKitchenChildMap)
        .toList(growable: false);
  }

  static MixedServiceDisplayEntry _childDisplayEntry(
    Map<String, dynamic> child,
  ) {
    final quantity = (child['quantity'] as num?)?.toInt() ?? 1;
    final productName = child['product_name']?.toString() ?? '-';
    final amountLabel = _storedChildOptionLabel(
      child,
      selectedServiceAmount:
          (child['selected_portion_value'] as num?)?.toDouble() ??
          (child['selected_service_amount'] as num?)?.toDouble() ??
          (child['selectedServiceAmount'] as num?)?.toDouble(),
      selectedWeightGrams:
          (child['selected_weight_grams'] as num?)?.toInt() ??
          (child['selectedWeightGrams'] as num?)?.toInt(),
    );
    final note = child['note']?.toString().trim() ?? '';
    // Include amountLabel in the main label string so that childItemDisplayLines
    // and buildKitchenNote share the same child presentation format.
    final label = amountLabel.isNotEmpty
        ? '$productName${quantity > 1 ? ' x$quantity' : ''} • $amountLabel'
        : '$productName x$quantity';
    final detailParts = <String>[];
    if (note.isNotEmpty) detailParts.add('Not: $note');
    return MixedServiceDisplayEntry.item(
      label,
      detail: detailParts.isEmpty ? null : detailParts.join(' • '),
    );
  }

  static List<MixedServiceDisplayEntry> childItemDisplayEntries(
    Map<String, dynamic> item,
  ) {
    final children = normalizeChildItems(item['child_items']);
    if (children.isEmpty) return const <MixedServiceDisplayEntry>[];

    if (!usesPlateGrouping(item)) {
      return children.map(_childDisplayEntry).toList(growable: false);
    }

    final entries = <MixedServiceDisplayEntry>[];
    final grouped = groupChildItemsByRound(item);
    final rounds = grouped.keys.toList()..sort();
    for (final round in rounds) {
      entries.add(MixedServiceDisplayEntry.groupHeader('Tabak $round'));
      for (final child in grouped[round]!) {
        entries.add(_childDisplayEntry(child));
      }
    }
    return entries;
  }

  static List<String> childItemDisplayLines(Map<String, dynamic> item) {
    return childItemDisplayEntries(
      item,
    ).map((entry) => entry.label).toList(growable: false);
  }

  static String childSummary(Map<String, dynamic> item) {
    final entries = childItemDisplayEntries(item);
    if (entries.isEmpty) return '';
    return entries
        .map((entry) => entry.isGroupHeader ? entry.label : '- ${entry.label}')
        .join(', ');
  }

  static double productUnitPrice(SellerProduct product) {
    if (product.hasDiscount && (product.discountPrice ?? 0) > 0) {
      return product.discountPrice ?? 0;
    }
    if (product.isWeightPriced) {
      if ((product.portionPrice ?? 0) > 0) {
        return product.portionPrice ?? 0;
      }
      if ((product.pricePerKg ?? 0) > 0) {
        return product.pricePerKg ?? 0;
      }
    }
    return product.price;
  }

  static double productUnitPriceForSelection(
    SellerProduct product, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    return ProductPriceCalculator.resolveServiceControlledUnitPrice(
      serviceControlType: product.resolvedServiceControlType,
      pricingType: product.resolvedPricingType,
      portionPrice: product.portionPrice,
      pricePerKg: product.pricePerKg,
      fallbackPrice: product.price,
      selectedAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
    );
  }

  static String productAmountLabelForSelection(
    SellerProduct product, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    if (!product.usesServiceControlStepper) return '';
    return ProductPriceCalculator.formatServiceAmountLabel(
      type: product.resolvedServiceControlType,
      amount: selectedServiceAmount,
      grams: selectedWeightGrams,
    );
  }

  static String productSelectedPricingTypeForSelection(
    SellerProduct product, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    return ProductPriceCalculator.selectedPricingTypeStorageValue(
      serviceControlType: product.resolvedServiceControlType,
      pricingType: product.resolvedPricingType,
    );
  }

  static Map<String, dynamic> childSelectionSnapshotForProduct(
    SellerProduct product, {
    int quantity = 1,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    final safeQuantity = _safeQuantity(quantity);
    final resolvedPortion = productSelectedPortionValueForSelection(
      product,
      selectedServiceAmount: selectedServiceAmount,
    );
    final resolvedWeight = productSelectedWeightGramsForSelection(
      product,
      selectedWeightGrams: selectedWeightGrams,
    );
    final unitPrice = productUnitPriceForSelection(
      product,
      selectedServiceAmount: resolvedPortion,
      selectedWeightGrams: resolvedWeight,
    );
    final optionLabel = productAmountLabelForSelection(
      product,
      selectedServiceAmount: resolvedPortion,
      selectedWeightGrams: resolvedWeight,
    );
    return <String, dynamic>{
      'selected_pricing_type': productSelectedPricingTypeForSelection(
        product,
        selectedServiceAmount: resolvedPortion,
        selectedWeightGrams: resolvedWeight,
      ),
      'selected_portion_value': resolvedPortion,
      'selected_service_amount': resolvedPortion,
      'selected_weight_grams': resolvedWeight,
      'selected_option_label': optionLabel,
      'amount_label': optionLabel,
      'unit_price': unitPrice,
      'line_total': childItemLineTotal(
        unitPrice: unitPrice,
        quantity: safeQuantity,
      ),
      'service_control_type': product.resolvedServiceControlType.storageValue,
    };
  }

  static double? productSelectedPortionValueForSelection(
    SellerProduct product, {
    double? selectedServiceAmount,
  }) {
    if (!product.usesPortionLikeStepper) return null;
    return ProductPriceCalculator.clampPortionSelection(
      selectedServiceAmount ?? product.resolvedDefaultServiceAmount,
      type: product.resolvedServiceControlType,
      minPortion: product.minPortion,
      maxPortion: product.maxPortion,
      portionStep: product.portionStep,
    );
  }

  static int? productSelectedWeightGramsForSelection(
    SellerProduct product, {
    int? selectedWeightGrams,
  }) {
    if (product.resolvedServiceControlType !=
        ProductServiceControlType.weightStepper) {
      return null;
    }
    return ProductPriceCalculator.clampWeightSelection(
      selectedWeightGrams ?? product.resolvedDefaultWeightGrams,
      minWeightGrams: product.minWeightGrams,
      weightStepGrams: product.weightStepGrams,
      maxWeightGrams: product.maxWeightGrams,
    );
  }

  static Map<String, dynamic> buildChildItemPayload(
    SellerProduct product, {
    int quantity = 1,
    double? selectedServiceAmount,
    int? selectedWeightGrams,
    int serviceRound = 1,
    String note = '',
    List<String> attributes = const <String>[],
    String? localRowId,
  }) {
    final safeQuantity = _safeQuantity(quantity);
    final selectionSnapshot = childSelectionSnapshotForProduct(
      product,
      quantity: safeQuantity,
      selectedServiceAmount: selectedServiceAmount,
      selectedWeightGrams: selectedWeightGrams,
    );
    final normalizedServiceRound = normalizeServiceRound(serviceRound);
    return <String, dynamic>{
      childLocalRowIdKey: (localRowId?.trim().isNotEmpty ?? false)
          ? localRowId!.trim()
          : buildChildLocalRowId(
              productId: product.id,
              serviceRound: normalizedServiceRound,
              selectedPricingType: selectionSnapshot['selected_pricing_type']
                  ?.toString(),
              selectedPortionValue:
                  (selectionSnapshot['selected_portion_value'] as num?)
                      ?.toDouble(),
              selectedWeightGrams:
                  (selectionSnapshot['selected_weight_grams'] as num?)?.toInt(),
              suffix: 'new',
            ),
      'product_id': product.id,
      'seller_product_id': product.id,
      'linked_product_id': product.id,
      'linked_product_ids': <String>[product.id],
      'product_name': product.name,
      'quantity': safeQuantity,
      ...selectionSnapshot,
      'service_round': normalizedServiceRound,
      'note': note.trim(),
      'attributes': attributes
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList(growable: false),
      'station_id': product.stationId,
      'printer_routing_enabled': product.printerRoutingEnabled,
    };
  }

  static Map<String, dynamic> buildOrderItemFromTemplateProduct(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
    List<Map<String, dynamic>>? overriddenChildItems,
    bool preselectTemplateItems = true,
    String? forcedPricingMode,
    double? manualPrice,
  }) {
    final config = templateConfigFromProduct(product);
    final templateProductType = productTypeFromProduct(product);
    final templateItems =
        overriddenChildItems ??
        (preselectTemplateItems
            ? childItemsFromTemplateProduct(
                product,
                availableProducts: availableProducts,
              )
            : const <Map<String, dynamic>>[]);
    final resolvedPricingMode = _normalizePricingMode(
      forcedPricingMode ?? config?['pricing_mode']?.toString(),
      fallback: autoSumPriceMode,
    );
    final pricingMode = resolvedPricingMode == manualPriceMode
        ? manualPriceMode
        : normalizeTemplatePricingMode(resolvedPricingMode);
    final fixedPrice = parsePrice(config?['fixed_price']);
    final total = resolveMainItemTotal(<String, dynamic>{
      'pricing_mode': pricingMode,
      'fixed_price': fixedPrice,
      'manual_price': manualPrice,
      'child_items': templateItems,
    });
    final stationIds = templateItems
        .map((item) => item['station_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final printerRoutingEnabled = templateItems.isEmpty
        ? product.printerRoutingEnabled
        : !templateItems.any(
            (item) => item['printer_routing_enabled'] == false,
          );
    return normalizeOrderItem(<String, dynamic>{
      'item_type': itemType,
      'product_id': product.id,
      'source_template_id': product.id,
      'source_product_type': templateProductType,
      'product_type': templateProductType,
      'name': product.name,
      'item_name': product.name,
      'price': total,
      'total_price': total,
      'line_total': total,
      'quantity': 1,
      'notes': '',
      'note': '',
      'pricing_mode': pricingMode,
      'fixed_price': fixedPrice,
      'manual_price': manualPrice,
      'manual_price_allowed':
          config?['manual_price_allowed'] == true ||
          pricingMode == manualAllowedPriceMode,
      'child_items': templateItems,
      'station_id': stationIds.length == 1
          ? stationIds.first
          : product.stationId,
      'printer_routing_enabled': printerRoutingEnabled,
      'attributes': const <String>[],
    });
  }

  static List<Map<String, dynamic>> childItemsFromTemplateProduct(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    final config = templateConfigFromProduct(product);
    return (config == null)
        ? const <Map<String, dynamic>>[]
        : templateConfigToChildItems(
            config['template_items'],
            availableProducts: availableProducts,
          );
  }

  static List<SellerProduct> selectableProductsForTemplate(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    return _templateResolutionForProduct(
      product,
      availableProducts: availableProducts,
    ).selectableProducts;
  }

  static List<Map<String, dynamic>> templateConfigToChildItems(
    dynamic raw, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    final matches = _resolveTemplateItemMatches(
      normalizeTemplateItems(raw),
      availableProducts: availableProducts,
    );
    return matches
        .map((resolved) {
          final item = resolved.item;
          final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
          final productId = item['product_id']?.toString() ?? '';
          final currentProduct = resolved.product;
          final selectedServiceAmount =
              (item['selected_portion_value'] as num?)?.toDouble() ??
              (item['selected_service_amount'] as num?)?.toDouble() ??
              (item['selectedServiceAmount'] as num?)?.toDouble();
          final selectedWeightGrams =
              (item['selected_weight_grams'] as num?)?.toInt() ??
              (item['selectedWeightGrams'] as num?)?.toInt();
          final safeQuantity = _safeQuantity(quantity);
          final unitPrice = currentProduct == null
              ? parsePrice(item['unit_price_snapshot'])
              : parsePrice(
                  childSelectionSnapshotForProduct(
                    currentProduct,
                    quantity: safeQuantity,
                    selectedServiceAmount: selectedServiceAmount,
                    selectedWeightGrams: selectedWeightGrams,
                  )['unit_price'],
                );
          final optionLabel = currentProduct == null
              ? _storedChildOptionLabel(
                  item,
                  selectedServiceAmount: selectedServiceAmount,
                  selectedWeightGrams: selectedWeightGrams,
                )
              : childSelectionSnapshotForProduct(
                      currentProduct,
                      quantity: safeQuantity,
                      selectedServiceAmount: selectedServiceAmount,
                      selectedWeightGrams: selectedWeightGrams,
                    )['selected_option_label']?.toString() ??
                    '';
          return <String, dynamic>{
            childLocalRowIdKey: normalizeChildLocalRowId(
              item,
              fallbackProductId: productId,
            ),
            'product_id': productId,
            'seller_product_id':
                item['seller_product_id']?.toString() ??
                item['sellerProductId']?.toString() ??
                productId,
            'linked_product_id':
                item['linked_product_id']?.toString() ??
                item['linkedProductId']?.toString() ??
                item['seller_product_id']?.toString() ??
                productId,
            'product_name':
                currentProduct?.name ?? item['product_name']?.toString() ?? '-',
            'quantity': safeQuantity,
            'selected_pricing_type':
                item['selected_pricing_type']?.toString() ??
                item['selectedPricingType']?.toString() ??
                (currentProduct == null
                    ? ((selectedWeightGrams ?? 0) > 0 ? 'kg' : 'portion')
                    : productSelectedPricingTypeForSelection(
                        currentProduct,
                        selectedServiceAmount: selectedServiceAmount,
                        selectedWeightGrams: selectedWeightGrams,
                      )),
            'selected_portion_value': selectedServiceAmount,
            'unit_price': unitPrice,
            'line_total': childItemLineTotal(
              unitPrice: unitPrice,
              quantity: safeQuantity,
            ),
            'service_control_type':
                currentProduct?.resolvedServiceControlType.storageValue ??
                item['service_control_type']?.toString() ??
                item['serviceControlType']?.toString(),
            'selected_service_amount': selectedServiceAmount,
            'selected_weight_grams': selectedWeightGrams,
            'selected_option_label': optionLabel,
            'amount_label': optionLabel,
            'service_round': normalizeServiceRound(item['service_round']),
            'note': item['note']?.toString() ?? '',
            'station_id':
                currentProduct?.stationId ??
                item['station_id']?.toString() ??
                item['stationId']?.toString(),
            'printer_routing_enabled':
                currentProduct?.printerRoutingEnabled ??
                item['printer_routing_enabled'] != false,
            if (_linkedIdsForTemplateItem(item).isNotEmpty)
              'linked_product_ids': _linkedIdsForTemplateItem(item),
          };
        })
        .toList(growable: false);
  }

  static MixedServiceTemplateResolution inspectTemplateSelectableProducts(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
    String? debugContext,
  }) {
    final candidateProducts = (availableProducts ?? const <SellerProduct>[])
        .where((candidate) => !isTemplateProduct(candidate))
        .toList(growable: false);
    debugPrint(
      '[SERVICE_RESOLVE_START] '
      'context=${(debugContext ?? '').trim().isEmpty ? '-' : debugContext!.trim()} '
      'serviceId=${product.id} '
      'serviceName="${product.name}" '
      'availableProducts=${candidateProducts.length}',
    );
    final resolution = _templateResolutionForProduct(
      product,
      availableProducts: candidateProducts,
    );
    final contextLabel = (debugContext ?? '').trim().isEmpty
        ? '-'
        : debugContext!.trim();
    debugPrint(
      '[SERVICE_FILTER_STAGE] context=$contextLabel stage=after_match '
      'count=${resolution.matchedSelectableProductsCount}',
    );
    debugPrint(
      '[SERVICE_FILTER_STAGE] context=$contextLabel stage=before_active_filter '
      'count=${resolution.matchedSelectableProductsCount}',
    );
    debugPrint(
      '[SERVICE_FILTER_STAGE] context=$contextLabel stage=after_active_filter '
      'count=${resolution.activeMatchedProductsCount}',
    );
    debugPrint(
      '[SERVICE_FILTER_STAGE] context=$contextLabel stage=after_stock_filter '
      'count=${resolution.selectableProducts.length}',
    );
    debugPrint(
      '[SERVICE_TEMPLATE_INPUT] context=$contextLabel '
      'serviceProductId=${product.id} '
      'serviceProductName="${product.name}" '
      'templateItemsCount=${resolution.templateItemsCount} '
      'linkedIds=${resolution.linkedIds} '
      'matchedSelectableProductsCount=${resolution.matchedSelectableProductsCount} '
      'activeProductsCount=${resolution.activeMatchedProductsCount} '
      'filteredOutProductsCount=${resolution.filteredOutProductsCount}',
    );
    for (final resolved in _resolveTemplateItemMatches(
      resolution.templateItems,
      availableProducts: candidateProducts,
    )) {
      if (resolved.product != null) continue;
      debugPrint(
        '[SERVICE_MATCH_MISS] context=$contextLabel '
        'service=${product.id}:${product.name} '
        'templateItem=${_templateItemDebugLabel(resolved.item)} '
        'reason=${resolved.missReason ?? 'unknown'}',
      );
    }
    return resolution;
  }

  static double templatePreviewPriceFromProduct(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    final config = templateConfigFromProduct(product);
    if (config == null) return product.price;
    final pricingMode = normalizeTemplatePricingMode(
      config['pricing_mode']?.toString(),
    );
    final childItems = templateConfigToChildItems(
      config['template_items'],
      availableProducts: availableProducts,
    );
    return resolveMainItemTotal(<String, dynamic>{
      'pricing_mode': pricingMode,
      'fixed_price': config['fixed_price'],
      'child_items': childItems,
    });
  }

  static String templatePricingLabel(SellerProduct product) {
    final config = templateConfigFromProduct(product);
    final pricingMode = normalizeTemplatePricingMode(
      config?['pricing_mode']?.toString(),
    );
    switch (pricingMode) {
      case manualAllowedPriceMode:
        return 'Manuel Fiyat Izinli';
      case autoSumPriceMode:
      default:
        return 'Otomatik Toplam';
    }
  }

  static String normalizeTemplatePricingMode(String? raw) {
    final value = _normalizePricingMode(raw, fallback: autoSumPriceMode);
    if (value == manualAllowedPriceMode) {
      return manualAllowedPriceMode;
    }
    return autoSumPriceMode;
  }

  static Map<String, SellerProduct> _productIndexById(
    Iterable<SellerProduct>? availableProducts,
  ) {
    if (availableProducts == null) {
      return const <String, SellerProduct>{};
    }
    final index = <String, SellerProduct>{};
    for (final product in availableProducts) {
      if (isTemplateProduct(product)) continue;
      index[product.id] = product;
    }
    return index;
  }

  static MixedServiceTemplateResolution _templateResolutionForProduct(
    SellerProduct product, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    final config = templateConfigFromProduct(product);
    final templateItems = (config == null)
        ? const <Map<String, dynamic>>[]
        : normalizeTemplateItems(config['template_items']);
    final matches = _resolveTemplateItemMatches(
      templateItems,
      availableProducts: availableProducts,
    );
    final seenIds = <String>{};
    final matchedProducts = <SellerProduct>[];
    for (final resolved in matches) {
      final matchedProduct = resolved.product;
      if (matchedProduct == null) continue;
      if (!seenIds.add(matchedProduct.id)) continue;
      matchedProducts.add(matchedProduct);
    }
    final activeMatchedProducts = matchedProducts
        .where(_isSelectableProductActive)
        .toList(growable: false);
    final selectableProducts = activeMatchedProducts
        .where((product) => product.stock > 0)
        .toList(growable: false);
    final linkedIds = templateItems
        .expand(_linkedIdsForTemplateItem)
        .toSet()
        .toList(growable: false);
    return MixedServiceTemplateResolution(
      serviceProductId: product.id,
      serviceProductName: product.name,
      templateItems: templateItems,
      linkedIds: linkedIds,
      matchedProducts: matchedProducts,
      activeMatchedProducts: activeMatchedProducts,
      selectableProducts: selectableProducts,
    );
  }

  static List<_ResolvedTemplateItemMatch> _resolveTemplateItemMatches(
    List<Map<String, dynamic>> templateItems, {
    Iterable<SellerProduct>? availableProducts,
  }) {
    final candidates = (availableProducts ?? const <SellerProduct>[])
        .where((product) => !isTemplateProduct(product))
        .toList(growable: false);
    final productIndex = _productIndexById(candidates);
    return templateItems
        .map(
          (item) => _resolveTemplateItemMatch(item, candidates, productIndex),
        )
        .toList(growable: false);
  }

  static _ResolvedTemplateItemMatch _resolveTemplateItemMatch(
    Map<String, dynamic> item,
    List<SellerProduct> candidates,
    Map<String, SellerProduct> productIndex,
  ) {
    final linkedIds = _linkedIdsForTemplateItem(item);
    for (final linkedId in linkedIds) {
      final matched = productIndex[linkedId];
      if (matched != null) {
        return _ResolvedTemplateItemMatch(
          item: item,
          product: matched,
          matchSource: 'id:$linkedId',
          missReason: null,
        );
      }
    }

    final templateItemName = _templateItemName(item);
    if (templateItemName.isNotEmpty) {
      for (final product in candidates) {
        if (product.name.trim() == templateItemName) {
          return _ResolvedTemplateItemMatch(
            item: item,
            product: product,
            matchSource: 'exact_name',
            missReason: null,
          );
        }
      }

      final normalizedTemplateName = _normalizedComparableName(
        templateItemName,
      );
      if (normalizedTemplateName.isNotEmpty) {
        for (final product in candidates) {
          if (_normalizedComparableName(product.name) ==
              normalizedTemplateName) {
            return _ResolvedTemplateItemMatch(
              item: item,
              product: product,
              matchSource: 'normalized_name',
              missReason: null,
            );
          }
        }
      }
    }

    return _ResolvedTemplateItemMatch(
      item: item,
      product: null,
      matchSource: null,
      missReason: linkedIds.isEmpty && templateItemName.isEmpty
          ? 'missing_product_id_and_name'
          : linkedIds.isNotEmpty && templateItemName.isNotEmpty
          ? 'no_match_for_ids_or_name'
          : linkedIds.isNotEmpty
          ? 'no_match_for_linked_ids'
          : 'no_match_for_name',
    );
  }

  static bool _isSelectableProductActive(SellerProduct product) {
    final normalizedStatus = product.status
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    if (normalizedStatus.isEmpty) return true;
    if (normalizedStatus == 'aktif' || normalizedStatus == 'active') {
      return true;
    }
    return normalizedStatus != 'pasif' &&
        normalizedStatus != 'inactive' &&
        normalizedStatus != 'draft' &&
        normalizedStatus != 'taslak' &&
        normalizedStatus != 'rejected' &&
        normalizedStatus != 'reddedildi' &&
        normalizedStatus != 'pending' &&
        normalizedStatus != 'pending_approval' &&
        normalizedStatus != 'beklemede' &&
        normalizedStatus != 'bekleniyor';
  }

  static List<String> _linkedIdsForTemplateItem(Map<String, dynamic> item) {
    final ids = <String>[];

    void addId(Object? raw) {
      final value = raw?.toString().trim() ?? '';
      if (value.isEmpty || ids.contains(value)) return;
      ids.add(value);
    }

    addId(item['product_id']);
    addId(item['productId']);
    addId(item['seller_product_id']);
    addId(item['sellerProductId']);
    addId(item['linked_product_id']);
    addId(item['linkedProductId']);

    void addDynamicList(dynamic raw) {
      if (raw is! List) return;
      for (final entry in raw) {
        if (entry is Map) {
          addId(entry['id']);
          addId(entry['product_id']);
          addId(entry['linked_product_id']);
          continue;
        }
        addId(entry);
      }
    }

    addDynamicList(item['linked_product_ids']);
    addDynamicList(item['linkedProductIds']);
    addDynamicList(item['linked_ids']);
    addDynamicList(item['linked_products']);
    return ids;
  }

  static String _templateItemName(Map<String, dynamic> item) {
    return item['product_name']?.toString().trim() ??
        item['name']?.toString().trim() ??
        '';
  }

  static String _normalizedComparableName(String raw) {
    return raw.trim().toLowerCase();
  }

  static String _templateItemDebugLabel(Map<String, dynamic> item) {
    return [
      'product_id=${item['product_id'] ?? item['productId'] ?? '-'}',
      'seller_product_id=${item['seller_product_id'] ?? item['sellerProductId'] ?? '-'}',
      'linked_product_id=${item['linked_product_id'] ?? item['linkedProductId'] ?? '-'}',
      'name="${_templateItemName(item)}"',
    ].join(' ');
  }

  static Map<String, dynamic>? _templateMetadataFromSpecifications(
    dynamic specifications,
  ) {
    final metadata = _metadataEnvelope(specifications);
    if (metadata.isEmpty) return null;
    return metadata;
  }

  static Map<String, dynamic> _metadataEnvelope(dynamic specifications) {
    if (specifications == null) return <String, dynamic>{};
    dynamic decoded = specifications;
    if (decoded is String) {
      final trimmed = decoded.trim();
      if (trimmed.isEmpty) return <String, dynamic>{};
      try {
        decoded = jsonDecode(trimmed);
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    if (decoded is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(decoded);
  }

  static int? _coalescedGramsFromItem(Map<String, dynamic> item) {
    final grams = (item['selected_grams'] as num?)?.toInt() ??
        (item['selectedGrams'] as num?)?.toInt() ??
        (item['selected_weight_grams'] as num?)?.toInt() ??
        (item['selectedWeightGrams'] as num?)?.toInt();
    return grams != null && grams > 0 ? grams : null;
  }

  static String _normalizePricingMode(String? raw, {required String fallback}) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == fixedPriceMode ||
        value == autoSumPriceMode ||
        value == manualPriceMode ||
        value == manualAllowedPriceMode) {
      return value;
    }
    if (value == 'portion' || value == 'size') {
      return value;
    }
    if (value == 'kilo' || value == 'weight') {
      return 'kilo';
    }
    return fallback;
  }

  static int _safeQuantity(int? quantity) {
    if (quantity == null || quantity <= 0) return 1;
    return quantity;
  }

  static String normalizeChildLocalRowId(
    Map<String, dynamic> item, {
    String? fallbackProductId,
    int? fallbackIndex,
  }) {
    final candidates = <String?>[
      item[childLocalRowIdKey]?.toString(),
      item['child_item_local_id']?.toString(),
      item['child_item_id']?.toString(),
      item['row_id']?.toString(),
      item['localKey']?.toString(),
    ];
    for (final candidate in candidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    final serviceRound = normalizeServiceRound(item['service_round']);
    final selectedPricingType =
        item['selected_pricing_type']?.toString() ??
        item['selectedPricingType']?.toString();
    final selectedPortionValue =
        (item['selected_portion_value'] as num?)?.toDouble() ??
        (item['selected_service_amount'] as num?)?.toDouble() ??
        (item['selectedServiceAmount'] as num?)?.toDouble();
    final selectedWeightGrams =
        (item['selected_weight_grams'] as num?)?.toInt() ??
        (item['selectedWeightGrams'] as num?)?.toInt();
    return buildChildLocalRowId(
      productId:
          fallbackProductId ??
          item['product_id']?.toString() ??
          item['productId']?.toString() ??
          'child',
      serviceRound: serviceRound,
      selectedPricingType: selectedPricingType,
      selectedPortionValue: selectedPortionValue,
      selectedWeightGrams: selectedWeightGrams,
      suffix: '${fallbackIndex ?? 0}',
    );
  }

  static String buildChildLocalRowId({
    required String productId,
    required int serviceRound,
    String? selectedPricingType,
    double? selectedPortionValue,
    int? selectedWeightGrams,
    String? suffix,
  }) {
    final safeProductId = _slugifyRowIdPart(productId);
    final safePricingType = _slugifyRowIdPart(selectedPricingType ?? 'std');
    final portionPart = selectedPortionValue == null
        ? 'na'
        : _slugifyRowIdPart(selectedPortionValue.toString());
    final weightPart = selectedWeightGrams?.toString() ?? 'na';
    final suffixPart = _slugifyRowIdPart(suffix ?? '0');
    return 'ms_${safeProductId}_r${serviceRound}_${safePricingType}_p${portionPart}_g${weightPart}_$suffixPart';
  }

  static String _storedChildOptionLabel(
    Map<String, dynamic> item, {
    double? selectedServiceAmount,
    int? selectedWeightGrams,
  }) {
    final explicitCandidates = <String?>[
      item['selected_option_label']?.toString(),
      item['selectedOptionLabel']?.toString(),
      item['amount_label']?.toString(),
      item['amountLabel']?.toString(),
      item['gramaj']?.toString(),
    ];
    for (final candidate in explicitCandidates) {
      final normalized = candidate?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    final serviceControlType = ProductServiceControlType.fromValue(
      item['service_control_type'] ?? item['serviceControlType'],
    );
    if (serviceControlType != ProductServiceControlType.none) {
      return ProductPriceCalculator.formatServiceAmountLabel(
        type: serviceControlType,
        amount: selectedServiceAmount,
        grams: selectedWeightGrams,
      );
    }
    if ((selectedWeightGrams ?? 0) > 0) {
      return ProductPriceCalculator.formatServiceAmountLabel(
        type: ProductServiceControlType.weightStepper,
        grams: selectedWeightGrams,
      );
    }
    if ((selectedServiceAmount ?? 0) > 0) {
      return ProductPriceCalculator.formatPortionLabel(
        selectedServiceAmount ?? 0,
      );
    }
    return '';
  }

  static String _slugifyRowIdPart(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('.', '_');
    final cleaned = normalized.replaceAll(RegExp(r'[^a-z0-9_]+'), '_');
    final collapsed = cleaned.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '').isEmpty
        ? 'x'
        : collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }
}
