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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<CategoryAttributeDefinition> get definitions => _definitions;
  Map<String, String> get valuesByAttributeId => _valuesByAttributeId;
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
      _applyInitialValues(initialValues);
    } catch (error) {
      _definitions = const <CategoryAttributeDefinition>[];
      _valuesByAttributeId = <String, String>{};
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

  Map<String, String> valuesByName() {
    final values = <String, String>{};
    for (final definition in _definitions) {
      final value = (_valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      values[definition.name] = value;
    }
    return values;
  }

  List<String> attributeLines() {
    final lines = <String>[];
    for (final definition in _definitions) {
      final value = (_valuesByAttributeId[definition.id] ?? '').trim();
      if (value.isEmpty) continue;
      lines.add('${definition.name}: $value');
    }
    return lines;
  }

  void _applyInitialValues(Map<String, String> initialValues) {
    if (_definitions.isEmpty || initialValues.isEmpty) return;
    final normalized = <String, String>{};
    initialValues.forEach((key, value) {
      final cleanKey = key.trim().toLowerCase();
      final cleanValue = value.trim();
      if (cleanKey.isEmpty || cleanValue.isEmpty) return;
      normalized[cleanKey] = cleanValue;
    });
    for (final definition in _definitions) {
      final match = normalized[definition.name.trim().toLowerCase()];
      if (match == null || match.isEmpty) continue;
      _valuesByAttributeId[definition.id] = match;
    }
  }
}
