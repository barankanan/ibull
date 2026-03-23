import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';

import 'media_perf_logger.dart';
import 'product_media_types.dart';

class MediaPickerService {
  MediaPickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<PickedProductVideo?> pickVideo({
    required ImageSource source,
    Duration maxDuration = const Duration(seconds: 30),
  }) async {
    final pickWatch = Stopwatch()..start();
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: maxDuration,
    );
    pickWatch.stop();
    MediaPerfLogger.logDuration('pick_suresi', pickWatch.elapsed);

    if (file == null) return null;

    final metadataWatch = Stopwatch()..start();
    final metadata = await _readVideoMetadata(file);
    metadataWatch.stop();
    MediaPerfLogger.logDuration(
      'video_metadata_okuma_suresi',
      metadataWatch.elapsed,
      extra: {
        'durationSec': metadata.duration.inSeconds,
        'sizeBytes': metadata.sizeBytes,
        'resolution': '${metadata.width}x${metadata.height}',
        'ext': metadata.extension,
      },
    );

    if (!metadata.isDurationValid) {
      throw ProductMediaValidationException(
        'Video süresi en fazla 30 saniye olabilir. Seçilen video: ${metadata.duration.inSeconds} saniye.',
      );
    }

    return PickedProductVideo(
      file: file,
      metadata: metadata,
      pickDuration: pickWatch.elapsed,
      metadataReadDuration: metadataWatch.elapsed,
    );
  }

  Future<ProductVideoMetadata> _readVideoMetadata(XFile file) async {
    final sizeBytes = await file.length();
    final extension = _resolveExtension(file).toLowerCase();
    var duration = Duration.zero;
    var width = 0;
    var height = 0;

    if (!kIsWeb) {
      try {
        final info = await VideoCompress.getMediaInfo(file.path);
        final ms = info.duration?.round() ?? 0;
        duration = Duration(milliseconds: ms);
        width = info.width?.round() ?? 0;
        height = info.height?.round() ?? 0;
      } catch (_) {
        // Fall back to video_player metadata read below.
      }
    }

    if (duration == Duration.zero || width <= 0 || height <= 0) {
      VideoPlayerController? controller;
      try {
        final uri = kIsWeb ? Uri.parse(file.path) : Uri.file(file.path);
        controller = VideoPlayerController.networkUrl(uri);
        await controller.initialize();
        duration = controller.value.duration;
        width = controller.value.size.width.round();
        height = controller.value.size.height.round();
      } catch (_) {
        // Keep default metadata if controller cannot initialize.
      } finally {
        await controller?.dispose();
      }
    }

    return ProductVideoMetadata(
      duration: duration,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      extension: extension,
      mimeType: _mimeTypeByExtension(extension),
    );
  }

  String _resolveExtension(XFile file) {
    final fromName = p.extension(file.name);
    if (fromName.isNotEmpty) {
      return fromName.replaceFirst('.', '');
    }
    final fromPath = p.extension(file.path);
    if (fromPath.isNotEmpty) {
      return fromPath.replaceFirst('.', '');
    }
    return 'mp4';
  }

  String _mimeTypeByExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      default:
        return 'application/octet-stream';
    }
  }
}
