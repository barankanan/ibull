class StationModel {
  const StationModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.code,
    this.color,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String name;
  final String code;
  final String? color;
  final bool isActive;
  final DateTime createdAt;

  factory StationModel.fromMap(Map<String, dynamic> map) {
    return StationModel(
      id: map['id']?.toString() ?? '',
      restaurantId: map['restaurant_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      color: map['color']?.toString(),
      isActive: map['is_active'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'name': name,
      'code': code,
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  StationModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? code,
    String? color,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return StationModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      code: code ?? this.code,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
