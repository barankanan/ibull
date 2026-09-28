class StoreContractVersion {
  const StoreContractVersion({
    required this.contractId,
    required this.versionId,
    required this.title,
    required this.type,
    required this.version,
    this.bodyText,
    this.pdfBucket,
    this.pdfPath,
    this.isActive = true,
    this.updatedAt,
  });

  final String contractId;
  final String versionId;
  final String title;
  final String type;
  final int version;
  final String? bodyText;
  final String? pdfBucket;
  final String? pdfPath;
  final bool isActive;
  final DateTime? updatedAt;

  bool get isPdf => (pdfPath ?? '').trim().isNotEmpty;
  bool get isText => (bodyText ?? '').trim().isNotEmpty;

  factory StoreContractVersion.fromMap(Map<String, dynamic> map) {
    return StoreContractVersion(
      contractId: (map['contract_id'] ?? map['id'] ?? '').toString(),
      versionId: (map['version_id'] ?? map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      type: (map['contract_type'] ?? map['type'] ?? '').toString(),
      version: (map['version'] as num?)?.toInt() ?? 1,
      bodyText: map['body_text']?.toString(),
      pdfBucket: map['pdf_bucket']?.toString(),
      pdfPath: map['pdf_path']?.toString(),
      isActive: map['is_active'] != false,
      updatedAt: DateTime.tryParse(map['created_at']?.toString() ?? ''),
    );
  }
}

abstract final class StoreContractTypes {
  static const productSale = 'product_sale';
  static const vehicleRental = 'vehicle_rental';

  static const labels = <String, String>{
    productSale: 'Ürün Satış Sözleşmesi',
    vehicleRental: 'Araç Kiralama Sözleşmesi',
  };
}
