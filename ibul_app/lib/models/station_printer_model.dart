class StationPrinterModel {
  const StationPrinterModel({
    required this.id,
    required this.stationId,
    required this.printerId,
    required this.isPrimary,
    required this.createdAt,
    this.stationName,
    this.printerName,
    this.printerCode,
  });

  final String id;
  final String stationId;
  final String printerId;
  final bool isPrimary;
  final DateTime createdAt;
  final String? stationName;
  final String? printerName;
  final String? printerCode;

  factory StationPrinterModel.fromMap(Map<String, dynamic> map) {
    final station = map['stations'];
    final printer = map['printers'];
    return StationPrinterModel(
      id: map['id']?.toString() ?? '',
      stationId: map['station_id']?.toString() ?? '',
      printerId: map['printer_id']?.toString() ?? '',
      isPrimary: map['is_primary'] == true,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      stationName: station is Map ? station['name']?.toString() : null,
      printerName: printer is Map ? printer['name']?.toString() : null,
      printerCode: printer is Map ? printer['code']?.toString() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'station_id': stationId,
      'printer_id': printerId,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
      if (stationName != null) 'station_name': stationName,
      if (printerName != null) 'printer_name': printerName,
      if (printerCode != null) 'printer_code': printerCode,
    };
  }
}
