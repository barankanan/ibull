import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'media_perf_logger.dart';
import 'product_media_types.dart';

class StorageUploadService {
  StorageUploadService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const int standardUploadThresholdBytes = 6 * 1024 * 1024;
  static const int maxUploadBytes = 80 * 1024 * 1024;
  static const int _chunkBytes = 2 * 1024 * 1024;

  static const Set<String> _allowedContentTypes = {'video/mp4', 'image/jpeg'};

  Future<StorageObjectUploadResult> upload(
    XFile file, {
    required String bucket,
    required String objectPath,
    required String contentType,
    required String cacheControl,
    UploadCancelToken? cancelToken,
    void Function(MediaUploadProgress progress)? onProgress,
    int maxRetries = 2,
  }) async {
    final sizeBytes = await file.length();
    _validateUpload(file: file, sizeBytes: sizeBytes, contentType: contentType);

    if (sizeBytes <= standardUploadThresholdBytes) {
      await _uploadStandard(
        file: file,
        bucket: bucket,
        objectPath: objectPath,
        contentType: contentType,
        cacheControl: cacheControl,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } else {
      await _uploadTusWithRetry(
        file: file,
        bucket: bucket,
        objectPath: objectPath,
        contentType: contentType,
        cacheControl: cacheControl,
        cancelToken: cancelToken,
        onProgress: onProgress,
        maxRetries: maxRetries,
      );
    }

    final publicUrl = _supabase.storage.from(bucket).getPublicUrl(objectPath);
    return StorageObjectUploadResult(
      bucket: bucket,
      path: objectPath,
      publicUrl: publicUrl,
      sizeBytes: sizeBytes,
    );
  }

  Future<void> removeObject({
    required String bucket,
    required String path,
  }) async {
    if (path.trim().isEmpty) return;
    try {
      await _supabase.storage.from(bucket).remove([path]);
    } catch (error) {
      MediaPerfLogger.logInfo(
        'cleanup_warn',
        extra: {'path': path, 'error': error.toString()},
      );
    }
  }

  void _validateUpload({
    required XFile file,
    required int sizeBytes,
    required String contentType,
  }) {
    if (!_allowedContentTypes.contains(contentType)) {
      throw ProductMediaValidationException(
        'Desteklenmeyen dosya tipi: $contentType. İzin verilen tipler: ${_allowedContentTypes.join(', ')}',
      );
    }
    if (sizeBytes <= 0) {
      throw ProductMediaValidationException('Dosya boş görünüyor.');
    }
    if (sizeBytes > maxUploadBytes) {
      throw ProductMediaValidationException(
        'Dosya boyutu çok büyük (${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB). Maksimum ${maxUploadBytes ~/ (1024 * 1024)} MB destekleniyor.',
      );
    }
    final name = file.name.toLowerCase();
    if (contentType == 'video/mp4' && !name.endsWith('.mp4')) {
      throw ProductMediaValidationException(
        'Video yalnızca .mp4 formatında yüklenebilir.',
      );
    }
    if (contentType == 'image/jpeg' &&
        !(name.endsWith('.jpg') || name.endsWith('.jpeg'))) {
      throw ProductMediaValidationException(
        'Thumbnail yalnızca .jpg/.jpeg formatında yüklenebilir.',
      );
    }
  }

  Future<void> _uploadStandard({
    required XFile file,
    required String bucket,
    required String objectPath,
    required String contentType,
    required String cacheControl,
    UploadCancelToken? cancelToken,
    void Function(MediaUploadProgress progress)? onProgress,
  }) async {
    final totalBytes = await file.length();
    final encodedPath = objectPath
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    final uri = Uri.parse(
      '${_supabase.storage.url}/object/$bucket/$encodedPath',
    );

    final request = http.StreamedRequest('POST', uri)
      ..contentLength = totalBytes;
    request.headers.addAll(_buildAuthHeaders());
    request.headers['content-type'] = contentType;
    request.headers['cache-control'] = cacheControl;
    request.headers['x-upsert'] = 'true';

    var sent = 0;
    await for (final chunk in file.openRead()) {
      _throwIfCancelled(cancelToken);
      request.sink.add(chunk);
      sent += chunk.length;
      onProgress?.call(
        MediaUploadProgress(
          progress: (sent / totalBytes).clamp(0, 1).toDouble(),
          bytesSent: sent,
          totalBytes: totalBytes,
          serverProcessing: false,
        ),
      );
    }
    await request.sink.close();

    final client = http.Client();
    try {
      onProgress?.call(
        MediaUploadProgress(
          progress: 0.95,
          bytesSent: sent,
          totalBytes: totalBytes,
          serverProcessing: true,
        ),
      );
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception(
          'Storage upload failed (${response.statusCode}): $body',
        );
      }
      unawaited(response.stream.drain<void>());
      onProgress?.call(
        MediaUploadProgress(
          progress: 1,
          bytesSent: totalBytes,
          totalBytes: totalBytes,
          serverProcessing: false,
        ),
      );
    } finally {
      client.close();
    }
  }

