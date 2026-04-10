import 'package:image_picker/image_picker.dart';

import '../../../models/seller_product.dart';

class ProductQuickEditDraft {
  ProductQuickEditDraft({
    required this.originalProduct,
    required this.name,
    required this.priceText,
    required this.stockText,
    required this.status,
    required this.statusOptions,
    this.imageUrl,
    this.selectedImageFile,
    this.isSaving = false,
    this.errorMessage,
    this.successMessage,
  });

  static const Object _sentinel = Object();
  static const List<String> defaultStatusOptions = <String>[
    'Aktif',
    'Pasif',
    'Taslak',
  ];

  final SellerProduct originalProduct;
  final String name;
  final String priceText;
  final String stockText;
  final String status;
  final List<String> statusOptions;
  final String? imageUrl;
  final XFile? selectedImageFile;
  final bool isSaving;
  final String? errorMessage;
  final String? successMessage;

  String get productId => originalProduct.id;

  String get trimmedName => name.trim();

  double? get parsedPrice => _parsePrice(priceText);

  int? get parsedStock => int.tryParse(stockText.trim());

  String get storageStatus => storageStatusFromLabel(status);

  String? get previewImageUrl {
    final directUrl = imageUrl?.trim() ?? '';
    if (directUrl.isNotEmpty) return directUrl;
    if (originalProduct.imageUrls.isNotEmpty) {
      return originalProduct.imageUrls.first.trim();
    }
    final originalUrl = originalProduct.imageUrl?.trim() ?? '';
    return originalUrl.isEmpty ? null : originalUrl;
  }

  bool get hasPendingImageSelection => selectedImageFile != null;

  bool get hasPersistableChanges {
    final originalStatus = normalizeStatusLabel(originalProduct.status);
    return trimmedName != originalProduct.name.trim() ||
        parsedPrice != originalProduct.price ||
        parsedStock != originalProduct.stock ||
        normalizeStatusLabel(status) != originalStatus;
  }

  bool get isDirty {
    return hasPersistableChanges || hasPendingImageSelection;
  }

  String? get validationError {
    if (trimmedName.isEmpty) {
      return 'Ürün adı boş bırakılamaz.';
    }
    final price = parsedPrice;
    if (price == null || price <= 0) {
      return 'Geçerli bir fiyat girin.';
    }
    final stock = parsedStock;
    if (stock == null || stock < 0) {
      return 'Geçerli bir stok girin.';
    }
    return null;
  }

  ProductQuickEditDraft copyWith({
    SellerProduct? originalProduct,
    String? name,
    String? priceText,
    String? stockText,
    String? status,
    List<String>? statusOptions,
    Object? imageUrl = _sentinel,
    Object? selectedImageFile = _sentinel,
    bool? isSaving,
    Object? errorMessage = _sentinel,
    Object? successMessage = _sentinel,
  }) {
    return ProductQuickEditDraft(
      originalProduct: originalProduct ?? this.originalProduct,
      name: name ?? this.name,
      priceText: priceText ?? this.priceText,
      stockText: stockText ?? this.stockText,
      status: status ?? this.status,
      statusOptions: statusOptions ?? this.statusOptions,
      imageUrl: identical(imageUrl, _sentinel)
          ? this.imageUrl
          : imageUrl as String?,
      selectedImageFile: identical(selectedImageFile, _sentinel)
          ? this.selectedImageFile
          : selectedImageFile as XFile?,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      successMessage: identical(successMessage, _sentinel)
          ? this.successMessage
          : successMessage as String?,
    );
  }

  factory ProductQuickEditDraft.fromProduct(SellerProduct product) {
    final normalizedStatus = normalizeStatusLabel(product.status);
    final statusOptions = <String>[
      ...defaultStatusOptions,
      if (!defaultStatusOptions.contains(normalizedStatus)) normalizedStatus,
    ];
    return ProductQuickEditDraft(
      originalProduct: product,
      name: product.name,
      priceText: _formatEditablePrice(product.price),
      stockText: product.stock.toString(),
      status: normalizedStatus,
      statusOptions: statusOptions,
      imageUrl: product.imageUrl,
    );
  }

  static String normalizeStatusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'active':
      case 'aktif':
        return 'Aktif';
      case 'inactive':
      case 'pasif':
        return 'Pasif';
      case 'draft':
      case 'taslak':
        return 'Taslak';
      case 'pending':
      case 'pending_approval':
      case 'bekleniyor':
        return 'Bekleniyor';
      case 'rejected':
      case 'reddedildi':
        return 'Reddedildi';
      default:
        final trimmed = status.trim();
        return trimmed.isEmpty ? 'Taslak' : trimmed;
    }
  }

  static String storageStatusFromLabel(String label) {
    switch (normalizeStatusLabel(label)) {
      case 'Aktif':
        return 'Aktif';
      case 'Pasif':
        return 'Pasif';
      case 'Taslak':
        return 'Taslak';
      case 'Bekleniyor':
        return 'pending_approval';
      case 'Reddedildi':
        return 'rejected';
      default:
        return label.trim();
    }
  }

  static String _formatEditablePrice(double price) {
    final hasFraction = price != price.truncateToDouble();
    if (!hasFraction) {
      return price.toStringAsFixed(0);
    }
    return price
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  static double? _parsePrice(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    var normalized = trimmed.replaceAll(' ', '');
    if (normalized.contains(',') && normalized.contains('.')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    } else if (normalized.contains(',')) {
      normalized = normalized.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }
}
