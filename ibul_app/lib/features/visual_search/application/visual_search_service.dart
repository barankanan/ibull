import 'dart:convert';
import 'dart:typed_data';

import '../data/edge_visual_search_analyzer.dart';
import '../data/hybrid_visual_search_repository.dart';
import '../data/mock_visual_search_analyzer.dart';
import '../data/visual_search_image_memory.dart';
import '../data/visual_search_repository.dart';
import '../data/visual_search_supabase.dart';
import '../domain/visual_search_analyzer.dart';
import '../domain/visual_search_models.dart';

class VisualSearchService {
  VisualSearchService({
    VisualSearchRepository? repository,
    VisualSearchAnalyzer? analyzer,
  }) : _repository = repository ?? HybridVisualSearchRepository(),
       _analyzer =
           analyzer ??
           (VisualSearchConfig.useRemoteAnalyzer
               ? FallbackVisualSearchAnalyzer(
                   primary: const EdgeVisualSearchAnalyzer(),
                   fallback: const MockVisualSearchAnalyzer(),
                 )
               : const MockVisualSearchAnalyzer());

  static const maxBytes = 8 * 1024 * 1024;
  static const previewByteLimit = 48 * 1024;

  final VisualSearchRepository _repository;
  final VisualSearchAnalyzer _analyzer;

  Future<VisualSearchJob> submit({
    required VisualSearchJobType type,
    required Uint8List bytes,
    required String fileName,
    String? userId,
    List<VisualCatalogItem> catalog = const [],
    void Function(VisualSearchPhase phase)? onPhase,
  }) async {
    _validate(bytes, fileName);
    final now = DateTime.now().toUtc();
    var job = VisualSearchJob(
      id: newVisualSearchId(),
      userId: userId,
      fileName: fileName,
      jobType: type,
      status: VisualSearchJobStatus.pending,
      createdAt: now,
      updatedAt: now,
      previewDataUrl: _previewUrl(bytes, fileName),
    );
    VisualSearchImageMemory.put(job.id, bytes);
    await _repository.saveJob(job);

    onPhase?.call(VisualSearchPhase.uploading);
    final imageUrl = await _repository.uploadImage(
      jobId: job.id,
      userId: userId,
      bytes: bytes,
      fileName: fileName,
    );
    job = job.copyWith(
      status: VisualSearchJobStatus.processing,
      updatedAt: DateTime.now().toUtc(),
      imageUrl: imageUrl,
      savedRemotely: imageUrl != null,
    );
    await _repository.saveJob(job);

    onPhase?.call(VisualSearchPhase.analyzing);
    try {
      final analysis = await _analyzer.analyze(
        jobType: type,
        fileName: fileName,
        imageBytes: bytes,
        catalog: catalog,
      );
      job = job.copyWith(
        status: VisualSearchJobStatus.completed,
        updatedAt: DateTime.now().toUtc(),
        analysis: analysis,
        clearError: true,
      );
      await _repository.saveJob(job);
      return job;
    } catch (error) {
      job = job.copyWith(
        status: VisualSearchJobStatus.failed,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: 'Analiz tamamlanamadı. Tekrar deneyin.',
      );
      await _repository.saveJob(job);
      throw VisualSearchException(
        VisualSearchErrorCode.analysisFailed,
        job.errorMessage ?? error.toString(),
      );
    }
  }

  Future<List<VisualSearchJob>> history({
    String? userId,
    VisualSearchJobType? type,
  }) {
    return _repository.listJobs(userId: userId, type: type);
  }

  Future<VisualSearchJob?> job(String id) => _repository.getJob(id);

  Future<void> delete(String id) async {
    VisualSearchImageMemory.remove(id);
    await _repository.deleteJob(id);
  }

  Future<void> sendFeedback({
    required String jobId,
    required String feedbackType,
    String? userId,
    String? note,
  }) {
    return _repository.saveFeedback(
      VisualSearchFeedback(
        id: newVisualSearchId(),
        userId: userId,
        jobId: jobId,
        feedbackType: feedbackType,
        note: note,
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }

  void _validate(Uint8List bytes, String fileName) {
    if (bytes.isEmpty) {
      throw const VisualSearchException(
        VisualSearchErrorCode.emptyFile,
        'Fotoğraf okunamadı. Başka bir görsel seçin.',
      );
    }
    if (bytes.length > maxBytes) {
      throw const VisualSearchException(
        VisualSearchErrorCode.fileTooLarge,
        'Fotoğraf 8 MB sınırını aşıyor. Daha küçük bir görsel seçin.',
      );
    }
    final extension = _extension(fileName);
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if (extension.isNotEmpty && !allowed.contains(extension)) {
      throw const VisualSearchException(
        VisualSearchErrorCode.unsupportedType,
        'Bu dosya türü desteklenmiyor. JPG, PNG veya WEBP seçin.',
      );
    }
  }

  String? _previewUrl(Uint8List bytes, String fileName) {
    if (bytes.length > previewByteLimit) return null;
    final mime = _extension(fileName) == 'png' ? 'image/png' : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }
}
