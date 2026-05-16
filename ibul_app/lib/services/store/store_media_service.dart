import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_upload_progress_details.dart';

class StoreMediaService {
  StoreMediaService({
    required SupabaseClient supabase,
    required String? Function() currentUserIdResolver,
  }) : _supabase = supabase,
       _currentUserIdResolver = currentUserIdResolver;

  final SupabaseClient _supabase;
  final String? Function() _currentUserIdResolver;

  static const Duration compressTimeout = Duration(seconds: 45);
  static const Duration uploadTimeout = Duration(seconds: 180);

  int get _targetImageBytes => kIsWeb ? 500 * 1024 : 700 * 1024;

  /// Web and macOS encoders do not support WebP output in flutter_image_compress.
  bool get _useJpegEncoding =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.macOS;

  CompressFormat get _compressFormat =>
      _useJpegEncoding ? CompressFormat.jpeg : CompressFormat.webp;

  String get _contentType =>
      _useJpegEncoding ? 'image/jpeg' : 'image/webp';

  String get _fileExt => _useJpegEncoding ? 'jpg' : 'webp';

  String get _currentUserId {
    final currentUserId = _currentUserIdResolver()?.trim() ?? '';
    if (currentUserId.isEmpty) {
      throw Exception('Kullanıcı girişi yapılmamış');
    }
    return currentUserId;
  }

