class PrinterModel {
  const PrinterModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.code,
    required this.connectionType,
    this.ipAddress,
    this.port,
    this.deviceIdentifier,
    required this.paperWidthMm,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String restaurantId;
  final String name;
  final String code;
  final String connectionType;
  final String? ipAddress;
  final int? port;
  final String? deviceIdentifier;
  final int paperWidthMm;
  final bool isActive;
  final DateTime createdAt;

  factory PrinterModel.fromMap(Map<String, dynamic> map) {
    return PrinterModel(
      id: map['id']?.toString() ?? '',
      restaurantId: map['restaurant_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      code: map['code']?.toString() ?? '',
      connectionType: map['connection_type']?.toString() ?? 'network',
      ipAddress: map['ip_address']?.toString(),
      port: (map['port'] as num?)?.toInt(),
      deviceIdentifier: map['device_identifier']?.toString(),
      paperWidthMm: (map['paper_width_mm'] as num?)?.toInt() ?? 80,
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
      'connection_type': connectionType,
      'ip_address': ipAddress,
      'port': port,
      'device_identifier': deviceIdentifier,
      'paper_width_mm': paperWidthMm,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PrinterModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? code,
    String? connectionType,
    String? ipAddress,
    int? port,
    String? deviceIdentifier,
    int? paperWidthMm,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return PrinterModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      code: code ?? this.code,
      connectionType: connectionType ?? this.connectionType,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      deviceIdentifier: deviceIdentifier ?? this.deviceIdentifier,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
