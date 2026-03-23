import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

import 'media_perf_logger.dart';
import 'product_media_types.dart';

class VideoProcessingService {
  const VideoProcessingService();

  static const int _targetBitrateBps = 1800000; // ~1.8 Mbps

  Future<ProcessedProductVideo> optimizeForMobile(XFile sourceVideo) async {
    final sourceMetadata = await _readMetadata(sourceVideo);

    if (!sourceMetadata.isDurationValid) {
      throw ProductMediaValidationException(
        'Video süresi en fazla 30 saniye olabilir. Seçilen video: ${sourceMetadata.duration.inSeconds} saniye.',
      );
    }

    final compressionWatch = Stopwatch()..start();
    XFile optimizedXFile = sourceVideo;
    ProductVideoMetadata optimizedMetadata = sourceMetadata;

    if (!kIsWeb) {
      final compressed = await VideoCompress.compressVideo(
        sourceVideo.path,
        quality: VideoQuality.Res1280x720Quality,
        includeAudio: true,
        frameRate: 30,
        deleteOrigin: false,
      );

      final optimizedPath = compressed?.path;
      if (optimizedPath != null && optimizedPath.isNotEmpty) {
        optimizedXFile = XFile(optimizedPath);
        optimizedMetadata = await _readMetadata(optimizedXFile);
      }
    }

    compressionWatch.stop();

    MediaPerfLogger.logDuration(
      'compression_suresi',
      compressionWatch.elapsed,
      extra: {
        'inputBytes': sourceMetadata.sizeBytes,
        'outputBytes': optimizedMetadata.sizeBytes,
        'ratio': sourceMetadata.sizeBytes == 0
            ? '1.00'
            : (optimizedMetadata.sizeBytes / sourceMetadata.sizeBytes)
                  .toStringAsFixed(2),
        'targetBitrateBps': _targetBitrateBps,
      },
    );

    final thumbnailWatch = Stopwatch()..start();
    final thumb = await VideoCompress.getFileThumbnail(
      optimizedXFile.path,
      quality: 72,
      position: 1000,
    );
    thumbnailWatch.stop();

    final thumbPath = thumb.path;
    if (thumbPath.isEmpty) {
      throw ProductMediaValidationException('Video thumbnail üretilemedi.');
    }

    final thumbXFile = XFile(thumbPath, mimeType: 'image/jpeg');

    MediaPerfLogger.logDuration(
      'thumbnail_generation_suresi',
      thumbnailWatch.elapsed,
      extra: {'path': thumbPath},
    );

    MediaPerfLogger.logInfo(
      'compression_ozeti',
      extra: {
        'inputBytes': sourceMetadata.sizeBytes,
        'outputBytes': optimizedMetadata.sizeBytes,
        'compressionRatio': sourceMetadata.sizeBytes == 0
            ? '1.00'
            : (optimizedMetadata.sizeBytes / sourceMetadata.sizeBytes)
                  .toStringAsFixed(2),
        'resolution': '${optimizedMetadata.width}x${optimizedMetadata.height}',
        'durationSec': optimizedMetadata.duration.inSeconds,
      },
    );

    return ProcessedProductVideo(
      optimizedVideo: optimizedXFile,
      thumbnailImage: thumbXFile,
      sourceMetadata: sourceMetadata,
      optimizedMetadata: optimizedMetadata,
      compressionDuration: compressionWatch.elapsed,
      thumbnailDuration: thumbnailWatch.elapsed,
    );
  }

  Future<ProductVideoMetadata> _readMetadata(XFile file) async {
    final info = await VideoCompress.getMediaInfo(file.path);
    final duration = Duration(milliseconds: info.duration?.round() ?? 0);
    final sizeBytes = await file.length();
    final ext = p.extension(file.path).replaceFirst('.', '').toLowerCase();

    return ProductVideoMetadata(
      duration: duration,
      sizeBytes: sizeBytes,
      width: info.width?.round() ?? 0,
      height: info.height?.round() ?? 0,
      extension: ext.isEmpty ? 'mp4' : ext,
      mimeType: _mimeType(ext),
    );
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }
}