  Future<String> uploadDocument(
    String fileName,
    Uint8List fileBytes,
    String contentType,
  ) async {
    final currentUserId = _currentUserId;

    try {
      final path =
          '$currentUserId/documents/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _supabase.storage
          .from('seller-documents')
          .uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          )
          .timeout(const Duration(seconds: 60));

      return path;
    } catch (e) {
      throw Exception('Belge yüklenirken hata: $e');
    }
  }

  Future<String> getDocumentUrl(String path) {
    return _supabase.storage.from('seller-documents').createSignedUrl(path, 3600);
  }

  Future<String> uploadStoreImage(XFile file, String folderName) async {
    final currentUserId = _currentUserId;

    try {
      final rawName = file.name.replaceAll(RegExp(r"[^a-zA-Z0-9.-]"), "_");
      final normalizedName = rawName.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${normalizedName.isEmpty ? 'image' : normalizedName}.$_fileExt';
      final path = '$currentUserId/$folderName/$fileName';

      final data = await compressImage(
        file,
      ).timeout(compressTimeout, onTimeout: () => file.readAsBytes());

      await _supabase.storage
          .from('store-images')
          .uploadBinary(
            path,
            data,
            fileOptions: FileOptions(contentType: _contentType, upsert: true),
          );

      return _supabase.storage.from('store-images').getPublicUrl(path);
    } catch (e) {
      throw Exception('Görsel yüklenirken hata: $e');
    }
  }

  Future<String> uploadStoreImageBytes(
    Uint8List bytes,
    String folderName, {
    String fileName = 'image.jpg',
  }) async {
    final currentUserId = _currentUserId;

    try {
      final safeName = fileName.replaceAll(RegExp(r"[^a-zA-Z0-9.-]"), "_");
      final normalizedName = safeName.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final optimizedBytes = await compressBytes(
        bytes,
      ).timeout(compressTimeout, onTimeout: () => bytes);
      final path =
          '$currentUserId/$folderName/${DateTime.now().millisecondsSinceEpoch}_${normalizedName.isEmpty ? 'image' : normalizedName}.$_fileExt';

      await _supabase.storage
          .from('store-images')
          .uploadBinary(
            path,
            optimizedBytes,
            fileOptions: FileOptions(contentType: _contentType, upsert: true),
          );

      return _supabase.storage.from('store-images').getPublicUrl(path);
    } catch (e) {
      throw Exception('Görsel yüklenirken hata: $e');
    }
  }

  Future<String> uploadProductVideo(XFile videoFile) async {
    final currentUserId = _currentUserId;

    final size = await videoFile.length();
    if (size > 10 * 1024 * 1024) {
      throw Exception('Video boyutu 10MB\'dan büyük olamaz');
    }

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${videoFile.name.replaceAll(RegExp(r"[^a-zA-Z0-9.-]"), "_")}';
      final path = '$currentUserId/$fileName';

      final videoBytes = await videoFile.readAsBytes();

      await _supabase.storage
          .from('product_videos')
          .uploadBinary(
            path,
            videoBytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          )
          .timeout(const Duration(minutes: 5));

      return _supabase.storage.from('product_videos').getPublicUrl(path);
    } catch (e) {
      if (e.toString().contains('Violates row-level security policy') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized')) {
        throw Exception(
          'Video yükleme yetkiniz yok. Lütfen Supabase Storage panelinden "product_videos" bucket ayarlarını kontrol edin. (Public ve RLS kapalı veya Policy ekli olmalı)',
        );
      }
      throw Exception('Video yüklenirken hata: $e');
    }
  }

  Future<String> uploadStoreVideo(XFile videoFile) async {
    final currentUserId = _currentUserId;

    final size = await videoFile.length();
    if (size > 50 * 1024 * 1024) {
      throw Exception('Video boyutu 50MB\'dan büyük olamaz');
    }

    try {
      final fileName =
          'store_${DateTime.now().millisecondsSinceEpoch}_${videoFile.name.replaceAll(RegExp(r"[^a-zA-Z0-9.-]"), "_")}';
      final path = '$currentUserId/store_videos/$fileName';
      final videoBytes = await videoFile.readAsBytes();

      await _supabase.storage
          .from('product_videos')
          .uploadBinary(
            path,
            videoBytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: true,
            ),
          )
          .timeout(const Duration(minutes: 10));

      return _supabase.storage.from('product_videos').getPublicUrl(path);
    } catch (e) {
      if (e.toString().contains('Violates row-level security policy') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized')) {
        throw Exception(
          'Video yükleme yetkiniz yok. Lütfen Supabase Storage panelinden "product_videos" bucket ayarlarını kontrol edin.',
        );
      }
      throw Exception('Mağaza videosu yüklenirken hata: $e');
    }
  }

  Future<String> uploadStoreVideoWithProgress(
    XFile videoFile, {
    void Function(double progress)? onProgress,
    void Function(UploadProgressDetails details)? onProgressDetails,
  }) async {
    final currentUserId = _currentUserId;

    final size = await videoFile.length();
    if (size > 30 * 1024 * 1024) {
      throw Exception('Video boyutu 30MB\'dan büyük olamaz');
    }

    try {
      final fileName =
          'store_${DateTime.now().millisecondsSinceEpoch}_${videoFile.name.replaceAll(RegExp(r"[^a-zA-Z0-9.-]"), "_")}';
      final path = '$currentUserId/store_videos/$fileName';
      final videoBytes = await videoFile.readAsBytes();

      await uploadBinaryWithProgress(
        bucket: 'product_videos',
        objectPath: path,
        bytes: videoBytes,
        contentType: 'video/mp4',
        onProgress: onProgress,
        onProgressDetails: onProgressDetails,
      ).timeout(const Duration(minutes: 10));

      return _supabase.storage.from('product_videos').getPublicUrl(path);
    } catch (e) {
      if (e.toString().contains('Violates row-level security policy') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized')) {
        throw Exception(
          'Video yükleme yetkiniz yok. Lütfen Supabase Storage panelinden "product_videos" bucket ayarlarını kontrol edin.',
        );
      }
      throw Exception('Mağaza videosu yüklenirken hata: $e');
    }
  }

  Future<String> uploadProductImage(
    String productId,
    XFile file,
    int index,
  ) async {
    final currentUserId = _currentUserId;
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_$index.$_fileExt';
    final path = '$currentUserId/$productId/$fileName';

    final bytes = await compressImage(file);

    await _supabase.storage
        .from('product-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentType, upsert: true),
        );

    return _supabase.storage.from('product-images').getPublicUrl(path);
  }

  Future<String> uploadVariantImage(
    String productId,
    XFile file,
    int index,
  ) async {
    final currentUserId = _currentUserId;
    final fileName =
        'variant_${DateTime.now().millisecondsSinceEpoch}_$index.$_fileExt';
    final path = '$currentUserId/$productId/variants/$fileName';

    final data = await compressImage(file);

    await _supabase.storage
        .from('product-images')
        .uploadBinary(
          path,
          data,
          fileOptions: FileOptions(contentType: _contentType, upsert: true),
        );

    return _supabase.storage.from('product-images').getPublicUrl(path);
  }

  Future<Uint8List> compressImage(XFile file) async {
    try {
      final Uint8List input = await file.readAsBytes();
      if (input.isEmpty) return input;
      return compressBytes(input);
    } catch (_) {
      return file.readAsBytes();
    }
  }

  Future<Uint8List> compressBytes(Uint8List input) async {
    if (input.isEmpty) return input;

    try {
      return await _compressBytesWithFormat(input, _compressFormat);
    } on UnsupportedError {
      if (_compressFormat == CompressFormat.jpeg) {
        return input;
      }
      return _compressBytesWithFormat(input, CompressFormat.jpeg);
    }
  }

  Future<Uint8List> _compressBytesWithFormat(
    Uint8List input,
    CompressFormat format,
  ) async {
    int quality = kIsWeb ? 60 : 68;
    int minSide = kIsWeb ? 840 : 960;
    Uint8List best = input;

    for (int attempt = 0; attempt < 4; attempt++) {
      final Uint8List out = await FlutterImageCompress.compressWithList(
        input,
        minWidth: minSide,
        minHeight: minSide,
        quality: quality,
        format: format,
      );

      if (out.isNotEmpty) {
        best = out;
      }

      if (best.lengthInBytes <= _targetImageBytes) {
        return best;
      }

      quality = (quality - 8).clamp(38, 90);
      minSide = (minSide * 0.85).round().clamp(520, 1600);
    }
    return best;
  }

  Future<void> uploadBinaryWithProgress({
    required String bucket,
    required String objectPath,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
    void Function(UploadProgressDetails details)? onProgressDetails,
  }) async {
    final encodedPath = objectPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    final uri = Uri.parse(
      '${_supabase.storage.url}/object/$bucket/$encodedPath',
    );

    final request = http.StreamedRequest('POST', uri)
      ..contentLength = bytes.length;

    final headers = Map<String, String>.from(_supabase.storage.headers);
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    headers['content-type'] = contentType;
    headers['x-upsert'] = 'true';
    request.headers.addAll(headers);

    if (bytes.isEmpty) {
      throw Exception('Video dosyası boş.');
    }

    final client = http.Client();
    Timer? settleProgressTimer;
    final stopwatch = Stopwatch()..start();
    try {
      onProgress?.call(0);
      onProgressDetails?.call(
        UploadProgressDetails(
          progress: 0,
          bytesSent: 0,
          totalBytes: bytes.length,
          bytesPerSecond: 0,
          eta: null,
          isServerProcessing: false,
        ),
      );
      const uploadPhaseMax = 0.88;
      const chunkSize = 4 * 1024 * 1024;
      var sentBytes = 0;
      final responseFuture = client
          .send(request)
          .timeout(const Duration(minutes: 4));
      for (var offset = 0; offset < bytes.length; offset += chunkSize) {
        final end = (offset + chunkSize) > bytes.length
            ? bytes.length
            : (offset + chunkSize);
        final chunk = Uint8List.sublistView(bytes, offset, end);
        request.sink.add(chunk);
        sentBytes += chunk.length;
        final uploadProgress = (sentBytes / bytes.length).clamp(0.0, 1.0);
        final normalizedProgress = (uploadProgress * uploadPhaseMax).toDouble();
        onProgress?.call(normalizedProgress);
        final elapsedSeconds = math.max(
          0.001,
          stopwatch.elapsedMicroseconds / 1000000,
        );
        final bytesPerSecond = sentBytes / elapsedSeconds;
        final remainingBytes = math.max(0, bytes.length - sentBytes);
        final eta = bytesPerSecond <= 0
            ? null
            : Duration(seconds: (remainingBytes / bytesPerSecond).ceil());
        onProgressDetails?.call(
          UploadProgressDetails(
            progress: normalizedProgress,
            bytesSent: sentBytes,
            totalBytes: bytes.length,
            bytesPerSecond: bytesPerSecond,
            eta: eta,
            isServerProcessing: false,
          ),
        );
      }
      await request.sink.close();
      onProgress?.call(uploadPhaseMax);

      var settleProgress = uploadPhaseMax;
      settleProgressTimer = Timer.periodic(const Duration(milliseconds: 300), (
        timer,
      ) {
        settleProgress = (settleProgress + 0.003).clamp(uploadPhaseMax, 0.97);
        onProgress?.call(settleProgress);
        onProgressDetails?.call(
          UploadProgressDetails(
            progress: settleProgress,
            bytesSent: sentBytes,
            totalBytes: bytes.length,
            bytesPerSecond: 0,
            eta: null,
            isServerProcessing: true,
          ),
        );
        if (settleProgress >= 0.97) {
          timer.cancel();
        }
      });

      final response = await responseFuture;
      settleProgressTimer.cancel();
      settleProgressTimer = null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString().timeout(
          const Duration(seconds: 30),
        );
        throw Exception('HTTP ${response.statusCode}: $body');
      }
      unawaited(response.stream.drain<void>());
    } finally {
      settleProgressTimer?.cancel();
      stopwatch.stop();
      client.close();
    }

    onProgress?.call(1);
    onProgressDetails?.call(
      UploadProgressDetails(
        progress: 1,
        bytesSent: bytes.length,
        totalBytes: bytes.length,
        bytesPerSecond: 0,
        eta: Duration.zero,
        isServerProcessing: false,
      ),
    );
  }
}
