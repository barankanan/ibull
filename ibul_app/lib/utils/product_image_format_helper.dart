import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Ürün görseli yükleme format ve boyut doğrulaması.
class ProductImageFormatHelper {
  ProductImageFormatHelper._();

  static const int recommendedSize = 1200;
  static const int minSize = 800;
  static const int maxSize = 3000;

  static const String avifUnsupportedMessage =
      'AVIF bu cihazda desteklenmiyor. Lütfen JPG, PNG veya WebP yükleyin.';
  static const String unsupportedFormatMessage =
      'Desteklenmeyen görsel formatı. Lütfen JPG, PNG veya WebP yükleyin.';
  static const String unreadableImageMessage =
      'Görsel okunamadı. Lütfen farklı bir dosya deneyin.';
  static const String lowResolutionMessage =
      'Bu görsel düşük çözünürlüklü. En az 800×800 px önerilir.';

  /// Dosya seçicide gösterilen uzantılar (AVIF dahil değil).
  static const List<String> pickerExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  static const List<String> supportedMimeTypes = <String>[
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
}

enum ProductImageInputFormat { jpeg, png, webp, avif, unknown }

class ProductImageInputValidation {
  const ProductImageInputValidation({
    required this.isValid,
    this.format,
    this.width,
    this.height,
    this.errorMessage,
    this.lowResolutionWarning,
  });

  final bool isValid;
  final ProductImageInputFormat? format;
  final int? width;
  final int? height;
  final String? errorMessage;
  final String? lowResolutionWarning;
}

ProductImageInputFormat detectProductImageFormat({
  required Uint8List bytes,
  String? fileName,
}) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return ProductImageInputFormat.jpeg;
  }
  if (bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return ProductImageInputFormat.png;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ProductImageInputFormat.webp;
  }
  if (_looksLikeAvif(bytes)) {
    return ProductImageInputFormat.avif;
  }

  final String ext = _extensionFromName(fileName);
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return ProductImageInputFormat.jpeg;
    case 'png':
      return ProductImageInputFormat.png;
    case 'webp':
      return ProductImageInputFormat.webp;
    case 'avif':
      return ProductImageInputFormat.avif;
    default:
      return ProductImageInputFormat.unknown;
  }
}

bool _looksLikeAvif(Uint8List bytes) {
  if (bytes.length < 12) return false;
  final String header = String.fromCharCodes(bytes.sublist(4, 12));
  if (!header.startsWith('ftyp')) return false;
  final String brand = String.fromCharCodes(bytes.sublist(8, 12));
  return brand == 'avif' || brand == 'avis' || brand == 'mif1';
}

String _extensionFromName(String? fileName) {
  final String name = fileName?.trim().toLowerCase() ?? '';
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';
  return name.substring(dot + 1);
}

String? mimeTypeForProductImageFormat(ProductImageInputFormat format) {
  switch (format) {
    case ProductImageInputFormat.jpeg:
      return 'image/jpeg';
    case ProductImageInputFormat.png:
      return 'image/png';
    case ProductImageInputFormat.webp:
      return 'image/webp';
    case ProductImageInputFormat.avif:
      return 'image/avif';
    case ProductImageInputFormat.unknown:
      return null;
  }
}

String extensionForProductImageFormat(ProductImageInputFormat format) {
  switch (format) {
    case ProductImageInputFormat.jpeg:
      return 'jpg';
    case ProductImageInputFormat.png:
      return 'png';
    case ProductImageInputFormat.webp:
      return 'webp';
    case ProductImageInputFormat.avif:
      return 'avif';
    case ProductImageInputFormat.unknown:
      return 'jpg';
  }
}

ProductImageInputValidation validateProductImageInput({
  required Uint8List bytes,
  String? fileName,
}) {
  if (bytes.isEmpty) {
    return const ProductImageInputValidation(
      isValid: false,
      errorMessage: 'Görsel dosyası boş.',
    );
  }

  final ProductImageInputFormat format = detectProductImageFormat(
    bytes: bytes,
    fileName: fileName,
  );

  if (format == ProductImageInputFormat.avif) {
    return const ProductImageInputValidation(
      isValid: false,
      format: ProductImageInputFormat.avif,
      errorMessage: ProductImageFormatHelper.avifUnsupportedMessage,
    );
  }

  if (format == ProductImageInputFormat.unknown) {
    return const ProductImageInputValidation(
      isValid: false,
      errorMessage: ProductImageFormatHelper.unsupportedFormatMessage,
    );
  }

  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const ProductImageInputValidation(
      isValid: false,
      errorMessage: ProductImageFormatHelper.unreadableImageMessage,
    );
  }

  final int width = decoded.width;
  final int height = decoded.height;
  String? lowResolutionWarning;
  if (width < ProductImageFormatHelper.minSize ||
      height < ProductImageFormatHelper.minSize) {
    lowResolutionWarning = ProductImageFormatHelper.lowResolutionMessage;
  }

  return ProductImageInputValidation(
    isValid: true,
    format: format,
    width: width,
    height: height,
    lowResolutionWarning: lowResolutionWarning,
  );
}
