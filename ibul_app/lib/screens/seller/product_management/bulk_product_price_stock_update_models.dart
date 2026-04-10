import 'package:ibul_app/models/seller_product.dart';

const List<String> bulkProductPriceStockUpdateRequiredHeaders = <String>[
  'sku',
  'price',
  'stock',
];

const List<String> bulkProductPriceStockUpdateOptionalHeaders = <String>[
  'status',
];

const Map<String, String> bulkProductPriceStockUpdateHeaderAliases =
    <String, String>{
      'sku': 'sku',
      'stock_code': 'sku',
      'stockcode': 'sku',
      'product_sku': 'sku',
      'price': 'price',
      'fiyat': 'price',
      'stock': 'stock',
      'stok': 'stock',
      'status': 'status',
      'durum': 'status',
    };

const Map<String, String> bulkProductPriceStockUpdateAllowedStatuses =
    <String, String>{
      'aktif': 'Aktif',
      'active': 'Aktif',
      'pasif': 'Pasif',
      'inactive': 'Pasif',
      'passive': 'Pasif',
      'disabled': 'Pasif',
      'beklemede': 'pending_approval',
      'bekleniyor': 'pending_approval',
      'pending approval': 'pending_approval',
      'pending_approval': 'pending_approval',
      'pending-approval': 'pending_approval',
      'pending': 'pending_approval',
      'taslak': 'Taslak',
      'draft': 'Taslak',
      'reddedildi': 'rejected',
      'rejected': 'rejected',
    };

const String bulkProductPriceStockUpdateTemplateCsv =
    'sku,price,stock,status\n'
    'SKU-001,1650,980,Aktif\n'
    'SKU-002,95,40,Beklemede\n'
    'SKU-003,270,12,Aktif\n';

String normalizeBulkProductPriceStockHeader(String rawHeader) {
  final String trimmed = rawHeader.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final String normalizedKey = trimmed.toLowerCase();
  return bulkProductPriceStockUpdateHeaderAliases[normalizedKey] ??
      normalizedKey;
}

