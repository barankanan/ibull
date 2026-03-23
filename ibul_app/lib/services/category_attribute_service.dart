import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_attribute_definition.dart';
import '../models/category_attribute_filter_group.dart';
import '../models/product_model.dart';

class CategoryAttributeService {
  CategoryAttributeService._();

  static final CategoryAttributeService instance = CategoryAttributeService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final Map<String, List<CategoryAttributeDefinition>> _definitionCache =
      <String, List<CategoryAttributeDefinition>>{};
  final Map<String, Map<String, String>> _productValueCache =
      <String, Map<String, String>>{};

  String buildCategoryId({
    required String mainCategory,
    required String subCategory,
  }) {
    return '${_normalizeKey(mainCategory)}::${_normalizeKey(subCategory)}';
  }

  String _normalizeKey(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('&', ' ve ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<List<CategoryAttributeDefinition>> getAttributesForCategory({
    required String mainCategory,
    required String subCategory,
    bool forceRefresh = false,
  }) async {
    final categoryId = buildCategoryId(
      mainCategory: mainCategory,
      subCategory: subCategory,
    );
    if (!forceRefresh && _definitionCache.containsKey(categoryId)) {
      return _definitionCache[categoryId]!;
    }

    final response = await _supabase
        .from('category_attributes')
        .select('id, category_id, name, type, filterable, options, sort_order')
        .eq('category_id', categoryId)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);

    final definitions = (response as List)
        .map(
          (row) => CategoryAttributeDefinition.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);

    _definitionCache[categoryId] = definitions;
    return definitions;
  }

  Future<Map<String, String>> getProductAttributeValues(
    String productId,
  ) async {
    if (_productValueCache.containsKey(productId)) {
      return _productValueCache[productId]!;
    }

    final response = await _supabase
        .from('product_attributes')
        .select('value, category_attributes!inner(name)')
        .eq('product_id', productId);

    final values = <String, String>{};
    for (final row in response as List) {
      final map = Map<String, dynamic>.from(row as Map);
      final attribute = Map<String, dynamic>.from(
        map['category_attributes'] as Map,
      );
      final name = (attribute['name'] ?? '').toString().trim();
      final value = (map['value'] ?? '').toString().trim();
      if (name.isEmpty || value.isEmpty) continue;
      values[name] = value;
    }
    _productValueCache[productId] = Map.unmodifiable(values);
    return _productValueCache[productId]!;
  }

  Future<void> saveProductAttributes({
    required String productId,
    required List<CategoryAttributeDefinition> definitions,
    required Map<String, String> valuesByAttributeId,
  }) async {
    await _supabase
        .from('product_attributes')
        .delete()
        .eq('product_id', productId);

    final rows = <Map<String, dynamic>>[];
    for (final definition in definitions) {
      final value = (valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      rows.add({
        'product_id': productId,
        'attribute_id': definition.id,
        'value': value,
      });
    }

    if (rows.isNotEmpty) {
      await _supabase.from('product_attributes').insert(rows);
    }

    final namedValues = <String, String>{};
    for (final definition in definitions) {
      final value = (valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      namedValues[definition.name] = value;
    }
    _productValueCache[productId] = Map.unmodifiable(namedValues);
  }

  void invalidateCategoryCache({
    required String mainCategory,
    required String subCategory,
  }) {
    _definitionCache.remove(
      buildCategoryId(mainCategory: mainCategory, subCategory: subCategory),
    );
  }

  void invalidateProductCache(String productId) {
    _productValueCache.remove(productId);
  }

  Future<List<CategoryAttributeFilterGroup>> buildFilterGroupsForProducts({
    required String mainCategory,
    required String subCategory,
    required List<Product> products,
  }) async {
    final definitions = await getAttributesForCategory(
      mainCategory: mainCategory,
      subCategory: subCategory,
    );
    final filterableDefinitions = definitions.where((item) => item.filterable);
    if (filterableDefinitions.isEmpty) return const [];

    final grouped = <String, Set<String>>{};
    for (final definition in filterableDefinitions) {
      grouped[definition.name] = <String>{};
    }

    for (final product in products) {
      final specMap = decodeProductSpecifications(product.specifications);
      if (specMap.isEmpty) continue;
      for (final definition in filterableDefinitions) {
        final value = (specMap[definition.name] ?? '').trim();
        if (value.isEmpty) continue;
        grouped[definition.name]!.add(value);
      }
    }

    return filterableDefinitions
        .map((definition) {
          final values = grouped[definition.name]!.toList()..sort();
          return CategoryAttributeFilterGroup(
            attributeName: definition.name,
            values: values,
          );
        })
        .where((group) => group.values.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, String> decodeProductSpecifications(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String, String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const <String, String>{};
      }
      final values = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) continue;
        values[key] = value;
      }
      return values;
    } catch (error, stackTrace) {
      debugPrint('Kategori attribute JSON parse hatasi: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const <String, String>{};
    }
  }
}
