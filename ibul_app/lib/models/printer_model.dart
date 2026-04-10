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

  static const String localConnectionType = 'local';
  static const String networkConnectionType = 'network';
  static const String usbConnectionType = 'usb';
  static const String bluetoothConnectionType = 'bluetooth';
  static const String localDefaultHost = '127.0.0.1';
  static const int localDefaultPort = 3001;
  static const int defaultPaperWidthMm = 80;
  static const String localReceiptRoute = '/print/receipt';
  static const String localKitchenRoute = '/print/kitchen';

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

  String get _normalizedConnectionType => connectionType.trim().toLowerCase();

  String get _normalizedHost => ipAddress?.trim().toLowerCase() ?? '';

  bool get isLocalConnection {
    if (_normalizedConnectionType == localConnectionType) {
      return true;
    }
    if (_normalizedConnectionType != networkConnectionType &&
        _normalizedConnectionType.isNotEmpty) {
      return false;
    }
    final isLoopbackHost =
        _normalizedHost == localDefaultHost || _normalizedHost == 'localhost';
    return isLoopbackHost && (port ?? localDefaultPort) == localDefaultPort;
  }

  String get formConnectionType {
    if (isLocalConnection) {
      return localConnectionType;
    }
    if (_normalizedConnectionType.isEmpty) {
      return networkConnectionType;
    }
    return _normalizedConnectionType;
  }

  String get connectionTypeLabel {
    switch (formConnectionType) {
      case localConnectionType:
        return 'Local';
      case usbConnectionType:
        return 'USB';
      case bluetoothConnectionType:
        return 'Bluetooth';
      case networkConnectionType:
      default:
        return 'Network';
    }
  }

  String get logicalType {
    return formConnectionType;
  }

  String get resolvedHost {
    final host = ipAddress?.trim() ?? '';
    if (host.isNotEmpty) {
      return host;
    }
    return isLocalConnection ? localDefaultHost : '';
  }

  int? get resolvedPort {
    if (port != null && port! > 0) {
      return port;
    }
    if (isLocalConnection) {
      return localDefaultPort;
    }
    if (resolvedHost.isNotEmpty &&
        formConnectionType == networkConnectionType) {
      return 9100;
    }
    return null;
  }

  String get suggestedLocalRoute {
    final fingerprint =
        '${name.trim().toLowerCase()} ${code.trim().toLowerCase()}';
    final isKitchenRoute =
        fingerprint.contains('mutfak') || fingerprint.contains('kitchen');
    return isKitchenRoute ? localKitchenRoute : localReceiptRoute;
  }

  String get listSubtitle {
    final parts = <String>[connectionTypeLabel];
    if (isLocalConnection) {
      parts.add(targetHost);
      final route = targetRoute;
      if (route.isNotEmpty) {
        parts.add(route);
      }
      return parts.join(' • ');
    }

    final host = targetHost;
    if (host != '-') {
      parts.add(host);
    }
    final device = deviceIdentifier?.trim() ?? '';
    if (device.isNotEmpty) {
      parts.add(device);
    }
    return parts.join(' • ');
  }

  String get targetHost {
    final host = resolvedHost;
    final currentPort = resolvedPort;
    if (host.isEmpty) {
      return '-';
    }
    if (currentPort == null) {
      return host;
    }
    return '$host:$currentPort';
  }

  String get targetRoute {
    final normalizedConnection = connectionType.trim().toLowerCase();
    final candidate = deviceIdentifier?.trim() ?? '';
    if (candidate.startsWith('/')) {
      return candidate;
    }
    if (isLocalConnection || normalizedConnection == localConnectionType) {
      return suggestedLocalRoute;
    }
    return '';
  }

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
