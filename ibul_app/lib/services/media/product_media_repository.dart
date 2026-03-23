import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_perf_logger.dart';
import 'product_media_types.dart';
import 'storage_upload_service.dart';
import 'video_processing_service.dart';

class ProductMediaRepository {
  ProductMediaRepository({
    SupabaseClient? client,
    StorageUploadService? storageUploadService,
    VideoProcessingService? videoProcessingService,
  }) : _supabase = client ?? Supabase.instance.client,
       _storage = storageUploadService ?? StorageUploadService(client: client),
       _processor = videoProcessingService ?? const VideoProcessingService();

  final SupabaseClient _supabase;
  final StorageUploadService _storage;
  final VideoProcessingService _processor;

  static const String mediaBucket = 'product-media';

  Future<ProductMediaUploadResult> uploadProductMedia({
    required String sellerId,
    required String productId,
    required XFile sourceVideo,
    String? previousVideoPath,
    String? previousThumbnailPath,
    UploadCancelToken? cancelToken,
    void Function(ProductMediaStage stage, String label)? onStage,
    void Function(MediaUploadProgress progress)? onUploadProgress,
  }) async {
    onStage?.call(ProductMediaStage.optimizing, 'Video optimize ediliyor...');
    final processed = await _processor.optimizeForMobile(sourceVideo);

    final videoPath = 'products/$sellerId/$productId/video.mp4';
    final thumbnailPath = 'products/$sellerId/$productId/thumb.jpg';

    onStage?.call(ProductMediaStage.uploading, 'Video yükleniyor...');
    final uploadWatch = Stopwatch()..start();

    final videoResult = await _storage.upload(
      processed.optimizedVideo,
      bucket: mediaBucket,
      objectPath: videoPath,
      contentType: 'video/mp4',
      cacheControl: 'public, max-age=31536000, immutable',
      cancelToken: cancelToken,
      onProgress: onUploadProgress,
    );

    onStage?.call(
      ProductMediaStage.generatingThumbnail,
      'Thumbnail hazırlanıyor...',
    );
    onStage?.call(ProductMediaStage.uploading, 'Thumbnail yükleniyor...');
    final thumbResult = await _storage.upload(
      processed.thumbnailImage,
      bucket: mediaBucket,
      objectPath: thumbnailPath,
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=31536000, immutable',
      cancelToken: cancelToken,
      onProgress: onUploadProgress,
    );

    uploadWatch.stop();
    MediaPerfLogger.logDuration(
      'upload_suresi',
      uploadWatch.elapsed,
      extra: {
        'videoBytes': videoResult.sizeBytes,
        'thumbBytes': thumbResult.sizeBytes,
        'videoPath': videoResult.path,
      },
    );

    if (previousVideoPath != null &&
        previousVideoPath.isNotEmpty &&
        previousVideoPath != videoPath) {
      await _storage.removeObject(bucket: mediaBucket, path: previousVideoPath);
    }
    if (previousThumbnailPath != null &&
        previousThumbnailPath.isNotEmpty &&
        previousThumbnailPath != thumbnailPath) {
      await _storage.removeObject(
        bucket: mediaBucket,
        path: previousThumbnailPath,
      );
    }

    return ProductMediaUploadResult(
      video: videoResult,
      thumbnail: thumbResult,
      videoMetadata: processed.optimizedMetadata,
      videoStatus: 'ready',
    );
  }

  Future<void> saveProductMediaToDatabase({
    required String productId,
    required ProductMediaUploadResult media,
  }) async {
    final watch = Stopwatch()..start();
    final payload = media.toDatabaseMap()
      ..['updated_at'] = DateTime.now().toIso8601String();

    try {
      await _supabase.from('products').update(payload).eq('id', productId);
    } catch (error) {
      final message = error.toString();
      if (message.contains('column') || message.contains('does not exist')) {
        // Legacy fallback: eski şemada en azından video_url güncellemesi yapılır.
        await _supabase
            .from('products')
            .update({
              'video_url': media.video.publicUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', productId);
      } else {
        rethrow;
      }
    } finally {
      watch.stop();
      MediaPerfLogger.logDuration(
        'database_save_suresi',
        watch.elapsed,
        extra: {'productId': productId},
      );
    }
  }

  Future<void> cleanupProductMedia({
    String? videoPath,
    String? thumbnailPath,
  }) async {
    if (videoPath != null && videoPath.trim().isNotEmpty) {
      await _storage.removeObject(bucket: mediaBucket, path: videoPath.trim());
    }
    if (thumbnailPath != null && thumbnailPath.trim().isNotEmpty) {
      await _storage.removeObject(
        bucket: mediaBucket,
        path: thumbnailPath.trim(),
      );
    }
  }
}