String normalizeBulkProductSku(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

String _normalizeBulkProductStatusKey(String? value) {
  final String trimmed = value?.trim().toLowerCase() ?? '';
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeBulkProductStoredStatus(String? value) {
  final String normalized = _normalizeBulkProductStatusKey(value);
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized == 'aktif' || normalized == 'active') {
    return 'Aktif';
  }
  if (normalized == 'pasif' ||
      normalized == 'inactive' ||
      normalized == 'passive' ||
      normalized == 'disabled') {
    return 'Pasif';
  }
  if (normalized == 'bekleniyor' ||
      normalized == 'beklemede' ||
      normalized == 'pending approval' ||
      normalized == 'pending') {
    return 'pending_approval';
  }
  if (normalized == 'taslak' || normalized == 'draft') {
    return 'Taslak';
  }
  if (normalized == 'rejected' || normalized == 'reddedildi') {
    return 'rejected';
  }
  return value?.trim() ?? '';
}

String? normalizeBulkProductCsvStatus(String? value) {
  final String normalized = _normalizeBulkProductStatusKey(value);
  if (normalized.isEmpty) {
    return null;
  }
  return bulkProductPriceStockUpdateAllowedStatuses[normalized];
}

String resolveBulkProductExpectedStatus({
  required String currentStatus,
  String? requestedStatus,
}) {
  return requestedStatus ?? normalizeBulkProductStoredStatus(currentStatus);
}

String bulkProductStatusLabel(String? value) {
  switch (normalizeBulkProductStoredStatus(value)) {
    case 'Aktif':
      return 'Aktif';
    case 'Pasif':
      return 'Pasif';
    case 'pending_approval':
      return 'Bekleniyor';
    case 'Taslak':
      return 'Taslak';
    case 'rejected':
      return 'Reddedildi';
    default:
      final String text = value?.trim() ?? '';
      return text.isEmpty ? '-' : text;
  }
}

enum BulkProductPriceStockUpdateRowState { updatable, invalid, unchanged }

class BulkProductPriceStockCsvDocument {
  const BulkProductPriceStockCsvDocument({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<Map<String, String>> rows;
}

class BulkProductPriceStockUpdatePlan {
  const BulkProductPriceStockUpdatePlan({
    required this.currentProduct,
    required this.newPrice,
    required this.newStock,
    required this.effectiveStatus,
    required this.statusToPersist,
    required this.priceChanged,
    required this.stockChanged,
    required this.statusChanged,
  });

  final SellerProduct currentProduct;
  final double newPrice;
  final int newStock;
  final String effectiveStatus;
  final String? statusToPersist;
  final bool priceChanged;
  final bool stockChanged;
  final bool statusChanged;
}

class BulkProductPriceStockPreviewRow {
  const BulkProductPriceStockPreviewRow({
    required this.rowNumber,
    required this.sku,
    required this.rawValues,
    required this.errors,
    required this.rowState,
    this.currentProduct,
    this.updatePlan,
  });

  final int rowNumber;
  final String sku;
  final Map<String, String> rawValues;
  final SellerProduct? currentProduct;
  final List<String> errors;
  final BulkProductPriceStockUpdateRowState rowState;
  final BulkProductPriceStockUpdatePlan? updatePlan;

  bool get isUpdatable =>
      rowState == BulkProductPriceStockUpdateRowState.updatable;

  bool get isInvalid => rowState == BulkProductPriceStockUpdateRowState.invalid;

  bool get isUnchanged =>
      rowState == BulkProductPriceStockUpdateRowState.unchanged;

  String get currentStatusLabel =>
      bulkProductStatusLabel(currentProduct?.status);

  String get newStatusLabel {
    if (updatePlan != null) {
      return bulkProductStatusLabel(updatePlan!.effectiveStatus);
    }
    final String rawStatus = rawValues['status']?.trim() ?? '';
    if (rawStatus.isNotEmpty &&
        normalizeBulkProductCsvStatus(rawStatus) == null) {
      return rawStatus;
    }
    if (currentProduct != null) {
      return bulkProductStatusLabel(currentProduct!.status);
    }
    return '-';
  }
}

class BulkProductPriceStockUpdatePreview {
  const BulkProductPriceStockUpdatePreview({
    required this.fileName,
    required this.headers,
    required this.rows,
    this.fileErrors = const <String>[],
  });

  final String fileName;
  final List<String> headers;
  final List<BulkProductPriceStockPreviewRow> rows;
  final List<String> fileErrors;

  int get totalRows => rows.length;

  int get updatableRowCount => rows
      .where((BulkProductPriceStockPreviewRow row) => row.isUpdatable)
      .length;

  int get invalidRowCount =>
      rows.where((BulkProductPriceStockPreviewRow row) => row.isInvalid).length;

  int get unchangedRowCount => rows
      .where((BulkProductPriceStockPreviewRow row) => row.isUnchanged)
      .length;

  bool get hasUpdatableRows => updatableRowCount > 0;
}

class BulkProductPriceStockUpdateFailure {
  const BulkProductPriceStockUpdateFailure({
    required this.rowNumber,
    required this.sku,
    required this.message,
  });

  final int rowNumber;
  final String sku;
  final String message;
}

class BulkProductPriceStockUpdateExecutionSummary {
  const BulkProductPriceStockUpdateExecutionSummary({
    required this.totalRows,
    required this.updatedRows,
    required this.invalidRows,
    required this.unchangedRows,
    required this.failedRows,
    this.failures = const <BulkProductPriceStockUpdateFailure>[],
  });

  final int totalRows;
  final int updatedRows;
  final int invalidRows;
  final int unchangedRows;
  final int failedRows;
  final List<BulkProductPriceStockUpdateFailure> failures;
}
