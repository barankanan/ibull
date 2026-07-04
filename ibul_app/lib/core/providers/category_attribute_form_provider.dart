import 'package:flutter/foundation.dart';

import '../../models/category_attribute_definition.dart';
import '../../services/category_attribute_service.dart';

class CategoryAttributeFormProvider extends ChangeNotifier {
  CategoryAttributeFormProvider({CategoryAttributeService? service})
    : _service = service ?? CategoryAttributeService.instance;

  final CategoryAttributeService _service;

  bool _isLoading = false;
  String? _errorMessage;
  String? _mainCategory;
  String? _subCategory;
  List<CategoryAttributeDefinition> _definitions =
      const <CategoryAttributeDefinition>[];
  Map<String, String> _valuesByAttributeId = <String, String>{};
  List<Map<String, String>> _customAttributeRows = <Map<String, String>>[];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CategoryAttributeDefinition> get definitions => _definitions;
  Map<String, String> get valuesByAttributeId => _valuesByAttributeId;
  List<Map<String, String>> get customAttributeRows =>
      List<Map<String, String>>.unmodifiable(_customAttributeRows);
  bool get hasDefinitions => _definitions.isNotEmpty;

  Future<void> loadForCategory({
    required String mainCategory,
    required String subCategory,
    Map<String, String> initialValues = const <String, String>{},
    bool forceRefresh = false,
  }) async {
    final normalizedMain = mainCategory.trim();
    final normalizedSub = subCategory.trim();

    if (!forceRefresh &&
        normalizedMain == _mainCategory &&
        normalizedSub == _subCategory &&
        _definitions.isNotEmpty) {
      if (initialValues.isNotEmpty) {
        _applyInitialValues(initialValues);
      }
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _mainCategory = normalizedMain;
    _subCategory = normalizedSub;
    notifyListeners();

    try {
      final loadedDefinitions = await _service.getAttributesForCategory(
        mainCategory: normalizedMain,
        subCategory: normalizedSub,
        forceRefresh: forceRefresh,
      );
      _definitions = loadedDefinitions;
      _valuesByAttributeId = <String, String>{};
      _customAttributeRows = <Map<String, String>>[];
      _applyInitialValues(initialValues);
    } catch (error) {
      _definitions = const <CategoryAttributeDefinition>[];
      _valuesByAttributeId = <String, String>{};
      _customAttributeRows = <Map<String, String>>[];
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _errorMessage = null;
    _mainCategory = null;
    _subCategory = null;
    _definitions = const <CategoryAttributeDefinition>[];
    _valuesByAttributeId = <String, String>{};
    _customAttributeRows = <Map<String, String>>[];
    _isLoading = false;
    notifyListeners();
  }

  void setValue(String attributeId, String value, {bool notify = false}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _valuesByAttributeId.remove(attributeId);
    } else {
      _valuesByAttributeId[attributeId] = value;
    }
    if (notify) {
      notifyListeners();
    }
  }

  void addCustomAttributeRow() {
    _customAttributeRows.add(<String, String>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'key': '',
      'value': '',
    });
    notifyListeners();
  }

  void removeCustomAttributeRow(int index) {
    if (index < 0 || index >= _customAttributeRows.length) return;
    _customAttributeRows.removeAt(index);
    notifyListeners();
  }

  void setCustomAttributeKey(int index, String key) {
    if (index < 0 || index >= _customAttributeRows.length) return;
    _customAttributeRows[index]['key'] = key;
  }

  void setCustomAttributeValue(int index, String value) {
    if (index < 0 || index >= _customAttributeRows.length) return;
    _customAttributeRows[index]['value'] = value;
  }

  Map<String, String> valuesByName() {
    final values = <String, String>{};
    for (final definition in _definitions) {
      final value = (_valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      values[definition.name] = value;
    }
    _mergeCustomRowsInto(values);
    return values;
  }

  List<String> attributeLines() {
    final lines = <String>[];
    for (final definition in _definitions) {
      final value = (_valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      lines.add('${definition.name}: $value');
    }

    final usedKeys = _definitions
        .map((definition) => definition.name.trim().toLowerCase())
        .toSet();
    for (final row in _customAttributeRows) {
      final key = (row['key'] ?? '').trim();
      final value = (row['value'] ?? '').trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (usedKeys.contains(key.toLowerCase())) continue;
      lines.add('$key: $value');
    }
    return lines;
  }

  static bool isPlaceholderValue(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'none' ||
        normalized == 'n/a' ||
        normalized == '-';
  }

  void _applyInitialValues(Map<String, String> initialValues) {
    if (_definitions.isEmpty) return;

    _valuesByAttributeId = <String, String>{};
    _customAttributeRows = <Map<String, String>>[];
    if (initialValues.isEmpty) return;

    final definitionNames = <String, CategoryAttributeDefinition>{};
    for (final definition in _definitions) {
      definitionNames[definition.name.trim().toLowerCase()] = definition;
    }

    for (final entry in initialValues.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty || isPlaceholderValue(value)) continue;

      final definition = definitionNames[key.toLowerCase()];
      if (definition != null) {
        _valuesByAttributeId[definition.id] = value;
        continue;
      }
      _customAttributeRows.add(<String, String>{
        'id': '${key}_${value.hashCode}',
        'key': key,
        'value': value,
      });
    }
  }

  void _mergeCustomRowsInto(Map<String, String> values) {
    final usedKeys = _definitions
        .map((definition) => definition.name.trim().toLowerCase())
        .toSet();
    for (final row in _customAttributeRows) {
      final key = (row['key'] ?? '').trim();
      final value = (row['value'] ?? '').trim();
      if (key.isEmpty || value.isEmpty) continue;
      if (usedKeys.contains(key.toLowerCase())) continue;
      values.putIfAbsent(key, () => value);
    }
  }
}
