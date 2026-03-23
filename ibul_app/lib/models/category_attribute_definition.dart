enum CategoryAttributeInputType { text, number, select }

CategoryAttributeInputType categoryAttributeInputTypeFromString(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'number':
      return CategoryAttributeInputType.number;
    case 'select':
      return CategoryAttributeInputType.select;
    case 'text':
    default:
      return CategoryAttributeInputType.text;
  }
}

String categoryAttributeInputTypeToString(CategoryAttributeInputType type) {
  switch (type) {
    case CategoryAttributeInputType.number:
      return 'number';
    case CategoryAttributeInputType.select:
      return 'select';
    case CategoryAttributeInputType.text:
      return 'text';
  }
}

class CategoryAttributeDefinition {
  const CategoryAttributeDefinition({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.type,
    required this.filterable,
    this.options = const [],
    this.sortOrder = 0,
  });

  final String id;
  final String categoryId;
  final String name;
  final CategoryAttributeInputType type;
  final bool filterable;
  final List<String> options;
  final int sortOrder;

  bool get isSelect => type == CategoryAttributeInputType.select;
  bool get isNumber => type == CategoryAttributeInputType.number;

  factory CategoryAttributeDefinition.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final options = rawOptions is List
        ? rawOptions.map((item) => item.toString()).toList(growable: false)
        : const <String>[];

    return CategoryAttributeDefinition(
      id: map['id'].toString(),
      categoryId: (map['category_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      type: categoryAttributeInputTypeFromString(map['type']?.toString()),
      filterable: map['filterable'] == true,
      options: options,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'type': categoryAttributeInputTypeToString(type),
      'filterable': filterable,
      'options': options,
      'sort_order': sortOrder,
    };
  }
}
