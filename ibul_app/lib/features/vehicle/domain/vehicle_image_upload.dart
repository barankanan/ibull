import 'dart:typed_data';

/// Gallery photos are not product-video thumbnails.
/// Do not route them through StorageUploadService filename gates.
abstract final class VehicleImageUpload {
  static const bucket = 'vehicle-media';
  static const maxBytes = 15 * 1024 * 1024;

  static String contentTypeFor({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final mime = (mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/jpg') return 'image/jpeg';
    if (mime.startsWith('image/')) return mime;
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static String extensionFor(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
      case 'image/heif':
        return 'heic';
      default:
        return 'jpg';
    }
  }

  /// Storage RLS: first folder must equal auth.uid() / seller_id.
  static String objectPath({
    required String sellerId,
    required String listingId,
    required String fileId,
    required String extension,
  }) {
    return '$sellerId/$listingId/${DateTime.now().millisecondsSinceEpoch}_$fileId.$extension';
  }
}
