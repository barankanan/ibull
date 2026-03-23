import 'package:image_picker/image_picker.dart';

enum ProductMediaStage {
  idle,
  picking,
  readingMetadata,
  optimizing,
  generatingThumbnail,
  uploading,
  saving,
  done,
  failed,
  cancelled,
}

class ProductVideoMetadata {
  final Duration duration;
  final int sizeBytes;
  final int width;
  final int height;
  final String extension;
  final String mimeType;

  const ProductVideoMetadata({
    required this.duration,
    required this.sizeBytes,
    required this.width,
    required this.height,
    required this.extension,
    required this.mimeType,
  });

  bool get isDurationValid => duration.inSeconds <= 30;
}

class PickedProductVideo {
  final XFile file;
  final ProductVideoMetadata metadata;
  final Duration pickDuration;
  final Duration metadataReadDuration;

  const PickedProductVideo({
    required this.file,
    required this.metadata,
    required this.pickDuration,
    required this.metadataReadDuration,
  });
}

class ProcessedProductVideo {
  final XFile optimizedVideo;
  final XFile thumbnailImage;
  final ProductVideoMetadata sourceMetadata;
  final ProductVideoMetadata optimizedMetadata;
  final Duration compressionDuration;
  final Duration thumbnailDuration;

  const ProcessedProductVideo({
    required this.optimizedVideo,
    required this.thumbnailImage,
    required this.sourceMetadata,
    required this.optimizedMetadata,
    required this.compressionDuration,
    required this.thumbnailDuration,
  });

  double get compressionRatio {
    if (sourceMetadata.sizeBytes <= 0) return 1.0;
    return optimizedMetadata.sizeBytes / sourceMetadata.sizeBytes;
  }
}

class MediaUploadProgress {
  final double progress; // 0..1
  final int bytesSent;
  final int totalBytes;
  final bool serverProcessing;

  const MediaUploadProgress({
    required this.progress,
    required this.bytesSent,
    required this.totalBytes,
    required this.serverProcessing,
  });
}

class StorageObjectUploadResult {
  final String bucket;
  final String path;
  final String publicUrl;
  final int sizeBytes;

  const StorageObjectUploadResult({
    required this.bucket,
    required this.path,
    required this.publicUrl,
    required this.sizeBytes,
  });
}

class ProductMediaUploadResult {
  final StorageObjectUploadResult video;
  final StorageObjectUploadResult thumbnail;
  final ProductVideoMetadata videoMetadata;
  final String videoStatus;

  const ProductMediaUploadResult({
    required this.video,
    required this.thumbnail,
    required this.videoMetadata,
    required this.videoStatus,
  });

  Map<String, dynamic> toDatabaseMap() {
    return {
      'video_path': video.path,
      'video_public_url': video.publicUrl,
      'thumbnail_path': thumbnail.path,
      'thumbnail_public_url': thumbnail.publicUrl,
      'video_duration_seconds': videoMetadata.duration.inSeconds,
      'video_size_bytes': video.sizeBytes,
      'thumbnail_size_bytes': thumbnail.sizeBytes,
      'video_status': videoStatus,
      // Backward compatibility for existing schema/queries.
      'video_url': video.publicUrl,
    };
  }
}

class UploadCancelledException implements Exception {
  final String message;

  UploadCancelledException([
    this.message = 'Yükleme kullanıcı tarafından iptal edildi',
  ]);

  @override
  String toString() => message;
}

class ProductMediaValidationException implements Exception {
  final String message;

  ProductMediaValidationException(this.message);

  @override
  String toString() => message;
}

class UploadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}
