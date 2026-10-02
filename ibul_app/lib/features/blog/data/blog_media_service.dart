import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/store/store_media_service.dart';

enum BlogMediaKind { image, video }

class BlogMediaException implements Exception {
  const BlogMediaException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Uploads into the `blog-media` bucket under `{uid}/blog/...` (bucket policy
/// requires the first folder to be the uploader's uid).
class BlogMediaService {
  BlogMediaService._();

  static final BlogMediaService instance = BlogMediaService._();

  static const String bucket = 'blog-media';
  static const int maxImageBytes = 10 * 1024 * 1024;
  // Same limit as product/store videos and the bucket file_size_limit.
  static const int maxVideoBytes = 30 * 1024 * 1024;

  static const Map<String, String> _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
  };
  static const Map<String, String> _videoTypes = {
    'mp4': 'video/mp4',
    'webm': 'video/webm',
    'mov': 'video/quicktime',
  };

  SupabaseClient get _client => Supabase.instance.client;

  late final StoreMediaService _media = StoreMediaService(
    supabase: _client,
    currentUserIdResolver: () => _client.auth.currentUser?.id,
  );

  /// Opens a picker and uploads. Returns null when the user cancels.
  Future<String?> pickAndUpload(
    BlogMediaKind kind, {
    ValueChanged<double>? onProgress,
  }) async {
    final types = kind == BlogMediaKind.image ? _imageTypes : _videoTypes;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: types.keys.toList(),
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) return null;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const BlogMediaException('Dosya okunamadı.');
    }
    return upload(
      kind,
      bytes: bytes,
      fileName: file.name,
      onProgress: onProgress,
    );
  }

  Future<String> upload(
    BlogMediaKind kind, {
    required Uint8List bytes,
    required String fileName,
    ValueChanged<double>? onProgress,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const BlogMediaException('Yükleme için giriş yapmalısınız.');
    }
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    final types = kind == BlogMediaKind.image ? _imageTypes : _videoTypes;
    var contentType = types[extension];
    if (contentType == null) {
      throw BlogMediaException(
        'Desteklenmeyen dosya türü. İzin verilenler: ${types.keys.join(', ')}.',
      );
    }
    final limit = kind == BlogMediaKind.image ? maxImageBytes : maxVideoBytes;
    if (bytes.length > limit) {
      throw BlogMediaException(
        'Dosya en fazla ${limit ~/ (1024 * 1024)} MB olabilir.',
      );
    }

    var payload = bytes;
    var ext = extension;
    if (kind == BlogMediaKind.image && extension != 'gif') {
      try {
        payload = await _media.compressBytes(bytes);
      } catch (_) {
        payload = bytes;
      }
      final sniffed = _sniffImage(payload);
      if (sniffed != null) {
        ext = sniffed;
        contentType = _imageTypes[sniffed]!;
      }
    }

    final safeName = fileName
        .split('.')
        .first
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final path =
        '$uid/blog/${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? 'medya' : safeName}.$ext';
    try {
      await _media.uploadBinaryWithProgress(
        bucket: bucket,
        objectPath: path,
        bytes: payload,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (error) {
      final text = error.toString();
      if (text.contains('403') || text.toLowerCase().contains('security')) {
        throw const BlogMediaException(
          'Medya yükleme yetkiniz yok (yalnızca blog yazarları ve yöneticiler).',
        );
      }
      if (text.contains('Bucket not found') || text.contains('404')) {
        throw const BlogMediaException(
          'Blog medya alanı (blog-media) henüz kurulmamış.',
        );
      }
      if (text.contains('413') || text.toLowerCase().contains('too large')) {
        throw const BlogMediaException('Dosya boyutu sınırı aşıldı.');
      }
      throw const BlogMediaException(
        'Yükleme tamamlanamadı. Bağlantınızı kontrol edip tekrar deneyin.',
      );
    }
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Compression may change the encoding (JPEG on web/desktop, WebP on mobile).
  static String? _sniffImage(Uint8List b) {
    if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
    if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E) {
      return 'png';
    }
    if (b.length > 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[8] == 0x57 &&
        b[9] == 0x45) {
      return 'webp';
    }
    return null;
  }
}