  Future<void> _uploadTusWithRetry({
    required XFile file,
    required String bucket,
    required String objectPath,
    required String contentType,
    required String cacheControl,
    UploadCancelToken? cancelToken,
    void Function(MediaUploadProgress progress)? onProgress,
    required int maxRetries,
  }) async {
    final totalBytes = await file.length();
    var attempt = 0;
    Uri? uploadUrl;

    while (true) {
      _throwIfCancelled(cancelToken);
      attempt += 1;
      try {
        uploadUrl ??= await _createTusUpload(
          bucket: bucket,
          objectPath: objectPath,
          contentType: contentType,
          cacheControl: cacheControl,
          totalBytes: totalBytes,
        );

        final currentOffset = await _getTusOffset(uploadUrl);
        await _patchTusChunks(
          file: file,
          uploadUrl: uploadUrl,
          startOffset: currentOffset,
          totalBytes: totalBytes,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );
        return;
      } catch (error) {
        if (error is UploadCancelledException) rethrow;
        if (attempt > maxRetries + 1) rethrow;
        MediaPerfLogger.logInfo(
          'tus_retry',
          extra: {
            'attempt': attempt,
            'max': maxRetries + 1,
            'error': error.toString(),
          },
        );
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  Future<Uri> _createTusUpload({
    required String bucket,
    required String objectPath,
    required String contentType,
    required String cacheControl,
    required int totalBytes,
  }) async {
    final endpoint = Uri.parse('${_supabase.storage.url}/upload/resumable');
    final request = http.Request('POST', endpoint)
      ..headers.addAll(_buildAuthHeaders())
      ..headers['tus-resumable'] = '1.0.0'
      ..headers['x-upsert'] = 'true'
      ..headers['upload-length'] = '$totalBytes'
      ..headers['upload-metadata'] = _encodeTusMetadata(
        bucket: bucket,
        objectPath: objectPath,
        contentType: contentType,
        cacheControl: cacheControl,
      );

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('TUS create failed (${response.statusCode}): $body');
      }

      final rawLocation = response.headers['location'];
      if (rawLocation == null || rawLocation.isEmpty) {
        throw Exception('TUS location header missing');
      }

      return endpoint.resolve(rawLocation);
    } finally {
      client.close();
    }
  }

  Future<int> _getTusOffset(Uri uploadUrl) async {
    final request = http.Request('HEAD', uploadUrl)
      ..headers.addAll(_buildAuthHeaders())
      ..headers['tus-resumable'] = '1.0.0';

    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw Exception('TUS head failed (${response.statusCode}): $body');
      }

      final offsetHeader = response.headers['upload-offset'];
      return int.tryParse(offsetHeader ?? '0') ?? 0;
    } finally {
      client.close();
    }
  }

  Future<void> _patchTusChunks({
    required XFile file,
    required Uri uploadUrl,
    required int startOffset,
    required int totalBytes,
    UploadCancelToken? cancelToken,
    void Function(MediaUploadProgress progress)? onProgress,
  }) async {
    var offset = startOffset;

    while (offset < totalBytes) {
      _throwIfCancelled(cancelToken);

      final end = (offset + _chunkBytes > totalBytes)
          ? totalBytes
          : offset + _chunkBytes;
      final chunkBytes = await _readChunk(file: file, start: offset, end: end);

      final request = http.Request('PATCH', uploadUrl)
        ..headers.addAll(_buildAuthHeaders())
        ..headers['tus-resumable'] = '1.0.0'
        ..headers['upload-offset'] = '$offset'
        ..headers['content-type'] = 'application/offset+octet-stream'
        ..headers['content-length'] = '${chunkBytes.length}'
        ..bodyBytes = chunkBytes;

      final client = http.Client();
      try {
        final response = await client.send(request);
        if (response.statusCode == 409) {
          final remoteOffset = await _getTusOffset(uploadUrl);
          offset = remoteOffset;
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final body = await response.stream.bytesToString();
          throw Exception('TUS patch failed (${response.statusCode}): $body');
        }

        final remoteOffset = int.tryParse(
          response.headers['upload-offset'] ?? '',
        );
        offset = remoteOffset ?? end;
      } finally {
        client.close();
      }

      onProgress?.call(
        MediaUploadProgress(
          progress: (offset / totalBytes).clamp(0, 1).toDouble(),
          bytesSent: offset,
          totalBytes: totalBytes,
          serverProcessing: false,
        ),
      );
    }

    onProgress?.call(
      MediaUploadProgress(
        progress: 1,
        bytesSent: totalBytes,
        totalBytes: totalBytes,
        serverProcessing: false,
      ),
    );
  }

  Future<Uint8List> _readChunk({
    required XFile file,
    required int start,
    required int end,
  }) async {
    final chunks = <List<int>>[];
    var total = 0;
    await for (final chunk in file.openRead(start, end)) {
      chunks.add(chunk);
      total += chunk.length;
    }

    final out = Uint8List(total);
    var offset = 0;
    for (final chunk in chunks) {
      out.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return out;
  }

  Map<String, String> _buildAuthHeaders() {
    final headers = Map<String, String>.from(_supabase.storage.headers);
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  String _encodeTusMetadata({
    required String bucket,
    required String objectPath,
    required String contentType,
    required String cacheControl,
  }) {
    String enc(String input) => base64Encode(utf8.encode(input));
    return [
      'bucketName ${enc(bucket)}',
      'objectName ${enc(objectPath)}',
      'contentType ${enc(contentType)}',
      'cacheControl ${enc(cacheControl)}',
    ].join(',');
  }

  void _throwIfCancelled(UploadCancelToken? token) {
    if (token?.isCancelled == true) {
      throw UploadCancelledException();
    }
  }
}
